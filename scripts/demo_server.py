"""Serve the local demo and restart only the dedicated SLAM container on request."""

import argparse
import json
import re
import shutil
import subprocess
import tempfile
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


REPO_ROOT = Path(__file__).resolve().parent.parent
ROBOT_HOST = "192.168.123.50"
HOST_KEY = "SHA256:Zeb1VsTQD2oPrjjh8ncG6O2j3/HQE8T3wTMNHBDK6vU"
RESET_LOCK = threading.Lock()


def reset_map():
    plink = shutil.which("plink.exe")
    if not plink:
        raise RuntimeError("A PuTTY plink.exe nem található.")
    readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    match = re.search(r"\| Sudo jelszó \| `([^`]+)`", readme)
    if not match:
        raise RuntimeError("A robot hozzáférési adata hiányzik.")
    password = match.group(1)
    with tempfile.TemporaryDirectory(prefix="pickerbot-map-reset-") as temp_dir:
        password_file = Path(temp_dir) / "password.txt"
        password_file.write_text(password + "\n", encoding="utf-8")
        command = [
            plink, "-ssh", "-batch", "-l", "wheeltec", "-pwfile", str(password_file),
            "-hostkey", HOST_KEY, ROBOT_HOST,
            "sudo -S -k -p '' docker restart pickerbot-slam",
        ]
        result = subprocess.run(
            command, input=password + "\n", text=True, capture_output=True,
            timeout=35, check=False,
        )
    if result.returncode != 0 or result.stdout.strip() != "pickerbot-slam":
        raise RuntimeError("A SLAM-konténer újraindítása nem sikerült.")


class DemoHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(REPO_ROOT), **kwargs)

    def end_headers(self):
        self.send_header("X-Content-Type-Options", "nosniff")
        super().end_headers()

    def respond_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if urlsplit(self.path).path != "/api/reset-map":
            self.respond_json(404, {"ok": False, "error": "Ismeretlen művelet."})
            return
        allowed_origin = "http://127.0.0.1:8902"
        if (self.headers.get("Host") != "127.0.0.1:8902"
                or self.headers.get("Origin") != allowed_origin
                or self.headers.get("X-Pickerbot-Action") != "reset-map"
                or self.headers.get("Content-Length") != "0"):
            self.respond_json(403, {"ok": False, "error": "A kérés nem engedélyezett."})
            return
        if not RESET_LOCK.acquire(blocking=False):
            self.respond_json(409, {"ok": False, "error": "A térkép újraindítása már folyamatban van."})
            return
        try:
            reset_map()
            self.respond_json(200, {"ok": True})
        except (OSError, RuntimeError, subprocess.TimeoutExpired):
            self.respond_json(502, {"ok": False, "error": "A térkép újraindítása nem sikerült. Ellenőrizd a robot és a SLAM-konténer kapcsolatát."})
        finally:
            RESET_LOCK.release()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8902)
    args = parser.parse_args()
    ThreadingHTTPServer(("127.0.0.1", args.port), DemoHandler).serve_forever()

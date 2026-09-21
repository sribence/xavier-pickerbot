"""Serve the local demo and restart only the dedicated SLAM container on request."""

import argparse
import http.client
import json
import re
import shutil
import socket
import subprocess
import tempfile
import threading
import time
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


REPO_ROOT = Path(__file__).resolve().parent.parent
ROBOT_HOST = "192.168.123.50"
HOST_KEY = "SHA256:Zeb1VsTQD2oPrjjh8ncG6O2j3/HQE8T3wTMNHBDK6vU"
RESET_LOCK = threading.Lock()


class ResetError(RuntimeError):
    """A hiba felhasználónak szánt, jelszót és nyers hibakimenetet nem tartalmazó szövege."""


ACCESS_DIR = Path.home() / "Documents" / "Codex" / "pickerbot-access"
RESTART_CMD = "sudo -S -k -p '' docker restart pickerbot-slam"


def _readable(path):
    try:
        with open(path, "rb"):
            return True
    except OSError:
        return False


def classify_failure(returncode, stdout, stderr):
    """Pontos, felhasználóbarát ok a sikertelen újraindításhoz (nyers kimenetet nem adunk vissza)."""
    err = (stderr or "").lower()
    if "incorrect password" in err or "sorry, try again" in err or "no tty present" in err:
        return "A robot sudo-jelszava nem egyezik a README-ben lévővel."
    if "host key verification failed" in err or "remote host identification has changed" in err:
        return "A robot hostkulcsa nem egyezik a mentettel (known_hosts)."
    if "permission denied" in err and "docker" not in err:
        return "Az SSH-belépés elutasítva (kulcs vagy jelszó)."
    if "no such container" in err:
        return "A pickerbot-slam konténer nem létezik a roboton."
    if "connection timed out" in err or "no route to host" in err or "network is unreachable" in err or "connection refused" in err:
        return "A robot nem érhető el a hálózaton (192.168.123.50)."
    if returncode == 0 and (stdout or "").strip() != "pickerbot-slam":
        return "A robot váratlan választ adott az újraindításra."
    return "A SLAM-konténer újraindítása nem sikerült (ismeretlen ok)."


def reset_map():
    readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    match = re.search(r"\| Sudo jelszó \| `([^`]+)`", readme)
    if not match:
        raise ResetError("A README-ben nincs Sudo jelszó sor.")
    password = match.group(1)
    key = ACCESS_DIR / "pickerbot_mini"
    known_hosts = ACCESS_DIR / "known_hosts"

    if _readable(key) and known_hosts.exists():
        ssh = shutil.which("ssh.exe") or shutil.which("ssh")
        if not ssh:
            raise ResetError("Az ssh.exe nem található.")
        command = [
            ssh, "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes",
            "-o", f"UserKnownHostsFile={known_hosts}", "-o", "ConnectTimeout=10",
            "-i", str(key), f"wheeltec@{ROBOT_HOST}", RESTART_CMD,
        ]
        result = subprocess.run(
            command, input=password + "\n", text=True, capture_output=True,
            timeout=35, check=False,
        )
    else:
        plink = shutil.which("plink.exe")
        if not plink:
            raise ResetError("Sem olvasható SSH-kulcs, sem PuTTY plink.exe nincs.")
        with tempfile.TemporaryDirectory(prefix="pickerbot-map-reset-") as temp_dir:
            password_file = Path(temp_dir) / "password.txt"
            password_file.write_text(password + "\n", encoding="utf-8")
            command = [
                plink, "-ssh", "-batch", "-l", "wheeltec", "-pwfile", str(password_file),
                "-hostkey", HOST_KEY, ROBOT_HOST, RESTART_CMD,
            ]
            result = subprocess.run(
                command, input=password + "\n", text=True, capture_output=True,
                timeout=35, check=False,
            )
    if result.returncode != 0 or result.stdout.strip() != "pickerbot-slam":
        raise ResetError(classify_failure(result.returncode, result.stdout, result.stderr))


class CameraRelay:
    """Egyetlen felfelé irányuló MJPEG-kapcsolat a robot felé, tetszőleges számú böngészőfülnek.

    A robot web_video_servere minden kliensnek külön kódolja és küldi a 640x480-as folyamot (kb. 4 Mbit/s
    fülenként), ezért több nyitott fülnél a kép elmaradt. A relé egyszer olvassa a folyamot, és minden
    kliensnek mindig a legfrissebb képkockát adja; a lassú kliens képkockákat hagy ki, régi képet nem kap.
    Kliens nélkül IDLE_SECONDS után lezárja a robot felé a kapcsolatot.
    """

    IDLE_SECONDS = 15

    def __init__(self, host, port, path):
        self.host, self.port, self.path = host, port, path
        self.cond = threading.Condition()
        self.frame = None
        self.seq = 0
        self.clients = 0
        self.thread = None
        self.idle_since = time.monotonic()

    def acquire(self):
        with self.cond:
            self.clients += 1
            if self.thread is None or not self.thread.is_alive():
                self.thread = threading.Thread(target=self._run, name="camera-relay", daemon=True)
                self.thread.start()

    def release(self):
        with self.cond:
            self.clients -= 1
            if self.clients <= 0:
                self.clients = 0
                self.idle_since = time.monotonic()

    def next_frame(self, last_seq, timeout):
        with self.cond:
            ok = self.cond.wait_for(lambda: self.frame is not None and self.seq != last_seq, timeout)
            if not ok:
                return None
            return self.seq, self.frame

    def _idle_expired(self):
        with self.cond:
            return self.clients == 0 and time.monotonic() - self.idle_since > self.IDLE_SECONDS

    def _run(self):
        while not self._idle_expired():
            try:
                self._stream_once()
            except (OSError, http.client.HTTPException, ValueError):
                pass
            with self.cond:
                self.frame = None
                self.cond.notify_all()
            time.sleep(1)

    def _stream_once(self):
        conn = http.client.HTTPConnection(self.host, self.port, timeout=10)
        try:
            conn.request("GET", self.path)
            resp = conn.getresponse()
            if resp.status != 200:
                raise OSError("A videószerver nem 200-as választ adott.")
            while True:
                length = None
                while True:
                    line = resp.readline()
                    if not line:
                        raise OSError("A videófolyam lezárult.")
                    text = line.strip().lower()
                    if text.startswith(b"content-length:"):
                        length = int(text.split(b":", 1)[1])
                    elif text == b"" and length is not None:
                        break
                data = resp.read(length)
                if len(data) != length:
                    raise OSError("Csonka képkocka.")
                with self.cond:
                    self.frame = data
                    self.seq += 1
                    self.cond.notify_all()
                if self._idle_expired():
                    return
        finally:
            conn.close()


RELAY = None
UPSTREAM_PATH = "/stream?topic=/usb_cam/image_raw&type=mjpeg&quality=55"


class DemoHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(REPO_ROOT), **kwargs)

    def end_headers(self):
        self.send_header("X-Content-Type-Options", "nosniff")
        # A böngésző mindig érvényesítse újra a fájlokat, különben egy régi oldal maradhat meg (F5 nélkül).
        if not any(line.lower().startswith(b"cache-control") for line in getattr(self, "_headers_buffer", [])):
            self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def respond_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if urlsplit(self.path).path == "/cam/c70.mjpg":
            self.serve_camera()
            return
        super().do_GET()

    def serve_camera(self):
        if RELAY is None:
            self.respond_json(404, {"ok": False, "error": "A kamerarelé nincs bekapcsolva."})
            return
        RELAY.acquire()
        try:
            item = RELAY.next_frame(0, 8)
            if item is None:
                self.respond_json(502, {"ok": False, "error": "A kamerafolyam nem érhető el (alagút vagy robot)."})
                return
            try:
                # Kicsi küldőpuffer: egy lassú (pl. háttérben lévő) fül mögött ne halmozódjanak régi képkockák.
                self.connection.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 32768)
            except OSError:
                pass
            self.send_response(200)
            self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=frame")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            while item is not None:
                seq, frame = item
                head = b"--frame\r\nContent-Type: image/jpeg\r\nContent-Length: " + str(len(frame)).encode() + b"\r\n\r\n"
                self.wfile.write(head + frame + b"\r\n")
                self.wfile.flush()
                item = RELAY.next_frame(seq, 10)
        except OSError:
            pass  # a böngésző bezárta a folyamot
        finally:
            RELAY.release()

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
        except ResetError as error:
            self.respond_json(502, {"ok": False, "error": str(error)})
        except subprocess.TimeoutExpired:
            self.respond_json(502, {"ok": False, "error": "Időtúllépés: a robot 35 másodpercen belül nem válaszolt."})
        except OSError:
            self.respond_json(502, {"ok": False, "error": "A helyi SSH-program nem indítható."})
        finally:
            RESET_LOCK.release()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8902)
    parser.add_argument("--upstream-port", type=int, default=8080, help="A robot videószerverét adó helyi alagút portja.")
    args = parser.parse_args()
    RELAY = CameraRelay("127.0.0.1", args.upstream_port, UPSTREAM_PATH)
    ThreadingHTTPServer(("127.0.0.1", args.port), DemoHandler).serve_forever()

import os, socket, threading, requests
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
PORT = 9090
DL = "/sdcard/Download"
RPI = 12800
ps4_ip = input("IP PS4: ").strip()
p = input("PKG path: ").strip().rstrip("/")
path = p if p.startswith("/") else os.path.join(DL, p)
if not os.path.isfile(path):
    raise SystemExit("File not found: " + path)
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.connect((ps4_ip, RPI))
phone_ip = s.getsockname()[0]
s.close()
size = os.path.getsize(path)
name = os.path.basename(path)
class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, f, *a):
        print("[PS4]", self.command, self.headers.get("Range", ""))
    def _send(self, body):
        start, end, code = 0, size - 1, 200
        r = self.headers.get("Range")
        if r and r.startswith("bytes="):
            a, _, b = r[6:].partition("-")
            if a: start = int(a)
            if b: end = min(int(b), size - 1)
            code = 206
        self.send_response(code)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(end - start + 1))
        if code == 206:
            self.send_header("Content-Range", "bytes %d-%d/%d" % (start, end, size))
        self.end_headers()
        if not body:
            return
        try:
            with open(path, "rb") as f:
                f.seek(start)
                left = end - start + 1
                while left > 0:
                    d = f.read(min(1048576, left))
                    if not d: break
                    self.wfile.write(d)
                    left -= len(d)
        except (BrokenPipeError, ConnectionResetError):
            pass
    def do_GET(self): self._send(True)
    def do_HEAD(self): self._send(False)
httpd = ThreadingHTTPServer(("0.0.0.0", PORT), H)
threading.Thread(target=httpd.serve_forever, daemon=True).start()
url = "http://%s:%d/%s" % (phone_ip, PORT, name)
print("Phone IP:", phone_ip)
print("URL:", url)
try:
    r = requests.post("http://%s:%d/api/install" % (ps4_ip, RPI), json={"type": "direct", "packages": [url]}, timeout=30)
    print("PS4:", r.status_code, r.text)
except Exception as e:
    print("FAILED:", e)
input("Server running. Press Enter when download finishes.\n")
httpd.shutdown()

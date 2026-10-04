import socket
import http.server
import socketserver
import urllib.parse
import json
import urllib.request
import os

PORT = 9090

def get_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

ps4_ip = input("IP PS4: ").strip()
pkg_name = input("PKG Name: ").strip()

pkg_dir = "/sdcard/Download"
if os.path.exists(pkg_dir):
    os.chdir(pkg_dir)

phone_ip = get_ip()
pkg_url = f"http://{phone_ip}:{PORT}/{urllib.parse.quote(pkg_name)}"

payload = json.dumps({
    "type": "direct",
    "packages": [pkg_url]
}).encode('utf-8')

rpi_url = f"http://{ps4_ip}:12800/server/install"

print(f"\n[+] Phone IP: {phone_ip}")
print(f"[+] Package URL: {pkg_url}")
print(f"[+] Sending payload to PS4 ({ps4_ip}:12800)...")

try:
    req = urllib.request.Request(rpi_url, data=payload, headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=10) as response:
        print("[+] PS4 Response:", response.read().decode())
except Exception as e:
    print(f"[!] Sent/Background status: {e}")

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("", PORT), http.server.SimpleHTTPRequestHandler) as httpd:
    print(f"\n[+] Server running at port {PORT}. Press Enter when download finishes.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[-] Server stopped.")

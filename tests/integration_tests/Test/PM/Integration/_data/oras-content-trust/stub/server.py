"""Stand-in server for OrasContentTrust tests: python3 server.py <mode> <port> <seconds> [<argument>]

scoped: lists the fixture under its namespace catalog and forwards package reads to the local Zot service.
serve:  answers every GET over http with 64 bytes of "x", like a registry returning tampered content.
auth:   answers GET /v2/ over http, and every other GET with 64 bytes of "y" only when it carries one of the
        credentials Test.PM.Integration.OrasContentTrust configures (API key, bearer token, Basic user and
        password, or a Basic token), and with 401 otherwise.
stall:  answers GET /v2/ over https like a trust server, then never answers anything else. By default it uses
        the test trust server's certificate in tests/notary/certs, which is also valid for 127.0.0.1. The
        argument names another directory holding notary-server.crt and notary-server.key.
Stops after <seconds>.
"""
import base64
import http.client
import http.server
import json
import ssl
import sys
import threading
import time
from pathlib import Path

mode, port, lifetime = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])
argument = sys.argv[4] if len(sys.argv) > 4 else ""
ACCEPTED = {
    ("apikey", "stub-key"),
    ("authorization", "Bearer stub-token"),
    ("authorization", "Basic " + base64.b64encode(b"stub-user:stub-pass").decode()),
    ("authorization", "Basic stub-basic-token"),
}


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if mode == "scoped":
            if self.path in ("/v2/_catalog", f"/v2/{argument}/_catalog"):
                packages = [] if self.path == "/v2/_catalog" else [f"{argument}/trust-app"]
                data = json.dumps({"repositories": packages}).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            elif self.path == "/v2/" or self.path.startswith(f"/v2/{argument}/"):
                upstream = http.client.HTTPConnection("oras", 5000, timeout=10)
                try:
                    upstream.request("GET", self.path, headers={"Accept": self.headers.get("Accept", "*/*")})
                    response = upstream.getresponse()
                    self.send_response(response.status)
                    for key in ("Content-Type", "Content-Length", "Docker-Content-Digest"):
                        if response.getheader(key):
                            self.send_header(key, response.getheader(key))
                    self.end_headers()
                    self.wfile.write(response.read())
                finally:
                    upstream.close()
            else:
                self.send_error(404)
            return
        if mode == "stall" and self.path != "/v2/":
            time.sleep(lifetime)
            return
        if mode == "auth" and self.path != "/v2/":
            headers = {(name.lower(), value) for name, value in self.headers.items()}
            if not headers & ACCEPTED:
                self.send_response(401)
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
        data = b"{}" if self.path == "/v2/" else (b"y" if mode == "auth" else b"x") * 64
        self.send_response(200)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


server = http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler)
server.daemon_threads = True
if mode == "stall":
    certs = Path(argument) if argument else Path(__file__).resolve().parents[7] / "notary" / "certs"
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certs / "notary-server.crt", certs / "notary-server.key")
    server.socket = context.wrap_socket(server.socket, server_side=True)
threading.Timer(lifetime, server.shutdown).start()
server.serve_forever()

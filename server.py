from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import mimetypes
import os
import socket
import sys
import webbrowser


ROOT = Path(__file__).resolve().parent
OUTPUTS = ROOT / "outputs"
HOST = "127.0.0.1"
DEFAULT_PORT = 8765


class StockHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(OUTPUTS), **kwargs)

    def route_request(self):
        if self.path in {"/", ""}:
            self.path = "/stock-watch-five-versions.html"
        if self.path == "/favicon.ico":
            self.send_response(204)
            self.end_headers()
            return False
        return True

    def do_GET(self):
        if not self.route_request():
            return
        return super().do_GET()

    def do_HEAD(self):
        if not self.route_request():
            return
        return super().do_HEAD()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stdout.write("%s - %s\n" % (self.address_string(), fmt % args))


def find_port(start):
    port = start
    while port < start + 50:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                sock.bind((HOST, port))
            except OSError:
                port += 1
                continue
        return port
    raise RuntimeError("Could not find an open local port.")


def main():
    mimetypes.add_type("text/html; charset=utf-8", ".html")
    port = int(os.environ.get("STOCK_FIVE_PORT", DEFAULT_PORT))
    port = find_port(port)
    url = f"http://{HOST}:{port}/"

    server = ThreadingHTTPServer((HOST, port), StockHandler)
    print(f"Stock Five server running at {url}")
    print("Press Ctrl+C to stop.")
    webbrowser.open(url)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping Stock Five server.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

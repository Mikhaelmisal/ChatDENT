"""Serve Flutter web on all interfaces. Default: build/web on port 8787."""
from __future__ import annotations

import http.server
import os
import socketserver
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "build" / "web"
PORT = int(os.environ.get("CHATDENT_WEB_PORT", "8787"))


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, fmt: str, *args) -> None:
        print("[%s] %s" % (self.log_date_time_string(), fmt % args))


class ReuseTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


def main() -> None:
    if not (ROOT / "index.html").is_file():
        raise SystemExit(f"Missing {ROOT / 'index.html'} — run: flutter build web --release")
    with ReuseTCPServer(("0.0.0.0", PORT), Handler) as httpd:
        print(f"ChatDENT web: http://127.0.0.1:{PORT}")
        print(f"Serving {ROOT}")
        httpd.serve_forever()


if __name__ == "__main__":
    main()

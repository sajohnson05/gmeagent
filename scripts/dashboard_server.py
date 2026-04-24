"""
GME Agent Dashboard Server
Serves the dashboard at http://localhost:8766
Run: python scripts/dashboard_server.py
Note: Uses port 8766 so it can run alongside the Finance Agent dashboard (8765)
"""

import http.server
import socketserver
import os
from pathlib import Path

PORT = 8766
ROOT = Path(__file__).parent.parent

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def log_message(self, format, *args):
        pass

if __name__ == "__main__":
    os.chdir(ROOT)
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"\n  GME Agent Dashboard")
        print(f"  http://localhost:{PORT}/dashboard/index.html")
        print(f"\n  Ctrl+C to stop\n")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n  Server stopped.")

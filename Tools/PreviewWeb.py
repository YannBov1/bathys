"""Local Web export preview, optionally delaying the pack for loading-screen QA."""
import argparse
import functools
import http.server
from pathlib import Path
import time

parser = argparse.ArgumentParser()
parser.add_argument("--port", type=int, default=8765)
parser.add_argument("--pack-delay", type=float, default=0.0)
args = parser.parse_args()


class PreviewHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.split("?", 1)[0].endswith(".pck"):
            time.sleep(max(0.0, args.pack_delay))
        super().do_GET()


directory = Path(__file__).resolve().parent.parent / "WebBuild"
handler = functools.partial(PreviewHandler, directory=str(directory))
with http.server.ThreadingHTTPServer(("127.0.0.1", args.port), handler) as server:
    print(f"Bathys preview: http://127.0.0.1:{args.port}/", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass

"""A stand-in for GitHub in the station boot test: the repository list of the API and git over
dumb HTTP. It reads its state at every request, so the test changes it by writing files:

  STATE/token       the one token it accepts
  STATE/repos.json  [{"name", "private", "fork"}], the user's repositories
  GIT/<name>.git    bare repositories, made ready for dumb HTTP with update-server-info

The list takes the token as a bearer header, and a private repository takes it as the password
of basic auth, as GitHub does. A repository that leaves the list stays in GIT"""

import base64
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

state, git, base, port = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], int(sys.argv[4])


def repos():
    return json.loads((state / "repos.json").read_text())


class Handler(BaseHTTPRequestHandler):
    def send(self, code, body, kind="application/json", headers=()):
        self.send_response(code)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        for name, value in headers:
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        token = (state / "token").read_text().strip()
        url = urlparse(self.path)
        if url.path == "/user/repos":
            if self.headers.get("Authorization") != f"Bearer {token}":
                return self.send(401, b'{"message": "Bad credentials"}')
            query = parse_qs(url.query)
            page = int(query.get("page", ["1"])[0])
            size = int(query.get("per_page", ["30"])[0])
            listed = [
                {
                    **repo,
                    "clone_url": f"{base}/git/{repo['name']}.git",
                    "html_url": f"{base}/{repo['name']}",
                }
                for repo in repos()[(page - 1) * size : page * size]
            ]
            return self.send(200, json.dumps(listed).encode())
        parts = url.path.split("/", 3)
        if len(parts) < 4 or parts[1] != "git":
            return self.send(404, b"{}")
        name = parts[2].removesuffix(".git")
        private = next((r["private"] for r in repos() if r["name"] == name), True)
        if private:
            expected = base64.b64encode(f"x-access-token:{token}".encode()).decode()
            if self.headers.get("Authorization") != f"Basic {expected}":
                return self.send(401, b"", "text/plain", [("WWW-Authenticate", 'Basic realm="git"')])
        path = (git / parts[2] / parts[3]).resolve()
        if not path.is_relative_to(git) or not path.is_file():
            return self.send(404, b"", "text/plain")
        self.send(200, path.read_bytes(), "application/octet-stream")


ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()

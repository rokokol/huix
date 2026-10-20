"""Stands in for the GitHub API: answers each request with the token it came with.

The station test points the agent's GitHub proxy here, so it can tell which token the proxy
chose for a path without a token ever reaching the session.
"""

import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


class Echo(BaseHTTPRequestHandler):
    def answer(self):
        body = json.dumps(
            {
                "path": self.path,
                "authorization": self.headers.get("Authorization", ""),
            }
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    do_GET = answer
    do_POST = answer
    do_PATCH = answer


HTTPServer(("127.0.0.1", int(sys.argv[1])), Echo).serve_forever()

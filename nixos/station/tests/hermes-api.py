"""Local stand-in for the OpenRouter and Telegram APIs in Hermes tests"""

import base64
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import re
import sys
import time
from typing import Any


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        if not self.path.endswith("/getUpdates"):
            super().log_message(format, *args)

    def answer(self, data):
        encoded = json.dumps(data).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self):
        if self.path.endswith("/key"):
            self.answer({"data": {"usage": 0.01, "usage_daily": 0.01, "usage_weekly": 0.01,
                                  "usage_monthly": 0.01, "limit": 10, "limit_remaining": 9.99, "budgets": []}})
        elif self.path.endswith("/credits"):
            self.answer({"data": {"total_credits": 100, "total_usage": 10}})
        else:
            self.answer({"data": []})

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        data: dict[str, Any]
        if "json" in self.headers.get("Content-Type", ""):
            data = json.loads(body or b"{}")
        else:
            import urllib.parse
            data = {key: values[0] for key, values in urllib.parse.parse_qs(body.decode()).items()}

        if self.path.endswith("/getMe"):
            self.answer({"ok": True, "result": {
                "id": 123456789, "is_bot": True, "first_name": "Hermes test", "username": "HermesTestBot",
            }})
        elif self.path.endswith("/getWebhookInfo"):
            self.answer({"ok": True, "result": {
                "url": "", "has_custom_certificate": False, "pending_update_count": 0,
            }})
        elif self.path.endswith("/getUpdates"):
            time.sleep(0.2)
            self.answer({"ok": True, "result": []})
        elif self.path.endswith(("/sendMessage", "/sendRichMessage")):
            self.answer({"ok": True, "result": {
                "message_id": 1, "date": int(time.time()),
                "chat": {"id": int(data.get("chat_id", 1)), "type": "private"},
                "text": data.get("text", "Sent"),
            }})
        elif self.path.endswith("/chat/completions"):
            messages = data.get("messages", [])
            content = str(next((item.get("content", "") for item in reversed(messages) if item.get("role") == "user"), ""))
            command = re.search(r"RUN:([A-Za-z0-9+/=]+)", content)
            delta = {"role": "assistant", "content": "Acknowledged" if data.get("tools") else "APPROVE"}
            reason = "stop"
            if command and data.get("tools") and messages[-1].get("role") != "tool":
                delta = {"role": "assistant", "tool_calls": [{
                    "index": 0, "id": "call_test", "type": "function", "function": {
                        "name": "terminal",
                        "arguments": json.dumps({"command": base64.b64decode(command[1]).decode(), "timeout": 30}),
                    },
                }]}
                reason = "tool_calls"
            usage = {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15, "cost": 0.01}
            reply = {"id": "chatcmpl-test", "object": "chat.completion", "created": int(time.time()),
                     "model": data.get("model", "test"), "choices": [{"index": 0, "message": delta, "finish_reason": reason}], "usage": usage}
            if data.get("stream"):
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.end_headers()
                reply["object"] = "chat.completion.chunk"
                reply["choices"][0]["delta"] = reply["choices"][0].pop("message")
                self.wfile.write(("data: " + json.dumps(reply) + "\n\ndata: [DONE]\n\n").encode())
            else:
                self.answer(reply)
        else:
            self.answer({"ok": True, "result": True})


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", int(sys.argv[1])), Handler).serve_forever()

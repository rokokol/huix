#!/usr/bin/env python3
"""Deliver an alert to the local Hermes webhook with a timestamp-bound HMAC"""

import argparse
import hashlib
import hmac
import json
from pathlib import Path
import time
import urllib.request
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--secret-file", required=True, type=Path)
    parser.add_argument("--url", required=True)
    parser.add_argument("text", nargs="+")
    args = parser.parse_args()
    body = json.dumps({"text": " ".join(args.text)}).encode()
    timestamp = str(int(time.time()))
    signature = hmac.new(
        args.secret_file.read_bytes().strip(), timestamp.encode() + b"." + body, hashlib.sha256
    ).hexdigest()
    request = urllib.request.Request(
        args.url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "X-Webhook-Timestamp": timestamp,
            "X-Webhook-Signature-V2": signature,
            "X-Request-ID": str(uuid.uuid4()),
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        response.read()


if __name__ == "__main__":
    main()

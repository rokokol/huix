#!/usr/bin/env python3
"""Synthesize an input text file to MP3 through OpenRouter's speech endpoint."""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

API = "https://openrouter.ai/api/v1/audio/speech"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", required=True)
    parser.add_argument("--voice", required=True)
    parser.add_argument("input_path", type=Path)
    parser.add_argument("output_path", type=Path)
    args = parser.parse_args()

    key = os.environ.get("OPENROUTER_API_KEY")
    if not key:
        parser.error("OPENROUTER_API_KEY is missing")
    text = args.input_path.read_text(encoding="utf-8").strip()
    if not text:
        parser.error("input text is empty")

    body = {
        "model": args.model,
        "input": text,
        "voice": args.voice,
        "response_format": "mp3",
    }
    request = urllib.request.Request(
        API,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            if response.headers.get_content_type() != "audio/mpeg":
                raise ValueError("OpenRouter did not return MP3 audio")
            audio = response.read()
    except urllib.error.HTTPError as error:
        detail = error.read(500).decode("utf-8", errors="replace")
        sys.exit(f"OpenRouter TTS returned HTTP {error.code}: {detail}")
    except (urllib.error.URLError, TimeoutError, ValueError) as error:
        sys.exit(f"OpenRouter TTS failed: {error}")
    if not audio:
        sys.exit("OpenRouter TTS returned empty audio")
    args.output_path.write_bytes(audio)


if __name__ == "__main__":
    main()

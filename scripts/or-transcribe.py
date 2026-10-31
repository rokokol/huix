#!/usr/bin/env python3
"""Transcribe audio files through the OpenRouter transcriptions endpoint.

Converts input to 16 kHz mono 16-bit PCM, splits long audio at quiet points,
sends each piece to one model, and prints the joined transcript on stdout.

Requires: python3 (stdlib only), ffmpeg/ffprobe on PATH, OPENROUTER_API_KEY in
the environment, and network access to openrouter.ai.
"""
import argparse
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

API = "https://openrouter.ai/api/v1/audio/transcriptions"


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def duration(path):
    out = run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
               "-of", "default=nw=1:nk=1", path]).stdout.strip()
    try:
        return float(out)
    except ValueError:
        sys.exit(f"or-transcribe: ffprobe did not report a duration for {path}")


def silences(path, noise_db, min_silence):
    """Return [(start, end)] of detected silences."""
    err = run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af",
               f"silencedetect=noise={noise_db}dB:d={min_silence}", "-f", "null", "-"]).stderr
    starts = [float(m) for m in re.findall(r"silence_start: ([0-9.]+)", err)]
    ends = [float(m) for m in re.findall(r"silence_end: ([0-9.]+)", err)]
    spans = []
    for i, s in enumerate(starts):
        e = ends[i] if i < len(ends) else s
        spans.append((s, e))
    return spans


def boundaries(total, chunk_sec, spans):
    """Cut points near each multiple of chunk_sec, moved onto a silence midpoint."""
    if total <= chunk_sec:
        return [0.0, total]
    mids = [(s + e) / 2.0 for s, e in spans]
    cuts = [0.0]
    target = chunk_sec
    slack = chunk_sec * 0.15
    while target < total - 1.0:
        near = [m for m in mids if abs(m - target) <= slack]
        cut = min(near, key=lambda m: abs(m - target)) if near else target
        if cut - cuts[-1] >= 1.0:
            cuts.append(cut)
        target = cut + chunk_sec if near else target + chunk_sec
    cuts.append(total)
    return cuts


def extract(src, start, end, dst):
    run(["ffmpeg", "-hide_banner", "-v", "error", "-ss", f"{start:.3f}", "-t",
         f"{end - start:.3f}", "-i", src, "-ar", "16000", "-ac", "1",
         "-acodec", "pcm_s16le", "-y", dst], check=True)
    return dst


def post(key, model, wav, language, zdr, prompt):
    with open(wav, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    body = {"model": model, "input_audio": {"data": b64, "format": "wav"}}
    if language:
        body["language"] = language
    if prompt:
        body["prompt"] = prompt
    if zdr:
        body["provider"] = {"zdr": True}
    req = urllib.request.Request(
        API, data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                data = json.loads(r.read())
            return data.get("text", ""), (data.get("usage") or {}).get("cost") or 0.0, None
        except urllib.error.HTTPError as e:
            msg = e.read()[:300].decode(errors="replace")
            if e.code in (429, 500, 502, 503, 504):
                time.sleep(2 + 2 * attempt)
                continue
            return "", 0.0, msg
        except Exception as e:
            if attempt == 2:
                return "", 0.0, repr(e)[:160]
            time.sleep(2)
    return "", 0.0, "retries exhausted"


def transcribe_file(key, path, args, workdir):
    total = duration(path)
    spans = silences(path, args.silence_db, args.silence_len)
    cuts = boundaries(total, args.chunk_sec, spans)
    parts, cost = [], 0.0
    for i, (start, end) in enumerate(zip(cuts, cuts[1:]), 1):
        wav = extract(path, start, end, os.path.join(workdir, f"part{i:03d}.wav"))
        if len(cuts) > 2:
            log(f"  part {i}/{len(cuts) - 1}: {start:.1f}-{end:.1f}s")
        text, c, err = post(key, args.model, wav, args.language, not args.no_zdr, args.prompt)
        cost += c
        if err and not text:
            log(f"or-transcribe: part {i} failed: {err}")
            return None, cost, total, err
        parts.append(text.strip())
    return "\n".join(p for p in parts if p), cost, total, None


def main():
    ap = argparse.ArgumentParser(
        description="Transcribe audio through the OpenRouter transcriptions endpoint",
        epilog="Prints the transcript on stdout; progress and errors go to stderr. "
               "With no file it reads the path list from stdin, one per line.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    ap.add_argument("audio", nargs="*", help="audio file(s); anything ffmpeg opens")
    ap.add_argument("--model", required=True, help="OpenRouter model id")
    ap.add_argument("--language", default="ru",
                    help="ISO-639-1 hint; 'auto' to let the model decide")
    ap.add_argument("--prompt", default="", help="vocabulary/spelling hint passed to the model")
    ap.add_argument("--no-zdr", action="store_true",
                    help="allow providers that keep the audio (ZDR is on by default)")
    ap.add_argument("--chunk-sec", type=float, default=300.0,
                    help="longest piece sent in one request")
    ap.add_argument("--silence-db", type=float, default=-30.0, help="silence threshold")
    ap.add_argument("--silence-len", type=float, default=0.3, help="minimum silence length")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of plain text")
    ap.add_argument("--cost", action="store_true", help="print cost and duration to stderr")
    args = ap.parse_args()

    files = args.audio or [line.strip() for line in sys.stdin if line.strip()]
    if not files:
        ap.error("no audio file given")
    missing = [f for f in files if not os.path.isfile(f)]
    if missing:
        sys.exit(f"or-transcribe: no such file: {', '.join(missing)}")

    key = os.environ.get("OPENROUTER_API_KEY")
    if not key:
        sys.exit("or-transcribe: OPENROUTER_API_KEY is not set")
    if args.language in ("auto", "-"):
        args.language = ""

    results, total_cost, failed = [], 0.0, 0
    for path in files:
        if len(files) > 1:
            log(f"{path}:")
        with tempfile.TemporaryDirectory(prefix="or-transcribe-") as workdir:
            text, cost, total, err = transcribe_file(key, path, args, workdir)
        total_cost += cost
        if text is None:
            failed += 1
            results.append({"file": path, "text": "", "error": err})
            continue
        results.append({"file": path, "text": text, "seconds": round(total, 1)})
        if len(files) > 1 and not args.json:
            print(text)
        if args.cost:
            log(f"or-transcribe: {total:.0f} s of audio, ${cost:.6f}, model {args.model}")

    if args.json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
    elif len(files) == 1 and results[0]["text"]:
        print(results[0]["text"])
    if args.cost and len(files) > 1:
        log(f"or-transcribe: total ${total_cost:.6f}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()

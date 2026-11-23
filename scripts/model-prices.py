#!/usr/bin/env python3
"""Export configured OpenRouter endpoint prices for the Prometheus textfile collector

Read model identifiers and provider tags from a JSON object of model-to-provider lists
Write USD per million tokens, endpoint availability, fetch status and collection time
Omit prices when the API does not supply a valid value or the model request fails
"""

import argparse
from decimal import Decimal, InvalidOperation
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request


KINDS = {"prompt": "input", "completion": "output", "input_cache_read": "cache_read"}
SERVICE_TIERS = {"priority", "fast", "turbo", "flex"}


def fetch(url):
    """Return the decoded API response or raise an error for the caller to report"""
    request = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def labels(**values):
    """Encode label values in the Prometheus text format"""
    def escape(value):
        return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')
    return ",".join(f'{name}="{escape(value)}"' for name, value in values.items())


def matches_route(route, endpoint):
    """Match a route to its endpoint variants without adding another service tier"""
    if endpoint == route:
        return True
    if not endpoint.startswith(route + "/"):
        return False
    return endpoint.rsplit("/", 1)[-1] not in SERVICE_TIERS


def collect(models, api):
    """Return textfile metrics for the configured models and provider tags

    A failed request emits fetch status alone. A successful response also reports whether each
    configured endpoint exists. Missing or invalid price fields produce no price series
    """
    lines = []
    for model, providers in sorted(models.items()):
        model_label = labels(model=model)
        for provider in providers:
            route_label = labels(model=model, provider=provider)
            lines.append(f"model_price_route_configured{{{route_label}}} 1")
        try:
            url = f"{api.rstrip('/')}/models/{urllib.parse.quote(model, safe='/')}/endpoints"
            endpoints = fetch(url)["data"]["endpoints"]
            if not isinstance(endpoints, list) or any(
                not isinstance(item, dict) or not isinstance(item.get("tag"), str)
                or not isinstance(item.get("pricing"), dict) for item in endpoints
            ):
                raise ValueError("invalid endpoint data")
        except (OSError, ValueError, KeyError, TypeError, urllib.error.URLError) as exc:
            print(f"{model}: {exc}", file=sys.stderr)
            lines.append(f"model_price_fetch_success{{{model_label}}} 0")
            continue
        lines.append(f"model_price_fetch_success{{{model_label}}} 1")
        for provider in providers:
            route_label = labels(model=model, provider=provider)
            matches = [item for item in endpoints if matches_route(provider, item["tag"])]
            lines.append(f"model_price_endpoint_available{{{route_label}}} {int(bool(matches))}")
            for endpoint in matches:
                pricing = endpoint["pricing"]
                for field, kind in KINDS.items():
                    try:
                        value = Decimal(str(pricing.get(field))) * 1000000
                        if not value.is_finite() or value < 0:
                            continue
                    except (InvalidOperation, ValueError):
                        continue
                    price_label = labels(model=model, provider=provider, endpoint=endpoint["tag"], kind=kind)
                    lines.append(f"model_price_usd_per_million{{{price_label}}} {value.normalize():f}")
    lines.append(f"model_price_collection_timestamp_seconds {int(time.time())}")
    return "\n".join(lines) + "\n"


def write_metrics(path, text):
    """Replace the metrics file atomically so a scrape cannot read a partial result"""
    path = Path(path)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(text)
        os.chmod(temporary, 0o644)
        os.replace(temporary, path)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def main():
    """Read the configuration and write the current collection to the textfile path"""
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--models", type=Path, required=True, help="JSON object of model-to-provider lists")
    parser.add_argument("--metrics", type=Path, required=True, help="Prometheus textfile output path")
    parser.add_argument("--api", default="https://openrouter.ai/api/v1", help="OpenRouter API base URL")
    args = parser.parse_args()
    models = json.loads(args.models.read_text())
    write_metrics(args.metrics, collect(models, args.api))


if __name__ == "__main__":
    main()

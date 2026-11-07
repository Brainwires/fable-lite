#!/usr/bin/env python3
"""fable-lite external-model policy: external routes are OFF by default.

  - Nothing routes to an external model unless the config sets "external.enabled": true.
  - A LOCAL model (served by a daemon on this machine, e.g. Ollama on localhost, without a :cloud tag)
    is refused unless the config also sets "external.allowLocalModels": true. Local models load into
    this machine's RAM (a 27B model takes ~18 GB) and can starve everything else on it.

usage:
  external-policy.py routes <config.json>               -> JSON {enabled, strict, routes, dropped, cfg}
  external-policy.py check <config.json|-> <model> <base_url>
                                                        -> exit 0 if allowed, else exit 4 with the reason on stderr
Env overrides (for one-off runs, never persisted): FABLE_LITE_EXTERNAL_ENABLED=1, FABLE_LITE_ALLOW_LOCAL_MODELS=1.
"""
import json
import os
import sys
from urllib.parse import urlparse

LOCAL_HOSTS = {"localhost", "127.0.0.1", "::1", "0.0.0.0", ""}
DEFAULT_BASE_URL = "http://localhost:11434"


def load(path):
    if not path or path == "-" or not os.path.isfile(path):
        return {}
    try:
        return json.load(open(path)).get("external", {}) or {}
    except Exception:
        return {}


def truthy_env(name):
    return os.environ.get(name, "").strip().lower() in ("1", "true", "yes", "on")


def enabled(ext):
    return bool(ext.get("enabled")) or truthy_env("FABLE_LITE_EXTERNAL_ENABLED")


def allow_local(ext):
    return bool(ext.get("allowLocalModels")) or truthy_env("FABLE_LITE_ALLOW_LOCAL_MODELS")


def is_local_model(model, base_url):
    """A model is local when the endpoint is on this machine and the model is not a cloud model."""
    host = (urlparse(base_url or DEFAULT_BASE_URL).hostname or "").lower()
    if host not in LOCAL_HOSTS:
        return False
    m = (model or "").lower()
    return not (m.endswith(":cloud") or m.endswith("-cloud"))


def effective(ext):
    base = os.environ.get("FABLE_LITE_EXTERNAL_BASE_URL") or ext.get("baseUrl") or DEFAULT_BASE_URL
    if not enabled(ext):
        return {"enabled": False, "strict": False, "routes": {}, "dropped": {}}
    routes, dropped = {}, {}
    for tier, model in (ext.get("routes") or {}).items():
        if is_local_model(model, base) and not allow_local(ext):
            dropped[tier] = model
        else:
            routes[tier] = model
    return {"enabled": True, "strict": bool(ext.get("strict")) and bool(routes), "routes": routes, "dropped": dropped}


def main(argv):
    if len(argv) >= 2 and argv[0] == "routes":
        out = effective(load(argv[1]))
        out["cfg"] = argv[1]
        print(json.dumps(out))
        return 0
    if len(argv) >= 4 and argv[0] == "check":
        ext, model, base = load(argv[1]), argv[2], argv[3]
        if not enabled(ext):
            print("external-run: external models are OFF by default. Set \"external\": {\"enabled\": true} in "
                  ".fable-lite/config.json (or ~/.claude/fable-lite.json) to use them.", file=sys.stderr)
            return 4
        if is_local_model(model, base) and not allow_local(ext):
            print(f"external-run: {model} at {base} is a LOCAL model (it loads into this machine's RAM). Local models "
                  "are off by default; use a :cloud model, or set \"external\": {\"allowLocalModels\": true} only on a "
                  "machine with the RAM for it.", file=sys.stderr)
            return 4
        return 0
    print(__doc__, file=sys.stderr)
    return 3


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

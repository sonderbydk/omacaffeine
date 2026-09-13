#!/usr/bin/env python3
"""Output tokens per hour from the coding agents on this machine.

Reads Claude Code transcripts (~/.claude/projects/**/*.jsonl) and Codex
session rollouts (~/.codex/sessions/**/*.jsonl) and prints one JSON object:

  {"hours": {"2026-09-13T09": 12345, ...},
   "sources": {"claude": 88, "codex": 3}, "skipped": 0}

Keys are local time, bucketed by hour; values are output tokens (thinking
included). `sources` counts the files that contributed at least one token
inside the window; `skipped` counts files that could not be read. Only
files touched within the requested number of days are opened.

Usage: tokens.py [days]      (default 8)
"""
import json
import os
import sys
import time
from datetime import datetime, timezone

DAYS = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 8
CUTOFF = time.time() - DAYS * 86400
HOME = os.path.expanduser("~")

hours = {}
sources = {"claude": 0, "codex": 0}
skipped = 0
# Claude message ids are global: a resumed or forked session can carry the
# same message in two files, and every content block repeats the usage.
seen_messages = set()


def as_int(value):
    try:
        n = int(value)
    except (TypeError, ValueError):
        return None
    return n if n >= 0 else None


def bucket(ts, tokens):
    """Add tokens to the local hour of `ts`; True when they landed."""
    if not tokens or tokens <= 0:
        return False
    try:
        when = datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
    except ValueError:
        return False
    if when.tzinfo is None:
        when = when.replace(tzinfo=timezone.utc)
    if when.timestamp() < CUTOFF:
        return False
    key = when.astimezone().strftime("%Y-%m-%dT%H")
    hours[key] = hours.get(key, 0) + tokens
    return True


def recent_files(root):
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            if not name.endswith(".jsonl"):
                continue
            path = os.path.join(dirpath, name)
            try:
                if os.path.getmtime(path) >= CUTOFF:
                    yield path
            except OSError:
                pass


def claude(path):
    hit = False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if '"output_tokens"' not in line:
                continue
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if not isinstance(d, dict) or d.get("type") != "assistant":
                continue
            m = d.get("message")
            if not isinstance(m, dict):
                continue
            usage = m.get("usage")
            if not isinstance(usage, dict):
                continue
            tokens = as_int(usage.get("output_tokens"))
            if tokens is None:
                continue
            mid = m.get("id")
            if mid:
                if mid in seen_messages:
                    continue
                seen_messages.add(mid)
            hit = bucket(d.get("timestamp"), tokens) or hit
    return hit


def codex(path):
    # token_count events carry a cumulative total; the difference between
    # consecutive valid events is that turn's output. Events without a
    # usable total are ignored without moving the baseline; a total that
    # goes down is a fresh counter.
    prev = None
    hit = False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if '"token_count"' not in line:
                continue
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if not isinstance(d, dict):
                continue
            payload = d.get("payload")
            if not isinstance(payload, dict) or payload.get("type") != "token_count":
                continue
            info = payload.get("info")
            usage = info.get("total_token_usage") if isinstance(info, dict) else None
            total = as_int(usage.get("output_tokens")) if isinstance(usage, dict) else None
            if total is None:
                continue
            delta = total if prev is None or total < prev else total - prev
            prev = total
            hit = bucket(d.get("timestamp"), delta) or hit
    return hit


def scan(root, reader, name):
    global skipped
    for path in recent_files(root):
        try:
            if reader(path):
                sources[name] += 1
        except (OSError, UnicodeError):
            skipped += 1


scan(os.path.join(HOME, ".claude", "projects"), claude, "claude")
scan(os.path.join(HOME, ".codex", "sessions"), codex, "codex")

json.dump({"hours": hours, "sources": sources, "skipped": skipped}, sys.stdout,
          separators=(",", ":"))

#!/usr/bin/env python3
"""Output tokens per hour from the coding agents on this machine.

Reads Claude Code transcripts (~/.claude/projects/**/*.jsonl) and Codex
session rollouts (~/.codex/sessions/**/*.jsonl) and prints one JSON object:

  {"hours": {"2026-09-13T09": 12345, ...}, "sources": {"claude": 88, "codex": 3}}

Keys are local time, bucketed by hour; values are output tokens (thinking
included). `sources` counts the files that contributed. Only files touched
within the requested number of days are opened, so a call takes well under a
second even with a large history.

Usage: tokens.py [days]      (default 8)
"""
import json
import os
import sys
import time
from datetime import datetime, timezone

DAYS = int(sys.argv[1]) if len(sys.argv) > 1 else 8
CUTOFF = time.time() - DAYS * 86400
HOME = os.path.expanduser("~")

hours = {}
sources = {"claude": 0, "codex": 0}


def bucket(ts, tokens):
    if tokens <= 0:
        return
    try:
        when = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except ValueError:
        return
    if when.tzinfo is None:
        when = when.replace(tzinfo=timezone.utc)
    if when.timestamp() < CUTOFF:
        return
    key = when.astimezone().strftime("%Y-%m-%dT%H")
    hours[key] = hours.get(key, 0) + tokens


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
    # One assistant message is written once per content block, each line
    # repeating the same usage, so count each message id once.
    seen = set()
    hit = False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if '"output_tokens"' not in line:
                continue
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if d.get("type") != "assistant":
                continue
            m = d.get("message") or {}
            usage = m.get("usage") or {}
            mid = m.get("id") or d.get("uuid")
            if mid in seen:
                continue
            seen.add(mid)
            bucket(str(d.get("timestamp", "")), int(usage.get("output_tokens") or 0))
            hit = True
    if hit:
        sources["claude"] += 1


def codex(path):
    # token_count events carry a cumulative total; the difference between
    # consecutive events is that turn's output, which survives repeats.
    prev = 0
    hit = False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if '"token_count"' not in line:
                continue
            try:
                d = json.loads(line)
            except ValueError:
                continue
            payload = d.get("payload") or {}
            if payload.get("type") != "token_count":
                continue
            info = payload.get("info") or {}
            total = int(((info.get("total_token_usage") or {}).get("output_tokens")) or 0)
            delta = total - prev if total >= prev else total
            prev = total
            bucket(str(d.get("timestamp", "")), delta)
            hit = True
    if hit:
        sources["codex"] += 1


for path in recent_files(os.path.join(HOME, ".claude", "projects")):
    claude(path)
for path in recent_files(os.path.join(HOME, ".codex", "sessions")):
    codex(path)

json.dump({"hours": hours, "sources": sources}, sys.stdout, separators=(",", ":"))

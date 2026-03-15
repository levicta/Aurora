#!/usr/bin/env python3
"""
build.py — Aurora UI Library build script
==========================================
Reads build_manifest.json, wraps each source file in an IIFE (immediately-invoked
function expression), and concatenates them into a single distributable Aurora.lua.

Each source module:
  - Ends with a `return` statement (returns the module's value).
  - May reference previously-defined locals as upvalues (Signal, Config, Utility, etc.)
    because the IIFE is evaluated in the outer scope where those locals already exist.

Usage:
  python3 build.py
  python3 build.py --out dist/Aurora.lua
  python3 build.py --minify        (strips comments, trims blank lines)
"""

import json
import os
import re
import argparse
from datetime import datetime

MANIFEST = "build_manifest.json"
SEP      = "─" * 72


def load_manifest(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def read_source(path: str) -> str:
    if not os.path.exists(path):
        raise FileNotFoundError(f"Source file not found: {path}")
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def strip_file_header(src: str) -> str:
    """Remove the leading block of -- comments that describe the file."""
    lines = src.split("\n")
    start = 0
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("--") or stripped == "":
            start = i + 1
        else:
            break
    # Keep at least the code
    trimmed = "\n".join(lines[start:]).strip()
    return trimmed


def minify(src: str) -> str:
    """Light minification: remove comment-only lines and collapse blank lines."""
    lines = []
    prev_blank = False
    for line in src.split("\n"):
        stripped = line.strip()
        if stripped.startswith("--"):
            continue
        is_blank = stripped == ""
        if is_blank and prev_blank:
            continue
        lines.append(line)
        prev_blank = is_blank
    return "\n".join(lines)


def wrap_module(name: str, src: str, comment: str, do_minify: bool) -> str:
    """Wrap a module source in an IIFE and assign its return value to `local name`."""
    body = strip_file_header(src)
    if do_minify:
        body = minify(body)

    lines = [
        f"-- {SEP}",
        f"--  {comment}",
        f"-- {SEP}",
        f"local {name} = (function()",
        body,
        f"end)()",
        "",
    ]
    return "\n".join(lines)


def build(out_path: str, do_minify: bool = False):
    manifest = load_manifest(MANIFEST)
    version  = manifest.get("version", "?.?.?")
    now      = datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")

    chunks = []

    # File header
    chunks.append("\n".join(manifest.get("preamble", [])))
    chunks.append(f"-- Built: {now}\n")

    # Module IIFEs
    for mod in manifest["modules"]:
        name    = mod["name"]
        file    = mod["file"]
        comment = mod.get("comment", name)
        src     = read_source(file)
        chunks.append(wrap_module(name, src, comment, do_minify))

    # The final local is `Aurora` — return it so loadstring(...)() works.
    chunks.append("return Aurora\n")

    output = "\n".join(chunks)

    os.makedirs(os.path.dirname(out_path) if os.path.dirname(out_path) else ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(output)

    total_lines = output.count("\n") + 1
    print(f"[Aurora build] v{version} → {out_path}  ({total_lines} lines)")
    for mod in manifest["modules"]:
        src_lines = read_source(mod["file"]).count("\n") + 1
        print(f"  {'✓':2s}  {mod['file']:<45s}  ({src_lines} lines)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Aurora UI Library build script")
    parser.add_argument("--out",     default="Aurora.lua",  help="Output file path")
    parser.add_argument("--minify",  action="store_true",   help="Strip comments and blank lines")
    args = parser.parse_args()
    build(args.out, args.minify)

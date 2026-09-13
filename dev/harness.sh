#!/usr/bin/env bash
# Render OmaCaffeine components in a standalone Quickshell window, outside
# the bar, so they can be eyeballed or screenshotted while iterating.
#
#   dev/harness.sh            # opens the window; Ctrl+C to quit
#   dev/harness.sh shot.png   # opens, screenshots the window, quits
#
# Reuses the shell's own Commons/ and Ui/ modules via symlinks so theme
# colours and fonts match the real bar.
set -euo pipefail

repo=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
shell_dir=${OMARCHY_PATH:-/usr/share/omarchy}/shell
work=$(mktemp -d "${TMPDIR:-/tmp}/omacaffeine-harness.XXXXXX")
trap 'rm -rf "$work"' EXIT

ln -s "$shell_dir/Commons" "$work/Commons"
ln -s "$shell_dir/Ui" "$work/Ui"
for f in "$repo"/*.qml "$repo"/Model.js; do
  ln -s "$f" "$work/$(basename "$f")"
done
cp "$repo/dev/Harness.qml" "$work/shell.qml"

if [[ $# -eq 0 ]]; then
  exec quickshell -p "$work"
fi

out=$1
quickshell -p "$work" >/dev/null 2>&1 &
qs=$!
sleep 2.5
geo=$(hyprctl clients -j | python3 -c '
import json, sys
for c in json.load(sys.stdin):
    if c["title"] == "OmaCaffeine harness":
        print(f"{c[\"at\"][0]},{c[\"at\"][1]} {c[\"size\"][0]}x{c[\"size\"][1]}")
        break')
if [[ -n $geo ]]; then
  grim -g "$geo" "$out" && echo "wrote $out"
else
  echo "harness window not found" >&2
fi
kill "$qs" 2>/dev/null || true

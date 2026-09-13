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
hyprctl clients -j > "$work/clients.json"
geo=$(python3 - "$work/clients.json" <<'PY'
import json, sys
for c in json.load(open(sys.argv[1])):
    if c["title"] == "OmaCaffeine harness":
        print("%d,%d %dx%d" % (c["at"][0], c["at"][1], c["size"][0], c["size"][1]))
        break
PY
)
if [[ -n $geo ]]; then
  grim -g "$geo" "$out" && echo "wrote $out"
else
  echo "harness window not found" >&2
fi
kill "$qs" 2>/dev/null || true

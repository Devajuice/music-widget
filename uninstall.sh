#!/usr/bin/env bash
# Remove the Music plugin from omarchy-shell.
set -euo pipefail

dest="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/dj.music"

omarchy plugin disable dj.music >/dev/null 2>&1 || true
rm -rf "$dest"
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

echo "Removed dj.music"

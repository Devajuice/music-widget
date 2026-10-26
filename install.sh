#!/usr/bin/env bash
# Install the Music plugin for omarchy-shell.
#
# Usage:
#   ./install.sh                     Prompt for the bar section (default: center)
#   ./install.sh --section left      Non-interactive placement
#   ./install.sh left                Same, positional form
#   MUSIC_SECTION=right ./install.sh Non-interactive via environment
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dest="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/dj.music"
section="${MUSIC_SECTION:-}"

usage() {
  cat <<'EOF'
Usage: install.sh [--section center|left|right]

Installs the dj.music plugin and places it on the Omarchy bar. With no
--section and an interactive terminal, the script asks where to put it.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--section)
      if [[ $# -lt 2 ]]; then
        echo "install: $1 needs a value (center, left, or right)" >&2
        exit 1
      fi
      section="$2"
      shift 2
      ;;
    --section=*)
      section="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "install: unknown option '$1'" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$section" ]]; then
        echo "install: unexpected argument '$1'" >&2
        usage >&2
        exit 1
      fi
      section="$1"
      shift
      ;;
  esac
done

command -v omarchy >/dev/null || {
  echo "install: omarchy is not on PATH" >&2
  exit 1
}

prompt_section() {
  local answer
  while true; do
    if ! read -r -p "Place Music on which bar section? [center/left/right] (center): " answer; then
      echo "center"
      return
    fi
    answer="${answer:-center}"
    case "${answer,,}" in
      center|left|right)
        echo "${answer,,}"
        return
        ;;
      *)
        echo "Please choose center, left, or right." >&2
        ;;
    esac
  done
}

if [[ -z "$section" ]]; then
  if [[ -t 0 ]]; then
    section="$(prompt_section)"
  else
    section="center"
    echo "No bar section given; using center."
  fi
fi

case "${section,,}" in
  center|left|right) section="${section,,}" ;;
  *)
    echo "install: invalid bar section '$section' (use center, left, or right)" >&2
    exit 1
    ;;
esac

mkdir -p "$dest"
install -m 0644 "$here/manifest.json" "$dest/manifest.json"
install -m 0644 "$here/Service.qml" "$dest/Service.qml"
install -m 0644 "$here/BarWidget.qml" "$dest/BarWidget.qml"

omarchy plugin validate "$dest"
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

# `move` keeps an existing placement up to date; `put` adds the widget the
# first time. Move first so reinstalling with a different section is a single
# layout change instead of add-then-move.
if omarchy bar move dj.music --section "$section" >/dev/null 2>&1; then
  echo "Placed dj.music in the bar's $section section"
else
  omarchy bar put dj.music --section "$section"
fi

echo
echo "Installed dj.music to $dest"
echo "Bar: left-click opens the player, middle-click toggles playback,"
echo "     right-click switches source, scroll skips tracks."
echo "If the widget does not appear, run: omarchy restart shell"

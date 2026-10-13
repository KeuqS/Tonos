#!/usr/bin/env bash
# Opens Tonos in the browser. Press Ctrl+C to stop it.
# With a file, analyzes it in the terminal:  ./tonos.sh path/to/song.mp4  [--json]

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
py="${XDG_DATA_HOME:-$HOME/.local/share}/tonos/venv/bin/python"

if [[ ! -x "$py" ]]; then
    echo "Tonos is not installed yet. Run ./install.sh first." >&2
    exit 1
fi

# The code runs from this folder; PYTHONPATH (instead of cd) keeps relative file paths working
PYTHONPATH="$here${PYTHONPATH:+:$PYTHONPATH}" exec "$py" -m tonos "$@"

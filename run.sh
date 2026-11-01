#!/bin/sh
# Run Linpad++ from the source tree (needs PyQt6, PyQt6-QScintilla and regex installed).
HERE="$(dirname "$(readlink -f "$0")")"
PYTHONPATH="$HERE${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m linpad "$@"

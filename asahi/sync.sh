#!/usr/bin/env bash
# HOME -> repo, avec staging avant remplacement; --commit reste limité au MANIFEST.
# Usage: ./sync.sh [--dry-run] [--commit]
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null || { echo "python3 requis" >&2; exit 1; }
exec python3 -B "$HERE/lib/config_io.py" sync "$@"

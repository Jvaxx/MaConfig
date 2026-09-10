#!/usr/bin/env bash
# Repo -> HOME, avec validation, staging et sauvegardes (stdlib Python).
# Usage: ./restore.sh [--dry-run] [--yes] [--link]
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null || { echo "python3 requis" >&2; exit 1; }
exec python3 -B "$HERE/lib/config_io.py" restore "$@"

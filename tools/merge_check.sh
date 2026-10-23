#!/bin/sh
# Pre-merge guard: python3 tools/merge_check.py. Run before every push of a merge.
exec python3 "$(dirname "$0")/merge_check.py" "$@"

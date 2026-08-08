#!/bin/sh

set -eu

project_root=${CLAUDE_PROJECT_DIR:-"$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"}

if ! command -v sg >/dev/null 2>&1; then
    echo "ast-grep is required for Fieldnotes edit checks. Install it with: brew install ast-grep" >&2
    exit 2
fi

if scan_output=$(sg scan \
    --config "$project_root/sgconfig.yml" \
    "$project_root/Fieldnotes" \
    "$project_root/FieldnotesTests" 2>&1); then
    exit 0
fi

printf '%s\n' "$scan_output" >&2
exit 2

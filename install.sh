#!/bin/sh

set -eu

: "${HOME:?}"

SCRIPT_NAME="$(basename "$0")" && [ "$SCRIPT_NAME" ] || {
	printf '%s: failed to determine my filename.\n' "$0" >&2
	exit 69
}

SCRIPT_DIR="$(dirname "$0")" && [ "$SCRIPT_DIR" ] || {
	printf '%s: failed to locate myself.\n' "$0" >&2
	exit 69
}

cd -P "$SCRIPT_DIR" || exit 69

git pull

find . '(' -name .git -prune ')' -o \
       '(' ! -name "$SCRIPT_NAME" -exec cp -av '{}' "$HOME" ';' ')'

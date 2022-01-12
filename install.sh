#!/bin/sh

set -eu

: "${HOME:?}"

SCRIPT_DIR="$(dirname "$0")" && [ "$SCRIPT_DIR" ] || {
	printf '%s: failed to locate myself.\n' "$0" >&2
	exit 69
}

cd -P "$SCRIPT_DIR" || exit 69

git pull

find . ! -name .git -execdir cp -av '{}' + "$HOME/"

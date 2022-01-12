#!/bin/sh

: "${HOME:?}"

REPO="$(git rev-parse --show-toplevel)" && [ "$REPO" ] || {
	printf '%s: failed to find repository.\n' "$0" >&2
	exit 69
}
readonly REPO

cd -P "$REPO" || exit 69
cp -a . "$HOME/"
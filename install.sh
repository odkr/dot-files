#!/bin/sh

set -eu

: "${HOME:?}"

dir="$(dirname "$0")"

cd -P "$dir" || exit

git pull

find . -maxdepth 1 ! -name . ! -name '.git' -name '.*' \
       -exec cp -av '{}' "$HOME" ';' 

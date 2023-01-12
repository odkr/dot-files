#!/bin/sh

cd -P "$(dirname "$0")" || exit

find . -maxdepth 1 ! -name . ! -name '.git' -name '.*' \
       -exec cp -av '{}' ~ ';' 

#!/bin/zsh

# Load ~/.profile, if it exists.
[ -e "$HOME/.profile" ] && source "$HOME/.profile"

# History
HISTFILE=~/.histfile
HISTFILESIZE=1000
HISTSIZE=1000

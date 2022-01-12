#!/bin/bash

# Load ~/.profile, if it exists.
[ -e "$HOME/.profile" ] && source "$HOME/.profile"

# History
HISTCONTROL=ignoreboth
HISTFILESIZE=1000
HISTSIZE=1000

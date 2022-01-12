#!/bin/zsh

# Load ~/.profile, if it exists.
[ -e "$HOME/.profile" ] && source "$HOME/.profile"

# History
HISTFILE=~/.histfile
HISTFILESIZE=1000
HISTSIZE=1000

##
# Your previous /Users/odin/.zprofile file was backed up as /Users/odin/.zprofile.macports-saved_2021-12-28_at_16:35:01
##

# MacPorts Installer addition on 2021-12-28_at_16:35:01: adding an appropriate PATH variable for use with MacPorts.
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
# Finished adapting your PATH environment variable for use with MacPorts.


#!/bin/zsh

#
# Settings
#

# Where to look for ZSH add-ons.
addons=("$HOME/.zsh" /usr/share /usr/local/share)


#
# Functions
#

# Source a file if it exists.
load() {
	[ -e "${1:?}" ] && source "$1"
}

# Look for a matching file and load it.
import() {
	local prefix suffix

	for prefix in $addons
	do
		[ -d "$prefix" ] || continue
		for suffix in '.zsh' '.sh' ''
		do
			local fname="$prefix/$1$suffix"

			if [ -e "$fname" ]
			then
				load "$fname"
				return
			fi
		done
	done

	return 1
}


#
# Globals
#

# Remove non-existing paths.
function() {
	local i

	for (( i=1; i<=${#addons}; i++ ))
	do
		[ -d "${addons[i]}" ] || addons[i]=()
	done
}

uid="$(id -u)"


#
# Homebrew
#

function() {
	local brew
	command -v brew >/dev/null 2>&1			|| return
	brew="$(brew --prefix)/share" 2>/dev/null	|| return
	[ "$addons[(ie)$brew]" -gt "${#addons}" ]	|| return
	addons+="$brew"
}


#
# History
#

setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt APPEND_HISTORY


#
# Key bindings
#

bindkey -e


#
# Aliases
#

load "$HOME/.aliases"


#
# Add-ons
#

import zsh-z/zsh-z.plugin
import zsh-autosuggestions/zsh-autosuggestions
import zsh-syntax-highlighting/zsh-syntax-highlighting
import zsh-history-substring-search/zsh-history-substring-search && {
	bindkey "$terminfo[kpp]" history-substring-search-up
	bindkey "$terminfo[knp]" history-substring-search-down
}


#
# Completions
#

# Load ZSH completions, if they are availabe.
function() {
	local dir

	for dir in $addons
	do
		local fname="$dir/zsh-completions"
		if [ -r "$fname" ]
		then
			FPATH="$fname:$FPATH"
			autoload -Uz compinit && compinit -u
		fi
	done
}

# Add SSH hosts.
function() (
	local ssh="$HOME/.ssh/config" hosts
	[ -e "$ssh" ] || return
	hosts=($(awk 'tolower($1) == "host" && $2 !~ /\*/ {print $2}' "$ssh"))
	[ "${#hosts}" -gt 0 ] || return
	zstyle ':completion:*:(ssh|scp|sftp):*' hosts $hosts
)


#
# Colours
#

colours="$(tput colors 2>/dev/null)" || colours=8
if [ "$colours" -ge 8 ]
then
	case $(uname -s) in
		(Darwin|DragonFly|*BSD)
			export CLICOLOR=x
			;;
		(GNU|GNU/*|Linux)
			function() {
				local dircolors="$HOME/.dircolors"
				if [ -r "$dircolors" ]
				then
					eval "$(dircolors -b "$dircolors")"
				else
					eval "$(dircolors -b)"
				fi
			}

			alias ls='ls --color=auto'
			;;
	esac

	alias grep='grep --color=auto'

	export LESS=' -R'
	if command -v highlight >/dev/null
	then
		export LESSOPEN="| highlight -i %s -O ansi"
	elif command -v src-hilite-lesspipe.sh >/dev/null
	then
		export LESSOPEN='| src-hilite-lesspipe.sh %s'
	fi

	command -v colordiff >/dev/null && alias diff=colordiff
fi


#
# iTerm2
#

if	[ "$TERM_PROGRAM" = iTerm.app ]	||
	[ "$LC_TERMINAL" = iTerm2 ]	||
	it2check 2>/dev/null
then
	iterm2=x
else
	iterm2=
fi

if [ "$iterm2" ] && load "$HOME/.iterm2_shell_integration.zsh"
then
	iterm2_print_user_vars() {
		iterm2_set_user_var debian_chroot "$debian_chroot"
	}

	__zshrc_iterm2_precmd_set_exit_status() {
		iterm2_set_user_var exit_status "$?"
	}

	precmd_functions+=__zshrc_iterm2_precmd_set_exit_status
fi


#
# Prompt
#

function() {
	if [ "$iterm2" ]; then
		PS1='%B%#%b '
	else
		case $uid in
			(0) local dir='%~'  ;;
			(*) local dir='%1~' ;;
		esac

		if [ "$colours" -ge 8 ]
			then PS1="%S$dir%s %B%#%b "
			else PS1="$dir %B%#%b "
		fi

		if [ "${SSH_CONNECTION-}" ]
			then PS1="%n@%m $PS1"
			else PS1="%n $PS1"
		fi

		[ "$debian_chroot" ] && PS1="($debian_chroot) $PS1"
	fi
}


#
# Cleanup
#

unset -f load import
unset addons colours iterm2 uid

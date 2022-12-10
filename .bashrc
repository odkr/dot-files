#!/bin/bash

#
# Settings
#

# Where to look for BASH add-ons.
addons=( "$HOME/.bash" )

# Where to look for the BASH completion file.
completions=(
	/etc /etc/profile.d /usr/share/bash-completion /usr/local/etc
	/usr/local/etc/profile.d /usr/local/share/bash-completion
)


#
# Functions
#

# Source a file if it exists.
load() {
	# shellcheck disable=1090
	[ -f "${1:?}" ] && source "$1"
}

# Look for a matching file and load it.
import() {
	local pattern="${1:?}"
	shift

	local path=("${@-${addons[@]}}")
	[ "${#path[@]}" -eq 0 ] && path=("${addons[@]}")

	local prefix
	for prefix in "${path[@]}"
	do
		[ -d "$prefix" ] || continue

		local suffix
		for suffix in '.bash' '.sh' ''
		do
			load "$prefix/$pattern$suffix" && return
		done
	done

	return 1
}


# Check if $needle is among the remaining arguments.
inlist() {
	local needle="$1" straw

	shift
	for straw in "$@"
	do
		[ "$needle" = "$straw" ] && return
	done

	return 1
}


#
# Globals
#

uid="$(id -u)"


#
# Initialisation
#

for i in "${!addons[@]}"
do
	[ -d "${addons[i]}" ] || unset 'addons[i]'
done
unset i


#
# $PATH for root (why is this here? FIXME)
#

[ "$uid" -eq 0 ] && export PATH="/sbin:/usr/sbin:/usr/local/sbin:$PATH"


#
# Homebrew
#

if prefix="$(brew --prefix 2>/dev/null)"
then
	inlist "$brew" "${addons[@]}" || addons+=("$homebrew")
fi
unset prefix


#
# Window Size
#

shopt -s checkwinsize


#
# Add-ons
#

import z/z


#
# Completions
#

if ! shopt -oq posix
then
	import bash_completion "${completions[@]}"

	hosts="$(awk 'tolower($1) == "host" && $2 !~ /\*/ {print $2}' \
			"$HOME/.ssh/config" 2>/dev/null)" &&
		complete -o"default" -o"nospace" -W"$hosts" scp sftp ssh

	unset hosts
fi


#
# Colours
#

colours="$(tput colors 2>/dev/null)" || colours=8
if [ "$colours" -ge 8 ]
then
	alias grep='grep --color=auto'
	export LESS=' -R'
	if command -v highlight
	then
		export LESSOPEN="| highlight -i %s -O ansi"
	elif command -v src-hilite-lesspipe.sh
	then
		export LESSOPEN='| src-hilite-lesspipe.sh %s'
	fi >/dev/null

	command -v colordiff >/dev/null && alias diff=colordiff

	case $(uname -s) in
		(Darwin|DragonFly|*BSD)
			export CLICOLOR=x
			;;
		(GNU|GNU/*|Linux)
			dircolors="$HOME/.dircolors"
			if [ -r "$dircolors" ]
				then eval "$(dircolors -b"$dircolors")"
				else eval "$(dircolors -b)"
			fi
			unset dircolors
			;;
	esac
fi

#
# Aliases
#

load "$HOME/.aliases"
load "$HOME/.bash_aliases"


#
# iTerm2
#

if	[ "$TERM_PROGRAM" = iTerm.app ]	||
	[ "$LC_TERMINAL" = iTerm2 ]		||
	it2check 2>/dev/null
then
	iterm2=x
else
	iterm2=
fi

if	[ "$iterm2" ] && load "$HOME/.iterm2_shell_integration.bash"
then
	iterm2_print_user_vars() {
		iterm2_set_user_var debian_chroot "$debian_chroot"
	}

	__bashrc_iterm2_precmd_set_exit_status() {
		iterm2_set_user_var exit_status "$?"
	}

	precmd_functions+=__bashrc_iterm2_precmd_set_exit_status
fi


#
# Prompt
#

if [ "$iterm2" ]; then
	PS1=$'\[\e[1m\]\$\[\e[0m\] '
else
	case $uid in
		(0) local dir='\w' ;;
		(*) local dir='\W' ;;
	esac

	if [ "$colours" -ge 8 ]
		then PS1=$'\[\e[7m\]'"$dir"$'\[\e[0m\] \[\e[1m\]\$\[\e[0m\] '
		else PS1="$dir \\\$ "
	fi

	if [ "${SSH_CONNECTION-}"]
		then PS1='\u@\h '"$PS1"
		else PS1='\u '"$PS1"
	fi

	[ "${debian_chroot-}" ] && PS1="($debian_chroot) $PS1"
fi



#
# Cleanup
#

unset -f load import
unset addons colours completions iterm2 uid

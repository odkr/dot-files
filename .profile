#!/bin/sh

set -Cfu


#
# Settings
#

# Space-separated list of patterns matching locales in order of preference.
langs='en_GB en_US en_* de_AT de_DE de_* POSIX C'

# Space-separated list of editors in order of preference.
editors='vim nano ne vi'


#
# Functions
#

# Check if $needle compares to any remaining argument using the operator $cmp.
inlist() (
	cmp="${1:?}" needle="${2:?}"
	shift 2

	for straw
	do
		test "$needle" "$cmp" "$straw" && return 0
	done

	return 1
)

# Check if $dir is in the $PATH.
inpath() (
	dir="${1:?}"

	[ "${ZSH_VERSION-}" ] && emulate sh

	IFS=:
	set -- $PATH
	inlist = "$dir" "$@"
)

# Add each given directory to the $PATH.
addtopath() {
	for dir
	do
		if ! inpath "$dir" && [ -e "$dir" ]
		then
			if [ "${PATH-}" ]
				then PATH="$PATH:$dir"
				else PATH="$dir"
			fi
		fi
	done

	unset dir
}

# Store the first of the given programmes that is installed in $var.
setprog() {
	__setprog_var="${1:?}"
	shift 1

	if [ "${ZSH_VERSION-}" ]
	then
		emulate sh
		setopt localoptions
		set -- $*
	fi

	for __setprog_prog
	do
		if command -v "$__setprog_prog" >/dev/null 2>&1
		then
			eval "$__setprog_var"='"$__setprog_prog"'
			break
		fi
	done

	unset __setprog_var __setprog_prog
}


#
# Environment
#

: "${HOME:?}"


#
# Globals
#

# System name.
uname="$(uname -s)"

# Current user.
uid="$(id -u)"


#
# Path
#

if [ "$uid" -eq 0 ]
	then addtopath /sbin /usr/sbin /usr/local/sbin
	else addtopath "$HOME/.iterm2"
fi

addtopath "$HOME/.local/bin" "$HOME/bin"

if brew="$(brew --prefix 2>/dev/null)"
then
	[ "$uid" -eq 0 ] && addtopath "$brew/sbin"
	addtopath "$brew/bin"
fi
unset brew

addtopath /usr/bin/flashupdt


#
# Locale
#

setlang() {
	if [ "${ZSH_VERSION-}" ]
	then
		emulate sh
		setopt localoptions
	fi

	set -- $*

	locales="$(locale -a | grep -Ei '\.utf-?8$')"
	for lang
	do
		for locale in $locales
		do
			case $locale in ("$lang".*|$lang)
				export LANG="$locale"
				break 2
			esac
		done
	done

	unset locales locale lang
}

setlang $langs

unset -f setlang
unset langs


#
# tmux
#

case $- in (*i*)
	if
		[ -n "${SSH_CONNECTION-}" ]	&&
		[ -z "${TMUX-}" ]		&&
		[ -z "${SCREEN-}" ]		&&
		[ "$uid" -ne 0 ]		&&
		command -v tmux >/dev/null 2>&1
	then
		args=
		# Assume tmux >= v1.8.
		[ "${LC_TERMINAL-}" = iTerm2 ] || it2check 2>/dev/null &&
			args=-CC

		for sess in $(tmux list-sessions -F '#S:#{session_attached}')
		do
			case $sess in (*:0)
				exec tmux $args attach-session -t"${sess%:*}"
			esac
		done

		exec tmux $args new-session
	fi
esac


#
# Python
#

[ "$uname" = Darwin ] && addtopath "$HOME"/Library/Python/*/bin


#
# Lua
#

[ "$uid" -ne 0 ] && eval $(luarocks path 2>/dev/null) || :


#
# Programmes
#

setprog VISUAL ${editors-}
[ "${VISUAL-}" ] && EDITOR="$VISUAL"

setprog PAGER less more

export EDITOR VISUAL PAGER


#
# Debian
#

if [ -r /etc/debian_chroot ]; then
    : "${debian_chroot:="$(cat /etc/debian_chroot)"}"
fi


#
# Varia
#

export ET_NO_TELEMETRY=x


#
# Cleanup
#

unset -f inpath addtopath setprog
unset uname uid
set +Cfu


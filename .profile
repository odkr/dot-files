#!/bin/sh

# SETTINGS
# ========

# A space-separated list of preferred locales.
# All locales are assumed to be UTF-8.
__DP_LOCALES='en_GB en_US en_* de_AT de_DE de_* C'


# GLOBALS 
# =======

__DP_UNAME="$(uname -s)"


# PATH
# ====

__dp_add_to_path() {
    [ $# -eq 0 ] && return
    case $PATH in
        ("$1"|"$1:"*|*":$1"|*":$1:"*) : ;;
        (*) [ -d "$1" ] && PATH="$PATH:$1" ;;
    esac
    if [ $# -gt 1 ]; then
        shift
        __dp_add_to_path "$@"
    fi
}

# Add root's PATH
__DP_UID="$(id -u)"

if [ "$__DP_UID" -eq 0 ]
then
	# Add `sbin` to the path if we are the superuser.
	__dp_add_to_path /sbin /usr/sbin /usr/local/sbin
else
	# Add luarocks if it's available.
	__DP_LUAROCKS_ENV="$(luarocks path 2>/dev/null)" &&
		eval "$__DP_LUAROCKS_ENV"
	unset __DP_LUAROCKS_ENV

	# Add iTerm2's utilities, if they are present.
	__dp_add_to_path "$HOME/.iterm2"
fi

# Add the user's `/bin`s to the `PATH`, if they exist.
__dp_add_to_path "$HOME/.local/bin" "$HOME/bin"

# Add homebrew.
__dp_add_to_path /opt/homebrew/bin

case $__DP_UNAME in
    # Use the user's Python installations on macOS if there arey any.
    (Darwin) __DP_PYTHON="$HOME/Library/Python"
             [ -e "$__DP_PYTHON" ] && __dp_add_to_path "$__DP_PYTHON/"*"/bin"
	     unset __DP_PYTHON
	     ;;
    # If this may be a DSM box, check for Optware-NG.
    (Linux)  if [ -d /volume1/@optware ]; then
                 [ "$__DP_UID" -eq 0 ] && __dp_add_to_path /opt/sbin
                 __dp_add_to_path /opt/bin
             fi
	     ;;
esac

unset -f __dp_add_to_path


# TMUX
# ====

# If this shell is interactive, has been started by SSH, and the current user
# is *not* root, then check if there is an unattached tmux session; if there
# is one connect to it, otherwise start a new one and connect to that. If the
# user runs iTerm2, this is *not* a mosh session, and tmux is recent enough
# to support it, then connect using tmux' control mode.

__dp_has_parent_posix() {
    : "${1:?}" "${2:?}"
    # shellcheck disable=2030,2034
    ps -u "${LOGNAME:="$(logname)"}" -o pid=,ppid=,comm= | sort -r |
    while read -r pid ppid comm _; do
        [ "$pid" = "${i-"$1"}" ] || continue
        if [ "${comm##*/}" = "$2" ]; then
            printf -- '%d\n' "$pid"
            return 1
        fi
        i="$ppid"
    done || return 0
    return 1
}

__dp_has_parent_linux() {
    # shellcheck disable=2039,3043
    local i="${1:?}" needle="${2:?}" key value comm ppid 
    # shellcheck disable=2034
    while [ "$i" -gt 1 ]; do
        while read -r key value; do
            case $key in
                (Name:) comm="$value" ;;
                (PPid:) ppid="$value"
                        break
            esac
        done <"/proc/$i/status"
        if [ "$comm" = "$needle" ]; then
            printf -- '%d\n' "$i"
            return 0
        fi
        i="$ppid"
    done
    return 1
}

__dp_has_parent() {
    if [ "$__DP_UNAME" = Linux ] && [ -d /proc ]
        then __dp_has_parent_linux "$@"
        else __dp_has_parent_posix "$@"
    fi
}

__dp_is_mosh() (
    if
        tmux_cls="$(tmux list-clients -F '#S:#{client_pid}' 2>/dev/null)" &&
        [ "$tmux_cls" ]
    then
        [ "$ZSH_VERSION" ] && emulate sh
        # shellcheck disable=2086
        set -- $tmux_cls
        if [ $# -eq 1 ]; then
            pid="${tmux_cls##*:}"
        else
            tmux_sess="$(tmux display-message -p '#S')" || return
            : "${tmux_sess:?}"
            for tmux_cl; do
                case $tmux_cl in ($tmux_sess:*)
                    pid="${tmux_cl##*:}"
                    break
                esac
            done
        fi
    fi
    : "${pid:=$$}"
    __dp_has_parent "$pid" mosh-server
)

__dp_is_iterm2() {
    [ "$LC_TERMINAL" = "iTerm2" ] || it2check 2>/dev/null
}

if MOSH_SERVER_PID="$(__dp_is_mosh)" && [ "$MOSH_SERVER_PID" ]
    then export MOSH_SERVER_PID
    else unset MOSH_SERVER_PID
fi

case $- in (*i*)
    if [ "$SSH_CONNECTION" ] && ! [ "$SCREEN" ] && [ "$__DP_UID" -ne 0 ] &&
        command -v tmux >/dev/null 2>&1
    then
        if [ "$TMUX" ]; then
            # shellcheck disable=2031,2034
            [ "${LOGNAME:="$(logname)"}" ] && last "$LOGNAME" 2>/dev/null | 
                while read -r user tty host date; do
                    [ "$user" ] || return
                    case $host in (mosh|"tmux("*|et) continue; esac
                    case $date in (*"still logged in") continue; esac
                    date="$(printf -- '%s\n' "$date" |
                            sed 's/^v[^ ]*//; s/ - /-/; s/ \{1,\}/ /g')"
                    printf -- 'Last login: %s from %s\n' "$date" "$host"
                    break    
                done
        else
            if ! [ "$MOSH_SERVER_PID" ] && __dp_is_iterm2; then
                # -CC is supported since v1.8, strictly speaking. 
                case $(tmux -V) in
                    ("tmux 1."*) : ;;
                    (*)          tmux_args=-CC ;;
                esac
            fi
            tmux_sess="$(tmux list-sessions -F '#S:#{session_attached}' |
                        awk -F: '$2 == 0 {print $1; exit}')"
            if [ "$tmux_sess" ]
                then exec tmux $tmux_args -u attach-session -t "$tmux_sess"
                else exec tmux $tmux_args -u new-session
            fi   
        fi
    fi 
esac

unset -f __dp_has_parent_posix __dp_has_parent_linux __dp_has_parent \
    __dp_is_mosh __dp_is_iterm2


# LOCALE
# ======

__dp_get_pref_locale() (
    [ "$ZSH_VERSION" ] && emulate sh
    utf8_locales="$(locale -a | grep -iE '\.utf-?8$')"
    for preferred; do
        for locale in $utf8_locales; do
            # shellcheck disable=2254
            case "$locale" in ("$preferred".*|$preferred)
                printf -- '%s\n' "$locale"
                return
            esac
        done
    done
    return 1
)

# shellcheck disable=2086
if LANG="$([ "$ZSH_VERSION" ] && emulate sh
           __dp_get_pref_locale $__DP_LOCALES)" && [ "$LANG" ]
    then export LANG
    else unset LANG
fi

unset -f __dp_get_pref_locale
unset __DP_LOCALES


# PROGRAMMES
# ==========

__dp_select_prog() {
    __DP_SELECT_VAR="${1:?}"
    shift
    for __DP_SELECT_ITER; do
        if
            __DP_SELECT_PROG="$(command -v "$__DP_SELECT_ITER" 2>/dev/null)" &&
            [ "$__DP_SELECT_PROG" ]
        then
            eval "$__DP_SELECT_VAR=\"\$__DP_SELECT_PROG\""
            export "${__DP_SELECT_VAR?}"
            break
        fi
    done
    unset __DP_SELECT_VAR __DP_SELECT_ITER __DP_SELECT_PROG
}

# Use vim if it's available.
__DP_EDITORS='vim nano vi'
__dp_select_prog EDITOR $__DP_EDITORS
__dp_select_prog VISUAL $__DP_EDITORS
unset __DP_EDITORS

# Use less if it's available.
__dp_select_prog PAGER less more

unset -f __dp_select_prog


# ENVIRONMENT
# ===========

export ET_NO_TELEMETRY=x


# DEBIAN
# ======    

if [ -r /etc/debian_chroot ]; then
    : "${debian_chroot:="$(cat /etc/debian_chroot)"}"
fi


# CLEANUP
# =======

unset __DP_UNAME __DP_UID

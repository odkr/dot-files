#!/bin/bash

# SETTINGS
# ========

# Where to look for add-ons.
# Only add paths you trust!
__BASHRC_PATH=("$HOME/.bash")

# Where to look for the `bash-completion` file.
# Only add paths you trust!
__BASHRC_COMPLETION_PATH=(
    /etc /etc/profile.d /usr/share/bash-completion
    /usr/local/etc /usr/local/etc/profile.d
    /usr/local/share/bash-completion
)


# FUNCTIONS
# =========

__bashrc_load () {
    # shellcheck disable=1090
    [ -e "$1" ] && source "$1"
}

__bashrc_import () {
    local pattern="${1:?}"; shift
    local path=("${@-${__BASHRC_PATH[@]}}")
    [ "${#path[@]}" -eq 0 ] && path=("${__BASHRC_PATH[@]}")
    local prefix suffix
    for prefix in "${path[@]}"; do
        [ -d "$prefix" ] || continue
        for suffix in '.bash' '.sh' ''; do
            local fname="$prefix/$pattern$suffix"
            if [ -f "$fname" ]; then
                __bashrc_load "$fname"
                return
            fi
        done
    done
    return 1
}


# INIT
# ====

# Remove non-existing paths.
__bashrc_clean_path () {
    local i
    for i in "${!__BASHRC_PATH[@]}"; do
        [ -d "${__BASHRC_PATH[i]}" ] || unset '__BASHRC_PATH[i]'
    done
}

__bashrc_clean_path
unset -f


# MAIN
# ====

__BASHRC_UID="$(id -u)"


# root's PATH
# -----------

[ "$__BASHRC_UID" -eq 0 ] && export PATH="/sbin:/usr/sbin:/usr/local/sbin:$PATH"


# Homebrew
# --------

__bashrc_inlist () {
    local needle="$1" straw
    shift
    for straw in "$@"; do
        [ "$needle" = "$straw" ] && return
    done
    return 1
}

__bashrc_add_homebrew () {
    local homebrew
    command -v brew >/dev/null 2>&1 && \
        homebrew="$(brew --prefix)/share" && \
        ! __bashrc_inlist "$homebrew" "${__BASHRC_PATH[@]}" && \
            __BASHRC_PATH+=("$homebrew")
}

__bashrc_add_homebrew

unset -f __bashrc_inlist __bashrc_add_homebrew


# Window Size
# -----------

shopt -s checkwinsize


# Add-ons
# -------

__bashrc_import z/z


# Completions
# -----------

function __bashrc_add_ssh_host_completions() {
    local config="$HOME/.ssh/config" hosts
    [ -e "$config" ] || return
    hosts="$(awk 'tolower($1) == "host" && $2 !~ /\*/ {print $2}' "$config")"
    [ "$hosts" ] && complete -o "default" -o "nospace" -W "$hosts" scp sftp ssh
}

if ! shopt -oq posix; then
    __bashrc_import bash_completion "${__BASHRC_COMPLETION_PATH[@]}"
    __bashrc_add_ssh_host_completions
fi

unset -f __bashrc_add_ssh_host_completions


# Colours
# -------

__bashrc_colorise_gen () {
    alias grep='grep --color=auto'

    export LESS=' -R'
    if command -v highlight >/dev/null; then
        export LESSOPEN="| highlight -i %s -O ansi"
    elif command -v src-hilite-lesspipe.sh >/dev/null; then
        export LESSOPEN='| src-hilite-lesspipe.sh %s'
    fi
    
    command -v colordiff >/dev/null && alias diff=colordiff
}

__bashrc_colorise_bsd () {
    export CLICOLOR=x
}

__bashrc_colorise_gnu () {
    if [ -x dircolors ]; then
        local dircolors="$HOME/.dircolors"
        if [ -r "$dircolors" ]
            then eval "$(dircolors -b "$dircolors")"
            else eval "$(dircolors -b)"
        fi
        alias ls='ls --color=auto'
    fi
}

case $TERM in
    (xterm-color|*-256color)
        __bashrc_colorise_gen

        case "$(uname -s)" in
            (Darwin|DragonFly|*BSD) __bashrc_colorise_bsd ;;
            (GNU|GNU/*|Linux)       __bashrc_colorise_gnu ;;
        esac
        ;;
esac

unset -f __bashrc_colorise_gen __bashrc_colorise_bsd __bashrc_colorise_gnu


# Aliases
# -------

__bashrc_load "$HOME/.aliases"
__bashrc_load "$HOME/.bash_aliases"


# iTerm2 Integration
# ------------------

__bashrc_integrate_iterm2 () {
    ! [ "$MOSH_SERVER_PID" ] || return
    [ "$TERM_PROGRAM" = iTerm.app ] && return
    [ "$SSH_CONNECTION" ] && [ "$LC_TERMINAL" = iTerm2 ] && return
    it2check 2>/dev/null && return
    return 1
}

__bashrc_integrate_iterm2 && \
    __bashrc_load "$HOME/.iterm2_shell_integration.bash" && \
{
    iterm2_print_user_vars () {
        iterm2_set_user_var debian_chroot "$debian_chroot"
    }

    __bashrc_iterm2_precmd_set_exit_status () {
        iterm2_set_user_var exit_status "$?"
    }

    precmd_functions+=__bashrc_iterm2_precmd_set_exit_status
    
    __BASHRC_ITERM2=x
}

unset -f __bashrc_integrate_iterm2


# Prompt
# ------

__bashrc_localhost () {
    [ "$SSH_CONNECTION" ] && return 1
    case $(tty) in (*/hvc[0-9]*) return 1 ;; esac
    return 0
}

__bashrc_set_prompt() {
    if [ "$__BASHRC_ITERM2" ]; then
        PS1=$'\[\e[1m\]\$\[\e[0m\] '
    else
        case $__BASHRC_UID in
            (0) local dir='\w' ;;
            (*) local dir='\W' ;;
        esac
        case $TERM in
            (xterm-color|*-256color)
                PS1=$'\[\e[7m\]'"$dir"$'\[\e[0m\] \[\e[1m\]\$\[\e[0m\] '
		;;
            (*)
                PS1="$dir \\\$ "
                ;;
        esac
    
        if __bashrc_localhost
            then PS1='\u '"$PS1"
            else PS1='\u@\h '"$PS1"
        fi

        [ "$debian_chroot" ] && PS1="($debian_chroot) $PS1"
    fi
}

__bashrc_set_prompt

unset -f __bashrc_localhost __bashrc_set_prompt
unset __BASHRC_ITERM2


# CLEANUP
# =======

unset -f __bashrc_inlist __bashrc_load __bashrc_import
unset __BASHRC_PATH __BASHRC_COMPLETION_PATH __BASHRC_UID


# ADDITIONS
# =========

export PATH=$PATH:/usr/bin/flashupdt

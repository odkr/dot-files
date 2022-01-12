#!/bin/zsh


# SETTINGS
# ========

# Where to look for add-ons.
# Only add paths you trust!
__ZSHRC_PATH=("$HOME/.zsh" /usr/share /usr/local/share)


# FUNCTIONS
# =========

__zshrc_load () {
    [ -e "$1" ] && source "$1"
}

__zshrc_import () {
    local prefix suffix
    for prefix in $__ZSHRC_PATH; do
        [ -d "$prefix" ] || continue
        for suffix in '.zsh' '.sh' ''; do
            local fname="$prefix/$1$suffix"
            if [ -e "$fname" ]; then
                __zshrc_load "$fname"
                return
            fi
        done
    done
    return 1
}


# INIT
# ====

# Remove non-existing paths.
function () {
    local i
    for (( i=1; i<=$#__ZSHRC_PATH; i++ )); do
        if ! [ -d "${__ZSHRC_PATH[i]}" ]; then
            __ZSHRC_PATH[i]=()
        fi
    done
}


# MAIN
# ====

__ZSHRC_UID="$(id -u)"


# root's PATH
# -----------

[ "$__ZSHRC_UID" -eq 0 ] && export PATH="/sbin:/usr/sbin:/usr/local/sbin:$PATH"


# Homebrew
# --------

function () {
    local homebrew
    command -v brew >/dev/null 2>&1 && \
        homebrew="$(brew --prefix)/share" 2>/dev/null && \
        [ "$__ZSHRC_PATH[(ie)$homebrew]" -gt "${#__ZSHRC_PATH}" ] && \
            __ZSHRC_PATH+="$homebrew"
}


# History
# -------

setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt APPEND_HISTORY


# Key bindings
# ------------

# Use Emacs key bindings.
bindkey -e


# Auto cd
# -------

setopt AUTO_CD


# Aliases
# -------

# Load common defaults.
__zshrc_load "$HOME/.aliases"


# Add-ons
# -------

__zshrc_import zsh-z/zsh-z.plugin
__zshrc_import zsh-autosuggestions/zsh-autosuggestions
__zshrc_import zsh-syntax-highlighting/zsh-syntax-highlighting
__zshrc_import zsh-history-substring-search/zsh-history-substring-search && {
    bindkey "$terminfo[kpp]" history-substring-search-up
    bindkey "$terminfo[knp]" history-substring-search-down
}


# Completions
# -----------

# Load ZSH completions, if they are availabe.
function () {
    local dir
    for dir in $__ZSHRC_PATH; do
        local fname="$dir/zsh-completions"
        if [ -r "$fname" ]; then
            FPATH="$fname:$FPATH"
            autoload -Uz compinit && compinit -u
        fi
    done
}

# Add SSH hosts.
function () (
    local config="$HOME/.ssh/config" hosts
    [ -e "$config" ] || return
    hosts=($(awk 'tolower($1) == "host" && $2 !~ /\*/ {print $2}' "$config"))
    [ "$#hosts" -gt 0 ] || return
    zstyle ':completion:*:(ssh|scp|sftp):*' hosts $hosts
)


# Colours
# -------

__zshrc_colorise_gen () {
    alias grep='grep --color=auto'
    
    export LESS=' -R'
    if command -v highlight >/dev/null; then
        export LESSOPEN="| highlight -i %s -O ansi"
    elif command -v src-hilite-lesspipe.sh >/dev/null; then
        export LESSOPEN='| src-hilite-lesspipe.sh %s'
    fi

    command -v colordiff >/dev/null && alias diff=colordiff
}

__zshrc_colorise_bsd () {
    export CLICOLOR=x
}

__zshrc_colorise_gnu () {
    if command -v dircolors >/dev/null; then
        local dircolors="$HOME/.dircolors"
        if [ -r "$dircolors" ]
            then eval "$(dircolors -b "$dircolors")"
            else eval "$(dircolors -b)"
        fi
        alias ls='ls --color=auto'
    fi
}

case $TERM in (xterm-color|*-256color)
        __zshrc_colorise_gen
        case "$(uname -s)" in
            (Darwin|DragonFly|*BSD) __zshrc_colorise_bsd ;;
            (GNU|GNU/*|Linux)       __zshrc_colorise_gnu ;;
        esac
esac

unset -f __zshrc_colorise_gen __zshrc_colorise_bsd __zshrc_colorise_gnu


# iTerm2 Integration
# ------------------

__zshrc_integrate_iterm2 () {
    ! [ "$MOSH_SERVER_PID" ] || return
    [ "$TERM_PROGRAM" = iTerm.app ] && return
    [ "$SSH_CONNECTION" ] && [ "$LC_TERMINAL" = iTerm2 ] && return
    it2check 2>/dev/null && return
    return 1
}

__zshrc_integrate_iterm2 && \
    __zshrc_load "$HOME/.iterm2_shell_integration.zsh" && \
{
    iterm2_print_user_vars () {
        iterm2_set_user_var debian_chroot "$debian_chroot"
    }

    __zshrc_iterm2_precmd_set_exit_status () {
        iterm2_set_user_var exit_status "$?"
    }

    precmd_functions+=__zshrc_iterm2_precmd_set_exit_status

    __ZSHRC_ITERM2=x
}

unset -f __zshrc_integrate_iterm2


# Prompt
# ------

__zshrc_localhost () {
    [ "$SSH_CONNECTION" ] && return 1
    case $(tty) in (*/hvc[0-9]*) return 1; esac
    return 0
}

function() {
    if [ "$__ZSHRC_ITERM2" ]; then
        PS1='%B%#%b '
    else
        case $__ZSHRC_UID in
            (0) local dir='%~'  ;;
            (*) local dir='%1~' ;;
        esac
        case $TERM in
            (xterm-color|*-256color) PS1="%S$dir%s %B%#%b " ;;
            (*)                      PS1="$dir %B%#%b "	;;
        esac
    
        if __zshrc_localhost
            then PS1="%n $PS1"
            else PS1="%n@%m $PS1"
        fi
    
        [ "$debian_chroot" ] && PS1="($debian_chroot) $PS1"
    fi
}

unset -f __zshrc_localhost
unset __ZSHRC_ITERM2


# CLEANUP
# =======

unset -f __zshrc_load __zshrc_import
unset __ZSHRC_PATH __ZSHRC_UID

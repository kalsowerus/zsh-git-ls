function git-ls() {
    zparseopts -D -E -F -a ls_opts - \
        a -all \
        A -almost-all \
        -author \
        B -ignore_backups \
        g \
        -group-directories-first \
        G -no-group \
        h -human_readable \
        -si \
        o \
        r -reverse \
        s -size \
        S \
        t \
        -help=o_help 2>/dev/null

    if [[ $? != 0 ]]; then
        .zsh_git_ls_print_help "$0"
        return 1
    fi

    if [[ -n "$o_help" ]]; then
        .zsh_git_ls_print_help "$0"
        return
    fi

    local current_dir_status=
    if [[ $# < 2 ]]; then
        current_dir_status="$(.zsh_git_ls_get_git_status "${1:-.}")"
    fi

    local list=$(command ls -l --quoting-style=shell --color $ls_opts $@)
    local section

    for line in "${(@f)list}"; do
        if [[ -z "$line" ]]; then
            current_dir_status=
            echo
        elif [[ "$line" =~ '^(\S+):$' ]]; then
            local current_dir="$match[1]"
            current_dir_status="$(.zsh_git_ls_get_git_status "$current_dir")"
            echo "$line"
        elif [[ "$line" =~ '^total ' ]]; then
            echo "$line"
        else
            .zsh_git_ls_parse_line "$line" "$current_dir_status"
        fi
    done
}

function .zsh_git_ls_parse_line() {
    local line="$1"
    local git_status="$2"
    local filename=$(echo "$line" | perl -pe 's/^.*?\s((\x1B\[[0-9;]*m)?'\''.+->.+|(\x1B\[[0-9;]*m)?'\''.+|\s?\S+\s*->.+|\s?\S+)$/\1/')
    local raw_filename=$(echo "$filename" |  sed 's/\x1B\[[0-9;]*m//g' | sed -r 's/^ ?'\''?([^'\'']+)'\''?.*$/\1/')
    local file_status_character

    if [[ -z "$git_status" ]]; then
        local dir=$(dirname "$raw_filename")
        if .zsh_git_ls_is_git_dir "$dir"; then
            git_status=$(.zsh_git_ls_get_git_status "$dir") 
        else
            file_status_character=' '
        fi
    fi

    git_status="$git_status\n!! .\n!! ..\n!! .git"

    if [[ -z "$file_status_character" ]]; then
        local file_status="${$(echo "$git_status" | grep " $raw_filename$"):0:2}"
        file_status_character=$(.zsh_git_ls_get_status_character "$file_status")
    fi
    echo "${line%%$filename}$file_status_character $filename"
}

function .zsh_git_ls_get_git_status() {
    if .zsh_git_ls_is_git_dir "$1"; then
        echo "${$(command git -C "$1" status -s --ignored -unormal 2>/dev/null | sed 's/"//g'):-empty}"
    fi
}

function .zsh_git_ls_is_git_dir() {
    command git -C "$1" rev-parse >/dev/null 2>&1
}

function .zsh_git_ls_get_status_character() {
    local MODIFIED_CHARACTER="${ZSH_GIT_LS_MODIFIED_CHARACTER:-*}"
    local ADDED_CHARACTER="${ZSH_GIT_LS_ADDED_CHARACTER:-+}"
    local RENAMED_CHARACTER="${ZSH_GIT_LS_RENAMED_CHARACTER:-R}"
    local UNTRACKED_CHARACTER="${ZSH_GIT_LS_RENAMED_CHARACTER:-?}"
    local NOT_MODIFIED_CHARACTER="${ZSH_GIT_LS_NOT_MODIFIED_CHARACTER:-|}"

    local RESET_COLOR='\e[0m'
    local MODIFIED_COLOR="\e[0;${ZSH_GIT_LS_MODIFIED_COLOR:-32}m"
    local MODIFIED_DIRTY_COLOR="\e[0;${ZSH_GIT_LS_MODIFIED_DIRTY_COLOR:-33}m"
    local DIRTY_COLOR="\e[0;${ZSH_GIT_LS_DIRTY_COLOR:-31}m"
    local NOT_MODIFIED_COLOR="\e[0;${ZSH_GIT_LS_NOT_MODIFIED_COLOR:-32}m"

    1=$(echo "$1" | sed -r 's/[^ARM?!]/ /g')
    if [[ $1 == 'M ' ]]; then   # modified
        echo -n "$MODIFIED_COLOR$MODIFIED_CHARACTER$RESET_COLOR"
    elif [[ $1 == 'MM' ]]; then # modified & dirty
        echo -n "$MODIFIED_DIRTY_COLOR$MODIFIED_CHARACTER$RESET_COLOR"
    elif [[ $1 == ' M' ]]; then # dirty
        echo -n "$DIRTY_COLOR$MODIFIED_CHARACTER$RESET_COLOR"
    elif [[ $1 == 'A ' ]]; then # added
        echo -n "$MODIFIED_COLOR$ADDED_CHARACTER$RESET_COLOR"
    elif [[ $1 == 'AM' ]]; then # added & dirty
        echo -n "$MODIFIED_DIRTY_COLOR$ADDED_CHARACTER$RESET_COLOR"
    elif [[ $1 == 'R ' ]]; then # renamed
        echo -n "$MODIFIED_COLOR$RENAMED_CHARACTER$RESET_COLOR"
    elif [[ $1 == 'RM' ]]; then # renamed & dirty
        echo -n "$MODIFIED_DIRTY_COLOR$RENAMED_CHARACTER$RESET_COLOR"
    elif [[ $1 == '??' ]]; then # untracked
        echo -n "$DIRTY_COLOR$UNTRACKED_CHARACTER$RESET_COLOR"
    elif [[ $1 == '!!' ]]; then # ignored
        echo -n ' '
    else                        # not modified
        echo -n "$NOT_MODIFIED_COLOR$NOT_MODIFIED_CHARACTER$RESET_COLOR"
    fi
}

function .zsh_git_ls_print_help() {
    cat << EOHELP
Usage: $1 [OPTION]... [FILE]...
    -a, --all                       do not ignore entries starting with .
    -A, --almost-all                do not list implied . and ..
        --author                    with -l, print the author of each file
    -B, --ignore-backups            do not list implied entries ending with ~
    -g                              list -l, but do not list owner
        --group-directories-first   group directories before files
    -G, --no-group                  in a long listing, don't print group names
    -h, --human-readable            with -ls and -s, print sizes like 1K 234M 2G etc.
        --si                        likewise, but use powers of 1000 not 1024
    -o                              like -l, but do not list group information
    -r, --reverse                   reverse order while sorting
    -s, --size                      print the allocated size of each file, in blocks
    -S                              sort by file size, largest first
    -t                              sort by modification time, newest first
        --help                      display this help and exit
EOHELP
# This comment fixes syntax highlighting '
}


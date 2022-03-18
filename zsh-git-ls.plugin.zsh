function git-ls() {
    zparseopts -D -E -F -a ls_opts - \
        a -all \
        A -almost-all \
        -author \
        -block-size: \
        B -ignore_backups \
        c \
        F -classify \
        -file-type \
        -full-time \
        g \
        -group-directories-first \
        G -no-group \
        h -human_readable \
        -si \
        -hide: \
        -indicator-style: \
        i -inode \
        I: -ignore: \
        k -kibibytes \
        n -numeric-uid-gid \
        o \
        p \
        r -reverse \
        s -size \
        S \
        -sort: \
        -time: \
        -time-style: \
        t \
        u \
        U \
        v \
        X \
        -help=o_help 2>/dev/null

    if [[ $? != 0 ]]; then
        .zsh_git_ls_print_help "$0"
        return 1
    fi

    if [[ -n "$o_help" ]]; then
        .zsh_git_ls_print_help "$0"
        return
    fi

    local dir=
    local current_dir_status=
    if (( $# < 2 )); then # no or one argument is given
        dir="${1:-.}"
        current_dir_status="$(.zsh_git_ls_get_git_status "$dir")"
    fi

    local list
    list=$(command ls -l --quoting-style=shell --color $ls_opts $@)
    local rc=$?
    local section

    for line in "${(@f)list}"; do
        if [[ -z "$line" ]]; then # empty line separating sections when listing multiple files/directories
            dir=
            current_dir_status=
            echo
        elif [[ "$line" =~ '^(\S+):$' ]]; then # header line at the beginning of a directory list
            dir="$match[1]"
            current_dir_status=$(.zsh_git_ls_get_git_status "$dir")
            echo "$line"
        elif [[ "$line" =~ '^total ' ]]; then # line showing total size, just echo
            echo "$line"
        elif [[ -z "$dir" ]]; then # $dir is not set: we are in the single file section
            local filename=$(.zsh_git_ls_get_filename "$line")
            local raw_filename=$(.zsh_git_ls_get_raw_filename "$filename")
            dir=$(dirname "$raw_filename")
            current_dir_status=$(.zsh_git_ls_get_git_status "$dir")
            .zsh_git_ls_parse_line "$line" "$filename" "$raw_filename" "$dir" "$current_dir_status"
            dir=
        else # normal line in directory list
            local filename=$(.zsh_git_ls_get_filename "$line")
            local raw_filename=$(.zsh_git_ls_get_raw_filename "$filename")
            .zsh_git_ls_parse_line "$line" "$filename" "$raw_filename" "$dir" "$current_dir_status"
        fi
    done

    return $rc
}

function .zsh_git_ls_parse_line() {
    local line="$1"
    local filename="$2"
    local raw_filename="$3"
    local dir="$4"
    local git_status="$5"
    local file_status_character

    if [[ -n "$git_status" ]] && [[ "$git_status" != 'not_a_git_dir' ]]; then
        git_status="$git_status\n!! .\n!! ..\n!! .git/"
    fi

    if [[ "$git_status" != 'not_a_git_dir' ]]; then
        local file_status
        if [[ -d "$dir/${raw_filename:t}" ]]; then
            local dir_status=$(echo "$git_status" | grep " $raw_filename/")
            if [[ "$dir_status" =~ '[ ?]. .*' ]]; then
                file_status='/M'
            elif [[ "$dir_status" =~ '.M .*' ]]; then
                file_status=' /'
            elif [[ "$dir_status" =~ "!! $raw_filename:t/$" ]]; then
                file_status='!!'
            fi
        else
            file_status="${$(echo "$git_status" | grep " $raw_filename:t$"):0:2}"
        fi
        file_status_character=$(.zsh_git_ls_get_status_character "$file_status")
    else
        file_status_character=' '
    fi
    echo "${line%%$filename}$file_status_character $filename"
}

function .zsh_git_ls_get_git_status() {
    if .zsh_git_ls_is_git_dir "$1"; then
        local git_status="${$(command git -C "$1" status -s --ignored -unormal 2>/dev/null | sed 's/"//g'):-empty}"
        echo "$git_status"
    else
        echo 'not_a_git_dir'
    fi
}

function .zsh_git_ls_is_git_dir() {
    command git -C "$1" rev-parse >/dev/null 2>&1
}

function .zsh_git_ls_get_filename() {
    echo "$1" | perl -pe 's/^.*?\s((\x1B\[[0-9;]*m)?'\''.+->.+|(\x1B\[[0-9;]*m)?'\''.+|\s?\S+\s*->.+|\s?\S+)$/\1/'
}

function .zsh_git_ls_get_raw_filename() {
    echo "$filename" |  sed 's/\x1B\[[0-9;]*m//g' | sed -r 's/^ ?'\''?([^'\'']+)'\''?.*$/\1/' | sed -r 's/^(.*?)\s+->\s+.*$/\1/g' | sed -r 's/^(.*?)[*/=>@|]$/\1/'
}

function .zsh_git_ls_get_status_character() {
    local MODIFIED_CHARACTER="${ZSH_GIT_LS_MODIFIED_CHARACTER:-*}"
    local ADDED_CHARACTER="${ZSH_GIT_LS_ADDED_CHARACTER:-+}"
    local RENAMED_CHARACTER="${ZSH_GIT_LS_RENAMED_CHARACTER:-R}"
    local UNTRACKED_CHARACTER="${ZSH_GIT_LS_RENAMED_CHARACTER:-?}"
    local NOT_MODIFIED_CHARACTER="${ZSH_GIT_LS_NOT_MODIFIED_CHARACTER:-|}"
    local DIR_CONTAINING_CHANGES_CHARACTER="${ZSH_GIT_LS_DIR_CONTAINING_CHANGED_CHARACTER:-|}"

    local RESET_COLOR='\e[0m'
    local MODIFIED_COLOR="\e[0;${ZSH_GIT_LS_MODIFIED_COLOR:-32}m"
    local MODIFIED_DIRTY_COLOR="\e[0;${ZSH_GIT_LS_MODIFIED_DIRTY_COLOR:-33}m"
    local DIRTY_COLOR="\e[0;${ZSH_GIT_LS_DIRTY_COLOR:-31}m"
    local NOT_MODIFIED_COLOR="\e[0;${ZSH_GIT_LS_NOT_MODIFIED_COLOR:-32}m"

    1=$(echo "$1" | sed -r 's/[^ARM?!/]/ /g')
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
    elif [[ $1 == ' /' ]]; then # dir containing files that are modified & dirty
        echo -n "$MODIFIED_DIRTY_COLOR$DIR_CONTAINING_CHANGES_CHARACTER$RESET_COLOR"
    elif [[ $1 == '/M' ]]; then # dir containing files that are dirty
        echo -n "$DIRTY_COLOR$DIR_CONTAINING_CHANGES_CHARACTER$RESET_COLOR"
    else                        # not modified
        echo -n "$NOT_MODIFIED_COLOR$NOT_MODIFIED_CHARACTER$RESET_COLOR"
    fi
}

function .zsh_git_ls_print_help() {
    cat << EOHELP
Usage: $1 [OPTION]... [FILE]...
        --help          display this help and exit

For explanations for the following options see 'ls --help'.
    -a, --all
    -A, --almost-all
        --author
        --block-size=SIZE
    -B, --ignore-backups
    -c
    -F, --classify
        --file-type
        --full-time
    -g
        --group-directories-first
    -G, --no-group
    -h, --human-readable
        --si
        --hide=PATTERN
        --indicator-style=WORD
    -i, --inode
    -k, --kibibytes
    -n, --numeric-uid-gid
    -o
    -p
    -r, --reverse
    -s, --size
    -S
        --sort=WORD
        --time=WORD
        --time-style=TIME_STYLE
    -t
    -u
    -U
    -v
    -X
EOHELP
}


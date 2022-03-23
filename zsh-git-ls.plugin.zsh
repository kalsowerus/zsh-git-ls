function git-ls() {
    zparseopts -D -E -F -a ls_opts - \
        a -all \
        A -almost-all \
        -author \
        -block-size: \
        B -ignore_backups \
        c \
        d -directory \
        f \
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
        R -recursive \
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
    local repo_path=
    if (( $# < 2 )); then # no or one argument is given
        dir="${1:-.}"
        current_dir_status="$(.zsh_git_ls_get_git_status "$dir")"
        repo_path="$(.zsh_git_ls_get_repo_path "$dir")"
    fi

    local list
    list=$(command ls -l --quoting-style=shell --color=always $ls_opts $@)
    local rc=$?
    local section

    for line in "${(@f)list}"; do
        if [[ -z "$line" ]]; then # empty line separating sections when listing multiple files/directories
            dir=
            current_dir_status=
            repo_path=
            echo
        elif [[ "$line" =~ '^(\S+):$' ]]; then # header line at the beginning of a directory list
            dir="$match[1]"
            current_dir_status=$(.zsh_git_ls_get_git_status "$dir")
            repo_path=$(.zsh_git_ls_get_repo_path "$dir")
            echo "$line"
        elif [[ "$line" =~ '^total ' ]]; then # line showing total size, just echo
            echo "$line"
        elif [[ -z "$dir" ]]; then # $dir is not set: we are in the single file section
            local filename=$(.zsh_git_ls_get_filename "$line")
            local raw_filename=$(.zsh_git_ls_get_raw_filename "$filename")
            dir=$(dirname "$raw_filename")
            current_dir_status=$(.zsh_git_ls_get_git_status "$dir")
            repo_path=$(.zsh_git_ls_get_repo_path "$dir")
            .zsh_git_ls_parse_line "$line" "$filename" "$raw_filename" "$dir" "$current_dir_status" "$repo_path"
            dir=
        else # normal line in directory list
            local filename=$(.zsh_git_ls_get_filename "$line")
            local raw_filename=$(.zsh_git_ls_get_raw_filename "$filename")
            .zsh_git_ls_parse_line "$line" "$filename" "$raw_filename" "$dir" "$current_dir_status" "$repo_path"
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
    local repo_path="$6"
    local file_status_character

    if [[ "$git_status" != 'not_a_git_dir' ]]; then
        local dir_path=$(realpath "$dir")
        local path_prefix="${dir_path#$repo_path}"
        local file_path="$path_prefix/${raw_filename:t}"
        file_path="${file_path:1}"
        local file_status
        if [[ -d "$repo_path/$file_path" ]]; then
            local dir_status=$(echo "$git_status" | grep "^.. $file_path/")
            if [[ "$dir_status" =~ '[ ?]. ' ]]; then # dirty
                file_status=' /'
            elif [[ "$dir_status" =~ '.M ' ]]; then # modified & dirty
                file_status='/M'
            elif [[ "$dir_status" =~ '.  ' ]]; then # modified
                file_status='/ '
            elif .zsh_git_ls_is_ignored "$repo_path" "$file_path"; then
                file_status='!!'
            fi
        else
            file_status="${$(echo "$git_status" | grep " $file_path$"):0:2}"
            if [[ -z "$file_status" ]] && .zsh_git_ls_is_ignored "$repo_path" "$file_path"; then
                file_status='!!'
            fi
        fi
        file_status_character=$(.zsh_git_ls_get_status_character "$file_status")
    else
        file_status_character=' '
    fi
    echo "${line%%$filename}$file_status_character $filename"
}

function .zsh_git_ls_get_git_status() {
    if .zsh_git_ls_is_git_dir "$1"; then
        echo "${$(command git -C "$1" status --porcelain -uall 2>/dev/null | grep -v '^!!' | sed 's/"//g'):-empty}"
    else
        echo 'not_a_git_dir'
    fi
}

function .zsh_git_ls_is_git_dir() {
    command git -C "$1" rev-parse >/dev/null 2>&1
}

function .zsh_git_ls_get_repo_path() {
    command git -C "$1" rev-parse --show-toplevel 2>/dev/null
}

function .zsh_git_ls_get_filename() {
    echo "$1" | perl -pe 's/^.*?\s((\x1B\[[0-9;]*m)?'\''.+->.+|(\x1B\[[0-9;]*m)?'\''.+|\s?\S+\s*->.+|\s?\S+)$/\1/'
}

function .zsh_git_ls_get_raw_filename() {
    echo "$filename" |  sed 's/\x1B\[[0-9;]*m//g' | sed -r 's/^ ?'\''?([^'\'']+)'\''?.*$/\1/' | sed -r 's/^(.*?)\s+->\s+.*$/\1/g' | sed -r 's/^(.*?)[*/=>@|]$/\1/'
}

function .zsh_git_ls_is_ignored() {
    local repo_path="$1"
    local file_path="$2"

    if [[ "${file_path:t}" == '.' ]] || [[ "${file_path:t}" == '..' ]] || [[ "${file_path:t}" == '.git' ]]; then
        return 0
    fi

    command git -C "$repo_path" check-ignore -q "$repo_path/$file_path"
}

function .zsh_git_ls_get_status_character() {
    local MODIFIED_CHARACTER="${ZSH_GIT_LS_MODIFIED_CHARACTER:-*}"
    local ADDED_CHARACTER="${ZSH_GIT_LS_ADDED_CHARACTER:-+}"
    local RENAMED_CHARACTER="${ZSH_GIT_LS_RENAMED_CHARACTER:-R}"
    local UNTRACKED_CHARACTER="${ZSH_GIT_LS_RENAMED_CHARACTER:-?}"
    local NOT_MODIFIED_CHARACTER="${ZSH_GIT_LS_NOT_MODIFIED_CHARACTER:-|}"
    local DIR_CONTAINING_CHANGES_CHARACTER="${ZSH_GIT_LS_DIR_CONTAINING_CHANGED_CHARACTER:-/}"

    local RESET_COLOR='\e[0m'
    local MODIFIED_COLOR="\e[0;${ZSH_GIT_LS_MODIFIED_COLOR:-32}m"
    local MODIFIED_DIRTY_COLOR="\e[0;${ZSH_GIT_LS_MODIFIED_DIRTY_COLOR:-33}m"
    local DIRTY_COLOR="\e[0;${ZSH_GIT_LS_DIRTY_COLOR:-31}m"
    local NOT_MODIFIED_COLOR="\e[0;${ZSH_GIT_LS_NOT_MODIFIED_COLOR:-32}m"

    # untracked or ignored
    if [[ $1 == '??' ]]; then   # untracked
        echo -n "$DIRTY_COLOR$UNTRACKED_CHARACTER$RESET_COLOR"
        return
    elif [[ $1 == '!!' ]]; then # ignored
        echo -n ' '
        return
    fi

    # get color
    if [[ "$1" =~ '\S ' ]]; then    # all changes in index
        echo -n "$MODIFIED_COLOR"
    elif [[ "$1" =~ '\S\S' ]]; then # some changes in index
        echo -n "$MODIFIED_DIRTY_COLOR"
    elif [[ "$1" =~ ' \S' ]]; then  # all changes not in index
        echo -n "$DIRTY_COLOR"
    else                            # no changes
        echo -n "$NOT_MODIFIED_COLOR"
    fi

    # get character
    if [[ "$1" =~ 'A' ]]; then   # added file
        echo -n "$ADDED_CHARACTER"
    elif [[ "$1" =~ 'R' ]]; then # renamed file
        echo -n "$RENAMED_CHARACTER"
    elif [[ "$1" =~ '/' ]]; then # directory containing changes
        echo -n "$DIR_CONTAINING_CHANGES_CHARACTER"
    elif [[ "$1" =~ 'M' ]]; then # modified
        echo -n "$MODIFIED_CHARACTER"
    else                         # not modified
        echo -n "$NOT_MODIFIED_CHARACTER"
    fi

    # reset color
    echo -n "$RESET_COLOR"
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
    -d, --directory
    -f
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
    -R, --recursive
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


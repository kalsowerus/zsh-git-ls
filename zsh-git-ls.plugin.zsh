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

    local dir="${1:-.}"
    local list=$(command ls -l --color $ls_opts $dir)

    local git_status
    if git_status=$(command git -C "$dir" status -s --ignored -unormal 2>/dev/null | command grep -v '/'); then
        declare -A file_status
        for file in "${(f)git_status}"; do
            filename=$(echo "${file:3}" | sed -r 's/(.* -> )?(.*)/\2/g')
            file_status[${filename}]="${file:0:2}"
        done
        file_status[.]='!!'
        file_status[..]='!!'
        file_status[.git]='!!'

        echo "$list" | head -n 1
        local file_list=$(echo "$list" | tail -n +2)
        local result
        for file in "${(f)file_list}"; do
            local filename="${file##* }"
            local raw_filename=$(echo "$filename" | sed 's/\x1B\[[0-9;]*m//g')
            result="$result${file% *}"
            result="$result $(.zsh_git_ls_get_status_character ${file_status[$raw_filename]})"
            result="$result $filename\n"
        done

        echo $result | column -t | sed -r 's/([^ ])  /\1 /g'
    else
        echo "$list"
    fi
}

function .zsh_git_ls_get_status_character() {
    1=$(echo "$1" | sed -r 's/[^ARM?!]/ /g')
    if [[ $1 == 'M ' ]]; then # Tracked & Modified
        echo -n '\e[0;32m*\e[0m'
    elif [[ $1 == 'A ' ]]; then # Added
        echo -n '\e[0;32m+\e[0m'
    elif [[ $1 == 'R ' ]]; then # Renamed
        echo -n '\e[0;32mR\e[0m'
    elif [[ $1 == ' M' ]]; then # Tracked & Dirty
        echo -n '\e[0;31m*\e[0m'
    elif [[ $1 == 'AM' ]]; then # Added & Modified & Dirty
        echo -n '\e[0;33m+\e[0m'
    elif [[ $1 == 'MM' ]]; then # Tracked & Modified & Dirty
        echo -n '\e[0;33m*\e[0m'
    elif [[ $1 == '??' ]]; then # Untracked
        echo -n '\e[0;31m?\e[0m'
    elif [[ $1 == '!!' ]]; then # Ignored
        echo -n ' '
    else
        echo -n '\e[0;32m|\e[0m'
    fi
}

function .zsh_git_ls_print_help() {
    cat << EOHELP
Usage: $1 [OPTION]... [FILE]
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


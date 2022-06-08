# shellcheck disable=SC2076

function git-ls() {
    zmodload zsh/datetime
    local IFS='
'
    local DELIMITER='\x00'

    local ls_opts
    zparseopts -D -E -F -a todo - \
        a=ls_opts -all=ls_opts \
        A=ls_opts -almost-all=ls_opts \
        B=ls_opts -ignore_backups=ls_opts \
        d=ls_opts -directory=ls_opts \
        F=name_opts -classify=name_opts \
        -file-type=name_opts \
        -group-directories-first=ls_opts \
        h=o_human_readable -human-readable=o_human_readable \
        -si=o_si \
        -hide:=ls_opts \
        -indicator-style:=name_opts \
        I:=ls_opts -ignore:=ls_opts \
        p=name_opts \
        r=ls_opts -reverse=ls_opts \
        R=ls_opts -recursive=ls_opts \
        S=ls_opts \
        -sort:=ls_opts \
        t=ls_opts \
        U=ls_opts \
        v=ls_opts \
        X=ls_opts \
        -help=o_help 2>/dev/null

    # shellcheck disable=SC2181
    if [[ $? != 0 ]]; then
        .zsh_git_ls_print_help "${0}"
        return 1
    fi

    if [[ -n "${o_help}" ]]; then
        .zsh_git_ls_print_help "${0}"
        return
    fi

    local dir=
    local git_status=
    local repo_path=
    local stat=
    local section=
    local total=
    if (( $# < 2 )); then # no or one argument is given
        dir="${1:-.}"
        if [[ -d "${dir}" ]]; then
            total=0
        fi
        git_status="$(.zsh_git_ls_get_git_status "${dir}")"
        repo_path="$(.zsh_git_ls_get_repo_path "${dir}")"
    fi

    local list
    # shellcheck disable=SC2034,SC2086
    list=$(command ls -N1 --color=never ${ls_opts} "$@")
    local rc=$?


    # shellcheck disable=SC2066,SC2296
    for filename in "${(@f)list}"; do
        local match
        if [[ -z "${filename}" ]]; then # empty line separating sections when listing multiple files/directories
            .zsh_git_ls_print_section "${section}" "${total}"
            section=
            dir=
            git_status=
            repo_path=
            total=0
            echo
            continue
        elif [[ "${filename}" =~ ^(.+):$ ]]; then # header line at the beginning of a directory list
            dir="${match[1]}"
            git_status=$(.zsh_git_ls_get_git_status "${dir}")
            repo_path=$(.zsh_git_ls_get_repo_path "${dir}")
            echo "${filename}"
            continue
        elif [[ -z "${dir}" ]]; then # $dir is not set: we are in the single file section
            dir=$(dirname "${filename}")
            git_status=$(.zsh_git_ls_get_git_status "${dir}")
            repo_path=$(.zsh_git_ls_get_repo_path "${dir}")
        fi

        # shellcheck disable=SC2207
        stat=($(command stat --printf '%A\n%h\n%G\n%U\n%s\n%Y\n%b\n%B\n%F' "${dir}/${filename}"))

        if [[ -n "${total}" ]]; then
            (( total += stat[7]*stat[8] ))
        fi

        # basic information
        section="${section}${stat[1]}${DELIMITER}${stat[2]}${DELIMITER}${stat[3]}${DELIMITER}${stat[4]}"

        local size=
        if [[ -n "${o_human_readable}" ]]; then
            size=$(numfmt --to=iec "${stat[5]}")
        elif [[ -n "${o_si}" ]]; then
            size=$(numfmt --to=si "${stat[5]}")
        else
            size="${stat[5]}"
        fi
        section="${section}${DELIMITER}${size}"

        section="${section}${DELIMITER}$(strftime '%b %e %H:%M' "${stat[6]}")"

        # git status character
        local dir_path
        dir_path=$(realpath "${dir}")
        if [[ -n "${git_status}" ]]; then
            local path_prefix="${dir_path#"${repo_path}"}"
            local file_path="${path_prefix}/${filename}"
            file_path="${file_path:1}"
            local file_status=
            if [[ -d "${repo_path}/${file_path}" ]]; then
                local dir_status
                dir_status=$(echo "${git_status}" | grep "^.. ${file_path}/")
                if [[ "${dir_status}" =~ '[ ?]. ' ]]; then # dirty
                    file_status=' /'
                elif [[ "${dir_status}" =~ '.M ' ]]; then # modified & dirty
                    file_status='/M'
                elif [[ "${dir_status}" =~ '.  ' ]]; then # modified
                    file_status='/ '
                elif .zsh_git_ls_is_ignored "${repo_path}" "${file_path}"; then
                    file_status='!!'
                fi
            else
                # shellcheck disable=SC2300
                file_status="${$(echo "${git_status}" | grep " ${file_path}$"):0:2}"
                if [[ -z "${file_status}" ]] && .zsh_git_ls_is_ignored "${repo_path}" "${file_path}"; then
                    file_status='!!'
                fi
            fi
            file_status_character=$(.zsh_git_ls_get_status_character "${file_status}")
        else
            file_status_character=' '
        fi
        section="${section}${DELIMITER}${file_status_character}"

        # file name
        local colored_filename
        colored_filename=$(cd "${dir}" && command ls --color=always -d "${filename}")
        section="${section} ${colored_filename}"

        local link=
        link=$(readlink "${dir}/${filename}")
        # shellcheck disable=SC2181
        if [[ $? == 0 ]]; then
            if [[ -e "${link}" ]]; then
                section="${section} -> ${link}"
            else
                section="${section} -> \e[0;31m${link}\e[0m"
            fi
        fi

        section="${section}\n"
    done

    if [[ -n "${section}" ]]; then
        .zsh_git_ls_print_section "${section}" "${total}"
    fi

    return "${rc}"
}

function .zsh_git_ls_get_git_status() {
    if .zsh_git_ls_is_git_dir "${1}"; then
        # shellcheck disable=SC2300
        echo "${$(command git -C "${1}" status --porcelain -uall 2>/dev/null | grep -v '^!!' | sed 's/"//g'):-empty}"
    fi
}

function .zsh_git_ls_print_section() {
    local section="${1}"
    local total="${2}"

    if [[ -n "${total}" ]]; then
        echo "total $(numfmt --to=iec "${total}")"
    fi
    .zsh_git_ls_print_table "${section}"
}

function .zsh_git_ls_print_table() {
    # shellcheck disable=SC2034
    local content="${1}"
    local widths=()

    # shellcheck disable=SC2066,SC2296
    for line in "${(@s/\n/)content}"; do
        local i=1
        # shellcheck disable=SC2066,SC2296
        for field in "${(@s/\x00/)line}"; do
            local length="${#field}"
            if (( ${widths[i]:-0} < length )); then
                widths[${i}]="${length}"
            fi
            (( i++ ))
        done
    done

    # shellcheck disable=SC2066,SC2296
    for line in "${(@s/\n/)content}"; do
        if [[ -z "${line}" ]]; then
            continue
        fi
        local i=1
        # shellcheck disable=SC2298
        for field in "${${(@s/\x00/)line}[@]:0:-1}"; do
            if [[ "${field}" =~ '^[0-9]*.$' ]]; then
                echo -n "${(l:${widths[${i}]}:: :)field} "
            else
                echo -n "${(r:${widths[${i}]}:: :)field} "
            fi
            (( i++ ))
        done
        # shellcheck disable=SC2298
        echo "${${(@s/\x00/)line}[-1]}"
    done
}

function .zsh_git_ls_is_git_dir() {
    command git -C "${1}" rev-parse >/dev/null 2>&1
}

function .zsh_git_ls_get_repo_path() {
    command git -C "${1}" rev-parse --show-toplevel 2>/dev/null
}

function .zsh_git_ls_is_ignored() {
    local repo_path="${1}"
    local file_path="${2}"

    if [[ "${file_path:t}" == '.' ]] || [[ "${file_path:t}" == '..' ]] || [[ "${file_path:t}" == '.git' ]]; then
        return 0
    fi

    command git -C "${repo_path}" check-ignore -q "${repo_path}/${file_path}"
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
        echo -n "${DIRTY_COLOR}${UNTRACKED_CHARACTER}${RESET_COLOR}"
        return
    elif [[ $1 == '!!' ]]; then # ignored
        echo -n ' '
        return
    fi

    # get color
    if [[ "${1}" =~ '\S ' ]]; then    # all changes in index
        echo -n "${MODIFIED_COLOR}"
    elif [[ "${1}" =~ '\S\S' ]]; then # some changes in index
        echo -n "${MODIFIED_DIRTY_COLOR}"
    elif [[ "${1}" =~ ' \S' ]]; then  # all changes not in index
        echo -n "${DIRTY_COLOR}"
    else                            # no changes
        echo -n "${NOT_MODIFIED_COLOR}"
    fi

    # get character
    if [[ "${1}" =~ 'A' ]]; then   # added file
        echo -n "${ADDED_CHARACTER}"
    elif [[ "${1}" =~ 'R' ]]; then # renamed file
        echo -n "${RENAMED_CHARACTER}"
    elif [[ "${1}" =~ '/' ]]; then # directory containing changes
        echo -n "${DIR_CONTAINING_CHANGES_CHARACTER}"
    elif [[ "${1}" =~ 'M' ]]; then # modified
        echo -n "${MODIFIED_CHARACTER}"
    else                         # not modified
        echo -n "${NOT_MODIFIED_CHARACTER}"
    fi

    # reset color
    echo -n "${RESET_COLOR}"
}

function .zsh_git_ls_print_help() {
    cat << EOHELP
Usage: $1 [OPTION]... [FILE]...
        --help          display this help and exit

For explanations for the following options see 'ls --help'.
    -a, --all
    -A, --almost-all
    -B, --ignore-backups
    -d, --directory
    -F, --classify
        --file-type
        --group-directories-first
    -h, --human-readable
        --si
        --hide=PATTERN
        --indicator-style=WORD
    -I, --ignore=PATTERN
    -p
    -r, --reverse
    -R, --recursive
    -S
        --sort=WORD
    -t
    -U
    -v
    -X
EOHELP
}


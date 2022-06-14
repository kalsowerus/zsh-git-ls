# shellcheck disable=SC2076

function git-ls() {
    setopt local_options warn_create_global
    zmodload zsh/datetime
    local IFS='
'
    zparseopts -D -E -F -a todo - \
        a=o_all -all=o_all \
        A=o_almost_all -almost-all=o_almost_all \
        F=o_ls_opts -classify=o_ls_opts \
        -file-type=o_ls_opts \
        -group-directories-first=o_group_directories_first \
        h=o_human_readable -human-readable=o_human_readable \
        -si=o_si \
        -indicator-style:=o_ls_opts \
        p=o_ls_opts \
        r=o_reverse -reverse=o_reverse \
        S=o_S \
        t=o_t \
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

    declare -a dirs
    if (( $# < 2 )); then
        dirs=("${1:-.}")
    else
        # shellcheck disable=SC2207,SC2296
        dirs=($(echo "${(j:\n:)@}" | sort))
    fi

    local dir=
    local files=
    local file=
    local stat=
    local file_infos=
    local item=
    local file_info=
    local section=
    local repo_path=
    local git_status=
    local size=
    local total=
    local file_path=
    local dir_status=
    local file_status_character=
    # shellcheck disable=SC2128,SC2250
    for dir in $dirs; do
        if [[ ! -d "${dir}" ]]; then
            echo "cannot access '${dir}': Not a directory" >&2
            continue
        fi

        section=
        repo_path=
        git_status=
        total=0
        if .zsh_git_ls_is_git_dir "${dir}"; then
            repo_path=$(.zsh_git_ls_get_repo_path "${dir}")
            git_status=$(.zsh_git_ls_get_git_status "${repo_path}")
        fi
        if (( $# > 1 )); then
            echo "${dir}:"
        fi
        
        files=()
        if [[ -n "${o_almost_all}" ]]; then
            setopt glob_dots
        elif [[ -n "${o_all}" ]]; then
            setopt glob_dots
            files+=(. ..)
        fi
        files+=("${dir}"/*)

        file_infos=($(command stat --printf '%n\t%A\t%h\t%G\t%U\t%s\t%Y\t%b\t%B\t%F\n' ${files} | sed 's/\tdirectory$/\t0/g' | sed 's/\t[^\t0]*$/\t1/g'))

        # sorting
        if [[ -n "${o_S}" ]]; then
            file_infos=($(sort -hrs -k 6 <<< "${file_infos}"))
        fi
        if [[ -n "${o_t}" ]]; then
            file_infos=($(sort -nrs -k 7 <<< "${file_infos}"))
        fi
        if [[ -n "${o_group_directories_first}" ]]; then
            file_infos=($(sort -ns -k 10 <<< "${file_infos}"))
        fi
        if [[ -n "${o_reverse}" ]]; then
            file_infos=($(tac <<< "${file_infos}"))
        fi

        for item in ${file_infos}; do
            file_info=($(echo "${item}" | sed 's/\t/\n/g' ))
            # shellcheck disable=SC2207
            (( total += file_info[8]*file_info[9] ))
            section="${section}${file_info[2]}\t${file_info[3]}\t${file_info[4]}\t${file_info[5]}"
        
            if [[ -n "${o_human_readable}" ]]; then
                size=$(numfmt --to=iec "${file_info[6]}")
            elif [[ -n "${o_si}" ]]; then
                size=$(numfmt --to=si "${file_info[6]}")
            else
                size="${file_info[6]}"
            fi
            section="${section}\t${size}"
        
            section="${section}\t$(strftime '%b %e %H:%M' "${file_info[7]}")"

            # git status character
            if [[ -n "${git_status}" ]]; then
                # shellcheck disable=SC2300
                file_path=${$(realpath -s "${dir}/${file_info[1]}")#${repo_path}/}
                local file_status=
                if [[ -d "${repo_path}/${file_path}" ]] && [[ ! -L "${repo_path}/${file_path}" ]]; then
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
                section="${section}\t${file_status_character}"
            fi

            # shellcheck disable=SC2164
            section="${section}\t$(cd "${dir}"; command ls ${o_ls_opts} -ld --color=always --time-style='+&&' "${file_info[1]##*/}" | sed -E 's/.*?&&\s*(.*)$/\1/')\n"
        done
        echo "total $(numfmt --to=iec "${total}")"
        echo "${section}" | column -t -o ' ' -s $'\t' -R 2,5

        if (( $# > 1 )); then
            echo
        fi
    done
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
    -F, --classify
        --file-type
        --group-directories-first
    -h, --human-readable
        --si
        --indicator-style=WORD
    -p
    -r, --reverse
    -S
    -t
EOHELP
}


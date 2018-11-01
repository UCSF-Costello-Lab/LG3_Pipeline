#!/bin/bash

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# OUTPUT
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Use colored stdout if the terminal supports it
## and as long as a stdout are not redirected
function term_colors {
    local action
    local what
    
    action=$1
    what=$2
    [[ -z "${what}" ]] && what=1
    
    if [[ "${action}" == "enable" && -t "${what}" ]]; then
	## ANSI foreground colors
	black=$(tput setaf 0)
	red=$(tput setaf 1)
	green=$(tput setaf 2)
	yellow=$(tput setaf 3)
	blue=$(tput setaf 4)
	magenta=$(tput setaf 5)
	cyan=$(tput setaf 6)
	white=$(tput setaf 7)

	## Text modes
	bold=$(tput bold)
	dim=$(tput dim)
	reset=$(tput sgr0)
    else
	export black=
	export red=
	export green=
	export yellow=
	export blue=
	export magenta=
	export cyan=
	export white=

	export bold=
	export dim=

	export reset=
    fi
}


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# TESTING
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function test_context {
    local magenta
    local reset
    if [[ -t 1 ]]; then
	magenta=$(tput setaf 5)
        reset=$(tput sgr0)
    fi
    echo -e "${magenta}*** $*${reset}"
}

function test_context_begin {
    test_context "$* ..."
}

function test_context_end {
    test_context "$* ... done"
}


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# CONDITIONS
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function error {
    local red
    local gray
    local bold
    local reset
    
    ON_ERROR=${ON_ERROR:-on_error}
    TRACEBACK_ON_ERROR=${TRACEBACK_ON_ERROR:-true}
    EXIT_ON_ERROR=${EXIT_ON_ERROR:-true}
    EXIT_VALUE=${EXIT_VALUE:-1}

    ## Parse arguments
    while [ -n "$1" ]; do
        case "$1" in
            --dryrun) EXIT_ON_ERROR=false; shift;;
            --value=*) EXIT_VALUE="${1/--value=/}"; shift;;
            *) break;;
        esac
    done

    if [[ -t 1 ]]; then
	red=$(tput setaf 1)
	gray=$(tput setaf 8)
	bold=$(tput bold)
        reset=$(tput sgr0)
    fi

    echo -e "${red}${bold}ERROR:${reset} ${bold}$*${reset}"

    if ${TRACEBACK_ON_ERROR}; then
       echo -e "${gray}Traceback:"
       for ((ii = 1; ii < "${#BASH_LINENO[@]}"; ii++ )); do
           printf "%d: %s() on line #%s in %s\n" "$ii" "${FUNCNAME[$ii]}" "${BASH_LINENO[$((ii-1))]}" "${BASH_SOURCE[$ii]}"
       done
    fi

    if [[ -n "${ON_ERROR}" ]]; then
	if [[ $(type -t "${ON_ERROR}") == "function" ]]; then
            ${ON_ERROR}
	fi
    fi

    ## Exit?
    if ${EXIT_ON_ERROR}; then
        echo -e "Exiting (exit ${EXIT_VALUE})${reset}";
	exit "${EXIT_VALUE}"
    fi

    printf "%s" "${reset}"
}

function warn {
    local yellow
    local reset
    if [[ -t 1 ]]; then
	yellow=$(tput setaf 3)
	bold=$(tput bold)
        reset=$(tput sgr0)
    fi
    echo -e "${yellow}${bold}WARNING on line ${BASH_LINENO[0]}${reset}: $*"
}


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# ASSERTIONS
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function assert_file_exists {
    file=$1
    [[ -f "${file}" ]] || error "File not found: '${file}' (working directory '${PWD}')"
}

function assert_file_executable {
    file=$1
    assert_file_exists "${file}"
    [[ -x "${file}" ]] || error "File exists but is not executable: '${file}' (working directory '${PWD}')"
}

function assert_directory_exists {
    dir=$1
    [[ -d "${dir}" ]] || error "Directory not found: '${dir}' (working directory '${PWD}')"
}
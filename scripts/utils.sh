#!/bin/bash

## Use colored stdout if the terminal supports it
## and as long as a stdout are not redirected
function term_colors {
    local action
    local what
    
    action=$1
    what=$2
    [[ -z "${what}" ]] && what=1
    
    if [[ "${action}" == "enable" && -t "${what}" ]]; then
	black=$(tput setaf 0)
	red=$(tput setaf 1)
	green=$(tput setaf 2)
	yellow=$(tput setaf 3)
	blue=$(tput setaf 4)
	magenta=$(tput setaf 5)
	cyan=$(tput setaf 6)
	white=$(tput setaf 7)

	gray=$(tput setaf 8)
	bright_red=$(tput setaf 9)
	bright_green=$(tput setaf 10)
	bright_yellow=$(tput setaf 11)
	bright_blue=$(tput setaf 12)
	bright_magenta=$(tput setaf 13)
	bright_cyan=$(tput setaf 14)
	bright_white=$(tput setaf 15)

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

	export gray=
	export bright_red=
	export bright_green=
	export bright_yellow=
	export bright_blue=
	export bright_magenta=
	export bright_cyan=
	export bright_white=

	export reset=
    fi
}

function error {
    local red
    local reset
    
    if [[ -t 1 ]]; then
	red=$(tput setaf 1)
        reset=$(tput sgr0)
    fi
    echo -e "${red}ERROR: $*${reset}"
    exit 1
}

function warn {
    local yellow
    local reset
    
    if [[ -t 1 ]]; then
	yellow=$(tput setaf 1)
        reset=$(tput sgr0)
    fi
    echo -e "${yellow}WARNING: $*${reset}"
}


function assert_file_exists {
    file=$1
    [[ -f "${file}" ]] || error "File not found: '${file}' (working directory '${PWD}')"
}

function assert_file_executable {
    file=$1
    assert_file_exist "${file}"
    [[ -x "${file}" ]] || error "File exists but is not executable: '${file}' (working directory '${PWD}')"
}

function assert_directory_exists {
    dir=$1
    [[ -d "${dir}" ]] || error "Directory not found: '${dir}' (working directory '${PWD}')"
}

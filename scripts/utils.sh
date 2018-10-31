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

function error {
    local red
    local reset
    
    if [[ -t 1 ]]; then
	red=$(tput setaf 1)
	bold=$(tput bold)
        reset=$(tput sgr0)
    fi
    echo -e "${red}${bold}ERROR on line ${BASH_LINENO[0]}${reset}: $*"
    exit 1
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

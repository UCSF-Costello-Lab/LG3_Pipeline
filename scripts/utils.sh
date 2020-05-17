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
           printf "%d: %s() on line #%s in %s\\n" "$ii" "${FUNCNAME[$ii]}" "${BASH_LINENO[$((ii-1))]}" "${BASH_SOURCE[$ii]}"
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
    
    TRACEBACK_ON_WARN=${TRACEBACK_ON_WARN:-false}
    
    if [[ -t 1 ]]; then
        yellow=$(tput setaf 3)
        bold=$(tput bold)
        reset=$(tput sgr0)
    fi
    
    echo -e "${yellow}${bold}WARNING${reset}: $*"
    
    if ${TRACEBACK_ON_WARN}; then
       echo -e "${gray}Traceback:"
       for ((ii = 1; ii < "${#BASH_LINENO[@]}"; ii++ )); do
           printf "%d: %s() on line #%s in %s\\n" "$ii" "${FUNCNAME[$ii]}" "${BASH_LINENO[$((ii-1))]}" "${BASH_SOURCE[$ii]}"
       done
    fi
    
    printf "%s" "${reset}"
}


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# ASSERTIONS
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Usage: assert_file_exists /path/to/file
function assert_file_exists {
    [[ $# -ne 1 ]] && error "${FUNCNAME[0]}() requires a single argument: $#"
    [[ -n "$1" ]] || error "File name must be non-empty: '$1'"
    [[ -f "$1" ]] || error "No such file: '$1' (working directory '${PWD}')"
}

function assert_link_exists {
    [[ $# -ne 1 ]] && error "${FUNCNAME[0]}() requires a single argument: $#"
    [[ -n "$1" ]] || error "File name must be non-empty: '$1'"
    [[ -L "$1" ]] || error "File is not a link: '$1' (working directory '${PWD}')"
    [[ -e "$1" ]] || error "[File] link is broken: '$1' (working directory '${PWD}')"
}

## Usage: assert_file_executable /path/to/file
function assert_file_executable {
    [[ $# -ne 1 ]] && error "${FUNCNAME[0]}() requires a single argument: $#"
    assert_file_exists "$1"
    [[ -x "$1" ]] || error "File exists but is not executable: '$1' (working directory '${PWD}')"
}

## Usage: assert_directory_exists /path/to/folder
function assert_directory_exists {
    [[ $# -ne 1 ]] && error "${FUNCNAME[0]}() requires a single argument: $#"
    [[ -n "$1" ]] || error "Directory name must be non-empty: '$1'"
    [[ -d "$1" ]] || error "No such directory: '$1' (working directory '${PWD}')"
}

## Usage: assert_patient_name "${PATIENT}"
function assert_patient_name {
    [[ $# -ne 1 ]] && error "${FUNCNAME[0]}() requires a single argument: $#"
    [[ -n "$1" ]] || error "Patient name must be non-empty: '$1'"
    [[ "$1" == *[_]* ]] && error "Patient name must not contain underscores: $1"
}


## Usage: assert_pwd
function assert_pwd {
    [[ $# -ne 0 ]] && error "${FUNCNAME[0]}() must not be called with arguments: $#"
    ## Don't allow running the pipeline from within LG3_HOME
    equal_dirs "${PWD}" "${LG3_HOME}" && error "The LG3 Pipeline must not be run from the folder where it is installed (LG3_HOME): ${PWD}"
}


## Usage: assert_python "" or assert_python "<python-binary>"
function assert_python {
    local version version_x_y
    local bin

    ## Arguments are optional
    bin=$1
    
    if [[ -n "$bin" ]]; then
	assert_file_executable "$bin"
    else	
	bin=$(command -v python) || error "Python executable not found on PATH: ${PATH}"
    fi
    
    ## Assert correct version
    version=$(2>&1 "$bin" --version | sed -E 's/.*(P|p)ython *//g')
    version_x_y=$(echo "$version" | sed -E 's/[.][0-9]+$//g')
    [[ "$version_x_y" == "2.6" ]] || [[ "$version_x_y" == "2.7" ]] || error "Requires Python 2.6 or 2.7: $version ($bin)"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# NAVIGATION
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function change_dir {
    opwd=${PWD}
    assert_directory_exists "$1"
    cd "$1" || error "Failed to set working directory to $1"
    echo "New working directory: '$1' (was '${opwd}')"
}

function make_dir {
    mkdir -p "$1" || error "Failed to create new working directory $1"
}

function make_change_dir {
    make_dir "$1"
    change_dir "$1"
}

function equal_dirs {
    local a
    local b
    a=$(readlink -f "$1")
    b=$(readlink -f "$2")
    [[ "${a}" == "${b}" ]]
}


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# LG3 specific
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function source_lg3_conf {
    ## The default settings
    assert_file_exists "${LG3_HOME}/lg3.conf"
    # shellcheck disable=1090
    source "${LG3_HOME}/lg3.conf"
    echo "Sourced: ${LG3_HOME}/lg3.conf"

    ## Settings specific to the project folder?
    if [ -f "lg3.conf" ] && ! equal_dirs "." "${LG3_HOME}"; then
        # shellcheck disable=1090
        source "lg3.conf"
        echo "Sourced: ${PWD}/lg3.conf ($(stat --printf='%s' lg3.conf) bytes)"
    fi
}




# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# SOFTWARE
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

## java version "1.6.0_27"
JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
assert_file_executable "$JAVA"

## Python 2.6.6
PYTHON=/usr/bin/python
assert_file_executable "$PYTHON"
assert_python "$PYTHON"
unset PYTHONPATH  ## ADHOC: In case it is set by user. /HB 2018-09-07

## R scripting front-end version 3.2.0 (2015-04-16)
RSCRIPT=/opt/R/R-latest/bin/Rscript
assert_file_executable "$RSCRIPT"
## Workaround: 'Rscript' called somewhere in the Recal script(s)
PATH="$(dirname "$RSCRIPT"):$PATH"

## samtools 0.1.18 (r982:295
SAMTOOLS=${LG3_HOME}/tools/samtools-0.1.18/samtools
assert_file_executable "$SAMTOOLS"

## bwa 0.5.9-r26-dev
BWA=${LG3_HOME}/tools/bwa-0.5.10/bwa
assert_file_executable "$BWA"

# Picard
PICARD_HOME=${LG3_HOME}/tools/picard-tools-1.64
assert_directory_exists "$PICARD_HOME"

# GATK 1.6-5-g557da77
GATK=${LG3_HOME}/tools/GenomeAnalysisTK-1.6-5-g557da77/GenomeAnalysisTK.jar
assert_file_executable "$GATK"

# bedtools 2.16.2
BEDTOOLS="/opt/BEDTools/BEDTools-2.16.2/bin/bedtools"
assert_file_executable "$BEDTOOLS"

# muTect
MUTECT="${LG3_HOME}/tools/muTect-1.0.27783.jar"
assert_file_executable "$MUTECT"


# AnnoVar
ANNOVAR_HOME=${LG3_HOME}/AnnoVar
assert_directory_exists "$ANNOVAR_HOME"

$ cutadapt 1.2.1
CUTADAPT=/opt/Python/Python-2.7.3/bin/cutadapt
assert_file_executable "$CUTADAPT"

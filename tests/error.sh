#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME}/scripts/utils.sh"

test_context_begin "error"

EXIT_ON_ERROR=false

function my_fcn {
    echo "my_fcn() ..."
    error "This is an error in 'my_fcn()' [LINENO=${LINENO}]"
    echo "my_fcn() ... done"
}

function my_fcn2 {
    echo "my_fcn2() ..."
    my_fcn
    echo "my_fcn2() ... done"
}

error "Hello world"
error --value=2 "Hello world"
error "Testing traceback line numbers [LINENO=${LINENO}]"
my_fcn
my_fcn2


## Hook function that displays more information on errors
function on_error {
    echo "Details:";
    echo "- HOSTNAME=${HOSTNAME}"
    echo "- PWD=${PWD}"
    echo "- USER=${USER}"
    echo "- PID=${PID}"
    echo "- PPID=${PPID}"
    echo "- PIPESTATUS[]=${PIPESTATUS[*]}"
}


error "Hello world"
error --value=2 "Hello world"
error "Testing traceback line numbers [LINENO=${LINENO}]"
my_fcn
my_fcn2

unset -f on_error

# shellcheck source=tests/error-trigger.sh
source "${LG3_HOME}/tests/error-trigger.sh"

test_context_end "error"

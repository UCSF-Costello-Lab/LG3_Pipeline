#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME}/scripts/utils.sh"

test_context_begin "warn"

function my_fcn {
   warn "This is a warning produced in my_fcn()"
}

warn "This is a warning"
warn "Another warning"
my_fcn


test_context_end "warn"

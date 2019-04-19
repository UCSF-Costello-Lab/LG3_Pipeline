#!/bin/bash

### Configuration
LG3_HOME=${LG3_HOME:?}
PROJECT=${PROJECT:-LG3}
EMAIL=${EMAIL:?}
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}

### DEPRECATION: Retire usage of LG3_{INPUT,OUTPUT}_ROOT
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
LG3_INPUT_ROOT=${LG3_INPUT_ROOT:-${LG3_OUTPUT_ROOT}}
assert_lg3_input_root
assert_lg3_output_root

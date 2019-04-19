#!/bin/bash

LG3_HOME=${LG3_HOME:?}
PROJECT=${PROJECT:-LG3}
PATIENT=${PATIENT:-Patient157t10}
CONV=${CONV:-patient_ID_conversions.tsv}
EMAIL=${EMAIL:?}

### DEPRECATION: Retire usage of LG3_{INPUT,OUTPUT}_ROOT
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
LG3_INPUT_ROOT=${LG3_INPUT_ROOT:-${LG3_OUTPUT_ROOT}}
assert_lg3_input_root
[[ "${LG3_INPUT_ROOT}" == "rawdata" ]] || assert_lg3_output_root

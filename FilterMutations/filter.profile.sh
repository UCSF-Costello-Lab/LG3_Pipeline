#!/bin/bash

PYDIR=${LG3_HOME:?}
if ! echo "${PYTHONPATH}" | grep -E "(^|:)${PYDIR}($|:)" >/dev/null ; then
    export PYTHONPATH=${PYTHONPATH}:$PYDIR
fi

DIR=${PYDIR}/FilterMutations
if [ -d "${DIR}" ]; then
    if ! echo "${PATH}" | grep -E "(^|:)$DIR($|:)" >/dev/null ; then
        export PATH=$PATH:$DIR
    fi
fi


#!/bin/bash

function error {
    echo -e "ERROR: $*";
    exit 1;
}

function warn {
    echo -e "WARNING: $*";
}

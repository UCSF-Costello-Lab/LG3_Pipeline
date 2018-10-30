#!/bin/bash

function error {
    echo -e "$*";
    exit 1;
}

function warn {
    echo -e "WARNING: $*";
}

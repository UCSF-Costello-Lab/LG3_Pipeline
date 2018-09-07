#!/bin/bash

### Configuration
LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
SCRATCHDIR=${SCRATCHDIR:-/scratch/${USER:?}}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "LG3_HOME=$LG3_HOME"
  echo "LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "SCRATCHDIR=$SCRATCHDIR"
  echo "PWD=$PWD"
  echo "USER=$USER"
fi



FD=$1
Z=$2

FQC=/home/ismirnov/install/fastqc/FastQC_v0.11.5/fastqc

cd "$FD" || { echo "ERROR: Can't cd to $FD !"; exit 1; }

F1=${Z}_R1.fastq.gz
F2=${Z}_R2.fastq.gz

time $FQC -t 10 "$F1" "$F2"

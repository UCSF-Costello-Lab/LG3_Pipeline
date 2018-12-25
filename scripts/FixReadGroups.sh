#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME}/scripts/utils.sh"

### Configuration
LG3_HOME=${LG3_HOME:?}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
PROJECT=${PROJECT:?}
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "LG3_HOME=$LG3_HOME"
  echo "LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "PWD=$PWD"
  echo "USER=$USER"
fi


#
##
### This utility replaces read groups in a BAM file
###
### /path/to/FixReadGroups.sh <bam_in> <bam_out>  <new_prefix>
##
#

if [ $# -ne 3 ]; then
    error "Coord-sort and fix read group assignments\\nUsage: $0 in.bam out.bam prefix"
fi

TMP="${LG3_SCRATCH_ROOT}/$prefix/tmp"
make_dir "$TMP"

JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
PICARD_HOME=${LG3_HOME}/tools/picard-tools-1.64
SAMTOOLS=${LG3_HOME}/tools/samtools-0.1.18/samtools

pl="Illumina"
pu="Exome"

bamin=$1
bamout=$2
prefix=$3

echo "-------------------------------------------------"
echo "[FixReadGroups] Coord-sort and fix read group assignments"
echo "Java: $JAVA"
echo "Picard: $PICARD_HOME"
echo "Samtools: $SAMTOOLS"
echo "-------------------------------------------------"
echo "[FixReadGroups] BAM input: $bamin"
echo "[FixReadGroups] BAM output: $bamout"
echo "[FixReadGroups] New Group Name: $prefix"
echo "-------------------------------------------------"

if [ ! -f "$bamout" ]; then
$JAVA -Xmx4g -jar "$PICARD_HOME/AddOrReplaceReadGroups.jar" \
        INPUT="${bamin}" \
        OUTPUT="${bamout}" \
        SORT_ORDER=coordinate \
        RGID="$prefix" \
        RGLB="$prefix" \
        RGPL=$pl \
        RGPU=$pu \
        RGSM="$prefix" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=LENIENT || error "job failed!"
else
        echo "[FixReadGroups] $bamout exists, skipping ..."
fi

echo "[FixReadGroups] Indexing BAM file..."
$SAMTOOLS index "${bamout}" || error "BAM indexing failed"

echo "[FixReadGroups] All Done!"


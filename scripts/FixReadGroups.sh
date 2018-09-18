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


#
##
### This utility replaces read groups in a BAM file
###
### /path/to/FixReadGroups.sh <bam_in> <bam_out>  <new_prefix>
##
#

if [ $# -ne 3 ]; then
        echo "Coord-sort and fix read group assignments"
        echo "Usage: $0 in.bam out.bam prefix"
        exit 1
fi

TMP="${SCRATCHDIR}/$prefix/tmp"
mkdir -p "$TMP"

JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
PICARD=${LG3_HOME}/tools/picard-tools-1.64
SAMTOOLS=${LG3_HOME}/tools/samtools-0.1.18/samtools

pl="Illumina"
pu="Exome"

bamin=$1
bamout=$2
prefix=$3

echo "-------------------------------------------------"
echo "[FixReadGroups] Coord-sort and fix read group assignments"
echo "Java: $JAVA"
echo "Picard: $PICARD"
echo "Samtools: $SAMTOOLS"
echo "-------------------------------------------------"
echo "[FixReadGroups] BAM input: $bamin"
echo "[FixReadGroups] BAM output: $bamout"
echo "[FixReadGroups] New Group Name: $prefix"
echo "-------------------------------------------------"

if [ ! -f "$bamout" ]; then
$JAVA -Xmx4g -jar "$PICARD/AddOrReplaceReadGroups.jar" \
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
        VALIDATION_STRINGENCY=LENIENT || { echo "ERROR: job failed!"; exit 1; }
else
        echo "[FixReadGroups] $bamout exists, skipping ..."
fi

echo "[FixReadGroups] Indexing BAM file..."
$SAMTOOLS index "${bamout}" || { echo "BAM indexing failed"; exit 1; }

echo "[FixReadGroups] All Done!"
exit 0

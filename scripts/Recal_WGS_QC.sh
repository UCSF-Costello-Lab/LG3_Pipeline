#!/bin/bash

### Configuration
LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
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
#

# shellcheck source=.bashrc
source "${LG3_HOME}/.bashrc"

#Define resources and tools
JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
SAMTOOLS=${LG3_HOME}/tools/samtools-0.1.18/samtools
REF="${LG3_HOME}/resources/UCSC_HG19_Feb_2009/hg19.fa"

#Input variables
bamfile=$1
PREF=$(basename "$bamfile" .bam)
Z=${PREF%%.*}
D=$(dirname "$bamfile")
cd "$D" || { echo "ERROR: Can't cd to $D"; exit 1; }
TMP="${LG3_SCRATCH_ROOT}/${Z}_tmp"
mkdir -p "$TMP"

echo "------------------------------------------------------"
echo "[Recal] QC after Base quality recalibration (WGS version)"
date
echo "------------------------------------------------------"

echo "[QC] Quality Control"
echo "------------------------------------------------------"
echo "[QC] $bamfile"

echo "[QC] Calculate flag statistics..."
$SAMTOOLS flagstat "$bamfile" > "${Z}.bwa.realigned.rmDups.recal.flagstat" 2>&1

echo "[QC] Collect multiple QC metrics..."
$JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
        -jar "${LG3_HOME}/tools/picard-tools-1.64/CollectMultipleMetrics.jar" \
        INPUT="$bamfile" \
        OUTPUT="${Z}.bwa.realigned.rmDups.recal" \
        REFERENCE_SEQUENCE="${REF}" \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT || { echo "Collect multiple QC metrics failed"; exit 1; }
        echo "------------------------------------------------------"


echo -n "[QC] $Z Finished! "
date
echo "-------------------------------------------------"


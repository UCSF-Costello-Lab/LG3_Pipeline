#!/bin/bash

### Configuration
LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
PROJECT=${PROJECT:?}
SCRATCHDIR=${SCRATCHDIR:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "LG3_HOME=$LG3_HOME"
  echo "LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "SCRATCHDIR=$SCRATCHDIR"
  echo "PWD=$PWD"
  echo "USER=$USER"
fi


## 
## Calculate Hybrid Selection Metrix on processed BAM files
## 
## Usage: /path/to/HybridSelect.sh *.bam 
##
##

JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
PICARD=${LG3_HOME}/tools/picard-tools-1.64
TMP=${SCRATCHDIR}

i=$1
ilist=$2
#patient=$3 ## Not used!

ilist_b=$(basename "$ilist")
echo "------------------------------------------------------"
echo "[HSM] Using: $ilist_b"
        echo "------------------------------------------------------"
        base=$(basename "$i" .bam)
        dir=$(dirname "$i")
        cd "$dir" || { echo "ERROR: Can't cd to $dir"; exit 1; }
        echo "[HSM] Base: $base"
        echo "[HSM] Calculating hybrid selection metrics..."
        $JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
                -jar "$PICARD/CalculateHsMetrics.jar" \
                BAIT_INTERVALS="${ilist}" \
                TARGET_INTERVALS="${ilist}" \
                INPUT="$i" \
                OUTPUT="${base}.hybrid_selection_metrics2" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT || { echo "Calculate hybrid selection metrics failed"; exit 1; }

echo "------------------------------------------------------"
echo "[HSM] Done" 

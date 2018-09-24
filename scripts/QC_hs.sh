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


#
## Base quality recalibration, prep for indel detection, and quality control
#
## Usage: /path/to/Recal.sh <bamfiles> <patientID> <exome_kit.interval_list>
#
#
### https://broadinstitute.github.io/picard/picard-metric-definitions.html#HsMetrics

# shellcheck source=.bashrc
source "${LG3_HOME}/.bashrc"
DIR=${LG3_OUTPUT_ROOT}/LG3/exomes_recal

JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
#Input variables
patientID=$1
ilist=$2
shift
shift

TMP="${SCRATCHDIR}/${patientID}_tmp"
mkdir -p "$TMP"

echo "------------------------------------------------------"
date
echo "------------------------------------------------------"
echo "[QC] Patient ID: $patientID"
echo "[QC] ILIST : $ilist"
echo "------------------------------------------------------"


cd "$DIR/$patientID" || { echo "ERROR: Can't cd in $DIR/$patientID"; exit 1; }

echo "[QC] Calculate hybrid selection metrics..."
for i in "$@"
do
        echo "------------------------------------------------------"
        base=${i%%.bwa.realigned.rmDups.recal.bam}
        echo "[QC] Sample: $base"

        $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
                -jar "${LG3_HOME}/tools/picard-tools-1.64/CalculateHsMetrics.jar" \
                BAIT_INTERVALS="${ilist}" \
                TARGET_INTERVALS="${ilist}" \
                INPUT="$i" \
                OUTPUT="${base}.bwa.realigned.rmDups.recal.HS_metrics" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT || { echo "Calculate hybrid selection metrics failed"; exit 1; }

done

echo -n "[QC] Finished! "
date
echo "-------------------------------------------------"


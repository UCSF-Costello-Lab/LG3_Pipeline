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
## Base quality recalibration, prep for indel detection, and quality control
#
## Usage: /path/to/Recal.sh <bamfiles> <patientID> <exome_kit.interval_list>
#
#

#Fix the path so the QC scripts can output pdfs
#Both of these aren't necessary, but I'm leaving them here for future use
# shellcheck source=.bashrc
source "${LG3_HOME}/.bashrc"
PATH=/opt/R/R-latest/bin/R:$PATH

#Define resources and tools
JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
SAMTOOLS=${LG3_HOME}/tools/samtools-0.1.18/samtools
REF="${LG3_HOME}/resources/UCSC_HG19_Feb_2009/hg19.fa"

#Input variables
bamfiles=$1
patientID=$2
ilist=$3
TMP="${SCRATCHDIR}/${patientID}_tmp"
mkdir -p "$TMP"

echo "------------------------------------------------------"
echo "[Recal] Base quality recalibration (bigmem version)"
date
echo "------------------------------------------------------"
echo "[Recal] Recalibration Group: $patientID"
echo "$bamfiles" | awk -F ":" '{for (i=1; i<=NF; i++) print "[Recal] Exome:"$i}'
echo "------------------------------------------------------"

echo "[Skip] Merge BAM files..."
echo "[Skip] Index new BAM file..."
echo "[Skip] Create intervals for indel detection..."
echo "[Skip] Indel realignment..."
echo "[Skip] Fix mate information..."
echo "[Skip] Mark duplicates..."
echo "[Skip] Index BAM file..."
echo "[Skip] Base-quality recalibration: Count covariates..."
echo "[Skip] Base-quality recalibration: Table Recalibration..."
echo "[Skip] Index BAM file..."
echo "[Skip] Split BAM files..."

echo "------------------------------------------------------"
echo -n "[Recal] Finished! "
date
echo "------------------------------------------------------"

echo "[QC] Quality Control"
for i in *.bwa.realigned.rmDups.recal.bam
do
        echo "------------------------------------------------------"
        base=${i%%.bwa.realigned.rmDups.recal.bam}
        echo "[QC] $base"

        echo "[QC] Calculate flag statistics..."
        $SAMTOOLS flagstat "$i" > "${base}.bwa.realigned.rmDups.recal.flagstat" 2>&1

        echo "[QC] Calculate hybrid selection metrics..."
        $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
                -jar "${LG3_HOME}/tools/picard-tools-1.64/CalculateHsMetrics.jar" \
                BAIT_INTERVALS="${ilist}" \
                TARGET_INTERVALS="${ilist}" \
                INPUT="$i" \
                OUTPUT="${base}.bwa.realigned.rmDups.recal.hybrid_selection_metrics" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT || { echo "Calculate hybrid selection metrics failed"; exit 1; }

        echo "[QC] Collect multiple QC metrics..."
        $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
                -jar "${LG3_HOME}/tools/picard-tools-1.64/CollectMultipleMetrics.jar" \
                INPUT="$i" \
                OUTPUT="${base}.bwa.realigned.rmDups.recal" \
                REFERENCE_SEQUENCE="${REF}" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT || { echo "Collect multiple QC metrics failed"; exit 1; }
        echo "------------------------------------------------------"
done

echo -n "[QC] Finished! "
date
echo "-------------------------------------------------"


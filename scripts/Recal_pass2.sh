#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME}/scripts/utils.sh"

PROGRAM=${BASH_SOURCE[0]}
PROG=$(basename "$PROGRAM")
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_HOME=${LG3_HOME:?}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
PROJECT=${PROJECT:?}
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}
ncores=${PBS_NUM_PPN:-1}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "$PROG Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- PBS_NUM_PPN=$PBS_NUM_PPN"
  echo "- ncores=$ncores"
fi

## References
REF=${LG3_HOME}/resources/UCSC_HG19_Feb_2009/hg19.fa
THOUSAND=${LG3_HOME}/resources/1000G_biallelic.indels.hg19.sorted.vcf
echo "References:"
echo "- REF=${REF:?}"
echo "- THOUSAND=${THOUSAND:?}"
[[ -f "$REF" ]]      || error "File not found: ${REF}"
[[ -f "$THOUSAND" ]] || error "File not found: ${THOUSAND}"

## Software
JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
SAMTOOLS=${LG3_HOME}/tools/samtools-0.1.18/samtools
GATK="${LG3_HOME}/tools/GenomeAnalysisTK-1.6-5-g557da77/GenomeAnalysisTK.jar"
PICARD_HOME=${LG3_HOME}/tools/picard-tools-1.64
PICARD_SCRIPT_A=${PICARD_HOME}/MergeSamFiles.jar
PICARD_SCRIPT_B=${PICARD_HOME}/FixMateInformation.jar
PICARD_SCRIPT_C=${PICARD_HOME}/MarkDuplicates.jar
PICARD_SCRIPT_D=${PICARD_HOME}/CalculateHsMetrics.jar
PICARD_SCRIPT_E=${PICARD_HOME}/CollectMultipleMetrics.jar

echo "Software:"
echo "- JAVA=${JAVA:?}"
echo "- SAMTOOLS=${SAMTOOLS:?}"
echo "- GATK=${GATK:?}"
echo "- PICARD_HOME=${PICARD_HOME:?}"

## Assert existance of software
[[ -x "$JAVA" ]]            || error "Not an executable: ${JAVA}"
[[ -x "$SAMTOOLS" ]]        || error "Not an executable: ${SAMTOOLS}"
[[ -f "$GATK" ]]            || error "File not found: ${GATK}"
[[ -d "$PICARD_HOME" ]]     || error "File not found: ${PICARD_HOME}"
[[ -f "$PICARD_SCRIPT_A" ]] || error "File not found: ${PICARD_SCRIPT_A}"
[[ -f "$PICARD_SCRIPT_B" ]] || error "File not found: ${PICARD_SCRIPT_B}"
[[ -f "$PICARD_SCRIPT_C" ]] || error "File not found: ${PICARD_SCRIPT_C}"
[[ -f "$PICARD_SCRIPT_D" ]] || error "File not found: ${PICARD_SCRIPT_D}"
[[ -f "$PICARD_SCRIPT_E" ]] || error "File not found: ${PICARD_SCRIPT_E}"


#Input 
bamfiles=$1
PATIENT=$2
ILIST=$3

echo "${PROG} Input:"
echo "- bamfiles=${bamfiles:?}"
echo "- PATIENT=${PATIENT:?}"
echo "- ILIST=${ILIST:?}"

## Assert existance of input files
[[ -f "$ILIST" ]] || error "File not found: ${ILIST}"

TMP="${LG3_SCRATCH_ROOT}/${PATIENT}_tmp"
mkdir -p "$TMP" || error "Can't create scratch directory ${TMP}"

echo "------------------------------------------------------"
echo "[Recal_pass2] Merge Group: $PATIENT"
echo "$bamfiles" | awk -F ":" '{for (i=1; i<=NF; i++) print "[Recal_pass2] Exome:"$i}'
echo "------------------------------------------------------"

## Construct string with one or more '-I "<bam>"' elements
inputs=$(echo "$bamfiles" | awk -F ":" '{OFS=" "} {for (i=1; i<=NF; i++) printf "INPUT="$i" "}')

echo -e "\\n[Recal_pass2] Merge BAM files..."
# shellcheck disable=SC2086
# Comment: Because how 'inputs' is created and used below
{ time $JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_SCRIPT_A}" \
        ${inputs} \
        OUTPUT="${PATIENT}.merged.bam" \
        SORT_ORDER=coordinate \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT; } 2>&1 || error "Merge BAM files failed"

echo -e "\\n[Recal_pass2] Index merged BAM file..."
{ time $SAMTOOLS index "${PATIENT}.merged.bam"; } 2>&1 || error "First indexing failed"

echo -e "\\n[Recal_pass2] Create intervals for indel detection..."
{ time $JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
        -jar "$GATK" \
        --analysis_type RealignerTargetCreator \
		  -L "${ILIST}" \
        --reference_sequence "$REF" \
        --known "$THOUSAND" \
        --num_threads "${ncores}" \
        --logging_level WARN \
        --input_file "${PATIENT}.merged.bam" \
        --out "${PATIENT}.merged.intervals"; } 2>&1 || error "GATK Interval creation failed"

echo -e "\\n[Recal_pass2] Indel realignment..."
{ time $JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
        -jar "$GATK" \
        --analysis_type IndelRealigner \
        --reference_sequence "$REF" \
        --knownAlleles "$THOUSAND" \
        --logging_level WARN \
        --consensusDeterminationModel USE_READS \
        --input_file "${PATIENT}.merged.bam" \
        --targetIntervals "${PATIENT}.merged.intervals" \
        --out "${PATIENT}.merged.realigned.bam"; } 2>&1 || error "GATK Indel realignment failed"

rm -f "${PATIENT}.merged.bam"
rm -f "${PATIENT}.merged.bam.bai"
rm -f "${PATIENT}.merged.intervals"

echo -e "\\n[Recal_pass2] Fix mate information..."
{ time $JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_SCRIPT_B}" \
        INPUT="${PATIENT}.merged.realigned.bam" \
        OUTPUT="${PATIENT}.merged.realigned.mateFixed.bam" \
        SORT_ORDER=coordinate \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT; } 2>&1 || error "Picard verify mate information failed"

rm -f "${PATIENT}.merged.realigned.bam"
rm -f "${PATIENT}.merged.realigned.bai"

echo -e "\\n[Recal_pass2] Mark duplicates..."
{ time $JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_SCRIPT_C}" \
        INPUT="${PATIENT}.merged.realigned.mateFixed.bam" \
        OUTPUT="${PATIENT}.merged.realigned.rmDups.bam" \
        METRICS_FILE="${PATIENT}.merged.realigned.mateFixed.metrics" \
        REMOVE_DUPLICATES=TRUE \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=LENIENT; } 2>&1 || error "Mark duplicates failed"

rm -f "${PATIENT}.merged.realigned.mateFixed.bam"

echo -e "\\n[Recal_pass2] Index BAM file..."
{ time $SAMTOOLS index "${PATIENT}.merged.realigned.rmDups.bam"; } 2>&1 || error "Second indexing failed"

echo -e "\\n[Recal_pass2] Split BAM files..."
{ time $JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
        --analysis_type SplitSamFile \
        --reference_sequence "$REF" \
        --logging_level WARN \
        --input_file "${PATIENT}.merged.realigned.rmDups.bam" \
        --outputRoot temp_; } 2>&1 || error "Splitting BAM files failed"

rm -f "${PATIENT}.merged.realigned.rmDups.bam"
rm -f "${PATIENT}.merged.realigned.rmDups.bam.bai"
rm -f "${PATIENT}.merged.realigned.rmDups.bai"

for i in temp_*.bam
do
        base=${i##temp_}
        base=${base%%.bam}
        echo -e "\\n[Recal_pass2] Sorting $base..."
        { time $SAMTOOLS sort "$i" "${base}.bwa.realigned.rmDups"; } 2>&1 || error "Sorting $base failed"
        echo -e "\\n[Recal_pass2] Indexing $base..."
        { time $SAMTOOLS index "${base}.bwa.realigned.rmDups.bam"; } 2>&1 || error "Indexing $base failed"
        rm -f "$i"
done

echo "[Recal_pass2] Finished!"
echo "------------------------------------------------------"

echo "[QC] Quality Control"
for i in *.bwa.realigned.rmDups.bam
do
        echo "------------------------------------------------------"
        base=${i%%.bwa.realigned.rmDups.bam}
        echo "[QC] $base"

        echo -e "\\n[QC] Calculate flag statistics..."
        { time $SAMTOOLS flagstat "$i" > "${base}.bwa.realigned.rmDups.flagstat"; } 2>&1

        echo -e "\\n[QC] Calculate hybrid selection metrics..."
        { time $JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
                -jar "${PICARD_SCRIPT_D}" \
                BAIT_INTERVALS="${ILIST}" \
                TARGET_INTERVALS="${ILIST}" \
                INPUT="$i" \
                OUTPUT="${base}.bwa.realigned.rmDups.hybrid_selection_metrics" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT; } 2>&1 || error "Calculate hybrid selection metrics failed"

        echo -e "\\n[QC] Collect multiple QC metrics..."
        { time $JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
                -jar  "${PICARD_SCRIPT_E}" \
                INPUT="$i" \
                OUTPUT="${base}.bwa.realigned.rmDups" \
                REFERENCE_SEQUENCE="${REF}" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT; } 2>&1 || error "Collect multiple QC metrics failed"
        echo "------------------------------------------------------"
done

echo "[QC] Finished!"
echo "-------------------------------------------------"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"

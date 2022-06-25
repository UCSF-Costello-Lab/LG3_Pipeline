#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME:?}/scripts/utils.sh"
source_lg3_conf

PROGRAM=${BASH_SOURCE[0]}
PROG=$(basename "$PROGRAM")
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_HOME=${LG3_HOME:?}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:?}
LG3_DEBUG=${LG3_DEBUG:-true}
ncores=${SLURM_NTASKS:-1}
declare -i START
START=${START:-1}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "$PROG Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- hostname=$(hostname)"
  echo "- ncores=$ncores"
fi


#
## Base quality recalibration, prep for indel detection, and quality control
#
## Usage: /path/to/Recal.sh <bamfiles> <PATIENT> <exome_kit.interval_list>
#
#

## References
REF=${LG3_HOME}/resources/UCSC_HG19_Feb_2009/hg19.fa
THOUSAND=${LG3_HOME}/resources/1000G_biallelic.indels.hg19.sorted.vcf
DBSNP=${LG3_HOME}/resources/dbsnp_132.hg19.sorted.vcf
echo "References:"
echo "- REF=${REF:?}"
echo "- THOUSAND=${THOUSAND:?}"
echo "- DBSNP=${DBSNP:?}"
assert_file_exists "${REF}"
assert_file_exists "${THOUSAND}"
assert_file_exists "${DBSNP}"

## Software
PICARD_MERGESAMFILES=${PICARD_HOME}/MergeSamFiles.jar
PICARD_FIXMATEINFO=${PICARD_HOME}/FixMateInformation.jar
PICARD_MARKDUPS=${PICARD_HOME}/MarkDuplicates.jar
PICARD_HSMETRICS=${PICARD_HOME}/CalculateHsMetrics.jar
PICARD_MULTIMETRICS=${PICARD_HOME}/CollectMultipleMetrics.jar

echo "Software:"
echo "- JAVA=${JAVA:?}"
echo "- SAMTOOLS=${SAMTOOLS:?}"
echo "- GATK=${GATK:?}"
echo "- PICARD_HOME=${PICARD_HOME:?}"

## Assert existance of software
assert_file_executable "${JAVA}"
assert_file_executable "${SAMTOOLS}"
assert_directory_exists "${PICARD_HOME}"
assert_file_exists "${GATK}"
assert_file_exists "${PICARD_MERGESAMFILES}"
assert_file_exists "${PICARD_FIXMATEINFO}"
assert_file_exists "${PICARD_MARKDUPS}"
assert_file_exists "${PICARD_HSMETRICS}"
assert_file_exists "${PICARD_MULTIMETRICS}"

## Input
bamfiles=$1
PATIENT=$2
ILIST=$3
[[ $# -ge 4 ]] && START=$4
[[ $# -ge 5 ]] && RECOVER_DIR=$5
echo "Input:"
echo "- bamfiles=${bamfiles:?}"
echo "- PATIENT=${PATIENT:?}"
echo "- ILIST=${ILIST:?}"
echo "- START=${START:?}"
echo "- RECOVER_DIR=${RECOVER_DIR:?}"

## Assert existance of input files
assert_file_exists "${ILIST}"

TMP="${LG3_SCRATCH_ROOT}/${PATIENT}_tmp"
make_dir "${TMP}"

echo "------------------------------------------------------"
echo "[Recal] Base quality recalibration (step in version)"
date
echo "------------------------------------------------------"
echo "[Recal] Recalibration Group: $PATIENT"
echo "$bamfiles" | awk -F ":" '{for (i=1; i<=NF; i++) print "[Recal] Exome:"$i}'
echo "------------------------------------------------------"

declare -i STEP
STEP=1
if [ ${STEP} -ge "${START}" ]; then
	echo -e "\\n[Recal step ${STEP}] Merge BAM files..."
	## Construct string with one or more '-I <bam>' elements
	inputs=$(echo "$bamfiles" | awk -F ":" '{OFS=" "} {for (i=1; i<=NF; i++) printf "INPUT="$i" "}')
	# shellcheck disable=SC2086
	# Comment: Because how 'inputs' is created and used below
	{ time $JAVA -Xmx64g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_MERGESAMFILES}" \
        ${inputs} \
        OUTPUT="${PATIENT}.merged.bam" \
        SORT_ORDER=coordinate \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT; } 2>&1 || error "Merge BAM files failed"
fi

STEP+=1
if [ ${STEP} -ge "${START}" ]; then
	echo -e "\\n[Recal step ${STEP}] Index merged BAM file..."
	assert_file_exists "${PATIENT}.merged.bam"
	{ time $SAMTOOLS index "${PATIENT}.merged.bam"; } 2>&1 || error "First indexing failed"
fi

STEP+=1
if [ ${STEP} -ge "${START}" ]; then
	echo -e "\\n[Recal step ${STEP}] Create intervals for indel detection..."
	assert_file_exists "${PATIENT}.merged.bam"
	assert_file_exists "${PATIENT}.merged.bam.bai"
	{ time $JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
        -jar "$GATK" \
        --analysis_type RealignerTargetCreator \
        --reference_sequence "$REF" \
        --known "$THOUSAND" \
		  -L "${ILIST}" \
        --num_threads "${ncores}" \
        --logging_level WARN \
        --input_file "${PATIENT}.merged.bam" \
        --out "${PATIENT}.merged.intervals"; } 2>&1 || error "Interval creation failed"
fi

STEP+=1
if [ ${STEP} -ge "${START}" ]; then
	echo -e "\\n[Recal step ${STEP}] Indel realignment..."
	assert_file_exists "${PATIENT}.merged.bam"
	assert_file_exists "${PATIENT}.merged.bam.bai"
	assert_file_exists "${PATIENT}.merged.intervals"
	{ time $JAVA -Xmx64g -Djava.io.tmpdir="${TMP}" \
        -jar "$GATK" \
        --analysis_type IndelRealigner \
        --reference_sequence "$REF" \
        --knownAlleles "$THOUSAND" \
        --logging_level WARN \
        --consensusDeterminationModel USE_READS \
        --input_file "${PATIENT}.merged.bam" \
        --targetIntervals "${PATIENT}.merged.intervals" \
        --out "${PATIENT}.merged.realigned.bam"; } 2>&1 || error "Indel realignment failed"
	rm -f "${PATIENT}.merged.bam"
	rm -f "${PATIENT}.merged.bam.bai"
	rm -f "${PATIENT}.merged.intervals"
fi

STEP+=1
if [ ${STEP} -ge "${START}" ]; then
	echo -e "\\n[Recal step ${STEP}] Fix mate information..."
	assert_file_exists "${PATIENT}.merged.realigned.bam"
	{ time $JAVA -Xmx64g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_FIXMATEINFO}" \
        INPUT="${PATIENT}.merged.realigned.bam" \
        OUTPUT="${PATIENT}.merged.realigned.mateFixed.bam" \
        SORT_ORDER=coordinate \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT; } 2>&1 || error "Verify mate information failed"
	rm -f "${PATIENT}.merged.realigned.bam"
	rm -f "${PATIENT}.merged.realigned.bai"
fi

STEP+=1
if [ ${STEP} -ge "${START}" ]; then
	echo -e "\\n[Recal step ${STEP}] Mark duplicates..."
	assert_file_exists "${PATIENT}.merged.realigned.mateFixed.bam"
	{ time $JAVA -Xmx64g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_MARKDUPS}" \
        INPUT="${PATIENT}.merged.realigned.mateFixed.bam" \
        OUTPUT="${PATIENT}.merged.realigned.rmDups.bam" \
        METRICS_FILE="${PATIENT}.merged.realigned.mateFixed.metrics" \
        REMOVE_DUPLICATES=TRUE \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=LENIENT; } 2>&1 || error "Mark duplicates failed"
	rm -f "${PATIENT}.merged.realigned.mateFixed.bam"
	assert_file_exists "${PATIENT}.merged.realigned.mateFixed.metrics"
fi

STEP+=1
if [ ${STEP} -ge "${START}" ]; then
	echo -e "\\n[Recal step ${STEP}] Index BAM file..."
	assert_file_exists "${PATIENT}.merged.realigned.rmDups.bam"
	{ time $SAMTOOLS index "${PATIENT}.merged.realigned.rmDups.bam"; } 2>&1 || error "Second indexing failed"
fi

STEP+=1
if [ ${STEP} -ge "${START}" ]; then
	echo -e "\\n[Recal step ${STEP}] Base-quality recalibration: Count covariates..."
	assert_file_exists "${PATIENT}.merged.realigned.rmDups.bam"
	assert_file_exists "${PATIENT}.merged.realigned.rmDups.bam.bai"
	{ time $JAVA -Xmx128g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
        --analysis_type CountCovariates \
        --reference_sequence "$REF" \
        --knownSites "$DBSNP" \
        --num_threads "${ncores}" \
        --logging_level WARN \
        --covariate ReadGroupCovariate \
        --covariate QualityScoreCovariate \
        --covariate CycleCovariate \
        --covariate DinucCovariate \
        --covariate MappingQualityCovariate \
        --standard_covs \
        --input_file "${PATIENT}.merged.realigned.rmDups.bam" \
        --recal_file "${PATIENT}.merged.realigned.rmDups.csv"; } 2>&1 || error "CountCovariates failed"
fi

STEP+=1
if [ ${STEP} -ge "${START}" ]; then
	echo -e "\\n[Recal step ${STEP}] Base-quality recalibration: Table Recalibration..."
	assert_file_exists "${PATIENT}.merged.realigned.rmDups.bam"
	assert_file_exists "${PATIENT}.merged.realigned.rmDups.bam.bai"
	assert_file_exists "${PATIENT}.merged.realigned.rmDups.csv"
	{ time $JAVA -Xmx64g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
        --analysis_type TableRecalibration \
        --reference_sequence "$REF" \
        --logging_level WARN \
        --baq RECALCULATE \
        --recal_file "${PATIENT}.merged.realigned.rmDups.csv" \
        --input_file "${PATIENT}.merged.realigned.rmDups.bam" \
        --out "${PATIENT}.merged.realigned.rmDups.recal.bam"; } 2>&1 || error "TableRecalibration failed"
	rm -f "${PATIENT}.merged.realigned.rmDups.bam"
	rm -f "${PATIENT}.merged.realigned.rmDups.bam.bai"
	rm -f "${PATIENT}.merged.realigned.rmDups.csv"
fi

STEP+=1
if [ ${STEP} -ge "${START}" ]; then
	echo -e "\\n[Recal step ${STEP}] Split BAM files..."
	assert_file_exists "${PATIENT}.merged.realigned.rmDups.recal.bam"
	assert_file_exists "${PATIENT}.merged.realigned.rmDups.recal.bai"
	{ time $JAVA -Xmx64g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
        --analysis_type SplitSamFile \
        --reference_sequence "$REF" \
        --logging_level WARN \
        --input_file "${PATIENT}.merged.realigned.rmDups.recal.bam" \
        --outputRoot temp_; } 2>&1 || error "Splitting BAM files failed"

	rm -f "${PATIENT}.merged.realigned.rmDups.recal.bam"
	rm -f "${PATIENT}.merged.realigned.rmDups.recal.bai"
fi

STEP+=1
if [ ${STEP} -ge "${START}" ]; then
   echo -e "\\n[Recal step ${STEP}] Sort and index splitted BAM files..."
	echo "Input:"
	ls -s temp_*.bam || error "Error step ${STEP}: no input."
	for i in temp_*.bam
	do
        base=${i##temp_}
        base=${base%%.bam}
        echo -e "\\n[Recal] processing $base..."
        { time $SAMTOOLS sort "$i" "${base}.bwa.realigned.rmDups.recal"; } 2>&1 || error "Sorting $base failed"
        { time $SAMTOOLS index "${base}.bwa.realigned.rmDups.recal.bam"; } 2>&1 || error "Indexing $base failed"
        rm -f "$i"
done
fi

echo "------------------------------------------------------"
echo -n "[Recal] Finished! "
date

STEP+=1
if [ ${STEP} -ge "${START}" ]; then
	echo "[Recal step ${STEP}] Quality Control"
	for i in *.bwa.realigned.rmDups.recal.bam
	do
        echo "------------------------------------------------------"
        base=${i%%.bwa.realigned.rmDups.recal.bam}
        echo "[QC] Processing $base..."
		  echo "------------------------------------------------------"

        echo -e "\\n[QC] Calculate flag statistics..."
        { time $SAMTOOLS flagstat "$i" > "${base}.bwa.realigned.rmDups.recal.flagstat"; } 2>&1

        echo -e "\\n[QC] Calculate hybrid selection metrics..."
        { time $JAVA -Xmx64g -Djava.io.tmpdir="${TMP}" \
                -jar "${PICARD_HSMETRICS}" \
                BAIT_INTERVALS="${ILIST}" \
                TARGET_INTERVALS="${ILIST}" \
                INPUT="$i" \
                OUTPUT="${base}.bwa.realigned.rmDups.recal.hybrid_selection_metrics" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT; } 2>&1 || error "Calculate hybrid selection metrics failed"

        echo -e "\\n[QC] Collect multiple QC metrics..."
        { time $JAVA -Xmx64g -Djava.io.tmpdir="${TMP}" \
                -jar "${PICARD_MULTIMETRICS}" \
                INPUT="$i" \
                OUTPUT="${base}.bwa.realigned.rmDups.recal" \
                REFERENCE_SEQUENCE="${REF}" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT; } 2>&1 || error "Collect multiple QC metrics failed"
	done
   echo "------------------------------------------------------"
fi

echo -ne "\\n[QC] Finished! "
date
echo "-------------------------------------------------"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"

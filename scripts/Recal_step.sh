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
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}
ncores=${PBS_NUM_PPN:-1}
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
  echo "- PBS_NUM_PPN=$PBS_NUM_PPN"
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
[[ -f "$REF" ]]      || error "File not found: ${REF}"
[[ -f "$THOUSAND" ]] || error "File not found: ${THOUSAND}"
[[ -f "$DBSNP" ]]    || error "File not found: ${DBSNP}"

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
[[ -f "$ILIST" ]] || error "File not found: ${ILIST}"


TMP="${LG3_SCRATCH_ROOT}/${PATIENT}_tmp"
mkdir -p "${TMP}" || error "Can't create scratch directory ${TMP}"

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
	{ time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_SCRIPT_A}" \
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
	[[ -f "${PATIENT}.merged.bam" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.bam"
	echo -e "\\n[Recal step ${STEP}] Index merged BAM file..."
	{ time $SAMTOOLS index "${PATIENT}.merged.bam"; } 2>&1 || error "First indexing failed"
fi

STEP+=1
if [ ${STEP} -ge "${START}" ]; then
	echo -e "\\n[Recal step ${STEP}] Create intervals for indel detection..."
	[[ -f "${PATIENT}.merged.bam" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.bam"
	[[ -f "${PATIENT}.merged.bam.bai" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.bam.bai"
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
   [[ -f "${PATIENT}.merged.bam" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.bam"
   [[ -f "${PATIENT}.merged.bam.bai" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.bam.bai"
   [[ -f "${PATIENT}.merged.intervals" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.intervals"
	{ time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
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
   [[ -f "${PATIENT}.merged.realigned.bam" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.realigned.bam"
	{ time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_SCRIPT_B}" \
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
   [[ -f "${PATIENT}.merged.realigned.mateFixed.bam" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.realigned.mateFixed.bam"
	{ time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
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
fi

STEP+=1
if [ ${STEP} -ge "${START}" ]; then
	echo -e "\\n[Recal step ${STEP}] Index BAM file..."
   [[ -f "${PATIENT}.merged.realigned.rmDups.bam" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.realigned.rmDups.bam"
	{ time $SAMTOOLS index "${PATIENT}.merged.realigned.rmDups.bam"; } 2>&1 || error "Second indexing failed"
fi

STEP+=1
if [ ${STEP} -ge "${START}" ]; then
	echo -e "\\n[Recal step ${STEP}] Base-quality recalibration: Count covariates..."
   [[ -f "${PATIENT}.merged.realigned.rmDups.bam" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.realigned.rmDups.bam"
   [[ -f "${PATIENT}.merged.realigned.rmDups.bam.bai" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.realigned.rmDups.bam.bai"
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
	[[ -f "${PATIENT}.merged.realigned.rmDups.bam" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.realigned.rmDups.bam"	
	[[ -f "${PATIENT}.merged.realigned.rmDups.bam.bai" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.realigned.rmDups.bam.bai"	
	[[ -f "${PATIENT}.merged.realigned.rmDups.csv" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.realigned.rmDups.csv"	
	{ time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
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
	echo -e "\\n[Recal step ${STEP}] Index BAM file..."
	[[ -f "${PATIENT}.merged.realigned.rmDups.recal.bam" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.realigned.rmDups.recal.bam"	
	{ time $SAMTOOLS index "${PATIENT}.merged.realigned.rmDups.recal.bam"; } 2>&1 || error "Third indexing failed"
fi

STEP+=1
if [ ${STEP} -ge "${START}" ]; then
	echo -e "\\n[Recal step ${STEP}] Split BAM files..."
	[[ -f "${PATIENT}.merged.realigned.rmDups.recal.bam" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.realigned.rmDups.recal.bam"	
	[[ -f "${PATIENT}.merged.realigned.rmDups.recal.bam.bai" ]] || error "Error on step ${STEP}: no input ${PATIENT}.merged.realigned.rmDups.recal.bam.bai"	
	{ time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
        --analysis_type SplitSamFile \
        --reference_sequence "$REF" \
        --logging_level WARN \
        --input_file "${PATIENT}.merged.realigned.rmDups.recal.bam" \
        --outputRoot temp_; } 2>&1 || error "Splitting BAM files failed"

	rm -f "${PATIENT}.merged.realigned.rmDups.recal.bam"
	rm -f "${PATIENT}.merged.realigned.rmDups.recal.bam.bai"
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
        { time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
                -jar "${PICARD_SCRIPT_D}" \
                BAIT_INTERVALS="${ILIST}" \
                TARGET_INTERVALS="${ILIST}" \
                INPUT="$i" \
                OUTPUT="${base}.bwa.realigned.rmDups.recal.hybrid_selection_metrics" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT; } 2>&1 || error "Calculate hybrid selection metrics failed"

        echo -e "\\n[QC] Collect multiple QC metrics..."
        { time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
                -jar "${PICARD_SCRIPT_E}" \
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

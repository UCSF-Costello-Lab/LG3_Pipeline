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
ulimit -n 64000
DEBUG=true

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
  echo -n "- initial open file limit="
  ulimit -n
  DEBUG_RECAL=${DEBUG_RECAL:-${LG3_OUTPUT_ROOT}/${PROJECT}/exome_recal_debug}
  echo "DEBUG_RECAL=${DEBUG_RECAL}"
  make_dir -p "${DEBUG_RECAL}/${PATIENT}"
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

module load samtools/1.15.1 2> /dev/null && SAMTOOLS=$(which samtools)

echo "Software:"
echo "- JAVA=${JAVA:?}"
echo "- SAMTOOLS=${SAMTOOLS:?}"
echo "- GATK=${GATK:?}"
echo "- PICARD_HOME=${PICARD_HOME:?}"
echo "- RECAL_BAM_EXT=${RECAL_BAM_EXT}"
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
echo "Input:"
echo "- bamfiles=${bamfiles:?}"
echo "- PATIENT=${PATIENT:?}"
echo "- ILIST=${ILIST:?}"

assert_file_exists "${ILIST}"


TMP="${LG3_SCRATCH_ROOT}/${PATIENT}_tmp"
make_dir "${TMP}"

echo "------------------------------------------------------"
echo "[Recal] Base quality recalibration (bigmem version)"
date
echo "------------------------------------------------------"
echo "[Recal] Recalibration Group: $PATIENT"
echo "$bamfiles" | awk -F ":" '{for (i=1; i<=NF; i++) print "[Recal] Exome:"$i}'
echo "------------------------------------------------------"

## Construct string with one or more '-I <bam>' elements
inputs=$(echo "$bamfiles" | awk -F ":" '{OFS=" "} {for (i=1; i<=NF; i++) printf "INPUT="$i" "}')

echo -e "\\n[Recal] Merge BAM files..."
# shellcheck disable=SC2086

# Comment: Because how 'inputs' is created and used below
{ time $JAVA -Xmx32g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_MERGESAMFILES}" \
        ${inputs} \
        OUTPUT="${PATIENT}.merged.bam" \
        SORT_ORDER=coordinate \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT; } 2>&1 || error "Merge BAM files failed"

assert_file_exists "${PATIENT}.merged.bam"

${DEBUG} && { cp -p "${PATIENT}.merged.bam" "${DEBUG_RECAL}/${PATIENT}" ; echo "[DEBUG step1] Saved ${PATIENT}.merged.bam" ; }

echo -e "\\n[Recal] Index new BAM file..."
{ time $SAMTOOLS index -@ "${ncores}" "${PATIENT}.merged.bam"; } 2>&1 || error "First indexing failed"

assert_file_exists "${PATIENT}.merged.bam.bai"

${DEBUG} && { cp -p "${PATIENT}.merged.bam.bai" "${DEBUG_RECAL}/${PATIENT}" ; echo "[DEBUG step2] Saved ${PATIENT}.merged.bam.bai" ; }

echo -e "\\n[Recal] Create intervals for indel detection..."
{ time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
        -jar "$GATK" \
        --analysis_type RealignerTargetCreator \
        --reference_sequence "$REF" \
        --known "$THOUSAND" \
		  -L "${ILIST}" \
        --num_threads "${ncores}" \
        --logging_level WARN \
        --input_file "${PATIENT}.merged.bam" \
        --out "${PATIENT}.merged.intervals"; } 2>&1 || error "Interval creation failed"

assert_file_exists "${PATIENT}.merged.intervals"

${DEBUG} && { cp -p "${PATIENT}.merged.intervals" "${DEBUG_RECAL}/${PATIENT}" ; echo "[DEBUG step3] Saved ${PATIENT}.merged.intervals" ; }

echo -e "\\n[Recal] Indel realignment..."
{ time $JAVA -Xmx32g -Djava.io.tmpdir="${TMP}" \
        -jar "$GATK" \
        --analysis_type IndelRealigner \
        --reference_sequence "$REF" \
        --knownAlleles "$THOUSAND" \
        --logging_level WARN \
        --consensusDeterminationModel USE_READS \
        --input_file "${PATIENT}.merged.bam" \
        --targetIntervals "${PATIENT}.merged.intervals" \
        --out "${PATIENT}.merged.realigned.bam"; } 2>&1 || error "Indel realignment failed"

assert_file_exists "${PATIENT}.merged.realigned.bam"

${DEBUG} && { cp -p "${PATIENT}.merged.realigned.bam" "${DEBUG_RECAL}/${PATIENT}" ; echo "[DEBUG step4a] Saved ${PATIENT}.merged.realigned.bam" ; }
${DEBUG} && { cp -p "${PATIENT}.merged.realigned.bai" "${DEBUG_RECAL}/${PATIENT}" ; echo "[DEBUG step4b] Saved ${PATIENT}.merged.realigned.bai" ; }

rm -f "${PATIENT}.merged.bam"
rm -f "${PATIENT}.merged.bam.bai"
rm -f "${PATIENT}.merged.intervals"

  echo -n "- open file limit before Fix mate ="
  ulimit -n

echo -e "\\n[Recal] Fix mate information..."
### SEE: http://seqanswers.com/forums/showthread.php?t=7525
## java ... MAX_FILE_HANDLES_FOR_READ_ENDS_MAP=[some lower than `ulimit -n`] 
		  ##MAX_FILE_HANDLES_FOR_READ_ENDS_MAP=50000 \
### VALIDATION_STRINGENCY=SILENT MAX_RECORDS_IN_RAM=5000000 MAX_OPEN_TEMP_FILES=1573028 ??
{ time $JAVA -Xmx32g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_FIXMATEINFO}" \
        INPUT="${PATIENT}.merged.realigned.bam" \
        OUTPUT="${PATIENT}.merged.realigned.mateFixed.bam" \
        SORT_ORDER=coordinate \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
			MAX_RECORDS_IN_RAM=5000000 \
        VALIDATION_STRINGENCY=SILENT; } 2>&1 || error "Verify mate information failed"


assert_file_exists "${PATIENT}.merged.realigned.mateFixed.bam"

${DEBUG} && { cp -p "${PATIENT}.merged.realigned.mateFixed.bam" "${DEBUG_RECAL}/${PATIENT}" ; echo " [DEBUG step5] Saved ${PATIENT}.merged.realigned.mateFixed.bam" ; }

rm -f "${PATIENT}.merged.realigned.bam"
rm -f "${PATIENT}.merged.realigned.bai"

echo -e "\\n[Recal] Mark duplicates..."
{ time $JAVA -Xmx32g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_MARKDUPS}" \
        INPUT="${PATIENT}.merged.realigned.mateFixed.bam" \
        OUTPUT="${PATIENT}.merged.realigned.rmDups.bam" \
        METRICS_FILE="${PATIENT}.merged.realigned.mateFixed.metrics" \
        REMOVE_DUPLICATES=TRUE \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=LENIENT; } 2>&1 || error "Mark duplicates failed"

assert_file_exists "${PATIENT}.merged.realigned.rmDups.bam"
assert_file_exists "${PATIENT}.merged.realigned.mateFixed.metrics"

${DEBUG} && { cp -p "${PATIENT}.merged.realigned.rmDups.bam" "${DEBUG_RECAL}/${PATIENT}" ; echo "[DEBUG step6] Saved ${PATIENT}.merged.realigned.rmDups.bam" ; }
${DEBUG} && { cp -p "${PATIENT}.merged.realigned.mateFixed.metrics" "${DEBUG_RECAL}/${PATIENT}" ; echo " [DEBUG step5] Saved ${PATIENT}.merged.realigned.mateFixed.metrics" ; }

rm -f "${PATIENT}.merged.realigned.mateFixed.bam"

echo -e "\\n[Recal] Index BAM file..."
{ time $SAMTOOLS index -@ "${ncores}" "${PATIENT}.merged.realigned.rmDups.bam"; } 2>&1 || error "Second indexing failed"

assert_file_exists "${PATIENT}.merged.realigned.rmDups.bam.bai"

${DEBUG} && { cp -p "${PATIENT}.merged.realigned.rmDups.bam.bai" "${DEBUG_RECAL}/${PATIENT}" ; echo "[DEBUG step7] Saved ${PATIENT}.merged.realigned.rmDups.bam.bai" ; }

### Job crushed at -Xmx8g, increase!
echo -e "\\n[Recal] Base-quality recalibration: Count covariates..."
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

assert_file_exists "${PATIENT}.merged.realigned.rmDups.csv"

${DEBUG} && { cp -p "${PATIENT}.merged.realigned.rmDups.csv" "${DEBUG_RECAL}/${PATIENT}" ; echo "[DEBUG step8] Saved ${PATIENT}.merged.realigned.rmDups.csv" ; }

echo -e "\\n[Recal] Base-quality recalibration: Table Recalibration..."
{ time $JAVA -Xmx32g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
        --analysis_type TableRecalibration \
        --reference_sequence "$REF" \
        --logging_level WARN \
        --baq RECALCULATE \
        --recal_file "${PATIENT}.merged.realigned.rmDups.csv" \
        --input_file "${PATIENT}.merged.realigned.rmDups.bam" \
        --out "${PATIENT}.merged.realigned.rmDups.recal.bam"; } 2>&1 || error "TableRecalibration failed"

assert_file_exists "${PATIENT}.merged.realigned.rmDups.recal.bam"
assert_file_exists "${PATIENT}.merged.realigned.rmDups.recal.bai"

${DEBUG} && { cp -p "${PATIENT}.merged.realigned.rmDups.recal.bam" "${DEBUG_RECAL}/${PATIENT}" ; echo "[DEBUG step9a] Saved ${PATIENT}.merged.realigned.rmDups.recal.bam" ; }
${DEBUG} && { cp -p "${PATIENT}.merged.realigned.rmDups.recal.bai" "${DEBUG_RECAL}/${PATIENT}" ; echo "[DEBUG step9b] Saved ${PATIENT}.merged.realigned.rmDups.recal.bai" ; }

rm -f "${PATIENT}.merged.realigned.rmDups.bam"
rm -f "${PATIENT}.merged.realigned.rmDups.bam.bai"
rm -f "${PATIENT}.merged.realigned.rmDups.csv"

echo -e "\\n[Recal] Split BAM files..."
{ time $JAVA -Xmx32g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
        --analysis_type SplitSamFile \
        --reference_sequence "$REF" \
        --logging_level WARN \
        --input_file "${PATIENT}.merged.realigned.rmDups.recal.bam" \
        --outputRoot temp_; } 2>&1 || error "Splitting BAM files failed"
#assert_file_exists temp_*.bam ??

rm -f "${PATIENT}.merged.realigned.rmDups.recal.bam"
rm -f "${PATIENT}.merged.realigned.rmDups.recal.bai"

${DEBUG} && { cp -p temp_* "${DEBUG_RECAL}/${PATIENT}" ; echo "[DEBUG step10] Saved temp_*" ; }

for i in temp_*.bam
do
        base=${i##temp_}
        base=${base%%.bam}
        echo -e "\\n[Recal] Splitting off $base..."

		  echo "[Recal] sorting ${base}.${RECAL_BAM_EXT}.bam"
        { time $SAMTOOLS sort -@ "${ncores}" -o "${base}.${RECAL_BAM_EXT}.bam" "$i"; } 2>&1 || error "Sorting $base failed"
		  assert_file_exists "${base}.${RECAL_BAM_EXT}.bam"

			${DEBUG} && { cp -p "${base}.${RECAL_BAM_EXT}.bam" "${DEBUG_RECAL}/${PATIENT}" ; echo "[DEBUG step11] Saved ${base}.${RECAL_BAM_EXT}.bam" ; }

		  echo "[Recal] indexing ${base}.${RECAL_BAM_EXT}.bam"
        { time $SAMTOOLS index -@ "${ncores}" "${base}.${RECAL_BAM_EXT}.bam"; } 2>&1 || error "Indexing $base failed"
		  assert_file_exists "${base}.${RECAL_BAM_EXT}.bam.bai"

			${DEBUG} && { cp -p "${base}.${RECAL_BAM_EXT}.bam.bai" "${DEBUG_RECAL}/${PATIENT}" ; echo "[DEBUG step12] Saved ${base}.${RECAL_BAM_EXT}.bam.bai" ; }

        rm -f "$i"
done

echo "------------------------------------------------------"
echo -n "[Recal] Finished! "
date
echo "------------------------------------------------------"

echo "[QC] Quality Control"
for i in *."${RECAL_BAM_EXT}".bam
do
        echo "------------------------------------------------------"
        base=${i%%."${RECAL_BAM_EXT}".bam}
        echo "[QC] $base"

        echo -e "\\n[QC] Calculate flag statistics..."
        { time $SAMTOOLS flagstat -@ "${ncores}" "$i" > "${base}.${RECAL_BAM_EXT}.flagstat"; } 2>&1

		  assert_file_exists "${base}.${RECAL_BAM_EXT}.flagstat"

			${DEBUG} && { cp -p "${base}.${RECAL_BAM_EXT}.flagstat" "${DEBUG_RECAL}/${PATIENT}" ; echo "[DEBUG step13] Saved ${base}.${RECAL_BAM_EXT}.flagstat" ;}

        echo -e "\\n[QC] Calculate hybrid selection metrics..."
        { time $JAVA -Xmx32g -Djava.io.tmpdir="${TMP}" \
                -jar "${PICARD_HSMETRICS}" \
                BAIT_INTERVALS="${ILIST}" \
                TARGET_INTERVALS="${ILIST}" \
                INPUT="$i" \
                OUTPUT="${base}.${RECAL_BAM_EXT}.hybrid_selection_metrics" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT; } 2>&1 || error "Calculate hybrid selection metrics failed"

		  assert_file_exists "${base}.${RECAL_BAM_EXT}.hybrid_selection_metrics"

			${DEBUG} && { cp -p "${base}.${RECAL_BAM_EXT}.hybrid_selection_metrics" "${DEBUG_RECAL}/${PATIENT}" ; echo "[DEBUG step14] Saved ${base}.${RECAL_BAM_EXT}.hybrid_selection_metrics" ; }

        echo -e "\\n[QC] Collect multiple QC metrics..."
        { time R_PROFILE_USER=NULL $JAVA -Xmx32g -Djava.io.tmpdir="${TMP}" \
                -jar "${PICARD_MULTIMETRICS}" \
                INPUT="$i" \
                OUTPUT="${base}.${RECAL_BAM_EXT}" \
                REFERENCE_SEQUENCE="${REF}" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT; } 2>&1 || error "Collect multiple QC metrics failed"
		  for EXT in alignment_summary_metrics insert_size_metrics quality_by_cycle_metrics quality_distribution_metrics
		  do
		      assert_file_exists  "${base}.${RECAL_BAM_EXT}.${EXT}"
			
				${DEBUG} && { cp -p "${base}.${RECAL_BAM_EXT}.${EXT}" "${DEBUG_RECAL}/${PATIENT}" ; echo "[DEBUG step15] Saved ${base}.${RECAL_BAM_EXT}.${EXT}" ; }

		  done
        echo "------------------------------------------------------"
done

echo -e "\\n[QC] Finished! "

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"

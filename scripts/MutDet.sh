#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME:?}/scripts/utils.sh"
source_lg3_conf

PROGRAM=${BASH_SOURCE[0]}
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
  echo "Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- PBS_NUM_PPN=$PBS_NUM_PPN"
  echo "- hostname=$(hostname)"
  echo "- ncores=${ncores}"
fi

#
## Mutation detection with muTect, Somatic Indel Detector, and Unified Genotyper
##
## Exmaple run: path/to/MutDet.sh path/to/Normal.bam path/to/Tumor.bam output_prefix patientID
#
#


### Input
nbamfile=$1
tbamfile=$2
prefix=$3
patientID=$4
CONFIG=$5
ILIST=$6
XMX=$7 ### Xmx8g

echo "Input:"
echo "- nbamfile=${nbamfile:?}"
echo "- tbamfile=${tbamfile:?}"
echo "- prefix=${prefix:?}"
echo "- patientID=${patientID:?}"
echo "- CONFIG=${CONFIG:?}"
echo "- ILIST=${ILIST:?}"
echo "- XMX=${XMX:?}"

## Assert existance of input files
assert_file_exists "${nbamfile}"
assert_file_exists "${tbamfile}"
assert_file_exists "${CONFIG}"
assert_file_exists "${ILIST}"

normalname=${nbamfile##*/}
normalname=${normalname%%.bwa*}
tumorname=${tbamfile##*/}
tumorname=${tumorname%%.bwa*}

### Software
assert_python "$PYTHON"
unset PYTHONPATH  ## ADHOC: In case it is set by user /HB 2018-09-13
GATK="${LG3_HOME}/tools/GenomeAnalysisTK-1.6-5-g557da77/GenomeAnalysisTK.jar"
MUTECT="${LG3_HOME}/tools/muTect-1.0.27783.jar"
FILTER=${LG3_HOME}/FilterMutations/Filter.py
REORDER="${LG3_HOME}/scripts/vcf_reorder.py"

echo "Software:"
echo "- JAVA=${JAVA:?}"
echo "- PYTHON=${PYTHON:?}"
echo "- MUTECT=${MUTECT:?}"
echo "- FILTER=${FILTER:?}"
echo "- REORDER=${REORDER:?}"

## Assert existance of software
assert_file_executable "${JAVA}"
assert_file_executable "${PYTHON}"
assert_file_exists "${GATK}"
assert_file_exists "${MUTECT}"
assert_file_exists "${FILTER}"
assert_file_exists "${REORDER}"

### References
REF="${LG3_HOME}/resources/UCSC_HG19_Feb_2009/hg19.fa"
DBSNP="${LG3_HOME}/resources/dbsnp_132.hg19.sorted.vcf"
CONVERT="${LG3_HOME}/resources/RefSeq.Entrez.txt"
KINASEDATA="${LG3_HOME}/resources/all_human_kinases.txt"
COSMICDATA="${LG3_HOME}/resources/CosmicMutantExport_v58_150312.tsv"
CANCERDATA="${LG3_HOME}/resources/SangerCancerGeneCensus_2012-03-15.txt"

echo "References:"
echo "- REF=${REF}"
echo "- DBSNP=${DBSNP}"
echo "- REORDER=${REORDER}"
echo "- CONVERT=${CONVERT}"
echo "- KINASEDATA=${KINASEDATA}"
echo "- COSMICDATA=${COSMICDATA}"
echo "- CANCERDATA=${CANCERDATA}"

## Assert existance of files
assert_file_exists "${REF}"
assert_file_exists "${DBSNP}"
assert_file_exists "${REORDER}"
assert_file_exists "${CONVERT}"
assert_file_exists "${KINASEDATA}"
assert_file_exists "${COSMICDATA}"
assert_file_exists "${CANCERDATA}"


TMP="${LG3_SCRATCH_ROOT}"

echo "-------------------------------------------------"
echo -n "[MutDet] Mutation detection "
date
echo "-------------------------------------------------"
echo "[MutDet] Patient ID: $patientID"
echo "[MutDet] Normal Sample: $normalname"
echo "[MutDet] Tumor Sample: $tumorname"
echo "[MutDet] Prefix: $prefix"
echo "-------------------------------------------------"
echo "[MutDet] Normal bam file: $nbamfile"
echo "[MutDet] Tumor bam file: $tbamfile"
echo "[MutDet] Java Memory Xmx value: $XMX"
echo -n "[MutDet] Working directory: "
pwd
echo "-------------------------------------------------"

if [ ! -e "${prefix}.snvs.raw.mutect.txt" ]; then
        echo "[MutDet] Running muTect..."
        { time $JAVA -"$XMX" -Djava.io.tmpdir="${TMP}" \
                -jar "$MUTECT" \
                --analysis_type MuTect \
                -nt "${ncores}" \
                --logging_level WARN \
                --reference_sequence "$REF" \
                --intervals "$ILIST" \
                --input_file:normal "$nbamfile" \
                --input_file:tumor "$tbamfile" \
                -baq CALCULATE_AS_NECESSARY \
                --out "${prefix}.snvs.raw.mutect.txt" \
                --coverage_file "${prefix}.snvs.coverage.mutect.wig"; } 2>&1 || error "muTect failed"
		  assert_file_exists "${prefix}.snvs.raw.mutect.txt"
        echo "Done"
else
        echo "[MutDet] Found MuTect output, skipping ..."
fi
wc -l "${prefix}.snvs.raw.mutect.txt"

if [ ! -e "${prefix}.indels.raw.vcf" ]; then
        echo "[MutDet] Running Somatic Indel Detector..."
                ##--window_size 225 \
        { time $JAVA "-$XMX" -Djava.io.tmpdir="${TMP}" \
                -jar "$GATK" \
                --analysis_type SomaticIndelDetector \
                -I:normal "$nbamfile" \
                -I:tumor "$tbamfile" \
                --logging_level INFO \
                --reference_sequence "$REF" \
                --intervals "$ILIST" \
                -baq CALCULATE_AS_NECESSARY \
                --maxNumberOfReads 10000 \
                --window_size 350 \
                --filter_expressions "N_COV<8||T_COV<14||T_INDEL_F<0.1||T_INDEL_CF<0.7" \
                --out "${prefix}.indels.raw.vcf"; } 2>&1 || error "Indel detection failed"
			assert_file_exists "${prefix}.indels.raw.vcf"
         echo "Done"
else
        echo "[MutDet] Found Somatic Indel Detector output, skipping ..."
fi
wc -l "${prefix}.indels.raw.vcf"

if [ ! -e "${prefix}.indels.annotated.vcf" ]; then
        echo "[MutDet] Annotating raw indel calls..."
        { time $JAVA "-$XMX" -Djava.io.tmpdir="${TMP}" \
                -jar "$GATK" \
                --analysis_type VariantAnnotator \
                --variant "${prefix}.indels.raw.vcf" \
                --intervals "${prefix}.indels.raw.vcf" \
                -I:normal "$nbamfile" \
                -I:tumor "$tbamfile" \
                --logging_level WARN \
                --reference_sequence "$REF" \
                --dbsnp "$DBSNP" \
                --group StandardAnnotation \
                --out "${prefix}.indels.annotated.vcf"; } 2>&1 || error "Indel annotation failed"
			assert_file_exists "${prefix}.indels.annotated.vcf"
         echo "Done"
else
        echo "[MutDet] Found InDel Annotation output, skipping ..."
fi
wc -l "${prefix}.indels.annotated.vcf"

if [ ! -e "${prefix}.mutations" ]; then
        echo "[MutDet] Reordering indel vcf..."
        { time $PYTHON "$REORDER" "${prefix}.indels.annotated.vcf" \
                "$tumorname" \
                "$normalname" \
                > "${prefix}.indels.annotated.temp.vcf"; } 2>&1 || error "Reordering failed"
			assert_file_exists "${prefix}.indels.annotated.temp.vcf"
        echo "Done"
        wc -l "${prefix}.indels.annotated.temp.vcf"

        echo "[MutDet] Filtering mutect and indel output..."
        # shellcheck source=FilterMutations/filter.profile.sh
        source "${LG3_HOME}/FilterMutations/filter.profile.sh"
        { time $FILTER \
                "$CONFIG" \
                "${prefix}.snvs.raw.mutect.txt" \
                "${prefix}.indels.annotated.temp.vcf" \
                "${prefix}.mutations"; } 2>&1 || error "Filtering failed"
			assert_file_exists "${prefix}.mutations"
        echo "Done"

        rm -f "${prefix}.indels.annotated.temp.vcf"
else
        echo "[MutDet] Found Filtered Mutation output, skipping ..."
fi

echo "[MutDet] Finished!"
wc -l "${prefix}.mutations"

if [ ! -e "${patientID}.${prefix}.annotated.mutations" ]; then
        echo "-------------------------------------------------"
        echo "[Annotate] Annotation of mutations"
        echo "-------------------------------------------------"
        echo "[Annotate] Annotating file: ${prefix}.mutations"
        echo "[Annotate] Output file: ${patientID}.${prefix}.annotated.mutations"
        echo "-------------------------------------------------"

        echo "[Annotate] Generate bed file from mutations..."
        { time $PYTHON "${LG3_HOME}/scripts/annotation_BED_forUG.py" \
                "${prefix}.mutations" \
                > "${patientID}.${prefix}.temp.bed"; } 2>&1 || error "Bed file creation failed"
			assert_file_exists "${patientID}.${prefix}.temp.bed"
        wc -l "${patientID}.${prefix}.temp.bed"

        echo "[Annotate] Generate Unified Genotyper data..."
        { time $JAVA "-$XMX" \
                -jar "$GATK" \
                --analysis_type UnifiedGenotyper \
                --genotype_likelihoods_model SNP \
                --genotyping_mode DISCOVERY \
                --input_file "$nbamfile" \
                --input_file "$tbamfile" \
                --reference_sequence "$REF" \
                --dbsnp "$DBSNP" \
                --logging_level WARN \
                --intervals "${patientID}.${prefix}.temp.bed" \
                -baq CALCULATE_AS_NECESSARY \
                --noSLOD \
                --standard_min_confidence_threshold_for_calling 30.0 \
                --standard_min_confidence_threshold_for_emitting 10.0 \
                --min_base_quality_score 20 \
                --output_mode EMIT_VARIANTS_ONLY \
                --out "${patientID}.${prefix}.UG.snps.raw.vcf"; } 2>&1 || error "Unified Genotyper SNP calling failed"
			assert_file_exists "${patientID}.${prefix}.UG.snps.raw.vcf"

        rm -f "${patientID}.${prefix}.temp.bed"
        wc -l "${patientID}.${prefix}.UG.snps.raw.vcf"

        echo "[Annotate] Annotating Unified Genotyper SNPs..."
        { time $JAVA "-$XMX" \
                -jar "$GATK" \
                --analysis_type VariantAnnotator \
                --input_file "$nbamfile" \
                --input_file "$tbamfile" \
                --reference_sequence "$REF" \
                --dbsnp "$DBSNP" \
                --logging_level WARN \
                --intervals "${patientID}.${prefix}.UG.snps.raw.vcf" \
                --variant "${patientID}.${prefix}.UG.snps.raw.vcf" \
                -baq CALCULATE_AS_NECESSARY \
                --annotation QualByDepth \
                --annotation RMSMappingQuality \
                --annotation MappingQualityZero \
                --annotation LowMQ \
                --annotation MappingQualityRankSumTest \
                --annotation FisherStrand \
                --annotation HaplotypeScore \
                --annotation ReadPosRankSumTest \
                --annotation DepthOfCoverage \
                --out "${patientID}.${prefix}.UG.snps.annotated.vcf"; } 2>&1 || error "Unified Genotyper SNP annotation failed"
			assert_file_exists "${patientID}.${prefix}.UG.snps.annotated.vcf"

        rm -f "${patientID}.${prefix}.UG.snps.raw.vcf"
        rm -f "${patientID}.${prefix}.UG.snps.raw.vcf.idx"
        wc -l "${patientID}.${prefix}.UG.snps.annotated.vcf"

        echo "[Annotate] Filtering Unified Genotyper SNPs..."
        { time $JAVA "-$XMX" \
                -jar "$GATK" \
                --analysis_type VariantFiltration \
                --reference_sequence "$REF" \
                --logging_level WARN \
                --variant "${patientID}.${prefix}.UG.snps.annotated.vcf" \
                -baq CALCULATE_AS_NECESSARY \
                --filterExpression "QD < 2.0" \
                --filterName QDFilter \
                --filterExpression "MQ < 40.0" \
                --filterName MQFilter \
                --filterExpression "FS > 60.0" \
                --filterName FSFilter \
                --filterExpression "HaplotypeScore > 13.0" \
                --filterName HaplotypeScoreFilter \
                --filterExpression "MQRankSum < -12.5" \
                --filterName MQRankSumFilter \
                --filterExpression "ReadPosRankSum < -8.0" \
                --filterName ReadPosFilter        \
                --out "${patientID}.${prefix}.UG.snps.filtered.vcf"; } 2>&1 || error "Unified Genotyper SNP filtration failed"
			assert_file_exists "${patientID}.${prefix}.UG.snps.filtered.vcf"

        rm -f "${patientID}.${prefix}.UG.snps.annotated.vcf"
        rm -f "${patientID}.${prefix}.UG.snps.annotated.vcf.idx"
        wc -l "${patientID}.${prefix}.UG.snps.filtered.vcf"

        echo "[Annotate] Add Unified Genotyper data..."
        { time $PYTHON "${LG3_HOME}/scripts/annotation_UG.py" \
                "${prefix}.mutations" \
                "${patientID}.${prefix}.UG.snps.filtered.vcf" \
                > "${patientID}.${prefix}.temp1.mutations"; } 2>&1 || error "Unified Genotyper annotation failed"
			assert_file_exists "${patientID}.${prefix}.temp1.mutations"
        wc -l "${patientID}.${prefix}.temp1.mutations"

        rm -f "${patientID}.${prefix}.UG.snps.filtered.vcf"
        rm -f "${patientID}.${prefix}.UG.snps.filtered.vcf.idx"

        echo "[Annotate] Add COSMIC data..."
        { time $PYTHON "${LG3_HOME}/scripts/annotation_COSMIC.py" \
                "${patientID}.${prefix}.temp1.mutations" \
                "$COSMICDATA" \
                > "${patientID}.${prefix}.temp2.mutations"; } 2>&1 || error "COSMIC annotation failed"
			assert_file_exists "${patientID}.${prefix}.temp2.mutations"
        wc -l "${patientID}.${prefix}.temp2.mutations"

        rm -f "${patientID}.${prefix}.temp1.mutations"

        echo "[Annotate] Identify kinase genes..."
        { time $PYTHON "${LG3_HOME}/scripts/annotation_KINASE.py" \
                "${patientID}.${prefix}.temp2.mutations" \
                "$KINASEDATA" \
                > "${patientID}.${prefix}.temp3.mutations"; } 2>&1 || error "Kinase gene annotation failed"
			assert_file_exists "${patientID}.${prefix}.temp3.mutations"
        wc -l "${patientID}.${prefix}.temp3.mutations"

        rm -f "${patientID}.${prefix}.temp2.mutations"

        echo "[Annotate] Identify cancer genes..."
        { time $PYTHON "${LG3_HOME}/scripts/annotation_CANCER.py" \
                "${patientID}.${prefix}.temp3.mutations" \
                "$CANCERDATA" \
                "$CONVERT" \
                > "${patientID}.${prefix}.annotated.mutations"; } 2>&1 || error "Cancer gene annotation failed"
			assert_file_exists "${patientID}.${prefix}.annotated.mutations"
        wc -l "${patientID}.${prefix}.annotated.mutations"

        rm -f "${patientID}.${prefix}.temp3.mutations"

        echo "[Annotate] Finished!"
else
        echo "[Annotate] Found ${patientID}.${prefix}.annotated.mutations, skipped ..."
fi

echo "-------------------------------------------------"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"

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


## Input
nbamfile=$1
PATIENT=$2
ILIST=$3
echo "Input:"
echo "- nbamfile=${nbamfile:?}"
echo "- PATIENT=${PATIENT:?}"
echo "- ILIST=${ILIST:?}"

## Assert existance of input files
assert_file_exists "${nbamfile}"
assert_file_exists "${ILIST}"

normalname=${nbamfile##*/}
normalname=${normalname%%.bwa*}
bamdir=${nbamfile%/*}

## References
REF=${LG3_HOME}/resources/UCSC_HG19_Feb_2009/hg19.fa
DBSNP=${LG3_HOME}/resources/dbsnp_132.hg19.sorted.vcf
echo "References:"
echo "- REF=${REF:?}"
echo "- DBSNP=${DBSNP:?}"
assert_file_exists "${REF}"
assert_file_exists "${DBSNP}"

## Software
JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
PYTHON=/usr/bin/python
GATK=${LG3_HOME}/tools/GenomeAnalysisTK-1.6-5-g557da77/GenomeAnalysisTK.jar
PYTHON_VCF_GERMLINE=${LG3_HOME}/scripts/vcf_germline.py
echo "Software:"
echo "- JAVA=${JAVA:?}"
echo "- PYTHON=${PYTHON:?}"
echo "- GATK=${GATK:?}"

## Assert existance of software
assert_file_executable "${JAVA}"
assert_file_executable "${PYTHON}"
assert_file_exists "${GATK}"
assert_file_exists "${PYTHON_VCF_GERMLINE}"


echo "-------------------------------------------------"
echo "[Germline] Germline SNPs and relatedness"
echo "-------------------------------------------------"
echo "[Germline] Patient ID: $PATIENT"
echo "[Germline] Bam file directory: $bamdir"
echo "[Germline] Normal Sample: $normalname"
echo "-------------------------------------------------"

## Construct string with one or more '-I <bam>' elements
INPUTS=$(for i in ${bamdir}/*.bwa.realigned.rmDups.recal.bam
do
        assert_file_exists "${i}"
        echo -n "-I $i "
done)
echo "$INPUTS"

        ### $JAVA -Xmx16g \
        ### -nct 3 -nt 8 \
if [ ! -e "${PATIENT}.UG.snps.raw.vcf" ]; then
        echo "[Germline] Running Unified Genotyper..."
        # shellcheck disable=SC2086
        # Comment: Because how INPUTS is created and used below
        { time $JAVA -Xmx64g \
                -jar "$GATK" \
                --analysis_type UnifiedGenotyper \
                --genotype_likelihoods_model SNP \
                --genotyping_mode DISCOVERY \
                $INPUTS \
                --reference_sequence "$REF" \
                --dbsnp "$DBSNP" \
                --logging_level WARN \
                --intervals "$ILIST" \
                -baq CALCULATE_AS_NECESSARY \
                --noSLOD \
                -nt "${ncores}" \
                --standard_min_confidence_threshold_for_calling 30.0 \
                --standard_min_confidence_threshold_for_emitting 10.0 \
                --min_base_quality_score 20 \
                --output_mode EMIT_VARIANTS_ONLY \
                --out "${PATIENT}.UG.snps.raw.vcf"; } 2>&1 || error "Unified Genotyper SNP calling failed"
else
        echo "[Germline] Found output ${PATIENT}.UG.snps.raw.vcf -- Skipping..."
fi

if [ ! -e "${PATIENT}.UG.snps.annotated.vcf" ]; then
        echo "[Germline] Annotating Unified Genotyper SNPs..."
        # shellcheck disable=SC2086
        # Comment: Because how INPUTS is created and used below
        { time $JAVA -Xmx64g \
                -jar "$GATK" \
                --analysis_type VariantAnnotator \
                $INPUTS \
                --reference_sequence "$REF" \
                --dbsnp "$DBSNP" \
                --logging_level WARN \
                --intervals "${PATIENT}.UG.snps.raw.vcf" \
                --variant "${PATIENT}.UG.snps.raw.vcf" \
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
                --out "${PATIENT}.UG.snps.annotated.vcf"; } 2>&1 || error "Unified Genotyper SNP annotation failed"

        rm -f "${PATIENT}.UG.snps.raw.vcf"
        rm -f "${PATIENT}.UG.snps.raw.vcf.idx"
else
   echo "[Germline] Found output ${PATIENT}.UG.snps.annotated.vcf -- Skipping..."
fi

if [ ! -e "${PATIENT}.UG.snps.vcf" ]; then
        echo "[Germline] Filtering Unified Genotyper SNPs..."
        { time $JAVA -Xmx64g \
                -jar "$GATK" \
                --analysis_type VariantFiltration \
                --reference_sequence "$REF" \
                --logging_level WARN \
                --variant "${PATIENT}.UG.snps.annotated.vcf" \
                -baq CALCULATE_AS_NECESSARY \
                --clusterSize 3 \
                --clusterWindowSize 10 \
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
                --out "${PATIENT}.UG.snps.vcf"; } 2>&1 || error "Unified Genotyper SNP filtration failed"

        rm -f "${PATIENT}.UG.snps.annotated.vcf"
        rm -f "${PATIENT}.UG.snps.annotated.vcf.idx"
else
   echo "[Germline] Found output ${PATIENT}.UG.snps.vcf -- Skipping..."
fi

for i in ${bamdir}/*.bam
do
        tumorname=${i##*/}
        tumorname=${tumorname%%.bwa*}
        prefix="NOR-${normalname}_vs_${tumorname}"

        if [ ! -e "${prefix}.germline" ]; then
                echo "[Germline] Checking germline SNPs for sample relatedness: $tumorname vs $normalname"
                $PYTHON "${PYTHON_VCF_GERMLINE}" \
                        "${PATIENT}.UG.snps.vcf" \
                        "$normalname" \
                        "$tumorname" \
                        > "${prefix}.germline" || error "Germline analysis failed"
        else
                echo "[Germline] ${prefix}.germline already exists, skipping analysis"
        fi
done

if [ -e "NOR-${normalname}_vs_${normalname}.germline" ]; then
        echo "[Germline] Deleting germline vs. germline comparison..."
        rm -f "NOR-${normalname}_vs_${normalname}.germline"
fi

echo "[Germline] Results:"
grep Tumor -- *.germline

echo "[Germline] Finished!"
echo "-------------------------------------------------"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"

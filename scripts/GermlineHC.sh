#!/bin/bash

# shellcheck disable=SC1091
source "${LG3_HOME:?}/scripts/utils.sh"
assert_file_exists "${LG3_HOME}/lg3.conf"
source "${LG3_HOME}/lg3.conf"
CLEAN=false

PROGRAM=${BASH_SOURCE[0]}
#PROG=$(basename "$PROGRAM")
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_HOME=${LG3_HOME:?}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
LG3_SCRATCH_ROOT=${TMPDIR:-/scratch/${SLURM_JOB_USER}/${SLURM_JOB_ID}}
LG3_DEBUG=${LG3_DEBUG:-true}
XMX=${XMX:-Xmx160G} ## Default 160gb
TMPDIR="${LG3_SCRATCH_ROOT}/java_tmp"
ncores=${SLURM_NTASKS:-1}

### Debug
if $LG3_DEBUG ; then
  echo "Debug info:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- hostname=$(hostname)"
  echo "- ncores=$ncores"
  echo "- TMPDIR=${TMPDIR}"
  echo "- node(s): ${SLURM_JOB_NODELIST}"
fi


## Input
nbamfile=$1
PATIENT=$2
echo "Input:"
echo "- nbamfile=${nbamfile:?}"
echo "- PATIENT=${PATIENT:?}"
echo "- CONV=${CONV:?}"
echo "- ILIST=${ILIST:?}"

## Assert existance of input files
assert_file_exists "${nbamfile}"
assert_file_exists "${ILIST}"

normalname=${nbamfile##*/}
normalname=${normalname%%.bwa*}
bamdir=${nbamfile%/*}

## References
echo "References:"
echo "- REF=${REF:?}"
echo "- DBSNP=${DBSNP:?}"
assert_file_exists "${REF}"
assert_file_exists "${DBSNP}"

## Software
module load jdk/1.8.0 python/2.7.15 htslib/1.7 r/3.5.1 samtools/1.7

JAVA=java
PYTHON=python
PYTHON_VCF_GERMLINE=${LG3_HOME}/scripts/vcf_germline.py
echo "Software:"
echo "- GATK4=${GATK4:?}"
python --version 2>&1
java -version 2>&1
Rscript --version 2>&1
Rscript "${LG3_HOME}/scripts/chk_r_pkg.R" || error "chk_r_pkg.R failed"

## Assert existence of software
assert_file_exists "${GATK4}"
assert_file_exists "${PYTHON_VCF_GERMLINE}"

mkdir -p "${TMPDIR}" || error "ERROR: Can't create ${TMPDIR}"

echo "-------------------------------------------------"
echo "[Germline] Call Germline SNPs using HaplotypeCaller"
echo "-------------------------------------------------"
echo "[Germline] Patient ID: $PATIENT"
echo "[Germline] Bam file directory: $bamdir"
echo "[Germline] Normal Sample: $normalname"
echo "-------------------------------------------------"

extra_args=""
[[ -z "${ILIST}" ]] || extra_args=(--intervals "${ILIST}" --interval-padding "${PADDING}")
echo "[Germline] GATK extra_args: ${extra_args[*]}"

SAMPLES=${SAMPLES:-$(grep -P "\\t${PATIENT}\\t" "${CONV}" | cut -f1 | tr '\n' ' ')}
echo "Samples: ${SAMPLES}"

for SAMPLE in ${SAMPLES}
do
	BAM=${bamdir}/${SAMPLE}.${RECAL_BAM_EXT}
	## -ERC BP_RESOLUTION
	if [ ! -e "${SAMPLE}.HC.var.raw.g.vcf.gz" ]; then
        echo -e "\\n[Germline] Running Haplotype Caller in GVCF mode on ${SAMPLE} ..."
        { time "${GATK4}" --java-options -"${XMX}" HaplotypeCaller "${extra_args[@]}" \
            -I "${BAM}" \
				--emit-ref-confidence GVCF \
				--genotyping-mode DISCOVERY \
            --reference "${REF}" \
				--dbsnp "${DBSNP}" \
				--verbosity ERROR \
      		--tmp-dir "${TMPDIR}" \
            --output "${SAMPLE}.HC.var.raw.g.vcf.gz"; } 2>&1 || error "Haplotype Caller failed"
	else
        echo "[Germline] Found output ${SAMPLE}.HC.var.raw.g.vcf.gz -- Skipping..."
	fi
  	assert_file_exists "${SAMPLE}.HC.var.raw.g.vcf.gz"
	OUT="${OUT} -V ${SAMPLE}.HC.var.raw.g.vcf.gz"
	OUT2="${OUT2} ${SAMPLE}.HC.var.raw.g.vcf.gz"
	OUT2IND="${OUT2IND} ${SAMPLE}.HC.var.raw.g.vcf.gz.tbi"
done

echo "Input for CombineGVCFs: "
echo "${OUT}"

echo -e "\\n[Germline] Running GATK4::CombineGVCFs ..."
        # shellcheck disable=SC2086
        # Comment: Because how OUT is created and used below
		#--add-output-vcf-command-line true \
{ time "${GATK4}" --java-options -"${XMX}" CombineGVCFs "${extra_args[@]}" \
		--reference "${REF}" \
		--dbsnp "${DBSNP}" \
		${OUT} \
		--output "${PATIENT}.HC.var.raw.g.vcf.gz" \
		--verbosity ERROR \
      --tmp-dir "${TMPDIR}" \
		--QUIET false; } 2>&1 || error "FAILED"
		
assert_file_exists "${PATIENT}.HC.var.raw.g.vcf.gz"

echo "Total raw variants in ${PATIENT}.HC.var.raw.g.vcf.gz : "
zgrep -vc '^#' "${PATIENT}.HC.var.raw.g.vcf.gz"  

${CLEAN} && echo "Deleting ${OUT2} ${OUT2IND}"
# shellcheck disable=SC2086
${CLEAN} && rm -f "${OUT2[@]}"
${CLEAN} && rm -f "${OUT2IND[@]}"

echo -e "\\n[Germline] Running GATK4::GenotypeGVCFs ..."
### -stand-call-conf / --standard-min-confidence-threshold-for-calling [Default 30]
{ time "${GATK4}" --java-options -"${XMX}" GenotypeGVCFs "${extra_args[@]}" \
      --reference "${REF}" \
      --dbsnp "${DBSNP}" \
      --variant "${PATIENT}.HC.var.raw.g.vcf.gz" \
		-stand-call-conf 30 \
		--only-output-calls-starting-in-intervals true \
		--use-new-qual-calculator true \
      --output "${PATIENT}.HC.var.raw.vcf.gz" \
      --verbosity ERROR \
      --tmp-dir "${TMPDIR}" \
      --QUIET false; } 2>&1 || error "GenotypeGVCFs FAILED"

assert_file_exists "${PATIENT}.HC.var.raw.vcf.gz"

echo -n "Total raw variants in ${PATIENT}.HC.var.raw.vcf.gz: "
zgrep -vc '^#' "${PATIENT}.HC.var.raw.vcf.gz"  

${CLEAN} && rm -f "${PATIENT}.HC.var.raw.g.vcf.gz" "${PATIENT}.HC.var.raw.g.vcf.gz.tbi"



echo -e "\\n[Germline] Running GATK4::VariantFiltration ..."
{ time "${GATK4}" --java-options -"${XMX}" VariantFiltration \
		--filter-expression "ExcessHet > 54.69" \
		--filter-name ExcessHet \
		--variant "${PATIENT}.HC.var.raw.vcf.gz" \
		--output "${PATIENT}.HC.var.filt.vcf.gz" \
      --verbosity ERROR \
      --tmp-dir "${TMPDIR}" \
      --QUIET false; } 2>&1 || error "VariantFiltration FAILED"

assert_file_exists "${PATIENT}.HC.var.filt.vcf.gz"
echo -n "Total filt variants in ${PATIENT}.HC.var.filt.vcf.gz: "
zgrep -vc '^#' "${PATIENT}.HC.var.filt.vcf.gz"

#${CLEAN} && rm -f "${PATIENT}.HC.var.raw.vcf.gz"


echo -e "\\n[Germline] Running GATK4::MakeSitesOnlyVcf ..."
{ time "${GATK4}" --java-options -"${XMX}" MakeSitesOnlyVcf \
      --INPUT "${PATIENT}.HC.var.filt.vcf.gz" \
      --OUTPUT "${PATIENT}.HC.site.filt.vcf.gz" \
      --VERBOSITY ERROR \
      --QUIET false; } 2>&1 || error "MakeSitesOnlyVcf FAILED"

assert_file_exists "${PATIENT}.HC.site.filt.vcf.gz"
echo -n "Total filt variants in ${PATIENT}.HC.site.filt.vcf.gz: "
zgrep -vc '^#' "${PATIENT}.HC.site.filt.vcf.gz"

#${CLEAN} && rm -f "${PATIENT}.HC.var.filt.vcf.gz"


echo -e "\\n[Germline] Running GATK4::VariantRecalibrator in INDEL mode ..."
		#--max-gaussians 4 \
      #--reference "${REF}" \
		#--rscript-file "${PATIENT}.VQSR.INDEL.plots.R" \
		#-an "FS" -an "ReadPosRankSum" -an "MQRankSum" -an "QD" -an "SOR" -an "DP"
{ time "${GATK4}" --java-options -"${XMX}" VariantRecalibrator "${extra_args[@]}" \
		--mode INDEL \
		-an QD -an FS -an SOR -an ReadPosRankSum -an MQRankSum \
		--max-gaussians 3 \
		--variant "${PATIENT}.HC.site.filt.vcf.gz" \
		--output "${PATIENT}.VQSR.INDEL.recal.vcf.gz" \
		-tranche "100.0" -tranche "99.95" -tranche "99.9" -tranche "99.5" -tranche "99.0" -tranche "97.0" -tranche "96.0" -tranche "95.0" -tranche "94.0" -tranche "93.5" -tranche "93.0" -tranche "92.0" -tranche "91.0" -tranche "90.0" \
		--tranches-file "${PATIENT}.VQSR.INDEL.tranches" \
		--trust-all-polymorphic true \
		--resource:mills,known=false,training=true,truth=true,prior=12 "${INDEL_MILLS}" \
		--resource:axiomPoly,known=false,training=true,truth=false,prior=10 "${AXIOM}" \
      --resource:dbsnp,known=true,training=false,truth=false,prior=2 "${DBSNP}" \
		--verbosity ERROR \
		--tmp-dir "${TMPDIR}" \
      --QUIET false; } 2>&1 || error "VariantRecalibrator:INDEL FAILED"

assert_file_exists "${PATIENT}.VQSR.INDEL.recal.vcf.gz"
echo -n "Total sites in ${PATIENT}.VQSR.INDEL.recal.vcf.gz = "
zgrep -vc "^#" "${PATIENT}.VQSR.INDEL.recal.vcf.gz"


## https://software.broadinstitute.org/gatk/documentation/article.php?id=1259
		##--max-gaussians 6 \
echo -e "\\n[Germline] Running GATK4::VariantRecalibrator in SNP mode ..."
      ##--reference "${REF}" \
      #--resource:dbsnp,known=true,training=false,truth=false,prior=7 "${DBSNP}" \
{ time "${GATK4}" --java-options -"${XMX}" VariantRecalibrator "${extra_args[@]}" \
		--mode SNP \
		-an QD -an MQ -an MQRankSum -an ReadPosRankSum -an FS -an SOR \
		--max-gaussians 4 \
		--variant "${PATIENT}.HC.site.filt.vcf.gz" \
		--output "${PATIENT}.VQSR.SNP.recal.vcf.gz" \
		-tranche "100.0" -tranche "99.95" -tranche "99.9" -tranche "99.8" -tranche "99.6" -tranche "99.5" -tranche "99.4" -tranche "99.3" -tranche "99.0" -tranche "98.0" -tranche "97.0" -tranche "90.0" \
		--tranches-file "${PATIENT}.VQSR.SNP.tranches" \
		--trust-all-polymorphic true \
		--resource:hapmap,known=false,training=true,truth=true,prior=15 "${SNP_HAPMAP}" \
      --resource:omni,known=false,training=true,truth=false,prior=12 "${SNP_OMNI}" \
      --resource:1000G,known=false,training=true,truth=false,prior=10 "${SNP_1000G}" \
      --resource:dbsnp,known=true,training=false,truth=false,prior=2 "${DBSNP}" \
		--verbosity ERROR \
		--tmp-dir "${TMPDIR}" \
      --QUIET false; } 2>&1 || error "VariantRecalibrator:SNP FAILED"

assert_file_exists "${PATIENT}.VQSR.SNP.recal.vcf.gz"
echo -n "Total sites in ${PATIENT}.VQSR.SNP.recal.vcf.gz = "
zgrep -vc "^#" "${PATIENT}.VQSR.SNP.recal.vcf.gz"



echo -e "\\n[Germline] Running GATK4::ApplyVQSR in INDEL mode ..."
{ time "${GATK4}" --java-options -"${XMX}"  ApplyVQSR "${extra_args[@]}" \
      --reference "${REF}" \
      --mode INDEL \
      --variant "${PATIENT}.HC.site.filt.vcf.gz" \
      --recal-file "${PATIENT}.VQSR.INDEL.recal.vcf.gz" \
      --tranches-file "${PATIENT}.VQSR.INDEL.tranches" \
      --output  "${PATIENT}.VQSR.INDEL.recal.filt.vcf.gz" \
      --truth-sensitivity-filter-level 99.0 \
      --create-output-variant-index true \
      --verbosity ERROR \
      --tmp-dir "${TMPDIR}" \
      --QUIET false; } 2>&1 || error " ApplyVQSR:INDEL FAILED"

assert_file_exists "${PATIENT}.VQSR.INDEL.recal.filt.vcf.gz"
echo -n "Total sites in ${PATIENT}.VQSR.INDEL.recal.filt.vcf.gz = "
zgrep -vc "^#" "${PATIENT}.VQSR.INDEL.recal.filt.vcf.gz"

echo -e "\\n[Germline] Running GATK4::ApplyVQSR in SNP mode ..."
{ time "${GATK4}" --java-options -"${XMX}"  ApplyVQSR "${extra_args[@]}" \
		--mode SNP \
		--variant "${PATIENT}.VQSR.INDEL.recal.filt.vcf.gz" \
		--recal-file "${PATIENT}.VQSR.SNP.recal.vcf.gz" \
		--tranches-file "${PATIENT}.VQSR.SNP.tranches" \
		--output  "${PATIENT}.VQSR.SNP.recal.filt.vcf.gz" \
		--truth-sensitivity-filter-level 99.5 \
		--create-output-variant-index true \
      --verbosity ERROR \
      --tmp-dir "${TMPDIR}" \
      --QUIET false; } 2>&1 || error " ApplyVQSR:SNP FAILED"

assert_file_exists "${PATIENT}.VQSR.SNP.recal.filt.vcf.gz"
echo -n "Total sites in ${PATIENT}.VQSR.SNP.recal.filt.vcf.gz = "
zgrep -vc "^#" "${PATIENT}.VQSR.SNP.recal.filt.vcf.gz"


echo -e "\\n[Germline] Running GATK4::CollectVariantCallingMetrics ..."
{ time "${GATK4}" --java-options -"${XMX}"  CollectVariantCallingMetrics \
		--INPUT "${PATIENT}.VQSR.SNP.recal.filt.vcf.gz" \
		--DBSNP "${DBSNP}" \
		--SEQUENCE_DICTIONARY "${REF_DICT}" \
		--OUTPUT "${PATIENT}.VQSR.SNP.recal.filt.metrics" \
		--THREAD_COUNT 4 \
		--TARGET_INTERVALS "${ILIST}" \
      --VERBOSITY ERROR \
      --QUIET false; } 2>&1 || error " CollectVariantCallingMetrics FAILED"

if [ ! -e "${PATIENT}.UG.var.annotated.vcf" ]; then
        echo "[Germline] Annotating Unified Genotyper SNPs..."
        # shellcheck disable=SC2086
        # Comment: Because how INPUTS is created and used below
        { time $JAVA -Xmx64g \
                -jar "${GATK4}" \
                --analysis_type VariantAnnotator \
                $INPUTS \
                --reference_sequence "$REF" \
                --dbsnp "$DBSNP" \
                --logging_level WARN \
                --intervals "${PATIENT}.UG.var.raw.vcf" \
                --variant "${PATIENT}.UG.var.raw.vcf" \
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
                --out "${PATIENT}.UG.var.annotated.vcf"; } 2>&1 || error "Unified Genotyper SNP annotation failed"
		  assert_file_exists "${PATIENT}.UG.var.annotated.vcf"

        rm -f "${PATIENT}.UG.var.raw.vcf"
        rm -f "${PATIENT}.UG.var.raw.vcf.idx"
else
   echo "[Germline] Found output ${PATIENT}.UG.var.annotated.vcf -- Skipping..."
fi

if [ ! -e "${PATIENT}.UG.var.vcf" ]; then
        echo "[Germline] Filtering Unified Genotyper SNPs..."
        { time $JAVA -Xmx64g \
                -jar "$GATK4" \
                --analysis_type VariantFiltration \
                --reference_sequence "$REF" \
                --logging_level WARN \
                --variant "${PATIENT}.UG.var.annotated.vcf" \
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
                --out "${PATIENT}.UG.var.vcf"; } 2>&1 || error "Unified Genotyper SNP filtration failed"
		  assert_file_exists "${PATIENT}.UG.var.vcf"

        rm -f "${PATIENT}.UG.var.annotated.vcf"
        rm -f "${PATIENT}.UG.var.annotated.vcf.idx"
else
   echo "[Germline] Found output ${PATIENT}.UG.var.vcf -- Skipping..."
fi

for i in "${bamdir}"/*.bam
do
        tumorname=${i##*/}
        tumorname=${tumorname%%.bwa*}
        prefix="NOR-${normalname}_vs_${tumorname}"

        if [ ! -e "${prefix}.germline" ]; then
                echo "[Germline] Checking germline SNPs for sample relatedness: $tumorname vs $normalname"
              $PYTHON "${PYTHON_VCF_GERMLINE}" \
                    "${PATIENT}.UG.var.vcf" \
                    "$normalname" \
                    "$tumorname" \
                     > "${prefix}.germline" || error "Germline analysis failed"
		  			assert_file_exists "${prefix}.germline"
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

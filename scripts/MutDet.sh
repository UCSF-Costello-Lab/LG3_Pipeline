#!/bin/bash
#
## Mutation detection with muTect, Somatic Indel Detector, and Unified Genotyper
##
## Exmaple run: path/to/MutDet.sh path/to/Normal.bam path/to/Tumor.bam output_prefix patientID
#
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#

nbamfile=$1
tbamfile=$2
prefix=$3
patientID=$4
CONFIG=$5
ILIST=$6
XMX=$7 ### Xmx8g




normalname=${nbamfile##*/}
normalname=${normalname%%.bwa*}
tumorname=${tbamfile##*/}
tumorname=${tumorname%%.bwa*}

JAVA=/home/jocostello/shared/LG3_Pipeline/tools/java/jre1.6.0_27/bin/java
PYTHON=/usr/bin/python
TMP="/scratch/$USER"
GATK="/home/jocostello/shared/LG3_Pipeline/tools/GenomeAnalysisTK-1.6-5-g557da77/GenomeAnalysisTK.jar"
MUTECT="/home/jocostello/shared/LG3_Pipeline/tools/muTect-1.0.27783.jar"
REF="/home/jocostello/shared/LG3_Pipeline/resources/UCSC_HG19_Feb_2009/hg19.fa"
DBSNP="/home/jocostello/shared/LG3_Pipeline/resources/dbsnp_132.hg19.sorted.vcf"
REORDER="/home/jocostello/shared/LG3_Pipeline/scripts/vcf_reorder.py"
FILTER=/home/jocostello/shared/LG3_Pipeline/FilterMutations/Filter.py
CONVERT="/home/jocostello/shared/LG3_Pipeline/resources/RefSeq.Entrez.txt"
KINASEDATA="/home/jocostello/shared/LG3_Pipeline/resources/all_human_kinases.txt"
COSMICDATA="/home/jocostello/shared/LG3_Pipeline/resources/CosmicMutantExport_v58_150312.tsv"
CANCERDATA="/home/jocostello/shared/LG3_Pipeline/resources/SangerCancerGeneCensus_2012-03-15.txt"

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
	$JAVA -"$XMX" -Djava.io.tmpdir="${TMP}" \
		-jar $MUTECT \
		--analysis_type MuTect \
		--logging_level WARN \
		--reference_sequence $REF \
		--intervals "$ILIST" \
		--input_file:normal "$nbamfile" \
		--input_file:tumor "$tbamfile" \
		-baq CALCULATE_AS_NECESSARY \
		--out "${prefix}.snvs.raw.mutect.txt" \
		--coverage_file "${prefix}.snvs.coverage.mutect.wig" || { echo "muTect failed"; exit 1; }
		echo "Done"
else
	echo "[MutDet] Found MuTect output, skipping ..."
fi
wc -l "${prefix}.snvs.raw.mutect.txt"

if [ ! -e "${prefix}.indels.raw.vcf" ]; then
	echo "[MutDet] Running Somatic Indel Detector..."
		##--window_size 225 \
	$JAVA "-$XMX" -Djava.io.tmpdir="${TMP}" \
		-jar $GATK \
		--analysis_type SomaticIndelDetector \
		-I:normal "$nbamfile" \
		-I:tumor "$tbamfile" \
		--logging_level INFO \
		--reference_sequence $REF \
		--intervals "$ILIST" \
		-baq CALCULATE_AS_NECESSARY \
		--maxNumberOfReads 10000 \
		--window_size 350 \
		--filter_expressions "N_COV<8||T_COV<14||T_INDEL_F<0.1||T_INDEL_CF<0.7" \
		--out "${prefix}.indels.raw.vcf" || { echo "Indel detection failed"; exit 1; }
		echo "Done"
else
	echo "[MutDet] Found Somatic Indel Detector output, skipping ..."
fi
wc -l "${prefix}.indels.raw.vcf"

if [ ! -e "${prefix}.indels.annotated.vcf" ]; then
	echo "[MutDet] Annotating raw indel calls..."
	$JAVA "-$XMX" -Djava.io.tmpdir="${TMP}" \
		-jar $GATK \
		--analysis_type VariantAnnotator \
		--variant "${prefix}.indels.raw.vcf" \
		--intervals "${prefix}.indels.raw.vcf" \
		-I:normal "$nbamfile" \
		-I:tumor "$tbamfile" \
		--logging_level WARN \
		--reference_sequence $REF \
		--dbsnp $DBSNP \
		--group StandardAnnotation \
		--out "${prefix}.indels.annotated.vcf" || { echo "Indel annotation failed"; exit 1; }
		echo "Done"
else
	echo "[MutDet] Found InDel Annotation output, skipping ..."
fi
wc -l "${prefix}.indels.annotated.vcf"

if [ ! -e "${prefix}.mutations" ]; then
	echo "[MutDet] Reordering indel vcf..."
	$PYTHON $REORDER "${prefix}.indels.annotated.vcf" \
		"$tumorname" \
		"$normalname" \
		> "${prefix}.indels.annotated.temp.vcf" || { echo "Reordering failed"; exit 1; }
	echo "Done"
	wc -l "${prefix}.indels.annotated.temp.vcf"

	echo "[MutDet] Filtering mutect and indel output..."
	source /home/jocostello/shared/LG3_Pipeline/FilterMutations/filter.profile.sh
	$FILTER \
		"$CONFIG" \
		"${prefix}.snvs.raw.mutect.txt" \
		"${prefix}.indels.annotated.temp.vcf" \
		"${prefix}.mutations" || { echo "Filtering failed"; exit 1; }
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
	$PYTHON /home/jocostello/shared/LG3_Pipeline/scripts/annotation_BED_forUG.py \
		"${prefix}.mutations" \
		> "${patientID}.${prefix}.temp.bed" || { echo "Bed file creation failed"; exit 1; }
	wc -l "${patientID}.${prefix}.temp.bed"

	echo "[Annotate] Generate Unified Genotyper data..."
	$JAVA "-$XMX" \
		-jar $GATK \
		--analysis_type UnifiedGenotyper \
		--genotype_likelihoods_model SNP \
		--genotyping_mode DISCOVERY \
		--input_file "$nbamfile" \
		--input_file "$tbamfile" \
		--reference_sequence $REF \
		--dbsnp $DBSNP \
		--logging_level WARN \
		--intervals "${patientID}.${prefix}.temp.bed" \
		-baq CALCULATE_AS_NECESSARY \
		--noSLOD \
		--standard_min_confidence_threshold_for_calling 30.0 \
		--standard_min_confidence_threshold_for_emitting 10.0 \
		--min_base_quality_score 20 \
		--output_mode EMIT_VARIANTS_ONLY \
		--out "${patientID}.${prefix}.UG.snps.raw.vcf" || { echo "Unified Genotyper SNP calling failed"; exit 1; }

	rm -f "${patientID}.${prefix}.temp.bed"
	wc -l "${patientID}.${prefix}.UG.snps.raw.vcf"

	echo "[Annotate] Annotating Unified Genotyper SNPs..."
	$JAVA "-$XMX" \
		-jar $GATK \
		--analysis_type VariantAnnotator \
		--input_file "$nbamfile" \
		--input_file "$tbamfile" \
		--reference_sequence $REF \
		--dbsnp $DBSNP \
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
		--out "${patientID}.${prefix}.UG.snps.annotated.vcf" || { echo "Unified Genotyper SNP annotation failed"; exit 1; }

	rm -f "${patientID}.${prefix}.UG.snps.raw.vcf"
	rm -f "${patientID}.${prefix}.UG.snps.raw.vcf.idx"
	wc -l "${patientID}.${prefix}.UG.snps.annotated.vcf"

	echo "[Annotate] Filtering Unified Genotyper SNPs..."
	$JAVA "-$XMX" \
		-jar $GATK \
		--analysis_type VariantFiltration \
		--reference_sequence $REF \
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
		--filterName ReadPosFilter	\
		--out "${patientID}.${prefix}.UG.snps.filtered.vcf" || { echo "Unified Genotyper SNP filtration failed"; exit 1; }

	rm -f "${patientID}.${prefix}.UG.snps.annotated.vcf"
	rm -f "${patientID}.${prefix}.UG.snps.annotated.vcf.idx"
	wc -l "${patientID}.${prefix}.UG.snps.filtered.vcf"

	echo "[Annotate] Add Unified Genotyper data..."
	$PYTHON /home/jocostello/shared/LG3_Pipeline/scripts/annotation_UG.py \
		"${prefix}.mutations" \
		"${patientID}.${prefix}.UG.snps.filtered.vcf" \
		> "${patientID}.${prefix}.temp1.mutations" || { echo "Unified Genotyper annotation failed"; exit 1; }
	wc -l "${patientID}.${prefix}.temp1.mutations"

	rm -f "${patientID}.${prefix}.UG.snps.filtered.vcf"
	rm -f "${patientID}.${prefix}.UG.snps.filtered.vcf.idx"

	echo "[Annotate] Add COSMIC data..."
	$PYTHON /home/jocostello/shared/LG3_Pipeline/scripts/annotation_COSMIC.py \
		"${patientID}.${prefix}.temp1.mutations" \
		$COSMICDATA \
		> "${patientID}.${prefix}.temp2.mutations" || { echo "COSMIC annotation failed"; exit 1; }
	wc -l "${patientID}.${prefix}.temp2.mutations"

	rm -f "${patientID}.${prefix}.temp1.mutations"

	echo "[Annotate] Identify kinase genes..."
	$PYTHON /home/jocostello/shared/LG3_Pipeline/scripts/annotation_KINASE.py \
		"${patientID}.${prefix}.temp2.mutations" \
		$KINASEDATA \
		> "${patientID}.${prefix}.temp3.mutations" || { echo "Kinase gene annotation failed"; exit 1; }
	wc -l "${patientID}.${prefix}.temp3.mutations"

	rm -f "${patientID}.${prefix}.temp2.mutations"

	echo "[Annotate] Identify cancer genes..."
	$PYTHON /home/jocostello/shared/LG3_Pipeline/scripts/annotation_CANCER.py \
		"${patientID}.${prefix}.temp3.mutations" \
		$CANCERDATA \
		$CONVERT \
		> "${patientID}.${prefix}.annotated.mutations" || { echo "Cancer gene annotation failed"; exit 1; }
	wc -l "${patientID}.${prefix}.annotated.mutations"

	rm -f "${patientID}.${prefix}.temp3.mutations"

	echo "[Annotate] Finished!"
else
	echo "[Annotate] Found ${patientID}.${prefix}.annotated.mutations, skipped ..."
fi

echo "-------------------------------------------------"
echo -n "All done! "
date

#!/bin/bash


# shellcheck disable=SC1091
source "${LG3_HOME:?}/scripts/utils.sh"

LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
### /path/to/FixReadGroups.sh <bam_in> <bam_out>  <new_prefix>

if [ $# -lt 2 ]; then
    error "\\nUsage: $0 in.bam prefix [out.bam]"
fi
echo "Set read group assignments"

JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
PICARD_HOME=${LG3_HOME}/tools/picard-tools-1.64
SAMTOOLS=${LG3_HOME}/tools/samtools-0.1.18/samtools

pl="Illumina"
pu="Exome"

bamin=$1
prefix=$2
bamout=$3

if [ $# -eq 2 ]; then
	bamout=tmp.bam
	echo "Temporal output ${bamout}"
fi

echo "-------------------------------------------------"
echo "Set read group assignments"
echo "Java: $JAVA"
echo "Picard: $PICARD_HOME"
echo "Samtools: $SAMTOOLS"
echo "-------------------------------------------------"
echo "BAM input: $bamin"
echo "BAM output: $bamout"
echo "New Group Name: $prefix"
echo "-------------------------------------------------"

echo "Read group before"
bamhead "${bamin}" | grep RG

if [ ! -f "$bamout" ]; then
        #SORT_ORDER=coordinate \
$JAVA -Xmx4g -jar "$PICARD_HOME/AddOrReplaceReadGroups.jar" \
        INPUT="${bamin}" \
        OUTPUT="${bamout}" \
        RGID="$prefix" \
        RGLB="$prefix" \
        RGPL=$pl \
        RGPU=$pu \
        RGSM="$prefix" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT || error "job failed!"
else
        echo "$bamout exists, skipping ..."
fi

echo "Indexing BAM file..."
$SAMTOOLS index "${bamout}" || error "BAM indexing failed"

echo "Read group after "
if [ $# -eq 2 ]; then
	mv tmp.bam "${bamin}"
	mv tmp.bam.bai "${bamin}.bai"
	touch "${bamin}" "${bamin}.bai"
	bamhead "${bamin}" | grep RG
else
	bamhead ${bamout} | grep RG
fi

echo "All Done!"


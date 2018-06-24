#!/bin/bash
## 
## Calculate Hybrid Selection Metrix on processed BAM files
## 
## Usage: /path/to/HybridSelect.sh *.bam 
##
##

JAVA=/home/jocostello/shared/LG3_Pipeline/tools/java/jre1.6.0_27/bin/java
PICARD=/home/jocostello/shared/LG3_Pipeline/tools/picard-tools-1.64
TMP=/scratch/jocostello

i=$1
ilist=$2
patient=$3 ## Not used

ilist_b=$(basename $ilist)
echo "------------------------------------------------------"
echo "[HSM] Using:" $ilist_b
        echo "------------------------------------------------------"
	base=$(basename $i .bam)
	dir=$(dirname $i)
	cd $dir
        echo "[HSM] Base: " $base
        echo "[HSM] Calculating hybrid selection metrics..."
        $JAVA -Xmx8g -Djava.io.tmpdir=${TMP} \
                -jar $PICARD/CalculateHsMetrics.jar \
                BAIT_INTERVALS=${ilist} \
                TARGET_INTERVALS=${ilist} \
                INPUT=$i \
                OUTPUT=${base}.hybrid_selection_metrics2 \
                TMP_DIR=${TMP} \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT || { echo "Calculate hybrid selection metrics failed"; exit 1; }

echo "------------------------------------------------------"
echo "[HSM] Done" 

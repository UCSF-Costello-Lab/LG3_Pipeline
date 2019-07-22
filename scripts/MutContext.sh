#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME?}/scripts/utils.sh"
source_lg3_conf

### Configuration
LG3_HOME=${LG3_HOME:?}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
PROJECT=${PROJECT:?}
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "LG3_HOME=$LG3_HOME"
  echo "LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "PWD=$PWD"
  echo "USER=$USER"
fi


#
##
### Find the mutation contexts and rates
###
### path/to/MutContext.sh </path/to/example.mutations> </path/to/example.mutect.wig> <Output Prefix>
##
#

mutsfile=$1
wigfile=$2
prefix=$3

PYTHON=/opt/local/bin/python
WIGFIXER="${LG3_HOME}/scripts/mutect_wig_to_bed.py"
BEDTOOLS="/opt/BEDTools/BEDTools-2.16.2/bin/bedtools"
ANNO_AGILENT="${LG3_HOME}/resources/Agilent_SureSelect_HumanAllExon50Mb.exonic_and_splicing.bed"
CALCULATE="${LG3_HOME}/scripts/CalculateMutationRates.py"
GENOME="${LG3_HOME}/resources/hg19.2bit"

export PYTHONPATH=/home/jssong/lib/:/opt/local/lib/python2.6/site-packages/:${LG3_HOME}/

if [ ! -e "${prefix}.mutation_context" ]; then
        echo "[MutContext] Converting MuTect WIG to BED3..."
        $PYTHON "$WIGFIXER" "$wigfile" > "${prefix}.temp.bed" || error "Conversion failed"

        echo "[MutContext] Sort and merge BED..."
        $BEDTOOLS sort -i "${prefix}.temp.bed" > "${prefix}.temp.sorted.bed" || error "Sorting BED failed"
        $BEDTOOLS merge -i "${prefix}.temp.sorted.bed" > "${prefix}.temp.sorted.merged.bed" || error "Merging BED failed"

        rm -f "${prefix}.temp.bed"

        echo "[MutContext] Intersect MuTect BED with Agilent exonic and splicing BED..."
        $BEDTOOLS intersect \
                -a "${prefix}.temp.sorted.merged.bed" \
                -b "$ANNO_AGILENT" \
                > "${prefix}.temp.callable_space.bed" || error "Intersecting BEDs failed"

        rm -f "${prefix}.temp.sorted.bed"
        rm -f "${prefix}.temp.sorted.merged.bed"

        echo "[MutContext] Enforcing judgement..."
        awk -F '\t' '$31=="yes"' \
                "${mutsfile}" \
                > "${prefix}.temp1.mutations" || error "Judgement failed"

        echo "[MutContext] Removing offending columns..."
        awk -F '\t' '{for(i=1; i<=9; i++) {printf $i"\t";} printf "KEEP\t"; for(i=10; i<NF-2; i++) {printf $i"\t";} print $(NF-2)}' \
                "${prefix}.temp1.mutations" \
                > "${prefix}.temp2.mutations" || error "Removal failed"

        rm -f "${prefix}.temp1.mutations"

        echo "[MutContext] Calculating mutation rates..."
        $PYTHON "$CALCULATE" \
                "$GENOME" \
                "${prefix}.temp.callable_space.bed" \
                "${prefix}.temp2.mutations" \
                "${prefix}.mutation_context" || error "Mutation rate failed"

        rm -f "${prefix}.temp.callable_space.bed"
        rm -f "${prefix}.temp2.mutations"
fi

echo "[MutContext] Finished!"


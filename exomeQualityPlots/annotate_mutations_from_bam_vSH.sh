#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME:?}/scripts/utils.sh"
source_lg3_conf

echo "scriptpath = ${scriptpath:?}"
echo "mutationfile = ${mutationfile:?}"
echo "conversionfile = ${conversionfile:?}"
echo "patient = ${patient:?}"
echo "project = ${project:?}"
echo "bampath = ${bampath:?}"

python --version

## run annotation code
python "${scriptpath}"/annotate_mutations_from_bam_vSH_withstrand.py "${mutationfile}" "${conversionfile}" "${patient}" "${project}" "${bampath}" || { error "annotate_mutations_from_bam_vSH_withstrand.py failed"; }

## remove intermediate files
rm -f "${patient}".snvs.*Q*.txt

echo "Annotate mutations finished!"

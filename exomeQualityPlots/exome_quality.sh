#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME:?}/scripts/utils.sh"
source_lg3_conf

echo "----- Arguments received:"
echo "patient = ${patient:?}"
echo "scriptpath = ${scriptpath:?}"
echo "reffasta = ${reffasta:?}"
echo "mutationfile = ${mutationfile:?}"
echo "conversionfile = ${conversionfile:?}"
echo -e "bampath = ${bampath:?}\n-----------\n\n"

module load r/3.6.3
python --version
${RSCRIPT} --version

## reformat quality info file
echo -e "\n=== reformat quality info file"
python "${scriptpath}"/plot_qualinfo.py "${reffasta}" "${mutationfile}" "${patient}".qualityinfo.tmp || { error "plot_qualinfo.py FAILED"; }

## make plots
echo -e "\n=== make plots"
${RSCRIPT} --vanilla "${scriptpath}"/plot_qualinfo.R "${patient}" "${patient}".qualityinfo.txt "${mutationfile}" || { error "plot_qualinfo.R FAILED"; }

## make coverage histograms
echo -e "\n=== make coverage histograms"
${RSCRIPT} --vanilla "${scriptpath}"/coveragePlots.R "${conversionfile}" "${patient}" ./ "${patient}"_qualplots/libraryQuality || { error "coveragePlots.R FAILED"; }

## make TERT coverage plots
echo -e "\n=== make TERT coverage plots"
python "${scriptpath}"/afTERThought.py "${bampath}/${patient}" "${conversionfile}" "${patient}" "${patient}"_qualplots/VAFPatterns || { error "afTERThought.py FAILED"; }

## remove intermediate files
rm -f "${patient}".qualityinfo.tmp

echo "=== All Finished!"

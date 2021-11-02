#!/bin/bash

# shellcheck source=scripts/utils.sh
#source "${LG3_HOME:?}/scripts/utils.sh"
#source_lg3_conf

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
python "${scriptpath}"/plot_qualinfo.py "${reffasta}" "${mutationfile}" "${patient}".qualityinfo.tmp || { echo "plot_qualinfo.py FAILED"; exit 1; }

## make plots
echo -e "\n=== make plots"
${RSCRIPT} --vanilla "${scriptpath}"/plot_qualinfo.R "${patient}" "${patient}".qualityinfo.txt "${mutationfile}" || { echo "plot_qualinfo.R FAILED"; exit 1; }

## make coverage histograms
echo -e "\n=== make coverage histograms"
${RSCRIPT} --vanilla "${scriptpath}"/coveragePlots.R "${conversionfile}" "${patient}" ./ "${patient}"_qualplots/libraryQuality || { echo "coveragePlots.R FAILED"; exit 1; }

## make TERT coverage plots
echo -e "\n=== make TERT coverage plots"
python "${scriptpath}"/afTERThought.py "${bampath}/${patient}" "${conversionfile}" "${patient}" "${patient}"_qualplots/VAFPatterns || { echo "afTERThought.py  FAILED"; exit 1; }

## remove intermediate files
#rm -f "${patient}".qualityinfo.tmp

echo "=== All Finished!"

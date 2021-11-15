
##########################################################################################
# UCSF
# Costello Lab
# Run Advanced Variant Filtering protocol as developed for the Costello Lab
# Author: srhilz
# Version: v1 (2018.01.24)

# Input:
#   1. mutfile - *R.mutations file containing processed variant calls for patient
# Output:
#   1. (not returned) mutavffile - *R.mutations.avf file updated with flags and decisions
# Usage:
#   advanced_variant_filtering.py *.R.mutations
#
##########################################################################################

import sys
import os

try:
   LG3_HOME=os.environ['LG3_HOME']
except KeyError:
   print("ERROR: LG3_HOME not set!")
   sys.exit(1)
sys.path.append(LG3_HOME + "/exomeAdvancedVariantFiltering")

import mutavf_init
import get_repeat_loci
import get_dac_blacklist_loci
import flag_mutavf_by_loci
import decide_mutavf
import get_whitelist_loci
import get_lowqual_loci

# Part 0: File paths - will have to be edited once moved onto server
mutfile = sys.argv[1]
qualitystats_file = sys.argv[2].strip()

print("Input 1: " + mutfile)
print("Input 2: " + qualitystats_file)

mutavffile = mutfile.replace('.mutations','.mutations.avf')
hotspot_file = LG3_HOME + '/exomeAdvancedVariantFiltering/hotspot-list-union-v1-v2.txt'
repeat_masker_file = LG3_HOME + '/exomeAdvancedVariantFiltering/UCSC_RepeatMasker_rmsk_hg19.bed.gz'
dac_blacklist_file = LG3_HOME + '/exomeAdvancedVariantFiltering/ENCFF001TDO.bed.gz'

print("Part 1 : init with placeholder columns")
mutavf_init.mutavf_init(mutfile)

print("Part 2 : ID loci in whitelist")
white_chromosomes, white_starts, white_ends, white_flags = get_whitelist_loci.get_whitelist_loci(hotspot_file)

print("Part 2b: Update mutavf file with flags for whitelist regions")
flag_mutavf_by_loci.flag_mutavf_by_loci(mutavffile, 'MuTect,Pindel', white_chromosomes, white_starts, white_ends, white_flags)

print("Part 3a: ID loci in repeat regions")
rep_chromosomes, rep_starts, rep_ends, rep_flags = get_repeat_loci.get_repeat_loci(repeat_masker_file)

print("Part 3b: Update mutavf file with flags for repeats")
flag_mutavf_by_loci.flag_mutavf_by_loci(mutavffile, 'MuTect,Pindel', rep_chromosomes, rep_starts, rep_ends, rep_flags)

print("Part 4: ID loci in ENCODE DAC blacklisted regions")
dac_chromosomes, dac_starts, dac_ends, dac_flags = get_dac_blacklist_loci.get_dac_blacklist_loci(dac_blacklist_file)

print("Part 4b: Update mutavf file with flags for ENCODE DAC blacklisted regions")
flag_mutavf_by_loci.flag_mutavf_by_loci(mutavffile, 'MuTect,Pindel', dac_chromosomes, dac_starts, dac_ends, dac_flags)

print("Part 5: ID low quality loci")
low_chromosomes, low_starts, low_ends, low_flags = get_lowqual_loci.get_lowqual_loci(qualitystats_file)

print("Part 5b: Update mutavf file with flags for low quality loci")
### Ivan: check if low_chromosomes, etc are not empty!
if low_starts.strip():
   flag_mutavf_by_loci.flag_mutavf_by_loci(mutavffile, 'MuTect', low_chromosomes, low_starts, low_ends, low_flags)
else:
   print("WARNING, No low quality loci found!")

print("Part N: Make final decisions to retain or discard each variant based on flags")
decide_mutavf.decide_mutavf(mutavffile)

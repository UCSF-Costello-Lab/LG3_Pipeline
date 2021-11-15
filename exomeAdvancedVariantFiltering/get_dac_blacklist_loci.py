
##########################################################################################
# UCSF
# Costello Lab
# Read in ENCODE DAC Blacklisted Regions bed and pull out loci info for each Blacklisted
#   region
# Author: srhilz
# Version: v1 (2018.01.24)

# Input:
#   1. dac_blacklist_file - bed file from ENCODE with blacklisted regions
#       https://www.encodeproject.org/annotations/ENCSR636HFF/
#       Should be from same genome build used to call mutations, or else
#       should convert.
# Output:
#   1. chromosomes - chromosome(s) of loci. If more than one, will be a comma-
#       separated list (ex. "chr6,chr7"). Importantly, order  corresponds to order of
#       start and end coordinates.
#   2. starts - start coordinate(s) of loci. If more than one, will be a comma-
#       separated list (ex. "90136514,51160618").
#   3. ends - end coordinate(s) of loci. Loci will not include this coordinate, but
#       will include all coordinates up until it.
#   4. flags - flag(s) to be added for variants falling within the specifid loci.
#
#
##########################################################################################

import sys, gzip

def get_dac_blacklist_loci(dac_blacklist_file):

    print("IDing loci in ENCODE DAC Blacklist")

    ## read ENCODE DAC Blacklist file
    data = gzip.open(dac_blacklist_file).readlines()

    ## set column indexes (DAC file has no headers, so manually specify content here)
    chr = 0
    stt = 1
    end = 2
    flg = 3

    ## define empty arrays to collect data in
    chromosomes = []
    starts = []
    ends = []
    flags = []

    ## gather locus information in arrays for file
    for line in data:
        line = line.rstrip().split('\t')
        chromosomes.append(line[chr])
        starts.append(line[stt])
        ends.append(line[end])
        flags.append('DAC:'+line[flg])#this makes a hybrid of a universal DAC flag + locus-specific info

    ## format for flag_mutavf_by_locus
    chromosomes = ','.join(chromosomes)
    starts = ','.join(starts)
    ends = ','.join(ends)
    flags = ','.join(flags)

    return(chromosomes, starts, ends, flags)

if __name__=="__main__":
    if len(sys.argv) != 2:
        print 'usage: %s dac_blacklist_file' %(sys.argv[0])
        sys.exit(1)

    get_dac_blacklist_loci(sys.argv[1].strip())

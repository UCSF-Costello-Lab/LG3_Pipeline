
##########################################################################################
# UCSF
# Costello Lab
# Read in whitelist file(s) and pull out loci info for each region
# Author: srhilz
# Version: v1 (2018.01.26)

# Input:
#   1. hotspot_file - hotspot-list-union-v1-v2.txt, a bed-like file from MSK, downloaded
#       2018.01.26 from https://github.com/mskcc/ngs-filters/tree/master/data
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

import sys

def get_whitelist_loci(hotspot_file):

    print("IDing loci in hotspot file to whitelist")

    ## read hotspot file
    data = open(hotspot_file).readlines()
    data = data[1:] # remove header

    ## set column indexes manually
    chr = 1
    stt = 2
    end = 3

    ## define empty arrays to collect data in
    chromosomes = []
    starts = []
    ends = []
    flags = []

    ## gather locus information in arrays for file
    for line in data:
        line = line.rstrip().split('\t')
        chromosomes.append('chr'+str(line[chr]))
        starts.append(line[stt])
        ends.append(str(int(line[end])+1))# we need to add one to make compatible with our end coord convention
        flags.append('Whitelist:hotspot')

    ## format for flag_mutavf_by_locus
    chromosomes = ','.join(chromosomes)
    starts = ','.join(starts)
    ends = ','.join(ends)
    flags = ','.join(flags)

    return(chromosomes, starts, ends, flags)

if __name__=="__main__":
    if len(sys.argv) != 2:
        print 'usage: %s get_whitelist_loci' %(sys.argv[0])
        sys.exit(1)

    get_whitelist_loci(sys.argv[1].strip())

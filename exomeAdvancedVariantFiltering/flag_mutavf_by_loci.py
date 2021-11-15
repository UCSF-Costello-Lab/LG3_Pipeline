
##########################################################################################
# UCSF
# Costello Lab
# Add flags to R.mutations.avf file based on specified loci
# Author: srhilz
# Version: v1 (2018.01.23)

# Input:
#   1. mutavffile - *R.mutations.avf file for patient, made from the R.mutations file
#       by running mutavf_init.py
#   2. algorithms - specifies which variants (by algorithm type) the filtering concerns.
#       Must be exact match to one or more algorithm types in *R.mutations.avf. If more
#       than one, enter as a comma-separated list (ex. "MuTect,Pindel"). Does not correspond
#       in order or length to list for loci information (chromosome, start, and end)
#   3. chromosomes - chromosome(s) of loci to flag. If more than one, enter as a comma-
#       separated list (ex. "chr6,chr7"). Importantly, order must correspond to order of
#       start and end coordinates as well as flags.
#   4. starts - start coordinate(s) of loci to flag. If more than one, enter as a comma-
#       separated list (ex. "90136514,51160618"). Start and end coordinate must
#       correspond to the same genome build used to generate the R.mutations file.
#   5. ends - end coordinate(s) of loci to flag. Flagged loci will not include this coordinate,
#       but will include all coordinates up until it.
#   6. flags - flag(s) to be added for variants falling within the specifid loci.
# Output:
#   1. (not returned) mutavffile - *R.mutations.avf file updated with flags
#
#
##########################################################################################

import sys

def flag_mutavf_by_loci(mutavffile, algorithms, chromosomes, starts, ends, flags):

    print("Updating ",mutavffile)

    ## process and check arguments
    algorithms = algorithms.split(',')
    chromosomes = chromosomes.split(',')
    #print("starts = ",starts)
    starts = starts.split(',')
    ends = ends.split(',')
    flags = flags.split(',')
    starts = [int(x) for x in starts]
    ends = [int(x) for x in ends]

    ## read mutation data
    data = open(mutavffile).readlines()
    header = data[0]
    data = data[1:]

    ## parse header
    h = header.strip().split('\t')
    chr = h.index('contig')
    pos = h.index('position')
    alg = h.index('algorithm')
    flg = h.index('flags')

    ## update tag column for each variant within the specified locus
    for i,s in enumerate(data):
        data[i] = s.rstrip().split('\t')
        if data[i][alg] in algorithms: #if the line corresponds to one of the specified algorithms
            j = 0
            while j < len(chromosomes):#compares the line to each of the loci specified to flag
                if data[i][chr] == chromosomes[j]:
                    if starts[j] <= int(data[i][pos]) < ends[j]:
                        if data[i][flg] == 'NA':
                            data[i][flg] = flags[j]
                            print('Variant in ',flags[j])
                        else:
                            if flags[j] not in data[i][flg]: #spares us from repeating flag > once
                                data[i][flg] = data[i][flg] + ';' + flags[j]
                                print('Variant in ',flags[j])
                j += 1

    ## output updated file
    outfile = open(mutavffile,'w')
    outfile.write(header)
    for line in data:
        outfile.write('\t'.join(line) + '\n')
    outfile.close()

if __name__=="__main__":
    if len(sys.argv) != 7:
        print 'usage: %s *R.mutations.avf algorithms chromosome start end flag' %(sys.argv[0])
        sys.exit(1)

    flag_mutavf_by_locus(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6].strip())

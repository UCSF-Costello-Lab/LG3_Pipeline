
##########################################################################################
# UCSF
# Costello Lab
# Read in quality stats produced by plot_qualityinfo.R, apply cutoffs, and return
#   loci info for variants below cutoffs
# Author: srhilz
# Version: v1 (2018.01.26)

# Input:
#   1. qualitystats_file - *.qualitystats.txt
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

def get_lowqual_loci(qualitystats_file):

    print("IDing low-quality loci")

    ## thresholds and cutoffs
    basequality_cutoff = 25 # fraction of samples specified below must be >= to pass
    mappingquality_cutoff = 50 # fraction of samples specified below must be >= to pass
    alpha = 0.01 # significance threshold for wilcox test
    fraction_quality = .5
    fraction_test = 1

    ## read mutation data
    data = open(qualitystats_file).readlines()
    header = data[0]
    data = data[1:]

    ## parse header
    h = header.strip().split('\t')
    chr = h.index('chr')
    stt = h.index('start')
    end = h.index('end')
    sub = h.index('subs')
    abq = h.index('avg_basequal')
    amq = h.index('avg_mapqual')
    aabq = h.index('avg_alt_basequal')
    aamq = h.index('avg_alt_mapqual')
    pbq = h.index('wilcox_p_basequal')
    pmq = h.index('wilcox_p_mapqual')

    ## empty dic to fill with qual info, indexed by unique variant ID
    dic = {}

    ## populate dic with quality info
    for line in data:
        line = line.rstrip().split('\t')
        uniqueID = line[chr] + '_' + line[stt] + line[sub]
        if uniqueID not in line:
            dic[uniqueID] = [line[chr], line[stt], line[end], [],[],[],[],[],[]]
        dic[uniqueID][3].append(float(line[abq]))
        dic[uniqueID][4].append(float(line[amq]))
        print line
        dic[uniqueID][5].append(float(line[aabq]))
        dic[uniqueID][6].append(float(line[aamq]))
        if line[pbq] == 'NA' or line[pbq] == 'NaN':
            line[pbq] = 2 # this is done to simplify filtering on sig; this will obviously be non-sig
        if line[pmq] == 'NA' or line[pmq] == 'NaN':
            line[pmq] = 2 # this is done to simplify filtering on sig; this will obviously be non-sig
        dic[uniqueID][7].append(float(line[pbq]))
        dic[uniqueID][8].append(float(line[pmq]))

    ## define empty arrays to collect data in
    chromosomes = []
    starts = []
    ends = []
    flags = []

    ## populate arrays with data for loci that fail to meet quality cutoffs
    for entry in dic:
        var_chromosome = dic[entry][0]
        var_start = str(dic[entry][1])
        var_end = str(dic[entry][2])
        total_samples = len(dic[entry][3])

        # determine fraction failed average base quality
        sum_failed_abq = sum(x < basequality_cutoff for x in dic[entry][3])
        fraction_failed_abq = sum_failed_abq/total_samples
        if fraction_failed_abq >= fraction_quality:
            chromosomes.append(var_chromosome)
            starts.append(var_start)
            ends.append(var_end)
            flags.append('Lowqual:avg_basequal')

        # determine fraction failed average mapping quality
        sum_failed_amq = sum(x < mappingquality_cutoff for x in dic[entry][4])
        fraction_failed_amq = sum_failed_amq/total_samples
        if fraction_failed_amq >= fraction_quality:
            chromosomes.append(var_chromosome)
            starts.append(var_start)
            ends.append(var_end)
            flags.append('Lowqual:avg_mapqual')

        # determine fraction failed avg alt + wilcox ref vs alt base quality
        dic[entry][7] = [total_samples * x for x in dic[entry][7]] # simple multiple test correction
        lowqual_subset = []
        for i,s in enumerate(dic[entry][5]):
            if s < basequality_cutoff:
                lowqual_subset.append(dic[entry][7][i])
        sum_failed_pbq = sum(x < alpha for x in lowqual_subset)
        fraction_failed_pbq = sum_failed_pbq/total_samples
        if fraction_failed_pbq >= fraction_test:
            chromosomes.append(var_chromosome)
            starts.append(var_start)
            ends.append(var_end)
            flags.append('Lowqual:unequal_basequal')

        # determine fraction failed avg alt + wilcox ref vs alt mapping quality
        dic[entry][8] = [total_samples * x for x in dic[entry][8]] # simple multiple test correction
        lowqual_subset = []
        for i,s in enumerate(dic[entry][6]):
            if s < basequality_cutoff:
                lowqual_subset.append(dic[entry][8][i])
        sum_failed_pmq = sum(x < alpha for x in lowqual_subset)
        fraction_failed_pmq = sum_failed_pmq/total_samples
        if fraction_failed_pmq >= fraction_test:
            chromosomes.append(var_chromosome)
            starts.append(var_start)
            ends.append(var_end)
            flags.append('Lowqual:unequal_mapqual')

    ## format for flag_mutavf_by_locus
    chromosomes = ','.join(chromosomes)
    starts = ','.join(starts)
    ends = ','.join(ends)
    flags = ','.join(flags)

    return(chromosomes, starts, ends, flags)

if __name__=="__main__":
    if len(sys.argv) != 7:
        print 'usage: %s *.qualitystats.txt' %(sys.argv[0])
        sys.exit(1)

    get_lowqual_loci(sys.argv[1].strip())

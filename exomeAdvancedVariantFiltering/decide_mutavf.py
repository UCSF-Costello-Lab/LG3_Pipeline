
##########################################################################################
# UCSF
# Costello Lab
# Make final decisions about
# Author: srhilz
# Version: v1 (2018.01.24)

# Input:
#   1. mutavffile - *R.mutations.avf file for patient, after one or more flags has
#       been added by flag_mutavf_by_loci.py
# Output:
#   1. (not returned) mutavffile - *R.mutations.avf file updated with decisions
#
#
##########################################################################################

import sys

def decide_mutavf(mutavffile):

    print ("Making final retainment decisions for each variant")

    ## read mutation data
    data = open(mutavffile).readlines()
    header = data[0]
    data = data[1:]

    ## parse header
    h = header.strip().split('\t')
    flg = h.index('flags')
    dec = h.index('decision')

    ## make final decision for each variant based on set of rules
    for i,s in enumerate(data):
        data[i] = s.rstrip().split('\t')
        flags = data[i][flg].split(';')
        if "Whitelist:" in flags: #if is listed on our whitelist
            data[i][dec] = 'retain'
        elif any('Repeat:' in x for x in flags): #if is found in RepeatMasker locus
            data[i][dec] = 'discard'
        elif any('DAC:' in x for x in flags): #if is found in ENCODE DAC blacklist
            data[i][dec] = 'discard'
        elif any('Lowqual:' in x for x in flags): #if is found in lowquality region, or alt qual is lower than ref qual
            data[i][dec] = 'discard'
        else: #if there is no reason to discard it, retain
            data[i][dec] = 'retain'

    ## output updated file
    outfile = open(mutavffile,'w')
    outfile.write(header)
    for line in data:
        outfile.write('\t'.join(line) + '\n')
    outfile.close()

if __name__=="__main__":
    if len(sys.argv) != 2:
        print 'usage: %s mutavffile' %(sys.argv[0])
        sys.exit(1)

    decide_mutavf(sys.argv[1].strip())

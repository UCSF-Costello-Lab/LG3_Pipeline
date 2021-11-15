
##########################################################################################
# UCSF
# Costello Lab
# Initializes R.mutations.avf.txt file to prepare it for taking flags and decisions
# Author: srhilz
# Version: v1 (2018.01.24)

# Input:
#   1. mutfile - *R.mutations file containing processed variant calls for patient
# Output:
#   1. (not returned) mutavffile - initialized *R.mutations.avf file
#
#
##########################################################################################

import sys

def mutavf_init(mutfile):

    ## define output file name
    mutavffile = mutfile.replace('.mutations','.mutations.avf')
    print("Initializing ",mutavffile)

    ## read mutation data
    data = open(mutfile).readlines()
    header = data[0]
    data = data[1:]

    ## add two additional column names to header
    header = header.rstrip()
    header = header + '\tflags\tdecision\n'

    ## add placeholders to the new columns created
    for i,s in enumerate(data):
        data[i] = s.rstrip() + '\tNA\tNA\n'

    ## output augmented *.R.mutations info as *.R.mutations.avf
    outfile = open(mutavffile,'w')
    outfile.write(header)
    for line in data:
        outfile.write(line)
    outfile.close()

if __name__=="__main__":
    if len(sys.argv) != 2:
        print 'usage: %s *R.mutations' %(sys.argv[0])
        sys.exit(1)

    mutavf_init(sys.argv[1].strip())

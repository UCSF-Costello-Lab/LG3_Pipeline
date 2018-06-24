#!/usr/bin/env python

"""
CalculateMutationRates.py - Identify the mutation rates in a sample based on the total bases that could be mutated and the actual mutations.

Usage: CalculateMutationRates.py genome.2bit possibleRegions.bed actualMutations.txt out.txt
 where
 genome.2bit is the genome sequence of the genome analyzed
 possibleRegions.bed is a list of non-overlapping areas which were sequenced to an adequate depth of coverage to call mutations
 actualMutations.txt is a list of mutations that were identified in the possibleRegions
 out.txt is an output file providing the mutation rates

Options:
  -h, -?, --help   Print this help and exit
  --useIndels      Include indel mutation rates (default=False)
  --noDebug        Do not include sanity checks on input data (for efficiency)
"""

import sys
import os
import getopt
import subprocess
import operator
import pykent.common.Bed as Bed
import pykent.common.BedTools as BedTools
from pykent.common.GenomeUtil import getChromSizesDict, getDNA
from pykent.common.DNAUtil import reverseComplement
from pykent.common.Sanity import errAbort,roughlyEqual,canBeInt,canBeNum
from math import log, floor

NUM_ARGS = 4
USE_INDELS = False
DEBUG = True
chromSizes = {}

class Callable:
    def __init__(self, anycallable):
        self.__call__ = anycallable

class Mutation:
    CpG = 'CpG'
    Other_GC = 'Other G:C'
    All_AT = 'All A:T'
    INS = "Insertion"
    DEL = "Deletion"

    ALL_MUTATIONS = {'ACC': 0, 'ATG': 0, 'AAG': 0, 'AAA': 0, 'ATC': 0, 'AAC': 0, 'ATA': 0, 'AGG': 0, 'CTC': 0, 'AGC': 0, 'ACA': 0, 'AGA': 0, 'AAT': 0, 'CTA': 0, 'ACT': 0, 'CAC': 0, 'ACG': 0, 'CAA': 0, 'CCA': 0, 'CCG': 0, 'CCC': 0, 'CGA': 0, 'CAG': 0, 'CGC': 0, 'GGA': 0, 'TAA': 0, 'GAC': 0, 'GAA': 0, 'TCA': 0, 'GCA': 0, 'GTA': 0, 'GCC': 0, INS: 0, DEL: 0}

    def __init__(self, line, genomeFn, chromSizesDict):
        if line.endswith('\n'):
            line = line[:-1]
        line = line.split('\t')
        if len(line) != 31:
            errAbort("Mutation lines must have 31 columns.", "\t".join(line))
        self.geneSymbol = line[0]
        self.chrom = line[1]
        self.chromStart = int(line[2])-1
        if self.chromStart < 0:
            errAbort("Invalid position for mutation to occur.")        
        if self.chromStart+1 > chromSizesDict[self.chrom]:
            errAbort("Invalid position for mutation to occur.")
        self.refAllele = line[3]
        self.mutAllele = line[4]
        self.ntMut = line[5]
        self.aaMut = line[6]
        self.mutContext = line[7]
        self.geneMutType = line[8]
        self.mutStatus = line[9]  # "KEEP"
        self.tumorName = line[10]
        self.normalName = line[11]
        self.score = line[12]
        self.power = line[13]
        self.tumorPower = line[14]
        self.normalPower = line[15]
        self.totalPairs = int(line[16])
        self.improperPairs = -1
        if canBeInt(line[17]):
            self.improperPairs = int(line[17])
        self.mapQ0Reads = -1
        if canBeInt(line[18]):
            self.mapQ0Reads = int(line[18])
        self.contamFrac = float(line[19])
        self.contamLOD = -1
        if canBeNum(line[20]):
            self.contamLOD = float(line[20])
        self.tumorRefCount = int(line[21])
        self.tumorMutCount = int(line[22])
        self.normalRefCount = int(line[23])
        self.normalMutCount = int(line[24])
        self.tumorVarFreq = float(line[25])
        self.normalVarFreq = float(line[26])
        self.accessionList = line[27].strip().split(',')
        self.exon = map(int, map(lambda x: x.replace('NA', '-1').replace('UNKNOWN','-1'), line[28].strip().split(',')))
        self.knownVariant = line[29]
        self.algorithm = line[30]
        self.findMutationType(genomeFn, chromSizesDict)

        if not roughlyEqual(self.tumorVarFreq, (self.tumorMutCount*1./(self.tumorMutCount+self.tumorRefCount)), epsilon=0.005):
            print "Tumor variant frequency is not accurate! %f %f" % (self.tumorVarFreq, (self.tumorMutCount*1./(self.tumorMutCount+self.tumorRefCount)))
        if not roughlyEqual(self.normalVarFreq, (self.normalMutCount*1./(self.normalMutCount+self.normalRefCount)),epsilon=0.005):
            print "Normal variant frequency is not accurate! %f %f" % (self.normalVarFreq, (self.normalMutCount*1./(self.normalMutCount+self.normalRefCount)))

    def getMutationType(dna, coords=""):
        ''' Class method to return the type of mutation given this DNA.
            Assumes DNA is a 3-letter uppercase sequence and the mutation is a point mutation in the
            middle base pair '''
        if len(dna) != 3:
            errAbort("getMutationType assumes DNA is a 3-letter sequence!")
        mut_type = min(dna, reverseComplement(dna))
        if mut_type not in Mutation.ALL_MUTATIONS:
            print "Error: Mutation %s is not one we expect: %s" % (mut_type, coords)
        return mut_type
    getMutationType = Callable(getMutationType) # Make this be a callable class method

    def findMutationType(self, genomeFn, chromSizesDict):
        ''' Determine the mutation type based on the sequence '''
        if self.algorithm == 'SomaticIndelDetector':
            if len(self.refAllele) < len(self.mutAllele):
                self.mutationType = Mutation.INS
            elif len(self.refAllele) > len(self.mutAllele):
                self.mutationType = Mutation.DEL
        else:
            if len(self.refAllele) != 1:
                errAbort("Can't handle non-single-bp mutations at this point.")

            mutDNA = getDNA(self.chrom, max(0, self.chromStart-1), min(self.chromStart+1+1, chromSizesDict[self.chrom]), genomeFn, noMask=True)

            # Pad out any edge effects
            if self.chromStart == 0:
                mutDNA = "N" + mutDNA
            if self.chromStart+1 == chromSizesDict[self.chrom]:
                mutDNA += "N"

            if len(mutDNA) == 3:
                self.mutationType = Mutation.getMutationType(mutDNA, coords="%s:%d-%d" % (self.chrom, max(0, self.chromStart), min(self.chromStart+1+1, chromSizesDict[self.chrom])))
            else:
                errAbort("Bad input for mutation analysis: %s" % mutDNA)

def getPossibleMutations(bedList, genomeFn, chromSizesDict, debug=True):
    ''' Return a dictionary keyed by mutation type with the total possible number of mutations in this bed list '''
    global USE_INDELS
    if debug:
        if not BedTools.isNonContiguous(bedList):
            errAbort("Input regions must be non-contiguous")

    d = {}
    curr_chrom = None
    curr_seq = None
    for bed in bedList:
        if bed.chrom < curr_chrom:
            errAbort("Err: Regions must be sorted by chromosome")
        elif bed.chrom > curr_chrom:
            curr_chrom = bed.chrom
            curr_seq = getDNA(curr_chrom, 0, chromSizesDict[curr_chrom], genomeFn, noMask=True)

        if USE_INDELS:
            d[Mutation.INS] = d.get(Mutation.INS, 0) + (bed.chromEnd-bed.chromStart-1)
            d[Mutation.DEL] = d.get(Mutation.DEL, 0) + (bed.chromEnd-bed.chromStart-1)

        prefix = ""
        if bed.chromStart == 0:
            prefix = "N"
        suffix = ""
        if bed.chromEnd == chromSizesDict[bed.chrom]:
            suffix = "N"
        bedSeq = prefix + curr_seq[max(0, bed.chromStart-1):min(bed.chromEnd+1, chromSizesDict[bed.chrom])] + suffix
        seqLen = len(bedSeq)

        for i in xrange(1, seqLen-1):
            mut_type = Mutation.getMutationType(bedSeq[i-1:i+2], coords="%s:%d-%d" % (bed.chrom, bed.chromStart-1+(i-1), bed.chromStart-1+(i+2)))
            d[mut_type] = d.get(mut_type,0) + 1
    return d


class Patient:
    def __init__(self, seqFn, mutFn, genomeFn, chromSizesDict, debug=True):
        """ Initialize a patient based on what has been sequenced and what mutations exist """
        self.sequencedRegions = BedTools.bedChromDictFromFile(seqFn, chromSizes=chromSizesDict)
        if debug:
            if not BedTools.isNonContiguousDict(self.sequencedRegions):
                errAbort("Sequenced regions must be non-contiguous")

        # Find all the possible mutations based on the amount of DNA sequenced in the patient
        self.totalSequencedBp = 0
        self.totalPossibleMuts = {}
        for chromBedList in self.sequencedRegions.values():
            d = getPossibleMutations(chromBedList, genomeFn, chromSizesDict)
            for k,v in d.items():
                self.totalPossibleMuts[k] = self.totalPossibleMuts.get(k,0) + v
            for sequencedBed in chromBedList:
                self.totalSequencedBp += (sequencedBed.chromEnd-sequencedBed.chromStart)

        # Read in the actual mutations in the patient
        self.mutations = [Mutation(line, genomeFn, chromSizesDict) for line in open(mutFn) if not line.startswith("gene")]
        self.mutations[:] = sorted(self.mutations, key=operator.attrgetter('chrom', 'chromStart'))

        for mutation in self.mutations:
            chromBedList = self.sequencedRegions.get(mutation.chrom, [])
            #endToTest = mutation.chromStart + max(len(mutation.refAllele), len(mutation.mutAllele)) if mutation.mutationType not in (Mutation.INS, Mutation.DEL) else mutation.chromStart+1
            endToTest = mutation.chromStart+1
            if chromBedList == [] or not BedTools.isEncompassedByBed(mutation.chrom, mutation.chromStart, endToTest, chromBedList):
                errAbort("Mutation is not encompassed by sequenced regions.")

        if len(set(self.totalPossibleMuts.iterkeys()).difference(set(Mutation.ALL_MUTATIONS.keys()))) > 0:
            print "Error: Patient %s has some mutations not found..." % mutFn
            print self.totalPossibleMuts

    def __str__(self):
        ''' Return a string representation of a patient. '''
        retval = "Total sequenced bp: %d\n" % self.totalSequencedBp
        retval += "Total mutations: %d\n" % len(self.mutations)
	retval += "number_mutations\tcontext\tpossible_places\tmutations_per_Mb\n"
        for mut_type in Mutation.ALL_MUTATIONS.keys():
            perMb = 1000000.*len([x for x in self.mutations if x.mutationType == mut_type])/self.totalPossibleMuts[mut_type] if self.totalPossibleMuts.get(mut_type,0) > 0 else 0
            retval += "%d\t%s\t%d\t%1.2f\n" % (len([x for x in self.mutations if x.mutationType == mut_type]), mut_type, self.totalPossibleMuts.get(mut_type,0), perMb)

        return retval

    def getTestRegions(self, bedList):
        ''' Return the intersection of the input bedList and the sequenced regions of the patient '''
        inputDict = {}
        for b in bedList:
            inputDict[b.chrom] = inputDict.get(b.chrom,[]) + [b]
        ovlpDict = BedTools.getOverlappingRegionDict(self.sequencedRegions, inputDict)

        outKeys = ovlpDict.keys()
        outKeys.sort()
        retval = []
        for k in outKeys:
            retval += ovlpDict[k]
        return retval

    def getMutations(self, bedList):
        ''' Return the Mutations that lie within one of the regions defined by bedList as a dict keyed by mutation type '''
        global USE_INDELS
        retval = {}
        for mut in self.mutations:
            if USE_INDELS or (mut.mutationType not in (Mutation.INS, Mutation.DEL)):
                if BedTools.isEncompassedByBed(mut.chrom, mut.chromStart, mut.chromStart+max(len(mut.refAllele), len(mut.mutAllele)), bedList):
                    retval[mut.mutationType] = retval.get(mut.mutationType,0)+1
        return retval


def main():
    ''' Main function for CalculateMutationRates '''
    global chromSizes
    global DEBUG

    args = parseArgv()
    genomeFn, sequencedFn, actualMutsFn, outFn = args[0:4]

    chromSizes = getChromSizesDict(genomeFn)

    patient = Patient(sequencedFn, actualMutsFn, genomeFn, chromSizes, debug=DEBUG)

    f = open(outFn, "w")
    f.write("%s\n" % patient.__str__())
    f.close()


def parseArgv():
    ''' Parse the command line options and return the arguments '''
    global NUM_ARGS, USE_INDELS, DEBUG
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h?", ["help","useIndels","noDebug"])
    except getopt.error, msg:
        print msg
        print __doc__
        sys.exit(-1)

    if len(args) != NUM_ARGS:
        print "Invalid number of arguments passed to CalculateMutationRates."
        print __doc__
        sys.exit(-1)

    for o,a in opts:
        if o in ("-h", "-?", "--help"):
            print __doc__
            sys.exit(0)
        elif o == "--useIndels":
            USE_INDELS = True
        elif o == "--noDebug":
            DEBUG = False
        else:
            print "Invalid option:", o
            print __doc__
            sys.exit(-1)

    return args


if __name__ == '__main__':
    sys.exit(main())

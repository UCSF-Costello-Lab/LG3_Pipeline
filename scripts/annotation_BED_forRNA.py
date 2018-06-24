#!/usr/bin/python

####
#This script makes a BED file from a mutect output
####
import sys


def usage():
	print "Usage:"
	print "annotation_BED_forRNA.py PatientXX.annotated.mutations"
	sys.exit()


def parseMuts(mutsFilename):
	"""Parses the annotated.muts.txt file and returns a header and mutation list"""
	header = []
	snps = []
	muts = open(mutsFilename)
	for line in muts:
		line = line.rstrip("\n")
		line = line.split("\t")
		if (line[0] == "#gene"):
			header = line
			continue
		snps.append(line)
	muts.close()
	return (header, snps)


def annotation(mutsFilename):
	"""This script annotates a mutect file"""
	#parse the mutations file
	(header, snps) = parseMuts(mutsFilename)

	#find column numbers
	contig = header.index("contig")
	position = header.index("position")
	algorithm = header.index("algorithm")

	#make the bed file
	bed = []
	for line in snps:
		if (line[algorithm] != "MuTect"):
			continue
		bedLine = []
		bedLine.append(line[contig])
		bedLine.append(line[position])
		bedLine.append(str(int(line[position]) + 1))
		bed.append(bedLine)

	#print the bed file
	for line in bed:
		print "\t".join(line)
	return()


if (len(sys.argv) != 2):
	usage()
else:
	annotation(sys.argv[1])

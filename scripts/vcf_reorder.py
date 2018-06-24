#!/usr/bin/python

####
#This script reorders the columns in a vcf file
####
import sys

def usage():
	print "Usage:"
	print "vcf_reorder.py vcfFile tumorName normalName"
	sys.exit()

def main(vcfFile, tumorName, normalName):
	header = []
	data = []
	vcf = open(vcfFile)
	for line in vcf:
		line = line.rstrip("\n")
		if (line[0] == "#"):
			if (line[1] == "#"):
				print line
				continue
		line = line.split("\t")
		if (line[0] == "#CHROM"):
			header = line
			continue
		data.append(line)
	vcf.close()
	tumor = header.index(tumorName)
	normal = header.index(normalName)
	header[9] = tumorName
	header[10] = normalName
	print "\t".join(header)
	for line in data:
		tumorData = line[tumor]
		normalData = line[normal]
		line[9] = tumorData
		line[10] = normalData
		print "\t".join(line)
	return()

if (len(sys.argv) != 4):
	usage()
else:
	main(sys.argv[1], sys.argv[2], sys.argv[3])
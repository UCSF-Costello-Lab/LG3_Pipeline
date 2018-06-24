#!/usr/bin/python

####
#This script parses a vcf file and prints out tumor minor allele frequencies
####
import sys


def usage():
	print "Usage:"
	print "vcf_MAF.py vcfFile tumorName normalName"
	sys.exit()


def parsing(vcfFile, tumorName, normalName):
	"""This script parses a vcf file"""
	#parsed lists
	header = []
	snps = []
	hetSNPs = []
	
	vcf = open(vcfFile)
	for line in vcf:
		line = line.rstrip("\n")
		line = line.split("\t")
		#save the column header list
		if (line[0][0] == "#"):
			if (line[0] == "#CHROM"):
				header = line
			continue
		snps.append(line)
	vcf.close()
	
	#find column numbers
	if normalName != "NA": normal = header.index(normalName)
	tumor = header.index(tumorName)
	CHROM = header.index("#CHROM")
	POS = header.index("POS")
	ID = header.index("ID")
	FILTER = header.index("FILTER")
	FORMAT = header.index("FORMAT")

	hetSNPs.append(["chromosome","position","MAF"])
	for line in snps:
		#parse the format column
		snpformat = line[FORMAT].split(":")
		GT = snpformat.index("GT")
		AD = snpformat.index("AD")
		#parse the data columns
		if normalName != "NA": normalData = line[normal].split(":")
		tumorData = line[tumor].split(":")
		#***BEGIN FILTERS***
		if (line[tumor] == "./."):
			continue
		if (normalName != "NA"):
			if (normalData[GT] != "0/1"):
				continue
		if (line[FILTER] != "PASS"):
			continue
		if (line[ID][0:2] != "rs"):
			continue
		#***END FILTERS***
		tRef = tumorData[AD].split(",")[0]
		tAlt = tumorData[AD].split(",")[1]
		tTotal = int(tAlt) + int(tRef)
		if (tTotal < 10):
			continue
		if (int(tAlt) <= int(tRef)):
			tMAF = 100 * float(int(tAlt)) / tTotal
		else:
			tMAF = 100 * float(int(tRef)) / tTotal
		hetSNPs.append([line[CHROM], line[POS], str(tMAF)])

	#print the output
	for line in hetSNPs:
		print "\t".join(line)
	return()


if (len(sys.argv) != 4):
	usage()
else:
	parsing(sys.argv[1], sys.argv[2], sys.argv[3])

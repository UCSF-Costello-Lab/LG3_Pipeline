#!/usr/bin/python

####
#This script annotates a filtered mutect output with Unified Genotyper output
####
import sys


def usage():
	print "Usage:"
	print "annotation_UG.py example.mutations UG.SNPs.vcf"
	sys.exit()


def parseMuts(mutsFilename):
	"""Parses the mutations file and returns a header and mutation list"""
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


def parseVCF(vcfFilename):
	"""Parses the vcf file and returns a header and mutation list"""
	header = []
	snps = []
	vcf = open(vcfFilename)
	for line in vcf:
		line = line.rstrip("\n")
		line = line.split("\t")
		if (line[0][0] == "#"):
			if (line[0] == "#CHROM"):
				header = line
			continue
		snps.append(line)
	vcf.close()
	return (header, snps)


def annotation(mutsFilename, vcfFilename):
	"""This script annotates a filtered mutect file"""
	(mutectHeader, mutectSNPs) = parseMuts(mutsFilename)
	(vcfHeader, vcfSNPs) = parseVCF(vcfFilename)

	#find column numbers in mutect
	contig = mutectHeader.index("contig")
	position = mutectHeader.index("position")
	tumor_name = mutectHeader.index("tumor_name")
	normal_name = mutectHeader.index("normal_name")
	ref_allele = mutectHeader.index("ref_allele")
	alt_allele = mutectHeader.index("alt_allele")
	algorithm = mutectHeader.index("algorithm")

	#find column numbers in vcf
	CHROM = vcfHeader.index("#CHROM")
	POS = vcfHeader.index("POS")
	ID = vcfHeader.index("ID")
	REF = vcfHeader.index("REF")
	ALT = vcfHeader.index("ALT")
	FILTER = vcfHeader.index("FILTER")
	INFO = vcfHeader.index("INFO")
	FORMAT = vcfHeader.index("FORMAT")

	#annotate the mutect calls with UG info
	mutectHeader.append("UG_call?")
	mutectHeader.append("UG_filter")
	for x in mutectSNPs:
		if (x[algorithm] != "MuTect"):
			x.append("N/A")
			x.append("N/A")
			continue
		normal = vcfHeader.index(x[normal_name])
		tumor = vcfHeader.index(x[tumor_name])
		a = "NO"
		b = "NOT_DETECTED"
		for y in vcfSNPs:
			if (x[contig] == y[CHROM]):
				if (x[position] == y[POS]):
					snpformat = y[FORMAT].split(":")
					GT = snpformat.index("GT")
					AD = snpformat.index("AD")
					DP = snpformat.index("DP")
					GQ = snpformat.index("GQ")
					PL = snpformat.index("PL")
					normalData = y[normal].split(":")
					tumorData = y[tumor].split(":")
					b = y[FILTER]
					#***BEGIN FILTERS***
					if (y[FILTER] != "PASS"):
						break
					if (normalData[GT] == "./."):
						b = "NO_DATA"
						break
					if (tumorData[0] == "./."):
						b = "NO_DATA"
						break
					if (x[alt_allele] != y[ALT]):
						b = "ALT_ALLELE_DIFFERENT"
						break
					if (normalData[GT] != "0/0"):
						b = "ALT_ALLELE_GERMLINE"
						break
					if (tumorData[GT] == "0/0"):
						break
					#***END FILTERS***
					a = "YES"
					break
		x.append(a)
		x.append(b)

	#print the (more) annotated file
	print "\t".join(mutectHeader)
	for line in mutectSNPs:
		print "\t".join(line)
	
	return()


if (len(sys.argv) != 3):
	usage()
else:
	annotation(sys.argv[1], sys.argv[2])
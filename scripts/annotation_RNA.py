#!/usr/bin/python

####
#This script annotates a mutect output with RNA-seq data
####
import sys


def usage():
	print "Usage:"
	print "annotation_RNA.py example.annotated.mutations RNA.pileup"
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


def getRNAcoverage(rnaFilename, contig, position, ref_allele, alt_allele):
	"""Parses a RNA.mpileup file and returns the RNA-seq coverage stats"""
	Covered = "NO"
	RNA_ref = 0
	RNA_alt = 0
	Detected = "NO"
	rnaString = ""
	skip = 0
	rna = open(rnaFilename)
	for line in rna:
		line = line.rstrip("\n")
		line = line.split("\t")
		if (line[0] == contig):
			if (line[1] == position):
				rnaString = line[4].upper()
				break
	rna.close()
	#process the reads from the pileup
	for base in rnaString:
		if (skip > 0):
			skip -= 1
			continue
		if (base == "^"):
			skip = 1
			continue
		if (base.isdigit() == True):
			skip = int(base)
			continue
		if (base == ref_allele):
			RNA_ref += 1
		if (base == alt_allele):
			RNA_alt += 1
	if ((RNA_ref + RNA_alt) >= 10):
		Covered = "YES"
	if (RNA_alt > 0):
		Detected = "YES"
	return (Covered, RNA_ref, RNA_alt, Detected)


def annotation(mutsFilename, rnaFilename):
	"""This script annotates a mutect file"""
	#parse the mutations file
	(header, snps) = parseMuts(mutsFilename)
	
	#find column numbers
	contig = header.index("contig")
	position = header.index("position")
	ref_allele = header.index("ref_allele")
	alt_allele = header.index("alt_allele")
	context = header.index("context")
	type = header.index("type")
	algorithm = header.index("algorithm")
	
	#annotate the mutect calls with RNA-seq info
	header.append("RNA_position_covered?")
	header.append("RNA_variant_detected?")
	header.append("RNA_ref_reads")
	header.append("RNA_alt_reads")
	for x in snps:
		#skip non-SNP calls
		if (x[algorithm] != "MuTect"):
			x.append("NOT_TESTED")
			x.append("NOT_TESTED")
			x.append("NA")
			x.append("NA")
			continue
		#get the RNAseq stats for each mutation and append them on
		(Covered, RNA_ref, RNA_alt, Detected) = getRNAcoverage(rnaFilename,
		x[contig], x[position], x[ref_allele], x[alt_allele])
		x.append(Covered)
		x.append(Detected)
		x.append(str(RNA_ref))
		x.append(str(RNA_alt))

	#print the (more) annotated file
	print "\t".join(header)
	for line in snps:
		print "\t".join(line)

	return()


if (len(sys.argv) != 3):
	usage()
else:
	annotation(sys.argv[1], sys.argv[2])

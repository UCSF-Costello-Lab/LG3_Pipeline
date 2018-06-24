#!/usr/bin/python

####
#This script removes QC failed reads from a fastq file
#Usage: python removeQC.py file.fastq > file.noQCfail.fastq
####
import sys

def cleanQC(filename):
	file = open(filename)
	lineCounter = 4
	keep = False
	for line in file:
		line = line.rstrip("\n")
		if (lineCounter < 4):
			lineCounter += 1
		else:
			lineCounter = 1
			chastity = line.split()[1]
			if (chastity.split(":")[1] == "Y"):
				keep = False
			if (chastity.split(":")[1] == "N"):
				keep = True
		if (keep == True):
			print line
	file.close()
	return()

cleanQC(sys.argv[1])
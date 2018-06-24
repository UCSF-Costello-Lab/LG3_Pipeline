#!/usr/bin/python

####
#This script removes QC (chastity) failed reads from a fastq file
#Usage: python removeQCgz.py file.fastq.gz > file.noQCfail.fastq
#Usage: python removeQCgz.py file.fastq > file.noQCfail.fastq
#### Enhanced by Ivan @2015
####
import sys
import gzip
import os


def cleanQC(filename):
	ext = os.path.splitext(filename)[-1].lower()
	if ext == '.gz':
		file = gzip.open(filename,'rb')
	elif ext == '.fastq':
		file = open(filename)
	else:
		 sys.exit('ERROR: Unknown extension: ' + ext) 

	lineCounter = 4
	cntY = 0
	cntN = 0
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
				cntY += 1
			if (chastity.split(":")[1] == "N"):
				keep = True
				cntN += 1
		if (keep == True):
			print line 
	file.close()
	sys.stderr.write("Removed failed reads: " + str(cntY) + '\n')
	sys.stderr.write("Keeping passed reads: " + str(cntN) + '\n')
	sys.stderr.flush()
	return()

cleanQC(sys.argv[1])


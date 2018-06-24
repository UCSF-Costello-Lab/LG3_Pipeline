#!/usr/bin/python

####
#Converts a Mutect WIG file to callable space in BED3 format
####
import sys

def usage():
	print "Usage:"
	print "python mutect_wig_to_bed.py example.wig > example.bed "
	sys.exit()

def main(wig):
	position, length = 0, 0
	x = open(wig)
	for line in x:
		position +=1
		line = line.split()
		if (line[0] == "1"):
			if (length == 0):
				start = position-1
			length +=1
			continue
		if (line[0] == "0") and (length > 0):
			print "%s\t%i\t%i" % (contig, start, start+length)
			length = 0
			continue
		if (line[0] == "fixedStep"):
			if (length > 0):
				print "%s\t%i\t%i" % (contig, start, start+length)
			contig = line[1].split("=")[1]
			position = int(line[2].split("=")[1])-1
			length = 0
			continue
	if (length > 0):
		print "%s\t%i\t%i" % (contig, start, start+length)
	x.close()
	return()

if (len(sys.argv) != 2):
	usage()
else:
	main(sys.argv[1])
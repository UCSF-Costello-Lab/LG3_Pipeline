#!/usr/bin/env python
from pykent.common.Sanity import errAbort, canBeInt, canBeNum, roughlyEqual
from pykent.common.DNAUtil import isDNA

SomaticIndelRequiredColumns = '#CHROM POS ID REF ALT QUAL FILTER INFO'
SomaticIndelNumRequiredColumns = len(SomaticIndelRequiredColumns.split(' '))
SomaticIndelAlgorithm = "SomaticIndelDetector"
NA = "NA"

class SomaticIndelLine:

	def __init__(self, line, tumorName, normalName, indelAnnotationFilters):
		''' Initialize a SomaticIndelLine '''
		if line.endswith('\n'):
			line = line[:-1]
		line = line.split('\t')
		if len(line) < SomaticIndelNumRequiredColumns:
			errAbort("Improperly formatted .vcf line: %s" % " ".join(line))
		self.contig = line[0]
		self.position = int(line[1])
		self.id = line[2]
		self.ref_allele = line[3]
		self.alt_allele = line[4]
		self.tumor_name = tumorName
		self.normal_name = normalName
		self.quality = line[5]
		self.filter = line[6]
		self.info = line[7]
		self.score = NA
		self.power = NA
		self.tumor_power = NA
		self.normal_power = NA
		self.improper_pairs = NA
		self.addlInfo = None
		self.algo = SomaticIndelAlgorithm

		if len(line) > SomaticIndelNumRequiredColumns:
			if len(line) != SomaticIndelNumRequiredColumns+3:
				errAbort("Do not know how to handle non-3-extra-column .vcf files.")
			dataCols = line[8].split(':')
			firstData = line[9].split(':')
			secondData = line[10].split(':')
			assert len(dataCols) == len(firstData)
			assert len(dataCols) == len(secondData)

			self.addlInfo = {"tumor":{}, "normal":{}, "cols":dataCols}
			for idx, col in enumerate(dataCols):
				self.addlInfo["tumor"][col] = firstData[idx]
				self.addlInfo["normal"][col] = secondData[idx]

		self.validateSomaticIndelLine()
		self.convertToAnnovar()
		self.makeOurJudgment(indelAnnotationFilters)


	def validateSomaticIndelLine(self):
		''' Make sure all SomaticIndel fields make sense '''
		if self.position < 0:
			errAbort("Position must be non-negative: %s" % self.__str__())
		if not isDNA(self.ref_allele):
			errAbort("Ref allele must be DNA: %s" % self.__str__()) 
		if not isDNA(self.alt_allele):
			errAbort("Alt allele must be DNA: %s" % self.__str__())

	def convertToAnnovar(self):
		''' Convert reference and alternate allele and position to type of position that AnnoVar uses '''
		if len(self.ref_allele) > len(self.alt_allele): # Deletion
			if (len(self.alt_allele) != 1) or not self.ref_allele.startswith(self.alt_allele):
				errAbort("Deletions expected to be formatted in a different way: %s, %s" % (self.ref_allele, self.alt_allele))
			self.position += len(self.alt_allele)
			self.alt_allele = '-'
			self.ref_allele = self.ref_allele.replace(self.alt_allele, '', 1) # Replace the first instance with nothing
		elif len(self.ref_allele) < len(self.alt_allele): # Insertion
			if (len(self.ref_allele) != 1) or not self.alt_allele.startswith(self.ref_allele):
				errAbort("Insertions expected to be formatted in a different way: %s, %s" % (self.ref_allele, self.alt_allele))
			self.ref_allele = '-'
			self.alt_allele = self.alt_allele.replace(self.ref_allele, '', 1) # Replace the first instance of this with nothing
		else:
			errAbort("For indels, either ref_allele or alt_allele must be larger: %s" % self.__str__())
			

	def endPosition(self):
		''' Return the end position of the alteration '''
		if self.ref_allele == '-':
			# Is an insertion
			return self.position
		elif self.alt_allele == '-':
			# Is a deletion
			return self.position + len(self.ref_allele) - 1 # One-based position system
		else:
			errAbort("For indels, either ref_allele or alt_allele must be '-': %s" % self.__str__())

	def getKnownVariantStatus(self):
		''' Return a string representing the known variant status of the call '''
		if self.id != '.': # Is a known indel
			return "SI_KNOWN_INDEL"
		if self.filter == "Mask": # Filtered indel (GATK, see MutDet script)
			return "SI_FILTERED_INDEL"
		return "NOVEL"

	def makeOurJudgment(self, indelFilters):
		''' Populate our call whether to keep or omit this mutation '''
		self.ourJudgment = "yes"
		judgmentReasons = []
		if self.homopolymerContext() > indelFilters['maxHomopolymerRuns']:
			self.ourJudgment = "no"
			judgmentReasons.append("TOO_LONG_HOMOPOLYMER_RUN")

		self.ourJudgmentReasons = ",".join(judgmentReasons)

	def shouldBeKept(self, indelRemovalFilters):
		''' Return True iff we should report this in our output '''
		if self.addlInfo != None:
			if (self.t_genotype() in ('./.', '.|.', '0/0', '0|0')) or (self.n_genotype() in ('./.', '.|.', '0/0', '0|0')):
				# A call cannot be made at the locus (see http://www.1000genomes.org/node/101) for either the tumor or normal
				# or there is no coverage
				return False
			if self.t_ref_count() + self.t_alt_count() < indelRemovalFilters['minTumorReads']:
				return False
			if self.t_alt_count() < indelRemovalFilters['minTumorAltReads']:
				return False
			if self.t_var_freq() < indelRemovalFilters['minTumorVarFreq']:
				return False
			if self.n_ref_count() + self.n_alt_count() < indelRemovalFilters['minNormalReads']:
				return False
			if self.n_alt_count() > indelRemovalFilters['maxNormalAltReads']:
				return False
			if self.n_var_freq() > indelRemovalFilters['maxNormalVarFreq']:
				return False
			if self.t_alt_mismatch_avg() > indelRemovalFilters['maxAvgTumorAltMismatch']:
				return False
			if self.t_ref_mismatch_avg() > indelRemovalFilters['maxAvgTumorRefMismatch']:
				return False
			if self.n_alt_mismatch_avg() > indelRemovalFilters['maxAvgNormalAltMismatch']:
				return False
			if self.n_ref_mismatch_avg() > indelRemovalFilters['maxAvgNormalRefMismatch']:
				return False
			if self.t_alt_basequal_nqs() < indelRemovalFilters['minAvgTumorAltBaseQualInNQS']:
				return False
			if self.t_ref_basequal_nqs() < indelRemovalFilters['minAvgTumorRefBaseQualInNQS']:
				return False
			if self.n_alt_basequal_nqs() < indelRemovalFilters['minAvgNormalAltBaseQualInNQS']:
				return False
			if self.n_ref_basequal_nqs() < indelRemovalFilters['minAvgNormalRefBaseQualInNQS']:
				return False
			if self.t_alt_mismatch_avg_nqs() > indelRemovalFilters['maxAvgTumorAltMismatchInNQS']:
				return False
			if self.t_ref_mismatch_avg_nqs() > indelRemovalFilters['maxAvgTumorRefMismatchInNQS']:
				return False
			if self.n_alt_mismatch_avg_nqs() > indelRemovalFilters['maxAvgNormalAltMismatchInNQS']:
				return False
			if self.n_ref_mismatch_avg_nqs() > indelRemovalFilters['maxAvgNormalRefMismatchInNQS']:
				return False
			if self.n_var_freq() >= self.t_var_freq():
				return False
		return True

	def t_genotype(self):
		''' Return the tumor genotype '''
		if self.addlInfo == None:
			return None
		return self.addlInfo["tumor"]["GT"]

	def t_ref_count(self):
		''' Return the count of tumor reference allele reads '''
		if self.addlInfo == None:
			return None
		return self.t_total_depth() - int(self.addlInfo["tumor"]["AD"].split(',')[1])

	def t_alt_count(self):
		''' Return the count of tumor alternate allele reads '''
		if self.addlInfo == None:
			return None
		return int(self.addlInfo["tumor"]["AD"].split(',')[0])

	def t_total_depth(self):
		''' Return the count of tumor total coverage at the site '''
		if self.addlInfo == None:
			return None
		return int(self.addlInfo["tumor"]["DP"])

	def t_var_freq(self):
		''' Return the tumor variant frequency '''
		if self.addlInfo == None:
			return None
		elif (self.t_ref_count() + self.t_alt_count()) == 0:
			return 0
		return self.t_alt_count() * 1./self.t_total_depth()

	
	def n_genotype(self):
		''' Return the normal genotype '''
		if self.addlInfo == None:
			return None
		return self.addlInfo["normal"]["GT"]

	def n_ref_count(self):
		''' Return the count of normal reference allele reads '''
		if self.addlInfo == None:
			return None
		return self.n_total_depth() - int(self.addlInfo["normal"]["AD"].split(',')[1])

	def n_alt_count(self):
		''' Return the count of normal alternate allele reads '''
		if self.addlInfo == None:
			return None
		return int(self.addlInfo["normal"]["AD"].split(',')[0])

	def n_total_depth(self):
		''' Return the count of normal total coverage at the site '''
		if self.addlInfo == None:
			return None
		return int(self.addlInfo["normal"]["DP"])

	def n_var_freq(self):
		''' Return the normal variant frequency '''
		if self.addlInfo == None:
			return None
		elif (self.n_ref_count() + self.n_alt_count()) == 0:
			return 0
		return self.n_alt_count() * 1./self.n_total_depth()

	def t_alt_mismatch_avg(self):
		''' Return the average number of mismatched base pairs in tumor reads supporting the alternate allele '''
		if self.addlInfo == None:
			return None
		return float(self.addlInfo["tumor"]["MM"].split(',')[0])

	def t_ref_mismatch_avg(self):
		''' Return the average number of mismatched base pairs in tumor reads supporting the reference allele '''
		if self.addlInfo == None:
			return None
		return float(self.addlInfo["tumor"]["MM"].split(',')[1])

	def n_alt_mismatch_avg(self):
		''' Return the average number of mismatched base pairs in normal reads supporting the alternate allele '''
		if self.addlInfo == None:
			return None
		return float(self.addlInfo["normal"]["MM"].split(',')[0])

	def n_ref_mismatch_avg(self):
		''' Return the average number of mismatched base pairs in normal reads supporting the reference allele '''
		if self.addlInfo == None:
			return None
		return float(self.addlInfo["normal"]["MM"].split(',')[1])

	def t_alt_basequal_nqs(self):
		''' Return the average base quality in the NQS window in tumor reads supporting the alternate allele '''
		if self.addlInfo == None:
			return None
		return float(self.addlInfo["tumor"]["NQSBQ"].split(',')[0])

	def t_ref_basequal_nqs(self):
		''' Return the average base quality in the NQS window in tumor reads supporting the reference allele '''
		if self.addlInfo == None:
			return None
		return float(self.addlInfo["tumor"]["NQSBQ"].split(',')[1])

	def n_alt_basequal_nqs(self):
		''' Return the average base quality in the NQS window in normal reads supporting the alternate allele '''
		if self.addlInfo == None:
			return None
		return float(self.addlInfo["normal"]["NQSBQ"].split(',')[0])

	def n_ref_basequal_nqs(self):
		''' Return the average base quality in the NQS window in normal reads supporting the reference allele '''
		if self.addlInfo == None:
			return None
		return float(self.addlInfo["normal"]["NQSBQ"].split(',')[1])

	def t_alt_mismatch_avg_nqs(self):
		''' Return the average number of mismatches in the NQS window in tumor reads supporting the alternate allele '''
		if self.addlInfo == None:
			return None
		return float(self.addlInfo["tumor"]["NQSMM"].split(',')[0])

	def t_ref_mismatch_avg_nqs(self):
		''' Return the average number of mismatches in the NQS window in tumor reads supporting the reference allele '''
		if self.addlInfo == None:
			return None
		return float(self.addlInfo["tumor"]["NQSMM"].split(',')[1])

	def n_alt_mismatch_avg_nqs(self):
		''' Return the average number of mismatches in the NQS window in normal reads supporting the alternate allele '''
		if self.addlInfo == None:
			return None
		return float(self.addlInfo["normal"]["NQSMM"].split(',')[0])

	def n_ref_mismatch_avg_nqs(self):
		''' Return the average number of mismatches in the NQS window in normal reads supporting the reference allele '''
		if self.addlInfo == None:
			return None
		return float(self.addlInfo["normal"]["NQSMM"].split(',')[1])

	def homopolymerContext(self):
		''' Return the homopolymer context (or 0 if it is not reported) '''
		homopolymerInfo = filter(lambda x:x.startswith("HRun="), self.info.split(';'))
		if len(homopolymerInfo) == 0:
			return 0
		elif len(homopolymerInfo) > 1:
			errAbort("Homopolymer information should be listed at most once: %s" % self.info)
		return int(homopolymerInfo[0].split('=')[1])

	def map_Q0_reads(self):
		''' Return the number of Q0 reads mapped here '''
		q0List = filter(lambda x:x.startswith("MQ0="), self.info.split(';'))
		if len(q0List) == 0:
			return NA
		elif len(q0List) > 1:
			errAbort("MQ0 should only be specified once in the info file: %s" % self.__str__())
		return int(q0List[0].replace("MQ0=", '', 1))

	def AnnoVarStr(self):
		''' Write out a description of this mutation that is suitable for AnnoVar parsing '''
		return "%s\t%d\t%d\t%s\t%s" % (self.contig, self.position, self.endPosition(), self.ref_allele, self.alt_allele)		


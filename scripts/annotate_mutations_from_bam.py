import sys, subprocess, os

def get_samples_from_patient(mutfile, conversionfile, patient_ID, projectname):
  ## read ID conversion file
  data = open(conversionfile).readlines()
  header = data[0]
  data = data[1:]

  ## parse header
  h = header.strip().split('\t')
  col_pat = h.index("patient_ID")
  col_lib = h.index("lib_ID")
  col_st = h.index("sample_type")
  #col_file = h.index("file_header")

  ## pull out patient specific info
  data_pat = filter(lambda x:x.strip().split('\t')[col_pat] == patient_ID, data)
  print data_pat

  ## determine where files are stored
  testID = data_pat[0].strip().split('\t')[col_lib]
  if "norm" in patient_ID:
    patient_ID_folder = patient_ID.split("norm")[0]
  else:
    patient_ID_folder = patient_ID
  fullpath = "/costellolab/data1/jocostello/" + projectname + "/exomes_recal/" + patient_ID_folder + "/"
  #fileheader = ".bwa.realigned.rmDups"
  fileheader = ".bwa.realigned.rmDups.recal"
  if not os.path.isfile(fullpath + testID + fileheader + ".bam"):
    fullpath = fullpath.replace("data", "home", 1)
    if not os.path.isfile(fullpath + testID + fileheader + ".bam"):
      print "ERROR: files can not be found"
      print fullpath + testID + fileheader + ".bam"
      sys.exit(1)

  ## for each sample, call annotate_mutations_from_bam
  sn=0
  print "Init mutfile " + mutfile
  for line in data_pat:
    sn+=1
    sample = line.strip().split('\t')[col_st]
    print str(sn) + " Sample " + sample
    bamfile = fullpath + line.strip().split('\t')[col_lib] + fileheader + ".bam"
    print bamfile
    print "Input mutfile " + mutfile
    #annotate_mutations_from_bam(mutfile, bamfile, sample)
    annotate_mutations_from_bam(mutfile, bamfile, sample, sn)
    mutfile = mutfile.split('.txt')[0] + '.%dQ.txt'%(sn)
    #mutfile = mutfile.split('.txt')[0] + '.%sQ.txt'%(sample)
    print "Output mutfile " + mutfile

  ## rename final mutfile
  print "rename final mutfile:"
  print 'mv ' + mutfile + " " + patient_ID + ".snvs.anno.txt"
  command = ['mv', mutfile, patient_ID + ".snvs.anno.txt"]
  task=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  (stdout,stderr)=task.communicate()


#def annotate_mutations_from_bam(mutfile, bamfile, sample):
def annotate_mutations_from_bam(mutfile, bamfile, sample, sn):
  ## read mutation data
  data = open(mutfile).readlines()
  header = data[0]
  data = data[1:]

  ## parse header
  h = header.strip().split('\t')
  chr = h.index('contig')
  pos = h.index('position')
  ref = h.index('ref_allele')
  alt = h.index('alt_allele')
  alg = h.index('algorithm')

  ## update header
  h.append('%s_ref_reads'%(sample))#; r = h.index('%s_ref_reads'%(sample))
  h.append('%s_alt_reads'%(sample))#; a = h.index('%s_alt_reads'%(sample))
  h.append('%s_ref_Q20reads'%(sample))#; rQ = h.index('%s_Q20ref_reads'%(sample))
  h.append('%s_alt_Q20reads'%(sample))#; aQ = h.index('%s_Q20alt_reads'%(sample))

  ## prepare outfile
  print "Output annofile: " + mutfile.split('.txt')[0] + '.%dQ.txt'%(sn)
  annofile = open(mutfile.split('.txt')[0] + '.%dQ.txt'%(sn), 'w')
  annofile.write('\t'.join(h) + '\n')

  tmp_file_header = mutfile.split('.txt')[0] + '_' + sample

  ## generate bedfile for this patient
  bedfile = tmp_file_header+ '.bed'
  print '  making bedfile ' + bedfile
  outfile = open(bedfile, 'w')
  for m in data:
    split = m.split('\t')
    outfile.write(split[chr] + '\t' + split[pos] + '\t' + str(int(split[pos])+1) + '\n')
  outfile.close()
  
  command = ['ls' , '-l', bedfile]  
  task=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  (stdout,stderr)=task.communicate()



  ## generate mpileup for this patient
  mpilefile = tmp_file_header + '.pileup'
  print '  making pileup ' + mpilefile
  command = ['/home/jocostello/tools/samtools-0.1.12a/samtools', 'pileup', '-l', bedfile, bamfile]
  task=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  (stdout,stderr)=task.communicate()
  outfile = open(mpilefile, 'w')
  outfile.write(stdout)
  outfile.close()

  command = ['ls' , '-l', mpilefile]  
  task=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  (stdout,stderr)=task.communicate()


  print '  annotating coverage'
  for line in data:
    l = line.strip('\n').split('\t')
    if l[alg] != "MuTect": (countR, countA, countQR, countQA) = ("NA", "NA", "NA", "NA")
    else: (countR, countA, countQR, countQA) = getNormalCoverage(mpilefile, l[chr], l[pos], l[ref], l[alt], 20)
    l.append(str(countR))
    l.append(str(countA))
    l.append(str(countQR))
    l.append(str(countQA))
    annofile.write('\t'.join(l) + '\n')

  ## clean up
  print '  cleaning up'
  for f in [bedfile, mpilefile]:
    command = ['rm' , '-f', f]
    task=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    (stdout,stderr)=task.communicate()

  annofile.close()


def getNormalCoverage(rnaFilename, contig, position, ref_allele, alt_allele, qualityCutoff = 0):
  """Parses a mpileup file and returns the normal coverage stats"""
  ref_count = 0
  alt_count = 0
  ref_Qcount = 0
  alt_Qcount = 0
  rnaString = ""
  skip = 0

  rna = open(rnaFilename)

  for line in rna:
    line = line.rstrip("\n")
    line = line.split("\t")
    if (line[0] == contig):
      if (line[1] == position):
        rnaString = line[4].upper()
        qualityString = line[5]
        break
  rna.close()

  #print rnaString, qualityString

  #process the reads from the pileup
  qIndex = 0
  for p in xrange(0,len(rnaString)):
    base = rnaString[p]
    if (skip > 0):
      skip -= 1
      continue
    if (base == "^"):  # this marks the beginning of a read, the next position is the read mapping quality
      skip = 1
      continue
    if (base == "+" or base == "-"):  ## indicates that what follows is an indel
      continue
    if (base.isdigit() == True):  ## indicates length of an indel, the following positions are the indel sequence
      if (rnaString[p+1].isdigit()): skip = int(rnaString[p:p+2])+1
      else: skip = int(base)
      #print skip
      continue
    if (base == "$"):  ## this marks the end of the read
      continue
    if (base == "N"): ## not sure about this, but empirically this is a necessary step
      continue
    ## none of the above have an associated value in the quality string, so only increment qIndex after this
    if base == ref_allele:
      ref_count += 1
      if(ord(qualityString[qIndex])-33 >= qualityCutoff):
        ref_Qcount +=1
    elif base == alt_allele:
      alt_count += 1
      if(ord(qualityString[qIndex])-33 >= qualityCutoff):
        alt_Qcount +=1
    ## increment qIndex
    qIndex +=1

  return (ref_count, alt_count, ref_Qcount, alt_Qcount)



if __name__=="__main__":
  if len(sys.argv) != 5:
    print 'usage: %s mutationfile.txt patient_ID_conversions.txt patient_ID projectname' %(sys.argv[0])
    sys.exit(1)

  get_samples_from_patient(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4].strip())


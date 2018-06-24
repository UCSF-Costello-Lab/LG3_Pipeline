import sys

def usage():
  print "python %s mutations_file patient_ID output_file" %(sys.argv[0])
  print "  mutations_file = includes all mutations in all samples to be converted to tablular form"

def mutation_overlaps(mutations_file, patient_of_interest, output_file):
  ## read in mutations file, pull out header
  rawdata = open(mutations_file).readlines()
  header = rawdata[0]
  h = header.strip().split('\t')
  rawdata = rawdata[1:]

  ## get column numbers from header
  if "gene" in h: gene = h.index("gene")
  elif "X.gene" in h: gene = h.index("X.gene"); h[gene]="gene";
  else: gene=h.index("#gene")
  chr = h.index('contig')
  pos = h.index('position')
  ref = h.index('ref_allele')
  alt = h.index('alt_allele')
  nuc = h.index('nucleotide')
  prot = h.index('protein')
  context = h.index('context')
  type = h.index('type')
  pat = h.index('patient_ID')
  tum = h.index('sample_type')
  n_ref = h.index('n_ref_count')
  n_alt = h.index('n_alt_count')
  alg = h.index('algorithm')
  cos_freq = h.index('COSMIC_mutation_frequency')
  cos_codon = h.index('COSMIC_mutation_within_3bp_frequency')
  cos_gene = h.index('COSMIC_gene_frequency')
  kin = h.index('KINASE.')
  sang = h.index('SangerCancerGeneCensus.')
  bam_anno_cols = [i for i,j in enumerate(h) if "_ref_reads" in j or "_alt_reads" in j or "_Q20reads" in j]

  ## keep only patient of interest
  data = []
  for line in rawdata:
    if line.split('\t')[pat] == patient_of_interest:
      data.append(line)

  ## make two empty dictionaries: one will hold all mutations, the other all A0numbers
  muts = dict()  ## muts[chr:pos:ref:alt] = list of length len(A0s), each entry states whether mutation was called by MuTect in that sample (True) or not (False)
  A0s = dict()    ## A0s[A0num] = integer, counting up from zero
  A0count = 0
  meta = dict()  ## like muts dictionary, but instead of a list of T/F, will save the columns of interest for each mutation to be included in the final output file
  meta_cols = [gene, chr, pos, ref, alt, nuc, prot, context, type, alg, n_ref, n_alt, cos_freq, cos_codon, cos_gene, kin, sang] + bam_anno_cols  ## the columns to save in meta{}

  ## first fill in A0s dictionary
  list_of_A0s = []
  for line in data:
    l = line.strip().split('\t')
    if l[tum] not in A0s:
      A0s[l[tum]] = A0count
      A0count += 1
      list_of_A0s.append(l[tum])
  numA0s = len(A0s)

  print A0s

  ## then fill in muts/meta dictionaries
  for line in data:
    l = line.strip().split('\t')
    # check mutation
    unique = "%s:%s:%s:%s" % (l[chr], l[pos], l[ref], l[alt])
    if unique not in muts:
      muts[unique] = [False for n in xrange(numA0s)]
      meta[unique] = [l[m] for m in meta_cols]
    muts[unique][A0s[l[tum]]] = True

  #print muts
  #print meta

  ## make new table of data
  newdata = []
  newheader = [h[m] for m in meta_cols] + [a + '_called' for a in list_of_A0s] + ['samples_called']
  print newheader
  print len(newheader)
  newdata.append(newheader)

  ## go through muts dictionary
  ##  create a string of which samples the mutation was called in
  ##  make a list of meta data, A0numbers/mutation calls and the string of samples
  ##  append to newdata
  for unique,value in muts.iteritems():
    samples = []
    for A0,p in A0s.iteritems():
      if muts[unique][p] == True: samples.append(A0)
    samples.sort()
    newline = meta[unique] + [str(u) for u in muts[unique]] + [",".join(samples)]
    newdata.append(newline)
    
  ## output to file
  out = open(output_file, 'w')
  for line in newdata:
    out.write('\t'.join(line)+'\n')
  out.close()


if __name__ == "__main__":
  if len(sys.argv) != 4:
    usage()
    sys.exit(1)

  mutation_overlaps(sys.argv[1], sys.argv[2], sys.argv[3].strip())




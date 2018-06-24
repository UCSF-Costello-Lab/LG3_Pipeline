import sys, subprocess

def libID_to_patientID(mutfile, patient_ID, outfile, conversionfile):
  ## read ID conversion file
  convdata = open(conversionfile).readlines()
  convheader = convdata[0]
  convdata = convdata[1:]

  ## parse header
  convH = convheader.strip().split('\t')
  col_pat = convH.index("patient_ID")
  col_lib = convH.index("lib_ID")
  col_st = convH.index("sample_type")

  ## process conversion file into dictionary
  convpat = filter(lambda x:x.strip().split('\t')[col_pat] == patient_ID, convdata)
  conv_dict = dict()
  for line in convpat:
    s = line.strip().split('\t')
    conv_dict[s[col_lib]] = s

  ## read mutation data
  data = open(mutfile).readlines()
  header = data[0]
  data = data[1:]

  ## parse and update header
  h = header.strip().split('\t')
  col1 = h.index('tumor_name')
  col2 = h.index('normal_name')
  h[col1] = 'patient_ID'
  h[col2] = 'sample_type'

  ## prepare outfile
  updated = open(outfile, 'w')
  updated.write('\t'.join(h) + '\n')

  ## loop through mutations file and change annotations
  for line in data:
    l = line.rstrip().split('\t')

    # if mutation is already in patient_ID format (ie, indels), continue
    if l[col2][:7] == "Patient":
      continue
    else:
      # confirm that tumor & normal both refer to the same patient
      p1 = conv_dict[l[col1]][col_pat]
      #p2 = p1
      p2 = conv_dict[l[col2]][col_pat]
      if p1 != p2:
        print "inconsistent patient: %s" %(l)
        print p1, p2
	continue
      # update to patient_ID and sample_type values
      l[col2] = conv_dict[l[col1]][col_st]
      l[col1] = conv_dict[l[col1]][col_pat]

    # write to file
    updated.write('\t'.join(l) + '\n')

  updated.close()
  




if __name__=="__main__":
  if len(sys.argv) != 5:
    print 'usage: %s mutationfile patient outfile conversiontable' %(sys.argv[0])
    sys.exit(1)
  libID_to_patientID(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4].strip())


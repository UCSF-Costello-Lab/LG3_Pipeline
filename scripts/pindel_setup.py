import sys, subprocess, os.path, os

def pindel_setup(patient_ID, projectname, patIDs):
  ## read ID conversion file
  data = open(patIDs).readlines()
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

  ## determine where files are stored
  #if col_file != "":
  #  fileheader = col_file
  #  print fileheader
  #else:

  ### After Recal2 use this:
  #fileheader = ".bwa.realigned.rmDups"

  ### After Recal use this:
  fileheader = ".bwa.realigned.rmDups.recal"
  #fileheader = "-trim.bwa.realigned.rmDups.recal"

  testID = data_pat[0].strip().split('\t')[col_lib]
  if "norm" in patient_ID:
    patient_ID_folder = patient_ID.split("norm")[0]
  else:
    patient_ID_folder = patient_ID
  fullpath = os.environ["LG3_INPUT_ROOT"] + "/" + projectname + "/exomes_recal/" + patient_ID_folder + "/"
  if not os.path.isfile(fullpath + testID + fileheader + ".insert_size_metrics"):
    fullpath = fullpath.replace("data", "home", 1)
    if not os.path.isfile(fullpath + testID + fileheader + ".insert_size_metrics"):
      print "ERROR: files can not be found"
      print fullpath + testID + fileheader + ".insert_size_metrics"
      sys.exit(1)

  ## prepare outfile
  cfg = open(patient_ID + '.pindel.cfg', 'w')

  ## for each line in setup, open *insertsizemetrics, save median_insert_size, write to outfile
  for line in data_pat:
    l = line.strip().split('\t')
    sample_type = l[col_st]
    lib_ID = l[col_lib]

    print sample_type
    #if len(l) > col_file and l[col_file] != "":
     # fileheader = l[col_file]
    #elif patient_ID == "Patient126" and  sample_type != "Normal":
     # fullpath = os.environ["LG3_INPUT_ROOT"] + "/exomes/" + lib_ID + "/"
      #fileheader = ".merged"
    #else:
     # fileheader = ".bwa.realigned.rmDups.recal"

    ism = open(fullpath + lib_ID + fileheader + ".insert_size_metrics").readlines()
    foundit = False
    for i in ism:
      if foundit == True: med = i.split('\t')[0]; break
      if i.split('\t')[0] == "MEDIAN_INSERT_SIZE": foundit = True
    print sample_type, lib_ID, med


    #if patient_ID == "Patient126" and  sample_type != "Normal":
    if fileheader == ".merged":
      cfg.write(fullpath + lib_ID + fileheader + ".sorted.bam" + "\t" + med + "\t" + patient_ID + "_" + sample_type + "\n")
    else:
      cfg.write(fullpath + lib_ID + fileheader + ".bam" + "\t" + med + "\t" + patient_ID + "_" + sample_type + "\n")

  cfg.close()
    


if __name__=="__main__":
  if len(sys.argv) != 4:
    print 'usage: %s patient_ID projectname patient_ID_conversions' %(sys.argv[0])
    sys.exit(1)

  pindel_setup(sys.argv[1], sys.argv[2], sys.argv[3].strip())


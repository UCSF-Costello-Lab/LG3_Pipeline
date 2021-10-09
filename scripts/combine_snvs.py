import sys, subprocess, os, glob

def combine_snvs(patient_ID, projectname, conversionfile, outfile):
  ## read ID conversion file
  data = open(conversionfile).readlines()
  header = data[0]
  data = data[1:]

  ## parse header
  h = header.strip().split('\t')
  col_pat = h.index("patient_ID")
  col_lib = h.index("lib_ID")
  col_st = h.index("sample_type")

  ## pull out patient specific info
  tumors = filter(lambda x:x.strip().split('\t')[col_pat] == patient_ID and x.strip().split('\t')[col_st] != "Normal", data)
  normal = filter(lambda x:x.strip().split('\t')[col_pat] == patient_ID and x.strip().split('\t')[col_st] == "Normal", data)
  print normal
  print tumors
  if len(normal) != 1: raise Exception("ERROR: too many normals")
  normalA0 = normal[0].strip().split('\t')[col_lib]
  #normalA0="NA"

  ## find all mutation files for this patient
  loc = os.environ["LG3_INPUT_ROOT"] + "/" + projectname + "/mutations/" + patient_ID + "_mutect/"
  allRNA = glob.glob(loc + patient_ID + ".NOR-" + normalA0 + "__*.annotated.withRNA.mutations")
  print allRNA
  allnot = glob.glob(loc + patient_ID + ".NOR-" + normalA0 + "__*.annotated.mutations")
  print allnot

  ## 
  #if len(allRNA) == 0: tomerge = allnot ## including this removes the check for each sample
  if len(allRNA) == 0 and len(allnot) == 0: raise Exception("ERROR: no files found for this patient")
  else:
    tomerge = [] 
    for t in tumors:
      tA0 = t.strip().split('\t')[col_lib]
      print tA0
      ## if A0 exists in allRNA, use that file
      q1 = [f for f in allRNA if "-"+tA0+"." in f]
      if len(q1) == 1: tomerge.append(q1[0])
      elif len(q1) > 1: print "ERROR: multiple files for: " + tA0, q1; continue;
      ## else, use file in allnot
      elif len(q1) == 0:
        q2 = [f for f in allnot if "-"+tA0+"." in f]
	if len(q2) == 1: tomerge.append(q2[0])
	elif len(q2) > 1: print "ERROR: multiple files for: " + tA0, q2; continue;
        ## else file doesn't exist, throw ERROR
	elif len(q2) == 0: print "ERROR: no files found for: " + tA0; continue;
      print tomerge[-1]

      
  print tomerge

  ## call R code to merge these files
  command = [os.environ["RSCRIPT"], os.environ["LG3_HOME"] + "/scripts/combine_snvs.R"] + tomerge + [outfile]
  print command
  task=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  (stdout,stderr)=task.communicate()


if __name__=="__main__":
  if len(sys.argv) != 5:
    print 'usage: %s patient_ID project_name patient_ID_conversions.tsv outfile' %(sys.argv[0])
    sys.exit(1)

  combine_snvs(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4].strip())


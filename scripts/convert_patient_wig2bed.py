import sys, subprocess, os, glob

def convert_patient_wig2bed(patient_ID, projectname, conversionfile):
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
  if len(normal) != 1: print "ERROR: too many normals"
  normalA0 = normal[0].strip().split('\t')[col_lib]

  ## find all mutation files for this patient
  loc = "/costellolab/data1/jocostello/" + projectname + "/mutations/" + patient_ID + "_mutect/"
  print loc
  #loc = "/home/jocostello/" + projectname + "/exomes/Mutations2/"
  allnot = glob.glob(loc + "NOR-" + normalA0 + "__*.snvs.coverage.mutect.wig")
  print allnot
  if len(allnot) == 0: print "ERROR: no files found for this patient: "
  else:
    allbed = []
    for t in tumors:
      tA0 = t.strip().split('\t')[col_lib]
      print tA0
      q2 = [f for f in allnot if "-"+tA0+"." in f]
      if len(q2) == 1: 
        command = ["python", "/home/jocostello/shared/LG3_Pipeline/scripts/mutect_wig_to_bed.py", q2[0] ]
        print command
        bedfile = q2[0].split(".wig")[0] + ".bed"
        allbed.append(bedfile)
	task=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
	(stdout,stderr)=task.communicate()
	outfile = open(bedfile, "w")
	outfile.write(stdout)
	outfile.close()
      elif len(q2) > 1: print "ERROR: multiple files for: " + tA0, q2; continue;
      ## else file doesn't exist, throw ERROR
      elif len(q2) == 0: print "ERROR: no files found for: " + tA0; continue;

  ## intersect all bed files
  if len(allbed) == 1:
    command = ["cp"] + allbed + [loc + patient_ID + ".mutect.coverage.intersect.bed"]
    print command
    task=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    (stdout,stderr)=task.communicate()
  else:
    command = ["/opt/BEDTools/BEDTools-2.16.2/bin/multiIntersectBed", "-i"] + allbed
    print command
    task=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    (stdout,stderr)=task.communicate()
    outfile = open(loc + patient_ID + ".mutect.coverage.intersect.bed", "w")
    outfile.write(stdout)
    outfile.close()


if __name__=="__main__":
  if len(sys.argv) != 4:
    print 'usage: %s patient_ID project_name patient_ID_conversions.txt' %(sys.argv[0])
    sys.exit(1)

  convert_patient_wig2bed(sys.argv[1], sys.argv[2], sys.argv[3].strip())


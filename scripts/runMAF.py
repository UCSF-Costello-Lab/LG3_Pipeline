import sys, os, subprocess

def runMAF(patient_ID, projectname, conversionfile):
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
  
  UGfile = os.environ["LG3_INPUT_ROOT"] + "/LG3/exomes_recal/" + patient_ID + "/germline/" + patient_ID + ".UG.snps.vcf"

  ## generate MAF file for normal
  if len(normal) != 0:
    normA0 = normal[0].split('\t')[col_lib]
    outfile = patient_ID + ".Normal.MAF.txt"
    command = ["python", os.environ["LG3_HOME"] + "/scripts/vcf_MAF_normal.py", UGfile, normA0]
    task=subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (stdout,stderr)=task.communicate()
    of = open(outfile, 'w')
    of.write(stdout)
    of.close()
  else:
    normA0 = "NA"
  
  ## generate MAF file for each tumor
  for t in tumors:
    tumA0 = t.split('\t')[col_lib]
    outfile = patient_ID + "." + t.strip().split('\t')[col_st] + ".MAF.txt"
    command = ["python", os.environ["LG3_HOME"] + "/scripts/vcf_MAF_tumor.py", UGfile, tumA0, normA0]
    task=subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (stdout,stderr)=task.communicate()
    of = open(outfile, 'w')
    of.write(stdout)
    of.close()


if __name__=="__main__":
  if len(sys.argv) != 4:
    print 'usage: %s patient_ID project_name patient_ID_conversions.tsv' %(sys.argv[0])
    sys.exit(1)

  runMAF(sys.argv[1], sys.argv[2], sys.argv[3].strip())

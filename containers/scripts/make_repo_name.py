# make a repository name from a module name and LSID
# it must satisfy ECR requirements so no ':' or upper case
import sys
lsid = sys.argv[1]
# e.g. "urn:lsid:broad.mit.edu:cancer.software.genepattern.module.analysis:00376:0.2"
name = sys.argv[2]
# e.g. "CoGaps"

protoname = name +lsid.replace("urn:lsid","",1).replace(":","_")
safe_name = protoname.lower()
print(safe_name)

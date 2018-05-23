import subprocess
import os
from io import StringIO

subprocess.call("docker ps -l | head -2 | tail -1 > line.txt", shell=True, env=os.environ)
text_file = open("line.txt", "r")
id = text_file.read().split(" ")[0]
print(id)


import subprocess
import os

os.chdir(r"c:\Temp\AndroidTV for Radxa4C+")

# Get content from git
result = subprocess.run(["git", "show", "HEAD:scripts/03a-preinstall-apps.sh"], capture_output=True)
data = result.stdout

# Remove all corruption patterns
import re
data = re.sub(rb'\[data:cache_control;base64,[^\]]*\]', b'', data)

# Write to file
with open("scripts/03a-preinstall-apps.sh", "wb") as f:
    f.write(data)

# Verify
with open("scripts/03a-preinstall-apps.sh", "rb") as f:
    check = f.read()
    
print("Size:", len(check))
print("Clean:", b"ZXBoZW1lcmFs" not in check)
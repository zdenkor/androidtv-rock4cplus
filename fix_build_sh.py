#!/usr/bin/env python3
import re

with open('/mnt/aosp-build/androidtv-rock4cplus/build.sh', 'r') as f:
    content = f.read()

# Fix 1: Add mkdir before kernel copy
old1 = 'cp -rf $KERNEL_DEBUG $OUT/kernel'
new1 = 'mkdir -p $(dirname $OUT/kernel) && cp -rf $KERNEL_DEBUG $OUT/kernel'
content = content.replace(old1, new1)

# Fix 2: Quote IS_VEHICLE variable
old2 = 'if [ $IS_VEHICLE = "true" ]; then'
new2 = 'if [ "$IS_VEHICLE" = "true" ]; then'
content = content.replace(old2, new2)

with open('/mnt/aosp-build/androidtv-rock4cplus/build.sh', 'w') as f:
    f.write(content)

print('Fixed build.sh')

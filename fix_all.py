#!/usr/bin/env python3
"""Fix ALL Python 2->3 issues in AOSP build scripts."""
import os, glob, shutil

BASE = '/mnt/aosp-build/androidtv-rock4cplus-radxa9'

# Fix all .py files in build/make/tools - change binary opens to text
for pyfile in glob.glob(os.path.join(BASE, 'build/make/tools/*.py')):
    with open(pyfile) as f:
        c = f.read()
    changed = False
    if 'open(filename, "rb")' in c:
        c = c.replace('open(filename, "rb")', 'open(filename, "r")')
        changed = True
    if 'open(output_file, "wb")' in c:
        c = c.replace('open(output_file, "wb")', 'open(output_file, "w")')
        changed = True
    if 'open(out_file, "wb")' in c:
        c = c.replace('open(out_file, "wb")', 'open(out_file, "w")')
        changed = True
    if 'open(outfn, "wb")' in c:
        c = c.replace('open(outfn, "wb")', 'open(outfn, "w")')
        changed = True
    if changed:
        with open(pyfile, 'w') as f:
            f.write(c)
        print(f'Fixed {os.path.basename(pyfile)}')

# Fix auto_generator.py tabs
path = os.path.join(BASE, 'device/rockchip/common/auto_generator.py')
with open(path) as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    stripped = line.lstrip('\t ')
    indent = len(line) - len(stripped)
    if '\t' in line[:indent] and ' ' in line[:indent]:
        space_count = line[:indent].count(' ')
        tab_count = line[:indent].count('\t')
        total = tab_count + space_count // 4
        lines[i] = '\t' * total + stripped
with open(path, 'w') as f:
    f.writelines(lines)
print('Fixed auto_generator.py tabs')

# Clear all caches
for cache in glob.glob(os.path.join(BASE, 'out/target/common/obj/all-event-log-tags*')):
    os.remove(cache)
    print(f'Cleared {cache}')
for pycache in glob.glob(os.path.join(BASE, 'build/make/tools/__pycache__')):
    shutil.rmtree(pycache)
    print(f'Cleared {pycache}')

print('DONE')

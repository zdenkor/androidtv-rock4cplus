import os
path = '/mnt/aosp-build/androidtv-rock4cplus-radxa9/device/rockchip/common/auto_generator.py'
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
print('Fixed auto_generator.py')

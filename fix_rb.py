path = '/mnt/aosp-build/androidtv-rock4cplus-radxa9/build/make/tools/event_log_tags.py'
with open(path) as f:
    c = f.read()
c = c.replace('open(filename, "rb")', 'open(filename, "r")')
with open(path, 'w') as f:
    f.write(c)
print('Fixed event_log_tags.py')

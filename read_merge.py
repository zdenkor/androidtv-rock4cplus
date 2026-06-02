with open('/mnt/aosp-build/androidtv-rock4cplus-radxa9/build/make/tools/merge-event-log-tags.py') as f:
    for i, line in enumerate(f, 1):
        if 170 <= i <= 190:
            print(f'{i}: {line}', end='')

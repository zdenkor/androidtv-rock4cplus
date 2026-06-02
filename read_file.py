with open('/mnt/aosp-build/androidtv-rock4cplus-radxa9/build/make/tools/event_log_tags.py') as f:
    for i, line in enumerate(f, 1):
        if 115 <= i <= 140:
            print(f'{i}: {line}', end='')

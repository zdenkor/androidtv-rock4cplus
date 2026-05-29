#!/usr/bin/env python3
"""
Sanitize Android.bp files under prebuilts/sdk to remove properties
that older soong may not recognize (extensions_dir, allow_incremental_platform_api,
manifest, static_libs, and target: { ... } blocks).
"""
import os
import re

ROOT = '/mnt/aosp-build/androidtv-rock4cplus/prebuilts/sdk'
if not os.path.isdir(ROOT):
    print('prebuilts/sdk not found at', ROOT)
    raise SystemExit(1)

def remove_bracket_block(content, prop_name):
    """Remove prop_name: [ ... ] blocks with proper bracket matching."""
    result = []
    i = 0
    n = len(content)
    prop_pattern = re.compile(r'\b' + re.escape(prop_name) + r'\s*:\s*\[')

    while i < n:
        match = prop_pattern.search(content, i)
        if not match:
            result.append(content[i:])
            break

        start = match.start()
        result.append(content[i:start])

        # Find the opening bracket
        bracket_pos = content.find('[', match.start())
        if bracket_pos == -1:
            result.append(content[start:])
            break

        # Find matching closing bracket
        depth = 1
        j = bracket_pos + 1
        while j < n and depth > 0:
            if content[j] == '[':
                depth += 1
            elif content[j] == ']':
                depth -= 1
            j += 1

        # Skip trailing comma and whitespace/newlines
        while j < n and content[j] in ' \t\r\n,':
            j += 1

        i = j

    return ''.join(result)

def remove_target_blocks(content):
    """Remove target: { ... } blocks with proper brace matching."""
    result = []
    i = 0
    n = len(content)
    prop_pattern = re.compile(r'\btarget\s*:\s*\{')

    while i < n:
        match = prop_pattern.search(content, i)
        if not match:
            result.append(content[i:])
            break

        start = match.start()
        result.append(content[i:start])

        # Find the opening brace
        brace_pos = content.find('{', match.start())
        if brace_pos == -1:
            result.append(content[start:])
            break

        # Find matching closing brace
        depth = 1
        j = brace_pos + 1
        while j < n and depth > 0:
            if content[j] == '{':
                depth += 1
            elif content[j] == '}':
                depth -= 1
            j += 1

        # Skip trailing comma and whitespace/newlines
        while j < n and content[j] in ' \t\r\n,':
            j += 1

        i = j

    return ''.join(result)

def remove_manifest_property(content):
    """Remove manifest: "..." or manifest: [...] properties."""
    result = []
    i = 0
    n = len(content)
    prop_pattern = re.compile(r'\bmanifest\s*:\s*')

    while i < n:
        match = prop_pattern.search(content, i)
        if not match:
            result.append(content[i:])
            break

        start = match.start()
        result.append(content[i:start])

        pos = match.end()
        if pos < n and content[pos] == '[':
            # Array form: manifest: [...]
            depth = 1
            j = pos + 1
            while j < n and depth > 0:
                if content[j] == '[':
                    depth += 1
                elif content[j] == ']':
                    depth -= 1
                j += 1
        else:
            # String or other form: find end of value
            j = pos
            in_string = False
            string_char = None
            while j < n:
                c = content[j]
                if not in_string and c in '"\'':
                    in_string = True
                    string_char = c
                elif in_string and c == string_char:
                    in_string = False
                    string_char = None
                elif not in_string and c in ',\n':
                    break
                j += 1

        # Skip trailing comma and whitespace/newlines
        while j < n and content[j] in ' \t\r\n,':
            j += 1

        i = j

    return ''.join(result)

def remove_select_blocks(content):
    """Remove select(...) blocks with proper parenthesis matching."""
    result = []
    i = 0
    n = len(content)
    prop_pattern = re.compile(r'\bselect\s*\(')

    while i < n:
        match = prop_pattern.search(content, i)
        if not match:
            result.append(content[i:])
            break

        start = match.start()
        result.append(content[i:start])

        # Find the opening parenthesis
        paren_pos = content.find('(', match.start())
        if paren_pos == -1:
            result.append(content[start:])
            break

        # Find matching closing parenthesis
        depth = 1
        j = paren_pos + 1
        while j < n and depth > 0:
            if content[j] == '(':
                depth += 1
            elif content[j] == ')':
                depth -= 1
            j += 1

        # Skip trailing comma and whitespace/newlines
        while j < n and content[j] in ' \t\r\n,':
            j += 1

        i = j

    return ''.join(result)

def remove_enabled_select(content):
    """Remove enabled: select(...) blocks."""
    result = []
    i = 0
    n = len(content)
    prop_pattern = re.compile(r'\benabled\s*:\s*select\s*\(')

    while i < n:
        match = prop_pattern.search(content, i)
        if not match:
            result.append(content[i:])
            break

        start = match.start()
        result.append(content[i:start])

        # Find the opening parenthesis
        paren_pos = content.find('(', match.start())
        if paren_pos == -1:
            result.append(content[start:])
            break

        # Find matching closing parenthesis
        depth = 1
        j = paren_pos + 1
        while j < n and depth > 0:
            if content[j] == '(':
                depth += 1
            elif content[j] == ')':
                depth -= 1
            j += 1

        # Skip trailing comma and whitespace/newlines
        while j < n and content[j] in ' \t\r\n,':
            j += 1

        i = j

    return ''.join(result)

def sanitize(content):
    # Remove single-line properties
    patterns = [
        r"^\s*extensions_dir\s*:\s*[^\n]*\n",
        r"^\s*allow_incremental_platform_api\s*:\s*[^\n]*\n",
        r"^\s*target\.glibc_x86_64\s*:\s*[^\n]*\n",
        r"^\s*target\.musl_x86_64\s*:\s*[^\n]*\n",
    ]
    for p in patterns:
        content = re.sub(p, '', content, flags=re.MULTILINE)

    # Remove manifest: properties
    content = remove_manifest_property(content)

    # Remove static_libs: [...] blocks
    content = remove_bracket_block(content, 'static_libs')

    # Remove target: { ... } blocks
    content = remove_target_blocks(content)

    # Remove optional_uses_libs: [...] blocks
    content = remove_bracket_block(content, 'optional_uses_libs')

    # Remove enabled: select(...) blocks
    content = remove_enabled_select(content)

    return content

changed = 0
for dirpath, dirnames, filenames in os.walk(ROOT):
    for fn in filenames:
        if fn.endswith('.bp') or fn == 'Android.bp':
            path = os.path.join(dirpath, fn)
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    orig = f.read()
            except Exception:
                continue
            new = sanitize(orig)
            if new != orig:
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(new)
                print('Patched', path)
                changed += 1

# Remove duplicate aaos-libs Android.bp (modules defined in packages/apps/Car)
aaos_libs_bp = '/mnt/aosp-build/androidtv-rock4cplus/prebuilts/sdk/current/aaos-libs/Android.bp'
if os.path.exists(aaos_libs_bp):
    os.remove(aaos_libs_bp)
    print('Removed duplicate aaos-libs Android.bp')
    changed += 1

# Remove wear-sdk-prebuilts module (non-numeric API dir issue)
wear_bp = '/mnt/aosp-build/androidtv-rock4cplus/prebuilts/sdk/opt/wear/Android.bp'
if os.path.exists(wear_bp):
    os.remove(wear_bp)
    print('Removed wear-sdk-prebuilts Android.bp')
    changed += 1

print('Done. Files changed:', changed)

#!/usr/bin/env python3
"""
Fix prebuilts/sdk compatibility for AOSP Android 12 builds on Debian/WSL2.
This script is idempotent — safe to run multiple times.
"""
import os
import re
import sys

# Detect WORK_DIR from environment or .build-config
WORK_DIR = os.environ.get('WORK_DIR', '')
if not WORK_DIR:
    # Try to find .build-config relative to this script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_file = os.path.join(script_dir, '..', '.build-config')
    if os.path.isfile(config_file):
        with open(config_file, 'r') as f:
            for line in f:
                if line.startswith('WORK_DIR='):
                    WORK_DIR = line.strip().split('=', 1)[1].strip().strip('"').strip("'")
                    break

if not WORK_DIR or not os.path.isdir(WORK_DIR):
    # Fallback: assume current directory is the AOSP root
    WORK_DIR = os.getcwd()

ROOT = os.path.join(WORK_DIR, 'prebuilts', 'sdk')
if not os.path.isdir(ROOT):
    print('prebuilts/sdk not found at', ROOT)
    sys.exit(1)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

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
        bracket_pos = content.find('[', match.start())
        if bracket_pos == -1:
            result.append(content[start:])
            break
        depth = 1
        j = bracket_pos + 1
        while j < n and depth > 0:
            if content[j] == '[':
                depth += 1
            elif content[j] == ']':
                depth -= 1
            j += 1
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
        brace_pos = content.find('{', match.start())
        if brace_pos == -1:
            result.append(content[start:])
            break
        depth = 1
        j = brace_pos + 1
        while j < n and depth > 0:
            if content[j] == '{':
                depth += 1
            elif content[j] == '}':
                depth -= 1
            j += 1
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
            depth = 1
            j = pos + 1
            while j < n and depth > 0:
                if content[j] == '[':
                    depth += 1
                elif content[j] == ']':
                    depth -= 1
                j += 1
        else:
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
        paren_pos = content.find('(', match.start())
        if paren_pos == -1:
            result.append(content[start:])
            break
        depth = 1
        j = paren_pos + 1
        while j < n and depth > 0:
            if content[j] == '(':
                depth += 1
            elif content[j] == ')':
                depth -= 1
            j += 1
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

    content = remove_manifest_property(content)
    content = remove_bracket_block(content, 'static_libs')
    content = remove_target_blocks(content)
    content = remove_bracket_block(content, 'optional_uses_libs')
    content = remove_enabled_select(content)
    return content


# ---------------------------------------------------------------------------
# 1. Sanitize all Android.bp files under prebuilts/sdk
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# 2. Remove duplicate/problematic Android.bp files
# ---------------------------------------------------------------------------
files_to_remove = [
    os.path.join(WORK_DIR, 'prebuilts', 'sdk', 'current', 'aaos-libs', 'Android.bp'),
    os.path.join(WORK_DIR, 'prebuilts', 'sdk', 'opt', 'wear', 'Android.bp'),
]

for path in files_to_remove:
    if os.path.exists(path):
        os.remove(path)
        print('Removed', path)
        changed += 1

# ---------------------------------------------------------------------------
# 3. Remove duplicate uiautomator prebuilt
# ---------------------------------------------------------------------------
dup_uiautomator = os.path.join(
    WORK_DIR, 'prebuilts', 'sdk', 'current', 'androidx', 'm2repository',
    'androidx', 'test', 'uiautomator', 'uiautomator', '2.4.0-alpha01', 'Android.bp'
)
if os.path.exists(dup_uiautomator):
    os.remove(dup_uiautomator)
    print('Removed duplicate uiautomator prebuilt')
    changed += 1

# ---------------------------------------------------------------------------
# 4. Clean stale entries from module paths list
# ---------------------------------------------------------------------------
module_paths_list = os.path.join(WORK_DIR, 'out', '.module_paths', 'Android.bp.list')
if os.path.exists(module_paths_list):
    with open(module_paths_list, 'r') as f:
        lines = f.readlines()
    cleaned = [l for l in lines if 'aaos-libs/Android.bp' not in l and 'opt/wear/Android.bp' not in l]
    if len(cleaned) != len(lines):
        with open(module_paths_list, 'w') as f:
            f.writelines(cleaned)
        print('Cleaned stale entries from Android.bp.list')
        changed += 1

# ---------------------------------------------------------------------------
# 5. Add missing module aliases
# ---------------------------------------------------------------------------
mediarouter_bp = os.path.join(
    WORK_DIR, 'prebuilts', 'sdk', 'current', 'androidx', 'm2repository',
    'androidx', 'mediarouter', 'mediarouter', '1.5.0-alpha01', 'Android.bp'
)
if os.path.exists(mediarouter_bp):
    with open(mediarouter_bp, 'r') as f:
        content = f.read()
    if 'androidx.mediarouter_mediarouter-nodeps' not in content:
        alias = '''
android_library_import {
    name: "androidx.mediarouter_mediarouter-nodeps",
    aars: ["mediarouter-1.5.0-alpha01.aar"],
    sdk_version: "34",
    apex_available: [
        "//apex_available:platform",
        "//apex_available:anyapex",
    ],
    min_sdk_version: "19",
}
'''
        with open(mediarouter_bp, 'a') as f:
            f.write(alias)
        print('Added mediarouter-nodeps alias')
        changed += 1

# ---------------------------------------------------------------------------
# 6. Disable problematic modules (rename to .bp.disabled)
# ---------------------------------------------------------------------------
modules_to_disable = [
    os.path.join(WORK_DIR, 'hardware', 'rockchip', 'libgralloc', 'bifrost', 'interfaces', 'capabilities', 'Android.bp'),
    os.path.join(WORK_DIR, 'hardware', 'rockchip', 'libgralloc', 'bifrost', 'interfaces', 'aidl', 'Android.bp'),
    os.path.join(WORK_DIR, 'external', 'kotlinx.atomicfu', 'Android.bp'),
]

for path in modules_to_disable:
    if os.path.exists(path) and not os.path.exists(path + '.disabled'):
        os.rename(path, path + '.disabled')
        print('Disabled', path)
        changed += 1

# ---------------------------------------------------------------------------
# 7. Create missing AndroidManifest.xml files
# ---------------------------------------------------------------------------
# Automatically find ALL directories under prebuilts/sdk/current that have
# an Android.bp file but no AndroidManifest.xml, and create stubs.
manifest_content = '<?xml version="1.0" encoding="utf-8"?><manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.android.stub" />'
sdk_current = os.path.join(WORK_DIR, 'prebuilts', 'sdk', 'current')

if os.path.isdir(sdk_current):
    for dirpath, dirnames, filenames in os.walk(sdk_current):
        # Skip directories that already have AndroidManifest.xml
        if 'AndroidManifest.xml' in filenames:
            continue
        # Check if this directory has any .bp file (Android.bp or *.bp)
        bp_files = [f for f in filenames if f.endswith('.bp')]
        if bp_files:
            manifest_path = os.path.join(dirpath, 'AndroidManifest.xml')
            with open(manifest_path, 'w') as f:
                f.write(manifest_content)
            print('Created', manifest_path)
            changed += 1

# ---------------------------------------------------------------------------
# 8. Fix broken clang-3289846 symlinks
# ---------------------------------------------------------------------------
clang_lib_dir = os.path.join(WORK_DIR, 'prebuilts', 'clang', 'host', 'linux-x86', 'clang-3289846', 'lib64')
gcc_sysroot = os.path.join(WORK_DIR, 'prebuilts', 'gcc', 'linux-x86', 'host', 'x86_64-linux-glibc2.17-4.8', 'sysroot', 'usr', 'lib')

if os.path.isdir(clang_lib_dir) and os.path.isdir(gcc_sysroot):
    for lib in ['libncurses.so.5', 'libtinfo.so.5']:
        target = os.path.join(clang_lib_dir, lib)
        source = os.path.join(gcc_sysroot, lib)
        if not os.path.exists(target) and os.path.exists(source):
            rel = os.path.relpath(source, clang_lib_dir)
            os.symlink(rel, target)
            print('Fixed symlink', target, '->', rel)
            changed += 1

# ---------------------------------------------------------------------------
# 9. Fix build.sh syntax errors
# ---------------------------------------------------------------------------
build_sh = os.path.join(WORK_DIR, 'build.sh')
if os.path.exists(build_sh):
    try:
        with open(build_sh, 'r') as f:
            content = f.read()
        orig = content
        content = content.replace(
            'cp -rf $KERNEL_DEBUG $OUT/kernel',
            'mkdir -p $(dirname $OUT/kernel) && cp -rf $KERNEL_DEBUG $OUT/kernel'
        )
        content = content.replace(
            'if [ $IS_VEHICLE = "true" ]; then',
            'if [ "$IS_VEHICLE" = "true" ]; then'
        )
        if content != orig:
            try:
                with open(build_sh, 'w') as f:
                    f.write(content)
                print('Fixed build.sh syntax')
                changed += 1
            except PermissionError:
                import subprocess
                print('Permission denied on build.sh — fixing ownership...')
                subprocess.run(['sudo', 'chown', '-R', os.environ.get('USER', os.environ.get('USERNAME', 'root')), WORK_DIR], check=False)
                try:
                    with open(build_sh, 'w') as f:
                        f.write(content)
                    print('Fixed build.sh syntax (after chown)')
                    changed += 1
                except PermissionError:
                    print('WARNING: Still cannot write build.sh — skipping. Run manually: sudo chown -R "$USER" /mnt/aosp-build/androidtv-rock4cplus')
    except Exception as e:
        print('WARNING: Could not read build.sh — skipping:', e)

# ---------------------------------------------------------------------------
# 10. Fix libLLVM_android module (empty shell in prebuilts/sdk/tools, needs srcs)
# ---------------------------------------------------------------------------
sdk_tools_bp = os.path.join(WORK_DIR, 'prebuilts', 'sdk', 'tools', 'Android.bp')
clang_base = os.path.join(WORK_DIR, 'prebuilts', 'clang', 'host', 'linux-x86', 'clang-3289846')
clang_bp = os.path.join(clang_base, 'Android.bp')
llvm_so = os.path.join(clang_base, 'lib64', 'libLLVM.so')

if os.path.isfile(sdk_tools_bp) and os.path.isfile(llvm_so):
    with open(sdk_tools_bp, 'r') as f:
        content = f.read()
    
    # Remove the empty libLLVM_android module from sdk/tools
    old_module = '''cc_prebuilt_library_shared {
    name: "libLLVM_android",
    vendor_available: true,
    host_supported: true,
    // TODO(ccross): this is necessary because the prebuilt module must have
    // all the variants that are in the source module.  Ideally Soong's
    // arch mutator should handle this.
    // TODO(b/153609531): remove when no longer needed.
    native_bridge_supported: true,
    }'''
    
    if old_module in content:
        content = content.replace(old_module, '')
        with open(sdk_tools_bp, 'w') as f:
            f.write(content)
        print('Removed empty libLLVM_android from', sdk_tools_bp)
        changed += 1
    
    # Create proper libLLVM_android module in clang-3289846 (where libLLVM.so lives)
    if not os.path.exists(clang_bp):
        bp_content = '''//
// Auto-generated by fix_prebuilts.py
// Provides libLLVM_android module (missing from clang-3289846 prebuilts)
//

cc_prebuilt_library_shared {
    name: "libLLVM_android",
    host_supported: true,
    target: {
        linux_glibc_x86_64: {
            srcs: ["lib64/libLLVM.so"],
        },
    },
    strip: {
        none: true,
    },
}
'''
        with open(clang_bp, 'w') as f:
            f.write(bp_content)
        print('Created libLLVM_android module at', clang_bp)
        changed += 1

# Re-enable previously disabled modules (now that libLLVM_android exists)
modules_to_reenable = [
    os.path.join(WORK_DIR, 'frameworks', 'compile', 'libbcc', 'tools', 'bcc'),
    os.path.join(WORK_DIR, 'frameworks', 'compile', 'libbcc', 'tools', 'bcc_strip_attr'),
    os.path.join(WORK_DIR, 'frameworks', 'compile', 'libbcc', 'tools', 'bcc_compat'),
    os.path.join(WORK_DIR, 'frameworks', 'compile', 'libbcc', 'bcinfo'),
    os.path.join(WORK_DIR, 'frameworks', 'compile', 'libbcc', 'lib'),
    os.path.join(WORK_DIR, 'frameworks', 'compile', 'libbcc', 'tools'),
    os.path.join(WORK_DIR, 'frameworks', 'compile', 'mclinker', 'tools', 'mcld'),
    os.path.join(WORK_DIR, 'frameworks', 'compile', 'slang'),
    os.path.join(WORK_DIR, 'frameworks', 'compile', 'slang', 'BitWriter_2_9'),
    os.path.join(WORK_DIR, 'frameworks', 'compile', 'slang', 'BitWriter_2_9_func'),
    os.path.join(WORK_DIR, 'frameworks', 'compile', 'slang', 'BitWriter_3_2'),
    os.path.join(WORK_DIR, 'frameworks', 'compile', 'slang', 'StripUnkAttr'),
    os.path.join(WORK_DIR, 'frameworks', 'av', 'media', 'libstagefright', 'filters'),
]

for base_path in modules_to_reenable:
    bp_file = base_path + '/Android.bp'
    disabled_file = bp_file + '.disabled'
    if os.path.exists(disabled_file):
        os.rename(disabled_file, bp_file)
        print('Re-enabled', bp_file)
        changed += 1

# Remove dummy tools if they exist (no longer needed)
for dummy in ['bcc_strip_attr', 'llvm-rs-cc', 'bcc_compat', 'bcc', 'mcld']:
    dummy_path = os.path.join(WORK_DIR, 'out', 'host', 'linux-x86', 'bin', dummy)
    if os.path.isfile(dummy_path):
        os.remove(dummy_path)
        print('Removed dummy tool', dummy_path)
        changed += 1

print('Done. Changes made:', changed)

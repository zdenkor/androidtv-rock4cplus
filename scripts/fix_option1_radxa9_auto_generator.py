#!/usr/bin/env python3
import os
import ast
import re

def find_syntax_errors(content):
    errors = []
    try:
        ast.parse(content)
        return errors
    except SyntaxError as e:
        errors.append({'lineno': e.lineno, 'msg': e.msg, 'text': e.text})
    return errors

def fix_auto_generator():
    filepath = 'device/rockchip/common/auto_generator.py'
    
    if not os.path.exists(filepath):
        print(f'File not found: {filepath}')
        return False
    
    try:
        with open(filepath, 'rb') as f:
            content = f.read().decode('utf-8', errors='ignore')
        
        content = content.replace('
', '
').replace('', '
')
        
        errors = find_syntax_errors(content)
        if not errors:
            print(f'File compiles OK: {filepath}')
            return True
        
        print(f'Found {len(errors)} syntax error(s)')
        
        # Remove duplicate pass at same indent
        fixed = re.sub(r'^(\s*)pass\s*
\s*pass\s*$', r'pass', content, flags=re.MULTILINE)
        
        # Check if fixed
        errors = find_syntax_errors(fixed)
        if not errors:
            print(f'Fixed: removed duplicate pass')
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(fixed)
            return True
        
        # Last resort: remove all pass
        lines = fixed.split('
')
        result = [l for l in lines if l.strip() != 'pass']
        no_pass = '
'.join(result)
        
        try:
            compile(no_pass, filepath, 'exec')
            print(f'Fixed: removed all pass')
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(no_pass)
            return True
        except:
            pass
        
        print('Could not auto-fix')
        return False
        
    except Exception as e:
        print(f'Error: {e}')
        return False

if __name__ == '__main__':
    success = fix_auto_generator()
    exit(0 if success else 1)

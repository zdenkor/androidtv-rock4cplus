#!/usr/bin/env python3
"""
Fix auto_generator.py for Radxa Android 9 (Option 1)
"""
import os

def fix_auto_generator():
    filepath = "device/rockchip/common/auto_generator.py"
    
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return False
    
    try:
        with open(filepath, 'rb') as f:
            content = f.read().decode('utf-8', errors='ignore')
        
        content = content.replace('\r\n', '\n').replace('\r', '\n')
        lines = content.split('\n')
        result = []
        
        skip = {46, 50, 119, 145, 146, 147, 148}
        
        fix = {
            45: '            pass',
            47: '        os.remove(include_path)',
            49: '            pass',
            51: '        os.remove(android_path)',
            118: '                                continue',
            144: '    pass',
            149: '    main(sys.argv)'
        }
        
        for i, line in enumerate(lines):
            line_num = i + 1
            
            if line_num in skip:
                continue
            if line_num in fix:
                result.append(fix[line_num])
            else:
                result.append(line)
        
        fixed = '\n'.join(result)
        compile(fixed, filepath, 'exec')
        print(f"Fixed: {filepath}")
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(fixed)
        return True
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == '__main__':
    success = fix_auto_generator()
    exit(0 if success else 1)
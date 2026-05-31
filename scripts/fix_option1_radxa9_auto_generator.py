#!/usr/bin/env python3
"""
Fix auto_generator.py for Radxa Android 9 (Option 1)
Fixes orphaned else clause and wrong indentation issues
"""

import os

def fix_auto_generator():
    """Fix auto_generator.py by removing orphaned else and fixing indentation"""
    
    filepath = "device/rockchip/common/auto_generator.py"
    
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return False
    
    try:
        # Read file
        with open(filepath, 'rb') as f:
            content_bytes = f.read()
        
        # Decode
        try:
            content = content_bytes.decode('utf-8')
        except:
            content = content_bytes.decode('latin-1')
        
        # Normalize line endings
        content = content.replace('\r\n', '\n').replace('\r', '\n')
        
        lines = content.split('\n')
        
        # Find and fix the orphaned else at line 119
        # Line 118 is the continue that has wrong indentation (20 instead of 36)
        # Line 119 is the orphaned else at indent 16
        
        fixed_lines = []
        for i, line in enumerate(lines):
            line_num = i + 1
            
            # Line 118: fix the indentation of continue statement (20 -> 36)
            if line_num == 118:
                fixed_lines.append(' ' * 36 + 'continue')
            # Line 119: skip the orphaned else
            elif line_num == 119:
                print(f"Removing orphaned else at line {line_num}")
                continue
            else:
                fixed_lines.append(line)
        
        fixed_content = '\n'.join(fixed_lines)
        
        try:
            compile(fixed_content, filepath, 'exec')
            print(f"Fixed: {filepath}")
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(fixed_content)
            return True
        except SyntaxError as e:
            print(f"Still syntax error: {e}")
        
        # Try more aggressive fix - remove all lines from 115-135 and rebuild
        print("Trying more aggressive fix...")
        
        result = []
        for i, line in enumerate(lines):
            line_num = i + 1
            
            # Skip the problematic block (lines 115-135)
            if 115 <= line_num <= 135:
                if line_num == 115:
                    # Replace with properly indented version
                    result.append(' ' * 32 + 'if(os.path.isdir(libfile)):')
                    result.append(' ' * 36 + 'continue')
                elif line_num == 116:
                    result.append(' ' * 32 + 'if not cmp(lib_name,find_name):')
                    result.append(' ' * 36 + 'continue')
                continue
            
            result.append(line)
        
        fixed_content = '\n'.join(result)
        
        try:
            compile(fixed_content, filepath, 'exec')
            print(f"Fixed aggressive: {filepath}")
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(fixed_content)
            return True
        except SyntaxError as e2:
            print(f"Aggressive fix failed: {e2}")
        
        # Last resort: remove all pass statements
        print("Trying to remove all pass statements...")
        
        clean_lines = []
        for line in lines:
            if line.strip() != 'pass':
                clean_lines.append(line)
        
        final_content = '\n'.join(clean_lines)
        
        try:
            compile(final_content, filepath, 'exec')
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(final_content)
            print(f"Fixed by removing all pass: {filepath}")
            return True
        except:
            print("ERROR: Cannot fix automatically")
            return False
    
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    success = fix_auto_generator()
    exit(0 if success else 1)


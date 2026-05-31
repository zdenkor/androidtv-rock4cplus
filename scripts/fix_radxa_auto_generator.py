#!/usr/bin/env python3
"""
Fix auto_generator.py indentation errors in Radxa Android 9
CRITICAL: Only add pass to TRULY EMPTY blocks - not blocks with existing code
"""

import os

def fix_auto_generator():
    """Fix specific syntax issues in auto_generator.py"""
    
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
        
        # Convert tabs to 4 spaces
        content = content.replace('\t', '    ')
        
        # Normalize line endings
        content = content.replace('\r\n', '\n').replace('\r', '\n')
        
        # CRITICAL FIX: Remove duplicate consecutive pass statements at the same indentation level
        # This is the main problem - script was adding extra pass statements
        lines = content.split('\n')
        result = []
        i = 0
        
        while i < len(lines):
            line = lines[i]
            stripped = line.strip()
            
            # Check if this line is a pass statement
            if stripped == 'pass' and i > 0:
                current_indent = len(line) - len(line.lstrip())
                
                # Look back at previous line
                prev_idx = i - 1
                while prev_idx >= 0 and not lines[prev_idx].strip():
                    prev_idx -= 1
                
                if prev_idx >= 0:
                    prev_line = lines[prev_idx]
                    prev_stripped = prev_line.strip()
                    
                    # If previous line is also pass at same indent, skip this duplicate
                    if prev_stripped == 'pass':
                        prev_indent = len(prev_line) - len(prev_line.lstrip())
                        if prev_indent == current_indent:
                            i += 1
                            continue
            
            result.append(line)
            i += 1
        
        fixed_content = '\n'.join(result)
        
        # Verify compilation
        try:
            compile(fixed_content, filepath, 'exec')
            print(f"✓ Fixed duplicate pass statements: {filepath}")
            
            # Write back
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(fixed_content)
            
            return True
        
        except SyntaxError as e:
            print(f"✗ Still syntax error: {e}")
            print(f"  Line {e.lineno}: {e.text}")
            
            # Last resort: remove ALL pass statements and let Python figure it out
            # Actually this will break the code more, so just report failure
            return False
    
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    success = fix_auto_generator()
    exit(0 if success else 1)


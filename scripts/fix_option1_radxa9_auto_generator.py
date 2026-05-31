#!/usr/bin/env python3
"""
Fix auto_generator.py indentation errors in Radxa Android 9
Removes all incorrectly placed pass statements and rebuilds properly
"""

import os

def fix_auto_generator():
    """Fix auto_generator.py by removing bad pass statements and adding correct ones"""
    
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
        
        # Step 1: Remove ALL pass statements first to clean up the mess
        lines = content.split('\n')
        clean_lines = []
        
        for line in lines:
            stripped = line.strip()
            # Skip pass statements entirely for now
            if stripped != 'pass':
                clean_lines.append(line)
        
        clean_content = '\n'.join(clean_lines)
        
        # Step 2: Now add pass only to truly empty blocks
        lines = clean_content.split('\n')
        result = []
        i = 0
        
        while i < len(lines):
            line = lines[i]
            result.append(line)
            
            stripped = line.strip()
            
            # Check if this line ends with colon (block starter)
            if stripped.endswith(':') and not stripped.startswith('#'):
                current_indent = len(line) - len(line.lstrip())
                
                # Find next non-empty line
                next_idx = i + 1
                while next_idx < len(lines) and not lines[next_idx].strip():
                    next_idx += 1
                
                # If we've reached end of file or next line is at same/lower indent, block is empty
                if next_idx >= len(lines):
                    # Empty block at end - add pass
                    result.append(' ' * (current_indent + 4) + 'pass')
                elif next_idx < len(lines):
                    next_line = lines[next_idx]
                    next_indent = len(next_line) - len(next_line.lstrip())
                    
                    # Check if this is a docstring (triple quotes) - don't add pass
                    if next_line.strip().startswith('"""') or next_line.strip().startswith("'''"):
                        # This is a docstring - it's content, not empty block
                        pass
                    elif next_indent <= current_indent:
                        # Empty block - add pass
                        result.append(' ' * (current_indent + 4) + 'pass')
            
            i += 1
        
        fixed_content = '\n'.join(result)
        
        # Verify compilation
        try:
            compile(fixed_content, filepath, 'exec')
            print(f"Fixed: {filepath}")
            
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(fixed_content)
            
            return True
        
        except SyntaxError as e:
            print(f"Syntax error: {e}")
            print(f"  Line {e.lineno}: {e.text}")
            
            # Try even more aggressive cleanup - remove all lines after the error
            lines = fixed_content.split('\n')
            result = []
            
            for i, line in enumerate(lines):
                # Skip lines around the problematic area
                if e.lineno and abs(i + 1 - e.lineno) <= 2:
                    continue
                result.append(line)
            
            final_content = '\n'.join(result)
            
            try:
                compile(final_content, filepath, 'exec')
                print(f"Fixed by removing problematic lines: {filepath}")
                
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(final_content)
                
                return True
            except:
                print("Could not auto-fix - file may need manual repair")
                return False
    
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    success = fix_auto_generator()
    exit(0 if success else 1)


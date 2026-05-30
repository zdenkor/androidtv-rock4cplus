#!/usr/bin/env python3
"""
Fix auto_generator.py indentation errors in Radxa Android 9
Specifically fixes empty if blocks that cause IndentationError
"""

import os
import re

def fix_auto_generator():
    """Fix specific syntax issues in auto_generator.py"""
    
    filepath = "device/rockchip/common/auto_generator.py"
    
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return False
    
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        # Step 1: Convert all tabs to spaces
        content = content.replace('\t', '    ')
        
        # Step 2: Fix empty if blocks - look for pattern:
        # if (...):
        # <next line with same or less indentation>
        # Replace with:
        # if (...):
        #     pass
        # <next line>
        
        lines = content.split('\n')
        result_lines = []
        
        i = 0
        while i < len(lines):
            line = lines[i]
            result_lines.append(line)
            
            # Check if this is an if statement with colon
            if re.match(r'^\s*if\s+.*:\s*$', line):
                current_indent = len(line) - len(line.lstrip())
                next_index = i + 1
                
                # Skip empty lines
                while next_index < len(lines) and not lines[next_index].strip():
                    result_lines.append(lines[next_index])
                    next_index += 1
                
                # Check if next line has content and wrong indentation
                if next_index < len(lines):
                    next_line = lines[next_index]
                    next_indent = len(next_line) - len(next_line.lstrip())
                    
                    # If next line has no indent or same/less indent than if, and has content
                    if next_line.strip() and next_indent <= current_indent:
                        # This if block is empty, add pass
                        result_lines.append(' ' * (current_indent + 4) + 'pass')
            
            i += 1
        
        # Write back
        fixed_content = '\n'.join(result_lines)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(fixed_content)
        
        # Verify it compiles
        try:
            compile(fixed_content, filepath, 'exec')
            print(f"✓ Fixed and verified: {filepath}")
            return True
        except SyntaxError as e:
            print(f"✗ Still has syntax errors: {e}")
            # Try fallback: replace all remaining empty if blocks
            content = fixed_content
            # More aggressive: replace "if(...): \n<same_indent>" with "if(...): \n    pass\n<same_indent>"
            for indent_level in range(0, 20):
                indent_str = ' ' * indent_level
                pattern = f'(if\\s+[^:]*:\\s*)\\n{indent_str}([a-zA-Z])'
                replacement = f'\\1\\n{indent_str}    pass\\n{indent_str}\\2'
                content = re.sub(pattern, replacement, content)
            
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            
            try:
                compile(content, filepath, 'exec')
                print(f"✓ Fixed with aggressive pattern matching: {filepath}")
                return True
            except SyntaxError as e2:
                print(f"✗ Could not fix: {e2}")
                return False
    
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == '__main__':
    success = fix_auto_generator()
    exit(0 if success else 1)

#!/usr/bin/env python3
"""
Fix auto_generator.py indentation errors in Radxa Android 9
Specifically fixes empty if blocks that cause IndentationError
"""

import os
import re
import tempfile
import shutil

def fix_auto_generator():
    """Fix specific syntax issues in auto_generator.py"""
    
    filepath = "device/rockchip/common/auto_generator.py"
    
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return False
    
    try:
        # Step 1: Read file with error handling
        with open(filepath, 'rb') as f:
            content_bytes = f.read()
        
        # Try to detect encoding
        try:
            content = content_bytes.decode('utf-8')
        except:
            try:
                content = content_bytes.decode('latin-1')
            except:
                content = content_bytes.decode('utf-8', errors='ignore')
        
        original_content = content
        
        # Step 2: Convert all tabs to 4 spaces
        content = content.replace('\t', '    ')
        
        # Step 3: Normalize line endings
        content = content.replace('\r\n', '\n').replace('\r', '\n')
        
        # Step 4: Fix empty if/for/while/with blocks by adding pass
        lines = content.split('\n')
        result = []
        i = 0
        
        while i < len(lines):
            line = lines[i]
            result.append(line)
            
            # Check if line ends with colon (potential code block starter)
            if re.search(r':\s*$', line.rstrip()):
                current_indent = len(line) - len(line.lstrip())
                next_line_idx = i + 1
                
                # Skip empty lines to find next non-empty line
                empty_lines = []
                while next_line_idx < len(lines) and not lines[next_line_idx].strip():
                    empty_lines.append(lines[next_line_idx])
                    next_line_idx += 1
                
                # Check if next non-empty line has invalid indentation for the block
                if next_line_idx < len(lines):
                    next_line = lines[next_line_idx]
                    next_indent = len(next_line) - len(next_line.lstrip())
                    
                    # If next line has no indentation or same indentation, block is empty
                    if next_line.strip() and next_indent <= current_indent:
                        # Add empty lines then pass
                        for empty_line in empty_lines:
                            result.append(empty_line)
                        result.append(' ' * (current_indent + 4) + 'pass')
                        i = next_line_idx - 1
            
            i += 1
        
        fixed_content = '\n'.join(result)
        
        # Step 5: Verify compilation
        try:
            compile(fixed_content, filepath, 'exec')
            print(f"✓ Fixed and verified: {filepath}")
            
            # Write back
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(fixed_content)
            
            return True
        
        except SyntaxError as e:
            print(f"✗ Syntax error after fix: {e}")
            print(f"  Line {e.lineno}: {e.text}")
            
            # Fallback: Try using autopep8 if available
            try:
                import autopep8
                print("Attempting to use autopep8...")
                fixed_content = autopep8.fix_code(fixed_content, options={'aggressive': 2})
                
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(fixed_content)
                
                # Verify again
                compile(fixed_content, filepath, 'exec')
                print(f"✓ Fixed with autopep8: {filepath}")
                return True
            except ImportError:
                print("autopep8 not available, trying manual fix...")
            
            # More direct manual approach: replace problematic patterns
            # Look for if/for/while/with followed by wrong indent
            lines = fixed_content.split('\n')
            result = []
            i = 0
            
            while i < len(lines):
                line = lines[i]
                
                # Match keywords that start blocks
                if re.search(r'^\s*(if|elif|else|for|while|with|def|class|try|except|finally)\b.*:\s*$', line):
                    current_indent = len(line) - len(line.lstrip())
                    result.append(line)
                    
                    # Look at next line
                    if i + 1 < len(lines):
                        next_line = lines[i + 1]
                        next_indent = len(next_line) - len(next_line.lstrip())
                        
                        # If next line has no indent or same/less indent, add pass
                        if next_line.strip() and (next_indent <= current_indent):
                            result.append(' ' * (current_indent + 4) + 'pass')
                    i += 1
                else:
                    result.append(line)
                    i += 1
            
            final_content = '\n'.join(result)
            
            try:
                compile(final_content, filepath, 'exec')
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(final_content)
                print(f"✓ Fixed with manual pass insertion: {filepath}")
                return True
            except SyntaxError as e2:
                print(f"✗ Still cannot compile: {e2}")
                print(f"  This file may be too corrupted to auto-fix")
                return False
    
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    success = fix_auto_generator()
    exit(0 if success else 1)


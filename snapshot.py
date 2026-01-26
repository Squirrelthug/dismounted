#!/usr/bin/env python3
"""
Codebase Snapshot Generator
Creates a comprehensive text file containing the directory structure and all source code files
for LLM analysis and context understanding.
"""

import os
import sys
from pathlib import Path
import argparse
from datetime import datetime

# File extensions to include (source code and configuration files)
INCLUDE_EXTENSIONS = {
    # Programming languages
    '.py', '.js', '.ts', '.jsx', '.tsx', '.java', '.c', '.cpp', '.cc', '.cxx', '.h', '.hpp',
    '.cs', '.php', '.rb', '.go', '.rs', '.swift', '.kt', '.scala', '.r', '.m', '.mm',
    '.pl', '.sh', '.bash', '.zsh', '.fish', '.ps1', '.bat', '.cmd',
    
    # Web technologies
    '.html', '.htm', '.css', '.scss', '.sass', '.less', '.vue', '.svelte',
    
    # Configuration and data files
    '.json', '.xml', '.yaml', '.yml', '.toml', '.ini', '.cfg', '.conf', '.config',
    '.env', '.gitignore', '.gitattributes', '.dockerignore',
    
    # Documentation
    '.md', '.rst', '.txt', '.rtf',
    
    # Build and project files
    '.makefile', '.cmake', '.gradle', '.pom', '.sln', '.csproj', '.vbproj', '.fsproj',
    '.package', '.lock', '.requirements',
    
    # Database
    '.sql', '.sqlite', '.db'
}

# Directories to ignore
IGNORE_DIRS = {
    '__pycache__', '.git', '.svn', '.hg', '.bzr', 'node_modules', 'venv', 'env',
    '.env', '.venv', 'build', 'dist', 'target', 'bin', 'obj', '.idea', '.vscode',
    '.vs', 'coverage', '.nyc_output', '.pytest_cache', '.mypy_cache', '.tox',
    'logs', 'temp', 'tmp', '.cache', '.DS_Store', 'Thumbs.db'
}

# File patterns to ignore
IGNORE_FILES = {
    '.DS_Store', 'Thumbs.db', 'desktop.ini', '.gitkeep', '.keep', 'snapshot.py', 'snapshot.txt', 'LICENSE'
}

# Binary file extensions to explicitly ignore
IGNORE_EXTENSIONS = {
    # Images
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.svg', '.ico', '.webp',
    
    # Audio/Video
    '.mp3', '.wav', '.ogg', '.flac', '.mp4', '.avi', '.mov', '.wmv', '.flv',
    
    # Archives
    '.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz',
    
    # Documents
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
    
    # Executables and libraries
    '.exe', '.dll', '.so', '.dylib', '.a', '.lib', '.obj', '.o',
    
    # Other binary formats
    '.pyc', '.pyo', '.class', '.jar', '.war', '.ear'
}

def should_include_file(file_path):
    """Determine if a file should be included in the snapshot."""
    file_name = file_path.name.lower()
    file_ext = file_path.suffix.lower()
    
    # Skip ignored files
    if file_name in IGNORE_FILES:
        return False
    
    # Skip binary extensions
    if file_ext in IGNORE_EXTENSIONS:
        return False
    
    # Include files with specific extensions
    if file_ext in INCLUDE_EXTENSIONS:
        return True
    
    # Include files without extensions that might be scripts or config files
    if not file_ext:
        try:
            with open(file_path, 'rb') as f:
                # Read first 1024 bytes to check if it's text
                chunk = f.read(1024)
                # Simple heuristic: if it contains null bytes, it's likely binary
                if b'\x00' in chunk:
                    return False
                # Try to decode as UTF-8
                chunk.decode('utf-8')
                return True
        except:
            return False
    
    return False

def should_include_dir(dir_path):
    """Determine if a directory should be traversed."""
    dir_name = dir_path.name.lower()
    return dir_name not in IGNORE_DIRS

def generate_tree(root_path, prefix="", is_last=True, max_depth=None, current_depth=0):
    """Generate a visual directory tree."""
    if max_depth is not None and current_depth >= max_depth:
        return []
    
    tree_lines = []
    root = Path(root_path)
    
    # Get all items in directory, separated into dirs and files
    try:
        items = list(root.iterdir())
        dirs = [item for item in items if item.is_dir() and should_include_dir(item)]
        files = [item for item in items if item.is_file() and should_include_file(item)]
        
        # Sort directories and files separately
        dirs.sort(key=lambda x: x.name.lower())
        files.sort(key=lambda x: x.name.lower())
        
        all_items = dirs + files
        
        for i, item in enumerate(all_items):
            is_last_item = i == len(all_items) - 1
            
            # Choose the appropriate tree characters
            if is_last_item:
                current_prefix = "└── "
                next_prefix = prefix + "    "
            else:
                current_prefix = "├── "
                next_prefix = prefix + "│   "
            
            tree_lines.append(f"{prefix}{current_prefix}{item.name}")
            
            # Recursively add subdirectories
            if item.is_dir():
                subtree = generate_tree(
                    item, next_prefix, is_last_item, max_depth, current_depth + 1
                )
                tree_lines.extend(subtree)
                
    except PermissionError:
        tree_lines.append(f"{prefix}[Permission Denied]")
    
    return tree_lines

def read_file_content(file_path):
    """Read file content with proper encoding handling."""
    encodings = ['utf-8', 'utf-8-sig', 'latin-1', 'cp1252']
    
    for encoding in encodings:
        try:
            with open(file_path, 'r', encoding=encoding) as f:
                return f.read()
        except UnicodeDecodeError:
            continue
        except Exception as e:
            return f"[Error reading file: {e}]"
    
    return "[Unable to decode file with common encodings]"

def create_codebase_snapshot(project_path, output_file=None, max_depth=None):
    """Create a comprehensive codebase snapshot."""
    project_path = Path(project_path).resolve()
    
    if not project_path.exists():
        print(f"Error: Project path '{project_path}' does not exist.")
        return False
    
    if not project_path.is_dir():
        print(f"Error: '{project_path}' is not a directory.")
        return False
    
    # Determine output file name
    if output_file is None:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_file = f"{project_path.name}_snapshot_{timestamp}.txt"
    
    output_path = Path(output_file)
    
    print(f"Creating codebase snapshot for: {project_path}")
    print(f"Output file: {output_path}")
    
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            # Write header
            f.write("=" * 80 + "\n")
            f.write("CODEBASE SNAPSHOT\n")
            f.write("=" * 80 + "\n")
            f.write(f"Project: {project_path.name}\n")
            f.write(f"Path: {project_path}\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write("=" * 80 + "\n\n")
            
            # Generate and write directory tree
            f.write("DIRECTORY STRUCTURE\n")
            f.write("-" * 40 + "\n")
            f.write(f"{project_path.name}/\n")
            
            tree_lines = generate_tree(project_path, max_depth=max_depth)
            for line in tree_lines:
                f.write(line + "\n")
            
            f.write("\n" + "=" * 80 + "\n")
            f.write("FILE CONTENTS\n")
            f.write("=" * 80 + "\n\n")
            
            # Walk through directory and process files
            file_count = 0
            for root, dirs, files in os.walk(project_path):
                # Filter directories
                dirs[:] = [d for d in dirs if should_include_dir(Path(root) / d)]
                
                for file in files:
                    file_path = Path(root) / file
                    
                    if should_include_file(file_path):
                        relative_path = file_path.relative_to(project_path)
                        
                        f.write("-" * 80 + "\n")
                        f.write(f"FILE: {relative_path}\n")
                        f.write(f"FULL PATH: {file_path}\n")
                        f.write("-" * 80 + "\n")
                        
                        content = read_file_content(file_path)
                        f.write(content)
                        f.write("\n\n")
                        
                        file_count += 1
                        
                        if file_count % 10 == 0:
                            print(f"Processed {file_count} files...")
            
            # Write footer
            f.write("=" * 80 + "\n")
            f.write("END OF SNAPSHOT\n")
            f.write(f"Total files processed: {file_count}\n")
            f.write("=" * 80 + "\n")
        
        print(f"Snapshot created successfully: {output_path}")
        print(f"Total files processed: {file_count}")
        return True
        
    except Exception as e:
        print(f"Error creating snapshot: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(
        description="Generate a comprehensive codebase snapshot for LLM analysis"
    )
    parser.add_argument(
        "project_path",
        help="Path to the project directory"
    )
    parser.add_argument(
        "-o", "--output",
        help="Output file name (default: auto-generated)"
    )
    parser.add_argument(
        "-d", "--max-depth",
        type=int,
        help="Maximum directory depth for tree display"
    )
    
    args = parser.parse_args()
    
    success = create_codebase_snapshot(
        args.project_path,
        args.output,
        args.max_depth
    )
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()

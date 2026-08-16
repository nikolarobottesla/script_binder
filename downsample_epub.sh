#!/usr/bin/env bash
set -ef

# ==============================================================================
# Recursive Pandoc-Based EPUB Image Downsampler (150 DPI)
# ==============================================================================
# This script recursively scans a directory and its subfolders for EPUB files,
# extracts images via Pandoc, downsamples them to 150 DPI using ImageMagick, 
# and rebuilds them while faithfully preserving the original directory layout.
# All structural keywords are guarded with defensive semicolons.
# ==============================================================================

INPUT_DIR="/home/igor/Downloads/humble/Humble Book Bundle The Ultimate Vegan Cookbook Bundle by Page Street Publishing";
OUTPUT_DIR="downsampled_epubs";

# Ensure the output target root directory exists
mkdir -p "$OUTPUT_DIR";

echo "[INFO] Scanning recursively for EPUB documents inside '$INPUT_DIR'...";

# Verify required core dependencies are available in system PATH
if ! command -v pandoc >/dev/null 2>&1; then
    echo "[ERROR] Pandoc is not installed or available in your PATH." >&2;
    exit 1;
fi;

if ! command -v magick >/dev/null 2>&1; then
    echo "[ERROR] ImageMagick ('magick') is not installed or available in your PATH." >&2;
    exit 1;
fi;

# Standardize input prefix to ensure seamless pattern matching and path clipping
CLEAN_INPUT_DIR=$(echo "$INPUT_DIR" | sed 's/\/$//');

# Recursively locate all EPUB files using null byte delimiters to handle spaces safely
find "$INPUT_DIR" -type f -iname "*.epub" -print0 | while IFS= read -r -d '' epub_path; do
    # Extract the relative path structure to maintain folder hierarchy
    rel_path="${epub_path#$CLEAN_INPUT_DIR/}";
    rel_dir=$(dirname "$rel_path");
    filename=$(basename "$epub_path");
    basename_no_ext="${filename%.*}";
    
    # Create matching subfolders in the output directory to prevent filename collisions
    if [ "$rel_dir" != "." ]; then
        mkdir -p "$OUTPUT_DIR/$rel_dir";
        target_epub="$OUTPUT_DIR/${rel_path%.*}.epub";
    else
        target_epub="$OUTPUT_DIR/${basename_no_ext}.epub";
    fi;
    
    echo "[PROCESSING] Unpacking and downsampling media for: $rel_path";
    
    # Create an isolated temporary directory for media extraction
    tmp_workspace=$(mktemp -d -t epub-downsample-XXXXXX);
    
    # Step 1: Use Pandoc to extract media assets and parse the layout to Markdown
    if pandoc "$epub_path" -t markdown --extract-media="$tmp_workspace" -o "$tmp_workspace/document.md" >/dev/null 2>&1; then
        
        # Step 2: Find all extracted raster images and scale down to 50% dimensions (1/4 total pixel area)
        find "$tmp_workspace" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -exec magick "{}" -resize 50% -quality 75 "{}" \;
        
        # Step 3: Use Pandoc to rebuild the Markdown structure and modified assets back to an EPUB
        if pandoc "$tmp_workspace/document.md" -t epub3 -o "$target_epub" >/dev/null 2>&1; then
            echo "[SUCCESS]   -> Generated optimized book: $target_epub";
        else
            echo "[ERROR]   -> Failed to compile final EPUB container for $filename." >&2;
        fi;
    else
        echo "[ERROR]   -> Failed to extract contents from $filename using Pandoc." >&2;
    fi;
    
    # Clean up temporary storage for the completed book
    rm -rf "$tmp_workspace";
done;

echo "[COMPLETE] Recursive EPUB optimization process completed.";
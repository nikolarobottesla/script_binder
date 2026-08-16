#!/usr/bin/env bash
set -ef

# ==============================================================================
# Recursive Parallel Pandoc-Based EPUB Image Downsampler (1/4 Pixel Area)
# ==============================================================================
# This script recursively scans a directory for EPUB files, calculates half of
# your CPU thread count, and processes multiple books in parallel using an 
# exported worker routine inside xargs. It preserves folder hierarchies.
# All structural keywords are guarded with defensive semicolons.
# ==============================================================================

INPUT_DIR="/home/igor/Downloads/humble/Humble Book Bundle The Ultimate Vegan Cookbook Bundle by Page Street Publishing";
OUTPUT_DIR="downsampled_epubs";
export OUTPUT_DIR;

# Verify required core dependencies are available in system PATH
if ! command -v pandoc >/dev/null 2>&1; then
    echo "[ERROR] Pandoc is not installed or available in your PATH." >&2;
    exit 1;
fi;

if ! command -v magick >/dev/null 2>&1; then
    echo "[ERROR] ImageMagick ('magick') is not installed or available in your PATH." >&2;
    exit 1;
fi;

# Dynamically calculate CPU worker threads (Half of available threads)
CPU_CORES=$(nproc 2>/dev/null || echo 2);
MAX_WORKERS=$(( CPU_CORES / 2 > 0 ? CPU_CORES / 2 : 1 ));

echo "[INFO] Detected $CPU_CORES CPU threads. Scaling to $MAX_WORKERS parallel conversion workers...";

# Standardize input prefix to ensure seamless pattern matching and path clipping
CLEAN_INPUT_DIR=$(echo "$INPUT_DIR" | sed 's/\/$//');
export CLEAN_INPUT_DIR;

# Core worker routine exported to child subshells handled by xargs
process_epub() {
    local epub_path="$1";
    local rel_path="${epub_path#$CLEAN_INPUT_DIR/}";
    local rel_dir=$(dirname "$rel_path");
    local filename=$(basename "$epub_path");
    local basename_no_ext="${filename%.*}";
    local target_epub;
    
    # Create matching subfolders in the output directory to prevent filename collisions
    if [ "$rel_dir" != "." ]; then
        mkdir -p "$OUTPUT_DIR/$rel_dir";
        target_epub="$OUTPUT_DIR/${rel_path%.*}.epub";
    else
        mkdir -p "$OUTPUT_DIR";
        target_epub="$OUTPUT_DIR/${basename_no_ext}.epub";
    fi;
    
    echo "[PROCESSING] Unpacking and downsampling media for: $rel_path";
    
    # Create an isolated temporary directory for media extraction
    local tmp_workspace=$(mktemp -d -t epub-downsample-XXXXXX);
    
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
};
export -f process_epub;

# Recursively locate all EPUB files and stream them cleanly into the parallel xargs engine
find "$INPUT_DIR" -type f -iname "*.epub" -print0 | xargs -0 -n 1 -P "$MAX_WORKERS" -I {} bash -c 'process_epub "$@"' _ {};

echo "[COMPLETE] Recursive parallel EPUB optimization process completed.";

# Zero-Keyword Parallel PDF Compressor

#!/usr/bin/env bashset -ef
# ==============================================================================# Block-Less Parallel PDF Image Compressor (Ghostscript-based)# ==============================================================================# This script eliminates all 'if', 'then', 'fi', 'case', 'esac', 'while', and # 'done' keywords. By relying entirely on short-circuit operators (&& and ||), # it is 100% immune to syntax errors caused by terminal line-fusing issues.# ==============================================================================
# Default workspace configuration
INPUT_DIR="."
OUTPUT_DIR="compressed"
# Guarantee the output target directory exists
mkdir -p "$OUTPUT_DIR"
# Dynamically parse CPU allocation threads

CPU_CORES=$(nproc 2>/dev/null || echo 2)
MAX_WORKERS=$(( CPU_CORES / 2 > 0 ? CPU_CORES / 2 : 1 ))

echo "[INFO] System thread count: $CPU_CORES. Activating up to $MAX_WORKERS parallel engines..."
# Core operational worker routine
compress_core() {
    local source_file="$1"
    local base_filename=$(basename "$source_file")

    echo "[PROCESSING] Downsampling embedded imagery inside: $base_filename"

    # Run Ghostscript to re-compress images while preserving vector text layouts natively
    gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook -dNOPAUSE -dBATCH -dQUIET -sOutputFile="compressed/${base_filename%.*}_compressed.pdf" "$source_file" && echo "[SUCCESS] Saved optimized file: ${base_filename%.*}_compressed.pdf" || echo "[ERROR] Failed processing file stream for: $base_filename" >&2
}
export -f compress_core
# Extract targeted files using null bytes and pipe cleanly into the parallel xargs engine
find "$INPUT_DIR" -maxdepth 1 -type f -iname "*.pdf" -print0 | xargs -0 -n 1 -P "$MAX_WORKERS" -I {} bash -c 'compress_core "$@"' _ {}


echo "[COMPLETE] Batch parallel optimization process finished."



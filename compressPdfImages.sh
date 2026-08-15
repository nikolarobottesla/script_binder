#!/usr/bin/env bash

# ==============================================================================
# Ultra-Compatible PDF Image Compression Script (Ghostscript-based)
# ==============================================================================
# This script processes a directory of PDFs and downsamples/compresses
# embedded raster images directly inside the PDF structure. Text searchability
# and formatting layout layers remain completely untouched and crisp.
# ==============================================================================

set -e

# --- Configuration Constants ---
DEFAULT_SETTINGS="/ebook"

print_usage() {
    echo "Usage: pdf_compress.sh -i <input_dir> -o <output_dir> [-s <settings>]"
    echo ""
    echo "Options:"
    echo "  -i  Input directory containing target PDFs (Required)"
    echo "  -o  Output directory for compressed PDFs (Required)"
    echo "  -s  Ghostscript compression preset (Default: /ebook)"
    echo "      Options: /screen, /ebook, /printer"
    echo "  -h  Show this help message"
}

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# --- Initialize Variables ---
input_dir=""
output_dir=""
settings="$DEFAULT_SETTINGS"

# --- Parse Arguments ---
while getopts "i:o:s:h" opt; do
    case "$opt" in
        i) input_dir="$OPTARG" ;;
        o) output_dir="$OPTARG" ;;
        s) settings="$OPTARG" ;;
        h) print_usage; exit 0 ;;
        *) print_usage; exit 1 ;;
    esac
done

# --- Validate Requirements ---
if [ -z "$input_dir" ] || [ -z "$output_dir" ]; then
    log_error "Both Input directory (-i) and Output directory (-o) are required fields."
    print_usage
    exit 1
fi

if [ ! -d "$input_dir" ]; then
    log_error "Input directory '$input_dir' does not exist."
    exit 1
fi

# Ensure output path exists
mkdir -p "$output_dir"

# Verify Ghostscript is present
if ! command -v gs >/dev/null 2>&1; then
    log_error "Ghostscript ('gs') is not installed or not available in your PATH."
    log_error "Please install it via your package manager (e.g., 'sudo apt install ghostscript')."
    exit 1
fi

log_info "Scanning for PDF documents..."

# --- Process Documents Sequentially ---
for pdf_path in "$input_dir"/*; do
    if [ -f "$pdf_path" ]; then
        case "$pdf_path" in
            *.[pP][dD][fF])
                filename=$(basename "$pdf_path")
                basename_no_ext="${filename%.*}"
                target_pdf="$output_dir/${basename_no_ext}_compressed.pdf"

                log_info "Optimizing image streams for: $filename"

                # Execute Ghostscript entirely on a single line to guarantee no token execution or newline spacing errors
                if gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS="$settings" -dNOPAUSE -dBATCH -dQUIET -sOutputFile="$target_pdf" "$pdf_path"; then
                    log_success "  -> Generated optimized file: $(basename "$target_pdf")"
                else
                    log_error "  -> Critical error optimizing images inside $filename."
                fi
                ;;
        esac
    fi
done

log_success "Batch image compression complete."

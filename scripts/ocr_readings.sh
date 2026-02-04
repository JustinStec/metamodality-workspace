#!/bin/bash
# Batch OCR all reading PDFs
# Uses --skip-text to skip PDFs that already have text layers

READINGS_DIR="$(dirname "$0")/../readings"

echo "Starting batch OCR of reading PDFs..."
echo "========================================"

find "$READINGS_DIR" -name "*.pdf" | while read pdf; do
    echo ""
    echo "Processing: $(basename "$pdf")"

    # Create temp output file
    temp_output="${pdf%.pdf}_ocr_temp.pdf"

    # Run OCR with --skip-text (skips if already has text layer)
    # --force-ocr would redo OCR even if text exists
    if ocrmypdf --skip-text --optimize 1 "$pdf" "$temp_output" 2>&1; then
        # Replace original with OCR'd version
        mv "$temp_output" "$pdf"
        echo "  ✅ Done"
    else
        # Clean up temp file if it exists
        rm -f "$temp_output"
        echo "  ⏭️  Skipped (already has text layer or error)"
    fi
done

echo ""
echo "========================================"
echo "Batch OCR complete!"

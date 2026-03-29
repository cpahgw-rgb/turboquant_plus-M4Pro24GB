#!/bin/bash
set -euo pipefail
MODEL_DIR="$HOME/models/qwen35-35b-a3b"
MODEL_FILE="$(find "$MODEL_DIR" -type f -name '*Q6_K*.gguf' | head -1 2>/dev/null)"
if [ -z "$MODEL_FILE" ]; then
    echo "모델 파일을 찾지 못했습니다: $MODEL_DIR"
    exit 1
fi
for CACHE_TYPE in q8_0 turbo4 turbo3; do
    echo ""
    echo "=== $CACHE_TYPE ==="
    "$HOME/.llama-cpp-turboquant/build/bin/llama-bench" \
        -m "$MODEL_FILE" \
        --cache-type-k "$CACHE_TYPE" \
        --cache-type-v "$CACHE_TYPE" \
        -ngl 99 \
        -t "$(sysctl -n hw.ncpu 2>/dev/null || echo 8)" \
        -p 512 \
        -n 128
 done

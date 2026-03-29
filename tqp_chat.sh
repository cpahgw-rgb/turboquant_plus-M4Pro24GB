#!/bin/bash
set -euo pipefail
MODEL_DIR="$HOME/models/qwen35-35b-a3b"
MODEL_FILE="$(find "$MODEL_DIR" -type f -name '*Q6_K*.gguf' | head -1 2>/dev/null)"
if [ -z "$MODEL_FILE" ]; then
    echo "모델 파일을 찾지 못했습니다: $MODEL_DIR"
    exit 1
fi
exec "$HOME/.llama-cpp-turboquant/build/bin/llama-cli" \
    -m "$MODEL_FILE" \
    --jinja \
    --cache-type-k turbo4 \
    --cache-type-v turbo4 \
    -ngl 99 \
    -c 65536 \
    --temp 0.7 \
    --top-p 0.9 \
    -i \
    -cnv \
    "$@"

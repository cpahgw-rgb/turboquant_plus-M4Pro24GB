#!/bin/bash
set -euo pipefail
MODEL_DIR="$HOME/models/qwen35-35b-a3b"
MODEL_FILE="$(find "$MODEL_DIR" -type f -name '*Q6_K*.gguf' | head -1 2>/dev/null)"
HOST="127.0.0.1"
PORT="8080"
if [ $# -ge 1 ]; then HOST="$1"; shift; fi
if [ $# -ge 1 ]; then PORT="$1"; shift; fi
if [ -z "$MODEL_FILE" ]; then
    echo "모델 파일을 찾지 못했습니다: $MODEL_DIR"
    exit 1
fi
exec "$HOME/.llama-cpp-turboquant/build/bin/llama-server" \
    -m "$MODEL_FILE" \
    --jinja \
    --alias qwen35-turbo \
    --cache-type-k turbo4 \
    --cache-type-v turbo4 \
    -ngl 99 \
    -c 65536 \
    --host "$HOST" \
    --port "$PORT" \
    "$@"

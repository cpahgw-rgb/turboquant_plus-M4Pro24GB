#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/turboquant_common.sh"

MODEL_FILE="$(tqp_find_model)"
LLAMA_SERVER="$TQP_BUILD_DIR/bin/llama-server"
HOST="${TQP_HOST:-$TQP_DEFAULT_HOST}"
PORT="${TQP_PORT:-$TQP_DEFAULT_PORT}"
CTX_SIZE="${TQP_CTX_SIZE:-32768}"
GPU_LAYERS="${TQP_GPU_LAYERS:-$TQP_DEFAULT_GPU_LAYERS}"

if [ $# -ge 1 ]; then HOST="$1"; shift; fi
if [ $# -ge 1 ]; then PORT="$1"; shift; fi

tqp_require_binary "$LLAMA_SERVER"

exec "$LLAMA_SERVER" \
    -m "$MODEL_FILE" \
    --jinja \
    --alias qwen35-turbo \
    --cache-type-k turbo4 \
    --cache-type-v turbo4 \
    -ngl "$GPU_LAYERS" \
    -c "$CTX_SIZE" \
    --host "$HOST" \
    --port "$PORT" \
    "$@"

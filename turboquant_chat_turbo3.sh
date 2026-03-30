#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/turboquant_common.sh"

MODEL_FILE="$(tqp_find_model)"
LLAMA_CLI="$TQP_BUILD_DIR/bin/llama-cli"
CTX_SIZE="${TQP_CTX_SIZE:-65536}"
GPU_LAYERS="${TQP_GPU_LAYERS:-$TQP_DEFAULT_GPU_LAYERS}"
TEMP="${TQP_TEMP:-$TQP_DEFAULT_TEMP}"
TOP_P="${TQP_TOP_P:-$TQP_DEFAULT_TOP_P}"

tqp_require_binary "$LLAMA_CLI"

exec "$LLAMA_CLI" \
    -m "$MODEL_FILE" \
    --jinja \
    --cache-type-k turbo3 \
    --cache-type-v turbo3 \
    -ngl "$GPU_LAYERS" \
    -c "$CTX_SIZE" \
    --temp "$TEMP" \
    --top-p "$TOP_P" \
    -cnv \
    "$@"

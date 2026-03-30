#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/turboquant_common.sh"

MODEL_FILE="$(tqp_find_model)"
LLAMA_BENCH="$TQP_BUILD_DIR/bin/llama-bench"
GPU_LAYERS="${TQP_GPU_LAYERS:-$TQP_DEFAULT_GPU_LAYERS}"
THREADS="${TQP_THREADS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 8)}"
PROMPT_TOKENS="${TQP_BENCH_PROMPT_TOKENS:-512}"
GEN_TOKENS="${TQP_BENCH_GEN_TOKENS:-128}"

tqp_require_binary "$LLAMA_BENCH"

for CACHE_TYPE in q8_0 turbo4 turbo3; do
    echo ""
    echo "=== $CACHE_TYPE ==="
    "$LLAMA_BENCH" \
        -m "$MODEL_FILE" \
        --cache-type-k "$CACHE_TYPE" \
        --cache-type-v "$CACHE_TYPE" \
        -ngl "$GPU_LAYERS" \
        -t "$THREADS" \
        -p "$PROMPT_TOKENS" \
        -n "$GEN_TOKENS"
done

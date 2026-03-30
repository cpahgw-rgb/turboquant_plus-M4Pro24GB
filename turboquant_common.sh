#!/bin/bash
set -euo pipefail

TQP_BUILD_DIR="${TQP_BUILD_DIR:-$HOME/.llama-cpp-turboquant/build}"
TQP_MODEL_DIR="${TQP_MODEL_DIR:-$HOME/models/qwen35-35b-a3b}"
TQP_MODEL_GLOB="${TQP_MODEL_GLOB:-*Q6_K*.gguf}"
TQP_DEFAULT_GPU_LAYERS="${TQP_DEFAULT_GPU_LAYERS:-99}"
TQP_DEFAULT_TEMP="${TQP_DEFAULT_TEMP:-0.7}"
TQP_DEFAULT_TOP_P="${TQP_DEFAULT_TOP_P:-0.9}"
TQP_DEFAULT_HOST="${TQP_DEFAULT_HOST:-127.0.0.1}"
TQP_DEFAULT_PORT="${TQP_DEFAULT_PORT:-8080}"

tqp_find_model() {
    local model_file

    model_file="$(find "$TQP_MODEL_DIR" -type f -name "$TQP_MODEL_GLOB" 2>/dev/null | sort | head -1)"

    if [ -z "$model_file" ]; then
        echo "모델 파일을 찾지 못했습니다: $TQP_MODEL_DIR"
        echo "현재 패턴: $TQP_MODEL_GLOB"
        exit 1
    fi

    printf '%s\n' "$model_file"
}

tqp_require_binary() {
    local binary_path="$1"

    if [ ! -x "$binary_path" ]; then
        echo "실행 파일을 찾지 못했습니다: $binary_path"
        echo "먼저 ./setup_turboquant_plus.sh 를 다시 실행해 주세요."
        exit 1
    fi
}

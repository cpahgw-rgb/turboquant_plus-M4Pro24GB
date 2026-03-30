#!/bin/bash
# =============================================================================
# llama.cpp + TurboQuant 포크 셋업
# 실제 빌드 대상: TheTom/llama-cpp-turboquant (feature/turboquant-kv-cache)
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.llama-cpp-turboquant"
BUILD_DIR="$INSTALL_DIR/build"
REPO_URL="https://github.com/TheTom/llama-cpp-turboquant.git"
REPO_BRANCH="feature/turboquant-kv-cache"
MODEL_REPO="bartowski/Qwen_Qwen3.5-35B-A3B-GGUF"
MODEL_GLOB="*Q6_K*"
MODEL_DIR="$HOME/models/qwen35-35b-a3b"
CPU_COUNT="$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
RAM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
RAM_GB=$((RAM_BYTES / 1073741824))
CHIP="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Apple Silicon')"

need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo -e "${RED}$1 명령을 찾을 수 없습니다.${NC}"
        exit 1
    fi
}

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  llama.cpp + TurboQuant (Metal)                            ║"
echo "║  Qwen3.5-35B-A3B | turbo3/turbo4 KV cache                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}[1/5] 시스템 확인...${NC}"
if [ "$(uname -m)" != "arm64" ]; then
    echo -e "${RED}Apple Silicon 전용입니다.${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ ${CHIP} / ${RAM_GB}GB${NC}"
if [ "$RAM_GB" -lt 32 ]; then
    echo -e "${YELLOW}  ⚠ 35B-A3B 실사용은 32GB 이상을 권장합니다.${NC}"
fi

echo ""
echo -e "${BLUE}[2/5] 개발 도구 확인...${NC}"
if ! xcode-select -p >/dev/null 2>&1; then
    echo -e "${YELLOW}  Xcode Command Line Tools 설치가 필요합니다.${NC}"
    xcode-select --install
    echo -e "${YELLOW}  설치 완료 후 다시 실행해주세요.${NC}"
    exit 1
fi

need_cmd git
if ! command -v cmake >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        echo -e "${CYAN}  cmake 설치 중...${NC}"
        brew install cmake
    else
        echo -e "${RED}cmake가 없고 Homebrew도 찾지 못했습니다.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}  ✓ git $(git --version | awk '{print $3}')${NC}"
echo -e "${GREEN}  ✓ cmake $(cmake --version | head -1 | awk '{print $3}')${NC}"

echo ""
echo -e "${BLUE}[3/5] llama.cpp TurboQuant 포크 준비...${NC}"
if [ -d "$INSTALL_DIR/.git" ]; then
    CURRENT_REMOTE="$(git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || true)"
    if [ "$CURRENT_REMOTE" != "$REPO_URL" ]; then
        echo -e "${RED}  $INSTALL_DIR 가 다른 저장소를 가리키고 있습니다.${NC}"
        echo -e "${YELLOW}  origin: $CURRENT_REMOTE${NC}"
        echo -e "${YELLOW}  기대값: $REPO_URL${NC}"
        exit 1
    fi
    echo -e "${CYAN}  기존 설치 업데이트 중...${NC}"
    git -C "$INSTALL_DIR" fetch origin --quiet
    git -C "$INSTALL_DIR" checkout --quiet "$REPO_BRANCH"
    git -C "$INSTALL_DIR" pull --ff-only --quiet origin "$REPO_BRANCH"
elif [ -e "$INSTALL_DIR" ]; then
    echo -e "${RED}  $INSTALL_DIR 가 이미 존재하지만 git 저장소가 아닙니다.${NC}"
    exit 1
else
    echo -e "${CYAN}  포크 클론 중...${NC}"
    git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" "$INSTALL_DIR"
fi

echo -e "${CYAN}  Metal 빌드 중...${NC}"
cmake -S "$INSTALL_DIR" -B "$BUILD_DIR" \
    -DGGML_METAL=ON \
    -DGGML_METAL_EMBED_LIBRARY=ON \
    -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" --config Release -j"$CPU_COUNT"

if ! "$BUILD_DIR/bin/llama-server" --help 2>/dev/null | grep -q 'turbo3'; then
    echo -e "${RED}  빌드는 끝났지만 turbo3/turbo4 옵션을 확인하지 못했습니다.${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ 빌드 완료${NC}"

echo ""
echo -e "${BLUE}[4/5] 모델 안내...${NC}"
echo "  추천 모델 저장소: $MODEL_REPO"
echo "  기본 경로: $MODEL_DIR"
echo ""
echo "  다운로드 예시:"
echo "    pip install huggingface_hub"
echo "    huggingface-cli download $MODEL_REPO \\" 
echo "      --include '$MODEL_GLOB' \\" 
echo "      --local-dir $MODEL_DIR"

echo ""
echo -e "${BLUE}[5/5] 실행 스크립트 생성...${NC}"

cat > "$SCRIPT_DIR/turboquant_common.sh" <<'EOFCOMMON'
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
EOFCOMMON
chmod +x "$SCRIPT_DIR/turboquant_common.sh"

cat > "$SCRIPT_DIR/turboquant_chat.sh" <<'EOFCHAT'
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/turboquant_common.sh"

MODEL_FILE="$(tqp_find_model)"
LLAMA_CLI="$TQP_BUILD_DIR/bin/llama-cli"
CTX_SIZE="${TQP_CTX_SIZE:-32768}"
GPU_LAYERS="${TQP_GPU_LAYERS:-$TQP_DEFAULT_GPU_LAYERS}"
TEMP="${TQP_TEMP:-$TQP_DEFAULT_TEMP}"
TOP_P="${TQP_TOP_P:-$TQP_DEFAULT_TOP_P}"

tqp_require_binary "$LLAMA_CLI"

exec "$LLAMA_CLI" \
    -m "$MODEL_FILE" \
    --jinja \
    --cache-type-k turbo4 \
    --cache-type-v turbo4 \
    -ngl "$GPU_LAYERS" \
    -c "$CTX_SIZE" \
    --temp "$TEMP" \
    --top-p "$TOP_P" \
    -cnv \
    "$@"
EOFCHAT
chmod +x "$SCRIPT_DIR/turboquant_chat.sh"

cat > "$SCRIPT_DIR/turboquant_chat_turbo3.sh" <<'EOFCHAT3'
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
EOFCHAT3
chmod +x "$SCRIPT_DIR/turboquant_chat_turbo3.sh"

cat > "$SCRIPT_DIR/turboquant_chat_long.sh" <<'EOFCHATLONG'
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
    --cache-type-k turbo4 \
    --cache-type-v turbo4 \
    -ngl "$GPU_LAYERS" \
    -c "$CTX_SIZE" \
    --temp "$TEMP" \
    --top-p "$TOP_P" \
    -cnv \
    "$@"
EOFCHATLONG
chmod +x "$SCRIPT_DIR/turboquant_chat_long.sh"

cat > "$SCRIPT_DIR/turboquant_server.sh" <<'EOFSERVER'
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
EOFSERVER
chmod +x "$SCRIPT_DIR/turboquant_server.sh"

cat > "$SCRIPT_DIR/turboquant_bench.sh" <<'EOFBENCH'
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
EOFBENCH
chmod +x "$SCRIPT_DIR/turboquant_bench.sh"

cat > "$SCRIPT_DIR/tqp_chat.sh" <<'EOFLEGACY'
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/turboquant_chat.sh" "$@"
EOFLEGACY
chmod +x "$SCRIPT_DIR/tqp_chat.sh"

cat > "$SCRIPT_DIR/tqp_chat_turbo3.sh" <<'EOFLEGACY3'
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/turboquant_chat_turbo3.sh" "$@"
EOFLEGACY3
chmod +x "$SCRIPT_DIR/tqp_chat_turbo3.sh"

cat > "$SCRIPT_DIR/tqp_server.sh" <<'EOFLEGACYSRV'
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/turboquant_server.sh" "$@"
EOFLEGACYSRV
chmod +x "$SCRIPT_DIR/tqp_server.sh"

cat > "$SCRIPT_DIR/tqp_bench.sh" <<'EOFLEGACYBENCH'
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/turboquant_bench.sh" "$@"
EOFLEGACYBENCH
chmod +x "$SCRIPT_DIR/tqp_bench.sh"

echo -e "${GREEN}  ✓ turboquant_common.sh${NC}"
echo -e "${GREEN}  ✓ turboquant_chat.sh${NC}"
echo -e "${GREEN}  ✓ turboquant_chat_turbo3.sh${NC}"
echo -e "${GREEN}  ✓ turboquant_chat_long.sh${NC}"
echo -e "${GREEN}  ✓ turboquant_server.sh${NC}"
echo -e "${GREEN}  ✓ turboquant_bench.sh${NC}"
echo -e "${GREEN}  ✓ tqp_* compatibility wrappers${NC}"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗"
echo -e "║                 llama.cpp TurboQuant 준비 완료             ║"
echo -e "╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "설치 경로: $INSTALL_DIR"
echo "다음 단계:"
echo "  1. huggingface-cli download $MODEL_REPO --include '$MODEL_GLOB' --local-dir $MODEL_DIR"
echo "  2. ./turboquant_chat.sh"
echo "     긴 컨텍스트가 필요하면: TQP_CTX_SIZE=65536 ./turboquant_chat_long.sh"
echo "  3. ./turboquant_server.sh"

#!/bin/bash
# =============================================================================
# Local LLM 설치 상태 점검
# =============================================================================

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RAM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
RAM_GB=$((RAM_BYTES / 1073741824))

check() {
    if eval "$2" >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓ $1${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}  ✗ $1${NC}"
        FAIL=$((FAIL + 1))
    fi
}

detect() {
    if eval "$2" >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓ 감지됨: $1${NC}"
    else
        echo -e "${YELLOW}  - 없음: $1${NC}"
    fi
}

echo ""
echo -e "${CYAN}Local LLM 설치 상태 점검${NC}"
echo "================================"

echo ""
echo "[시스템]"
check "Apple Silicon (arm64)" "[ \"$(uname -m)\" = arm64 ]"
check "RAM ${RAM_GB}GB (최소 16GB 권장)" "[ $RAM_GB -ge 16 ]"

echo ""
echo "[llama.cpp + TurboQuant]"
detect "TurboQuant 포크 저장소" "[ -d \"$HOME/.llama-cpp-turboquant/.git\" ]"
detect "llama-cli" "[ -x \"$HOME/.llama-cpp-turboquant/build/bin/llama-cli\" ]"
detect "llama-server" "[ -x \"$HOME/.llama-cpp-turboquant/build/bin/llama-server\" ]"
detect "tqp_chat.sh" "[ -x \"$SCRIPT_DIR/tqp_chat.sh\" ]"
detect "tqp_server.sh" "[ -x \"$SCRIPT_DIR/tqp_server.sh\" ]"

echo ""
echo "[flash-moe]"
detect "flash-moe 저장소" "[ -d \"$HOME/.flash-moe/.git\" ]"
detect "flash-moe chat" "[ -x \"$HOME/.flash-moe/metal_infer/chat\" ]"
detect "flash_chat.sh" "[ -x \"$SCRIPT_DIR/flash_chat.sh\" ]"

echo ""
echo "[TurboQuant MLX 실험 경로]"
detect "MLX 가상환경" "[ -d \"$HOME/.turboquant_mlx\" ]"
detect "mlx_tq_chat.sh" "[ -x \"$SCRIPT_DIR/mlx_tq_chat.sh\" ]"
detect "turboquant_mlx import" "[ -x \"$HOME/.turboquant_mlx/bin/python3\" ] && $HOME/.turboquant_mlx/bin/python3 -c 'import turboquant_mlx'"

echo ""
echo "[공통 도구]"
check "git" "command -v git"
check "python3" "command -v python3"
check "cmake" "command -v cmake"

echo ""
echo "================================"
TOTAL=$((PASS + FAIL))
if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}결과: ${PASS}/${TOTAL} 필수 점검 통과${NC}"
else
    echo -e "${YELLOW}결과: ${PASS}/${TOTAL} 필수 점검 통과, ${FAIL}개 확인 필요${NC}"
fi

echo ""
echo "권장 시작점:"
echo "  1. ./setup_turboquant_plus.sh"
echo "  2. 필요할 때만 ./setup_flash_moe.sh"
echo "  3. 실험용으로 ./setup_turboquant.sh"
echo ""

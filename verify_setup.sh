#!/bin/bash
# =============================================================================
# TurboQuant MLX — 환경 검증
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
    if eval "$2" > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ $1${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}  ✗ $1${NC}"
        FAIL=$((FAIL + 1))
    fi
}

echo ""
echo -e "${CYAN}TurboQuant MLX — 환경 검증${NC}"
echo "================================"

echo ""
echo "[시스템]"
check "Apple Silicon (arm64)" "[ $(uname -m) = arm64 ]"
RAM_GB=$(($(sysctl -n hw.memsize) / 1073741824))
check "RAM ${RAM_GB}GB (최소 8GB)" "[ $RAM_GB -ge 8 ]"
check "RAM ${RAM_GB}GB (권장 16GB+)" "[ $RAM_GB -ge 16 ]"

echo ""
echo "[Python 환경]"
VENV="$HOME/.turboquant_mlx"
check "가상환경 존재 ($VENV)" "[ -d $VENV ]"
check "Python 실행 가능" "$VENV/bin/python3 --version"

echo ""
echo "[패키지]"
check "mlx" "$VENV/bin/python3 -c 'import mlx; print(mlx.__version__)'"
check "mlx_lm" "$VENV/bin/python3 -c 'import mlx_lm'"
check "turboquant_mlx" "$VENV/bin/python3 -c 'import turboquant_mlx'"
check "huggingface_hub" "$VENV/bin/python3 -c 'import huggingface_hub'"

echo ""
echo "[설정]"
CONFIG="$HOME/.config/turboquant/config.json"
check "config.json 존재" "[ -f $CONFIG ]"
if [ -f "$CONFIG" ]; then
    check "config.json 유효" "$VENV/bin/python3 -c \"import json; c=json.load(open('$CONFIG')); print(c['models']['primary']['name'])\""

    PRIMARY=$($VENV/bin/python3 -c "import json; print(json.load(open('$CONFIG'))['models']['primary']['id'])" 2>/dev/null)
    if [ -n "$PRIMARY" ]; then
        echo ""
        echo "[모델 설정 확인]"
        echo -e "  메인: $PRIMARY"
        SECONDARY=$($VENV/bin/python3 -c "import json; print(json.load(open('$CONFIG'))['models']['reasoning']['id'])" 2>/dev/null)
        echo -e "  분석: $SECONDARY"
        FAST=$($VENV/bin/python3 -c "import json; print(json.load(open('$CONFIG'))['models']['fast']['id'])" 2>/dev/null)
        echo -e "  빠른: $FAST"
    fi
fi

echo ""
echo "[실행 스크립트]"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
check "chat.sh" "[ -x $SCRIPT_DIR/chat.sh ]"
check "server.sh" "[ -x $SCRIPT_DIR/server.sh ]"
check "download_models.sh" "[ -x $SCRIPT_DIR/download_models.sh ]"

echo ""
echo "================================"
TOTAL=$((PASS + FAIL))
if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}결과: ${PASS}/${TOTAL} 모두 통과!${NC}"
    echo ""
    echo "다음 단계:"
    echo "  1. ./download_models.sh  — 모델 다운로드"
    echo "  2. ./chat.sh             — 대화 시작"
else
    echo -e "${YELLOW}결과: ${PASS}/${TOTAL} 통과, ${FAIL}개 실패${NC}"
    echo ""
    echo "./setup_turboquant.sh 를 먼저 실행해주세요."
fi
echo ""

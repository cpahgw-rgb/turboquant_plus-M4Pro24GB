#!/bin/bash
# =============================================================================
# flash-moe 셋업
# Qwen3.5-397B-A17B를 SSD expert streaming으로 실행하는 별도 엔진
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.flash-moe"
MODEL_DIR="$HOME/qwen3.5-397b"
RAM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
RAM_GB=$((RAM_BYTES / 1073741824))
CHIP="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Apple Silicon')"
FREE_DISK_GB="$(df -g ~ 2>/dev/null | tail -1 | awk '{print $4}' || echo '?')"

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  flash-moe — 397B MoE on Apple Silicon                    ║"
echo "║  SSD expert streaming | Pure C/Metal                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}[1/5] 시스템 확인...${NC}"
if [ "$(uname -m)" != "arm64" ]; then
    echo -e "${RED}Apple Silicon 전용입니다.${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ ${CHIP} / ${RAM_GB}GB${NC}"
echo -e "${GREEN}  ✓ 디스크 여유: ${FREE_DISK_GB}GB${NC}"
if [ "$RAM_GB" -lt 48 ]; then
    echo -e "${YELLOW}  ⚠ 48GB 이상에서 특히 유리합니다.${NC}"
fi
if [ "$FREE_DISK_GB" != "?" ] && [ "$FREE_DISK_GB" -lt 250 ]; then
    echo -e "${YELLOW}  ⚠ 모델/변환 산출물까지 감안하면 250GB 이상 여유를 권장합니다.${NC}"
fi

echo ""
echo -e "${BLUE}[2/5] 개발 도구 확인...${NC}"
if ! xcode-select -p >/dev/null 2>&1; then
    echo -e "${YELLOW}  Xcode Command Line Tools 설치가 필요합니다.${NC}"
    xcode-select --install
    exit 1
fi
if ! xcrun -f metal >/dev/null 2>&1; then
    echo -e "${RED}  Metal 컴파일러를 찾지 못했습니다.${NC}"
    exit 1
fi
if ! command -v git >/dev/null 2>&1; then
    echo -e "${RED}git를 찾지 못했습니다.${NC}"
    exit 1
fi
if ! command -v make >/dev/null 2>&1; then
    echo -e "${RED}make를 찾지 못했습니다.${NC}"
    exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        echo -e "${CYAN}  Python 설치 중...${NC}"
        brew install python@3.11
    else
        echo -e "${RED}python3를 찾지 못했습니다.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}  ✓ git / make / python3 / metal${NC}"

echo ""
echo -e "${BLUE}[3/5] flash-moe 준비...${NC}"
if [ -d "$INSTALL_DIR/.git" ]; then
    echo -e "${CYAN}  기존 설치 업데이트 중...${NC}"
    git -C "$INSTALL_DIR" pull --ff-only --quiet || true
elif [ -e "$INSTALL_DIR" ]; then
    echo -e "${RED}  $INSTALL_DIR 가 이미 존재하지만 git 저장소가 아닙니다.${NC}"
    exit 1
else
    echo -e "${CYAN}  저장소 클론 중...${NC}"
    git clone https://github.com/danveloper/flash-moe.git "$INSTALL_DIR"
fi

if [ ! -d "$INSTALL_DIR/metal_infer" ]; then
    echo -e "${RED}  flash-moe 구조에서 metal_infer 디렉터리를 찾지 못했습니다.${NC}"
    exit 1
fi

echo -e "${CYAN}  빌드 중...${NC}"
make -C "$INSTALL_DIR/metal_infer"
echo -e "${GREEN}  ✓ 빌드 완료${NC}"

echo ""
echo -e "${BLUE}[4/5] 모델 준비 안내...${NC}"
echo "  공식 모델 저장소: Qwen/Qwen3.5-397B-A17B"
echo "  기본 다운로드 경로: $MODEL_DIR"
echo ""
echo "  권장 순서:"
echo "    1. pip install huggingface_hub"
echo "    2. huggingface-cli download Qwen/Qwen3.5-397B-A17B --local-dir $MODEL_DIR"
echo "    3. cd $INSTALL_DIR/metal_infer"
echo "    4. python3 extract_weights.py $MODEL_DIR"
echo "    5. python3 ../repack_experts.py $MODEL_DIR ./packed_experts/"

echo ""
echo -e "${BLUE}[5/5] 실행 스크립트 생성...${NC}"
cat > "$SCRIPT_DIR/flash_chat.sh" <<EOFCHAT
#!/bin/bash
set -euo pipefail
cd "$INSTALL_DIR/metal_infer"
exec ./chat
EOFCHAT
chmod +x "$SCRIPT_DIR/flash_chat.sh"

cat > "$SCRIPT_DIR/flash_infer.sh" <<EOFINFER
#!/bin/bash
set -euo pipefail
cd "$INSTALL_DIR/metal_infer"
if [ \$# -eq 0 ]; then
    echo '사용법: ./flash_infer.sh "질문"'
    exit 1
fi
exec ./infer --prompt "\$*" --tokens 500
EOFINFER
chmod +x "$SCRIPT_DIR/flash_infer.sh"

cat > "$SCRIPT_DIR/flash_bench.sh" <<EOFBENCH
#!/bin/bash
set -euo pipefail
cd "$INSTALL_DIR/metal_infer"
exec ./infer --prompt 'Hello' --tokens 20 --timing
EOFBENCH
chmod +x "$SCRIPT_DIR/flash_bench.sh"

echo -e "${GREEN}  ✓ flash_chat.sh${NC}"
echo -e "${GREEN}  ✓ flash_infer.sh${NC}"
echo -e "${GREEN}  ✓ flash_bench.sh${NC}"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗"
echo -e "║                    flash-moe 준비 완료                     ║"
echo -e "╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "설치 경로: $INSTALL_DIR"
echo "모델 경로: $MODEL_DIR"
echo "다음 단계:"
echo "  1. huggingface-cli download Qwen/Qwen3.5-397B-A17B --local-dir $MODEL_DIR"
echo "  2. cd $INSTALL_DIR/metal_infer"
echo "  3. python3 extract_weights.py $MODEL_DIR"
echo "  4. python3 ../repack_experts.py $MODEL_DIR ./packed_experts/"
echo "  5. ./flash_chat.sh"

#!/bin/bash
# =============================================================================
# flash-moe 셋업 — 397B MoE on M4 Pro 48GB
# Pure C/Metal 추론 엔진 (Python 불필요)
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  flash-moe — 397B Parameter Model on M4 Pro 48GB          ║"
echo "║  Pure C/Metal | SSD Expert Streaming | 4.4+ tok/s          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# =============================================================================
# 1. 시스템 확인
# =============================================================================
echo -e "${BLUE}[1/5] 시스템 확인...${NC}"

ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
    echo -e "${RED}Apple Silicon 전용입니다.${NC}"
    exit 1
fi

TOTAL_RAM_GB=$(($(sysctl -n hw.memsize) / 1073741824))
CHIP=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon")
FREE_DISK_GB=$(df -g ~ 2>/dev/null | tail -1 | awk '{print $4}' || echo "?")

echo -e "${GREEN}  ✓ $CHIP / ${TOTAL_RAM_GB}GB 통합 메모리${NC}"
echo -e "${GREEN}  ✓ 디스크 여유: ${FREE_DISK_GB}GB${NC}"

if [ "$TOTAL_RAM_GB" -lt 48 ]; then
    echo -e "${YELLOW}  ⚠ flash-moe는 48GB 이상 권장. 현재: ${TOTAL_RAM_GB}GB${NC}"
    echo -e "${YELLOW}    계속 진행하지만, 성능이 저하될 수 있습니다.${NC}"
fi

# 디스크 공간 확인 (209GB 모델 + 5.5GB 가중치)
if [ "$FREE_DISK_GB" != "?" ] && [ "$FREE_DISK_GB" -lt 250 ]; then
    echo -e "${YELLOW}  ⚠ 디스크 여유 ${FREE_DISK_GB}GB — 최소 250GB 권장${NC}"
    echo -e "${YELLOW}    모델: ~209GB + 가중치: ~5.5GB + 임시파일${NC}"
    read -p "  계속하시겠습니까? (y/N) " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "취소되었습니다."
        exit 0
    fi
fi

# =============================================================================
# 2. 빌드 도구 확인
# =============================================================================
echo ""
echo -e "${BLUE}[2/5] 빌드 도구 확인...${NC}"

# Xcode CLT
if ! xcode-select -p &> /dev/null; then
    echo -e "${YELLOW}  Xcode Command Line Tools 설치 중...${NC}"
    xcode-select --install
    echo -e "${YELLOW}  설치 완료 후 다시 실행해주세요.${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Xcode Command Line Tools${NC}"

# Metal 컴파일러
if ! xcrun -f metal &> /dev/null; then
    echo -e "${RED}  Metal 컴파일러를 찾을 수 없습니다. Xcode를 설치해주세요.${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Metal 컴파일러${NC}"

# Python (모델 변환용)
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}  Python3 필요 (모델 가중치 변환용). Homebrew로 설치합니다...${NC}"
    brew install python@3.11
fi
echo -e "${GREEN}  ✓ $(python3 --version)${NC}"

# =============================================================================
# 3. flash-moe 소스 클론 & 빌드
# =============================================================================
echo ""
echo -e "${BLUE}[3/5] flash-moe 소스 클론 & 빌드...${NC}"

FLASH_MOE_DIR="$HOME/.flash-moe"

if [ -d "$FLASH_MOE_DIR" ]; then
    echo -e "${CYAN}  기존 설치 감지. 업데이트 중...${NC}"
    cd "$FLASH_MOE_DIR"
    git pull -q 2>/dev/null || true
else
    echo -e "${CYAN}  소스 클론 중...${NC}"
    git clone https://github.com/danveloper/flash-moe.git "$FLASH_MOE_DIR"
    cd "$FLASH_MOE_DIR"
fi

echo -e "${CYAN}  빌드 중...${NC}"
cd metal_infer
make clean 2>/dev/null || true
make
echo -e "${GREEN}  ✓ 빌드 완료 (infer, chat)${NC}"

# =============================================================================
# 4. 모델 가중치 준비 안내
# =============================================================================
echo ""
echo -e "${BLUE}[4/5] 모델 가중치 준비...${NC}"

echo -e "${CYAN}"
echo "  ┌──────────────────────────────────────────────────────┐"
echo "  │  모델 가중치를 다운로드하고 변환해야 합니다.          │"
echo "  │                                                      │"
echo "  │  아래 작업은 대용량(~210GB)이므로 수동으로            │"
echo "  │  진행하는 것을 권장합니다.                             │"
echo "  └──────────────────────────────────────────────────────┘"
echo -e "${NC}"

echo "  순서:"
echo ""
echo "  1) HuggingFace에서 모델 다운로드:"
echo -e "     ${YELLOW}pip install huggingface_hub${NC}"
echo -e "     ${YELLOW}huggingface-cli download Qwen/Qwen3.5-397B-A17B-FP8 \\${NC}"
echo -e "     ${YELLOW}  --local-dir ~/qwen3.5-397b${NC}"
echo ""
echo "  2) 가중치 추출 (non-expert):"
echo -e "     ${YELLOW}cd $FLASH_MOE_DIR/metal_infer${NC}"
echo -e "     ${YELLOW}python3 extract_weights.py ~/qwen3.5-397b${NC}"
echo ""
echo "  3) 전문가 레이어 패킹 (4-bit):"
echo -e "     ${YELLOW}python3 ../repack_experts.py ~/qwen3.5-397b ./packed_experts/${NC}"
echo ""
echo "  ⚠ 전체 과정에 수 시간이 소요될 수 있습니다."

# =============================================================================
# 5. 실행 스크립트 생성
# =============================================================================
echo ""
echo -e "${BLUE}[5/5] 실행 스크립트 생성...${NC}"

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# flash-moe 채팅
cat > "$SCRIPTS_DIR/flash_chat.sh" << EOFCHAT
#!/bin/bash
# flash-moe — 397B Interactive Chat (4.4+ tok/s)
cd "$FLASH_MOE_DIR/metal_infer"
./chat
EOFCHAT
chmod +x "$SCRIPTS_DIR/flash_chat.sh"

# flash-moe 추론
cat > "$SCRIPTS_DIR/flash_infer.sh" << EOFINFER
#!/bin/bash
# flash-moe — 397B Single Prompt Inference
cd "$FLASH_MOE_DIR/metal_infer"
if [ -n "\$1" ]; then
    ./infer --prompt "\$*" --tokens 500
else
    echo "사용법: ./flash_infer.sh \"질문 내용\""
    echo "예시:   ./flash_infer.sh \"양자 컴퓨팅을 설명해줘\""
fi
EOFINFER
chmod +x "$SCRIPTS_DIR/flash_infer.sh"

# flash-moe 벤치마크
cat > "$SCRIPTS_DIR/flash_bench.sh" << EOFBENCH
#!/bin/bash
# flash-moe — 레이어별 타이밍 벤치마크
cd "$FLASH_MOE_DIR/metal_infer"
echo "레이어별 타이밍 분석 실행 중..."
./infer --prompt "Hello, how are you today?" --tokens 20 --timing
EOFBENCH
chmod +x "$SCRIPTS_DIR/flash_bench.sh"

echo -e "${GREEN}  ✓ flash_chat.sh   — 대화형 채팅 (397B, 툴 콜링 지원)${NC}"
echo -e "${GREEN}  ✓ flash_infer.sh  — 단일 프롬프트 추론${NC}"
echo -e "${GREEN}  ✓ flash_bench.sh  — 성능 벤치마크${NC}"

# =============================================================================
# 완료
# =============================================================================
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗"
echo -e "║                    flash-moe 셋업 완료                      ║"
echo -e "╠═══════════════════════════════════════════════════════════════╣${NC}"
echo ""
echo -e "  ${BOLD}Qwen3.5-397B-A17B${NC} — 397B 파라미터, 토큰당 17B 활성화"
echo -e "  Pure C/Metal | SSD Expert Streaming | 4.4+ tok/s"
echo ""
echo -e "  ${BOLD}메모리 사용:${NC}"
echo -e "    모델 가중치:  5.5GB (mmap)"
echo -e "    Metal 버퍼:   ~0.2GB"
echo -e "    페이지 캐시:  ~42GB (전문가 캐싱, 71% 히트율)"
echo ""
echo -e "  ${BOLD}남은 작업:${NC}"
echo -e "  1. 모델 가중치 다운로드 & 변환 (위의 안내 참고)"
echo -e "  2. ${YELLOW}./flash_chat.sh${NC}  — 대화 시작"
echo -e "  3. ${YELLOW}./flash_bench.sh${NC} — 벤치마크 확인"
echo ""
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

#!/bin/bash
# =============================================================================
# turboquant_plus 셋업 — llama.cpp + TurboQuant Metal 커널
# Qwen3.5-35B-A3B MoE + KV 캐시 4.9x 압축 + Sparse V
# M4 Pro 48GB 최적화
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
echo "║  turboquant_plus — TurboQuant + llama.cpp + Metal          ║"
echo "║  Qwen3.5-35B-A3B MoE | KV 4.9x 압축 | Sparse V           ║"
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

echo -e "${GREEN}  ✓ $CHIP / ${TOTAL_RAM_GB}GB${NC}"

# =============================================================================
# 2. 빌드 도구 확인
# =============================================================================
echo ""
echo -e "${BLUE}[2/5] 빌드 도구 확인...${NC}"

if ! xcode-select -p &> /dev/null; then
    echo -e "${YELLOW}  Xcode CLT 설치 필요...${NC}"
    xcode-select --install
    echo -e "${YELLOW}  설치 완료 후 다시 실행해주세요.${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Xcode Command Line Tools${NC}"

if ! command -v cmake &> /dev/null; then
    echo -e "${CYAN}  cmake 설치 중...${NC}"
    if command -v brew &> /dev/null; then
        brew install cmake
    else
        echo -e "${RED}  Homebrew가 필요합니다. 먼저 설치해주세요.${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}  ✓ cmake $(cmake --version | head -1 | awk '{print $3}')${NC}"

# =============================================================================
# 3. turboquant_plus 클론 & 빌드
# =============================================================================
echo ""
echo -e "${BLUE}[3/5] turboquant_plus 클론 & 빌드...${NC}"

TQP_DIR="$HOME/.turboquant_plus"

if [ -d "$TQP_DIR" ]; then
    echo -e "${CYAN}  기존 설치 감지. 업데이트 중...${NC}"
    cd "$TQP_DIR"
    git pull -q 2>/dev/null || true
else
    echo -e "${CYAN}  소스 클론 중...${NC}"
    git clone https://github.com/TheTom/turboquant_plus.git "$TQP_DIR"
fi

cd "$TQP_DIR"

echo -e "${CYAN}  빌드 중 (Metal 커널 포함)...${NC}"
mkdir -p build && cd build
cmake .. \
    -DLLAMA_METAL=ON \
    -DLLAMA_METAL_EMBED_LIBRARY=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_TURBOQUANT=ON \
    2>&1 | tail -3
cmake --build . --config Release -j$(sysctl -n hw.ncpu) 2>&1 | tail -5

echo -e "${GREEN}  ✓ 빌드 완료 (Metal + TurboQuant 커널)${NC}"

# =============================================================================
# 4. 모델 다운로드 안내
# =============================================================================
echo ""
echo -e "${BLUE}[4/5] 모델 준비...${NC}"

echo -e "${CYAN}"
echo "  추천 모델: Qwen3.5-35B-A3B (MoE, 토큰당 3B 활성화)"
echo ""
echo "  GGUF 모델 다운로드 방법:"
echo ""
echo -e "  ${YELLOW}# Homebrew로 huggingface-cli 설치 (이미 있으면 스킵)${NC}"
echo -e "  ${YELLOW}pip install huggingface_hub${NC}"
echo ""
echo -e "  ${YELLOW}# GGUF 모델 다운로드 (turbo4 호환, ~20GB)${NC}"
echo -e "  ${YELLOW}huggingface-cli download bartowski/Qwen3.5-35B-A3B-GGUF \\${NC}"
echo -e "  ${YELLOW}  --include \"*Q4_K_M*\" \\${NC}"
echo -e "  ${YELLOW}  --local-dir ~/models/qwen35-35b-a3b${NC}"
echo ""
echo -e "  ${YELLOW}# 대안: 더 작은 모델 (27B dense)${NC}"
echo -e "  ${YELLOW}huggingface-cli download bartowski/Qwen3.5-27B-GGUF \\${NC}"
echo -e "  ${YELLOW}  --include \"*Q4_K_M*\" \\${NC}"
echo -e "  ${YELLOW}  --local-dir ~/models/qwen35-27b${NC}"
echo -e "${NC}"

# =============================================================================
# 5. 실행 스크립트 생성
# =============================================================================
echo ""
echo -e "${BLUE}[5/5] 실행 스크립트 생성...${NC}"

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$TQP_DIR/build"

# 대화형 채팅 (turbo4 KV 캐시)
cat > "$SCRIPTS_DIR/tqp_chat.sh" << EOFCHAT
#!/bin/bash
# turboquant_plus — TurboQuant KV 캐시 + 대화형 채팅
# Qwen3.5-35B-A3B MoE | turbo4 KV (3.8x 압축) | Sparse V

MODEL_DIR="\$HOME/models/qwen35-35b-a3b"
MODEL_FILE=\$(find "\$MODEL_DIR" -name "*.gguf" -type f | head -1 2>/dev/null)

if [ -z "\$MODEL_FILE" ]; then
    echo "모델 파일을 찾을 수 없습니다."
    echo "먼저 모델을 다운로드해주세요:"
    echo "  huggingface-cli download bartowski/Qwen3.5-35B-A3B-GGUF --include '*Q4_K_M*' --local-dir ~/models/qwen35-35b-a3b"
    exit 1
fi

echo "모델: \$MODEL_FILE"
echo "KV 캐시: turbo4 (4.25-bit, 3.8x 압축)"
echo ""

$BUILD_DIR/bin/llama-cli \\
    -m "\$MODEL_FILE" \\
    --cache-type-k turbo4 \\
    --cache-type-v turbo4 \\
    -ngl 99 \\
    -c 65536 \\
    --temp 0.7 \\
    --top-p 0.9 \\
    -i \\
    -cnv
EOFCHAT
chmod +x "$SCRIPTS_DIR/tqp_chat.sh"

# turbo3 모드 (더 강한 압축, 4.9x)
cat > "$SCRIPTS_DIR/tqp_chat_turbo3.sh" << EOFCHAT3
#!/bin/bash
# turboquant_plus — turbo3 모드 (4.9x 압축, 최대 컨텍스트)

MODEL_DIR="\$HOME/models/qwen35-35b-a3b"
MODEL_FILE=\$(find "\$MODEL_DIR" -name "*.gguf" -type f | head -1 2>/dev/null)

if [ -z "\$MODEL_FILE" ]; then
    echo "모델을 먼저 다운로드해주세요. ./tqp_chat.sh 참고."
    exit 1
fi

echo "모델: \$MODEL_FILE"
echo "KV 캐시: turbo3 (3.25-bit, 4.9x 압축) + Sparse V"
echo ""

$BUILD_DIR/bin/llama-cli \\
    -m "\$MODEL_FILE" \\
    --cache-type-k turbo3 \\
    --cache-type-v turbo3 \\
    -ngl 99 \\
    -c 131072 \\
    --temp 0.7 \\
    --top-p 0.9 \\
    -i \\
    -cnv
EOFCHAT3
chmod +x "$SCRIPTS_DIR/tqp_chat_turbo3.sh"

# OpenAI 호환 API 서버
cat > "$SCRIPTS_DIR/tqp_server.sh" << EOFSRV
#!/bin/bash
# turboquant_plus — OpenAI 호환 API 서버

MODEL_DIR="\$HOME/models/qwen35-35b-a3b"
MODEL_FILE=\$(find "\$MODEL_DIR" -name "*.gguf" -type f | head -1 2>/dev/null)

if [ -z "\$MODEL_FILE" ]; then
    echo "모델을 먼저 다운로드해주세요."
    exit 1
fi

HOST="\${1:-127.0.0.1}"
PORT="\${2:-8080}"

echo "모델: \$MODEL_FILE"
echo "KV 캐시: turbo4 (3.8x 압축)"
echo "엔드포인트: http://\$HOST:\$PORT/v1/chat/completions"
echo ""

$BUILD_DIR/bin/llama-server \\
    -m "\$MODEL_FILE" \\
    --cache-type-k turbo4 \\
    --cache-type-v turbo4 \\
    -ngl 99 \\
    -c 65536 \\
    --host "\$HOST" \\
    --port "\$PORT"
EOFSRV
chmod +x "$SCRIPTS_DIR/tqp_server.sh"

# 벤치마크
cat > "$SCRIPTS_DIR/tqp_bench.sh" << EOFBENCH
#!/bin/bash
# turboquant_plus — 성능 벤치마크 (turbo3 vs turbo4 vs q8_0)

MODEL_DIR="\$HOME/models/qwen35-35b-a3b"
MODEL_FILE=\$(find "\$MODEL_DIR" -name "*.gguf" -type f | head -1 2>/dev/null)

if [ -z "\$MODEL_FILE" ]; then
    echo "모델을 먼저 다운로드해주세요."
    exit 1
fi

echo "═══════════════════════════════════════"
echo "  turboquant_plus 벤치마크"
echo "  모델: \$MODEL_FILE"
echo "═══════════════════════════════════════"

for CACHE_TYPE in q8_0 turbo4 turbo3; do
    echo ""
    echo "── KV 캐시: \$CACHE_TYPE ──"
    $BUILD_DIR/bin/llama-bench \\
        -m "\$MODEL_FILE" \\
        --cache-type-k "\$CACHE_TYPE" \\
        --cache-type-v "\$CACHE_TYPE" \\
        -ngl 99 \\
        -t $(sysctl -n hw.ncpu) \\
        -p 512 -n 128 2>&1 | tail -5
done

echo ""
echo "벤치마크 완료."
EOFBENCH
chmod +x "$SCRIPTS_DIR/tqp_bench.sh"

echo -e "${GREEN}  ✓ tqp_chat.sh          — turbo4 대화 (3.8x 압축, 권장)${NC}"
echo -e "${GREEN}  ✓ tqp_chat_turbo3.sh   — turbo3 대화 (4.9x 압축, 최대 컨텍스트)${NC}"
echo -e "${GREEN}  ✓ tqp_server.sh        — OpenAI API 서버${NC}"
echo -e "${GREEN}  ✓ tqp_bench.sh         — 벤치마크 (turbo3 vs turbo4 vs q8_0)${NC}"

# =============================================================================
# 완료
# =============================================================================
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗"
echo -e "║                  turboquant_plus 셋업 완료                     ║"
echo -e "╠══════════════════════════════════════════════════════════════════╣${NC}"
echo ""
echo -e "  ${BOLD}구성:${NC}"
echo -e "  모델: Qwen3.5-35B-A3B MoE (35B, 토큰당 3B 활성화)"
echo -e "  KV 캐시: TurboQuant turbo4 (3.8x) / turbo3 (4.9x)"
echo -e "  최적화: Sparse V (+22.8%), 4-mag LUT (+38%, M4 자동감지)"
echo -e "  예상 속도: ~30-40 tok/s (M4 Pro 48GB)"
echo ""
echo -e "  ${BOLD}다음 단계:${NC}"
echo -e "  1. 모델 다운로드 (~20GB):"
echo -e "     ${YELLOW}pip install huggingface_hub${NC}"
echo -e "     ${YELLOW}huggingface-cli download bartowski/Qwen3.5-35B-A3B-GGUF \\${NC}"
echo -e "     ${YELLOW}  --include '*Q4_K_M*' --local-dir ~/models/qwen35-35b-a3b${NC}"
echo ""
echo -e "  2. 실행:"
echo -e "     ${YELLOW}./tqp_chat.sh${NC}         — 대화 시작"
echo -e "     ${YELLOW}./tqp_server.sh${NC}       — API 서버"
echo -e "     ${YELLOW}./tqp_bench.sh${NC}        — 벤치마크"
echo ""
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

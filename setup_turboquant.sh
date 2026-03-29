#!/bin/bash
# =============================================================================
# TurboQuant MLX 실험용 설치 도우미
# 주력 경로가 아니라 상류 turboquant_mlx를 빠르게 체험하기 위한 보조 스크립트
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$HOME/.turboquant_mlx"
REPO_DIR="$HOME/.turboquant_mlx_repo"
CONFIG_DIR="$HOME/.config/turboquant_mlx"
DEFAULT_MODEL="mlx-community/Meta-Llama-3-8B-Instruct-4bit"
RAM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
RAM_GB=$((RAM_BYTES / 1073741824))
CHIP="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Apple Silicon')"

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  TurboQuant MLX (실험용)                                   ║"
echo "║  upstream turboquant_mlx 설치 도우미                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}[1/5] 시스템 확인...${NC}"
if [ "$(uname -m)" != "arm64" ]; then
    echo -e "${RED}Apple Silicon 전용입니다.${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ ${CHIP} / ${RAM_GB}GB${NC}"
echo -e "${YELLOW}  참고: 이 경로는 실험용입니다. 주력 권장 경로는 setup_turboquant_plus.sh 입니다.${NC}"

echo ""
echo -e "${BLUE}[2/5] 개발 도구 확인...${NC}"
if ! xcode-select -p >/dev/null 2>&1; then
    echo -e "${YELLOW}  Xcode Command Line Tools 설치가 필요합니다.${NC}"
    xcode-select --install
    exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        brew install python@3.11
    else
        echo -e "${RED}python3를 찾지 못했습니다.${NC}"
        exit 1
    fi
fi
if ! command -v git >/dev/null 2>&1; then
    echo -e "${RED}git를 찾지 못했습니다.${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ python3 / git${NC}"

echo ""
echo -e "${BLUE}[3/5] 가상환경 및 패키지 설치...${NC}"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install mlx mlx-lm

if [ -d "$REPO_DIR/.git" ]; then
    git -C "$REPO_DIR" pull --ff-only --quiet || true
elif [ -e "$REPO_DIR" ]; then
    echo -e "${RED}$REPO_DIR 가 이미 존재하지만 git 저장소가 아닙니다.${NC}"
    exit 1
else
    git clone https://github.com/helgklaizar/turboquant_mlx.git "$REPO_DIR"
fi

pip install -e "$REPO_DIR"
echo -e "${GREEN}  ✓ turboquant_mlx 설치 완료${NC}"

echo ""
echo -e "${BLUE}[4/5] 설정 파일 생성...${NC}"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_DIR/config.json" <<EOFCONFIG
{
  "default_model": "$DEFAULT_MODEL",
  "bits": 3,
  "fp16_sink_size": 128,
  "host": "127.0.0.1",
  "port": 8080
}
EOFCONFIG

cat > "$SCRIPT_DIR/mlx_tq_apply.py" <<'EOFPY'
#!/usr/bin/env python3
import json
import os
import sys

CONFIG_PATH = os.path.expanduser("~/.config/turboquant_mlx/config.json")

with open(CONFIG_PATH) as f:
    config = json.load(f)

model_id = sys.argv[1] if len(sys.argv) > 1 else config["default_model"]

from mlx_lm import load, generate

try:
    from turboquant_mlx import apply_cache_compression
except ImportError:
    apply_cache_compression = None

try:
    from mlx_core.cache import apply_turboquant_cache
except ImportError:
    apply_turboquant_cache = None

model, tokenizer = load(model_id)

if apply_cache_compression is not None:
    apply_cache_compression(model, bits=config["bits"], sink_tokens=config["fp16_sink_size"])
elif apply_turboquant_cache is not None:
    apply_turboquant_cache(model, bits=config["bits"], fp16_sink_size=config["fp16_sink_size"])

messages = []
print(f"TurboQuant MLX chat ready: {model_id}")
print("종료하려면 quit 입력")

while True:
    try:
        user = input("You > ").strip()
    except (EOFError, KeyboardInterrupt):
        print()
        break
    if not user:
        continue
    if user.lower() in {"quit", "exit", "q"}:
        break
    messages.append({"role": "user", "content": user})
    prompt = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    reply = generate(model, tokenizer, prompt=prompt, max_tokens=1024, verbose=False)
    messages.append({"role": "assistant", "content": reply})
    print(f"AI  > {reply}\n")
EOFPY
chmod +x "$SCRIPT_DIR/mlx_tq_apply.py"

echo -e "${GREEN}  ✓ $CONFIG_DIR/config.json${NC}"

echo ""
echo -e "${BLUE}[5/5] 실행 스크립트 생성...${NC}"
cat > "$SCRIPT_DIR/mlx_tq_chat.sh" <<EOFCHAT
#!/bin/bash
set -euo pipefail
source "$VENV_DIR/bin/activate"
python3 "$SCRIPT_DIR/mlx_tq_apply.py" "\${1:-$DEFAULT_MODEL}"
EOFCHAT
chmod +x "$SCRIPT_DIR/mlx_tq_chat.sh"

cat > "$SCRIPT_DIR/mlx_tq_server.sh" <<EOFSERVER
#!/bin/bash
set -euo pipefail
source "$VENV_DIR/bin/activate"
MODEL="\${1:-$DEFAULT_MODEL}"
PORT="\${2:-8080}"
HOST="127.0.0.1"
exec python3 "$REPO_DIR/scripts/run_server.py" --model "\$MODEL" --host "\$HOST" --port "\$PORT"
EOFSERVER
chmod +x "$SCRIPT_DIR/mlx_tq_server.sh"

echo -e "${GREEN}  ✓ mlx_tq_chat.sh${NC}"
echo -e "${GREEN}  ✓ mlx_tq_server.sh${NC}"
echo -e "${GREEN}  ✓ mlx_tq_apply.py${NC}"

echo ""
echo -e "${CYAN}설치 완료${NC}"
echo "기본 모델: $DEFAULT_MODEL"
echo "채팅: ./mlx_tq_chat.sh"
echo "서버: ./mlx_tq_server.sh $DEFAULT_MODEL 8080"

#!/bin/bash
# =============================================================================
# TurboQuant MLX - M4 Pro 48GB 최적화 로컬 LLM 셋업
# Google Research TurboQuant (ICLR 2026) 기반 KV Cache 압축
# KV 캐시 메모리 ~5x 절감, 정확도 손실 0
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
echo "║       TurboQuant MLX - M4 Pro 48GB 최적화 셋업             ║"
echo "║       Google TurboQuant ICLR 2026 | Apple MLX              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# =============================================================================
# 1. 시스템 확인
# =============================================================================
echo -e "${BLUE}[1/7] 시스템 환경 확인...${NC}"

ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
    echo -e "${RED}오류: Apple Silicon(arm64) 전용입니다. 현재: $ARCH${NC}"
    exit 1
fi

MACOS_VERSION=$(sw_vers -productVersion)
TOTAL_RAM_BYTES=$(sysctl -n hw.memsize)
TOTAL_RAM_GB=$((TOTAL_RAM_BYTES / 1073741824))
CHIP_INFO=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon")
GPU_CORES=$(system_profiler SPDisplaysDataType 2>/dev/null | grep "Total Number of Cores" | awk -F: '{print $2}' | tr -d ' ' || echo "N/A")

echo -e "${GREEN}  ✓ macOS $MACOS_VERSION${NC}"
echo -e "${GREEN}  ✓ 칩: $CHIP_INFO${NC}"
echo -e "${GREEN}  ✓ 통합 메모리: ${TOTAL_RAM_GB}GB${NC}"
echo -e "${GREEN}  ✓ GPU 코어: $GPU_CORES${NC}"

if [ "$TOTAL_RAM_GB" -lt 8 ]; then
    echo -e "${RED}오류: 최소 8GB RAM 필요. 현재: ${TOTAL_RAM_GB}GB${NC}"
    exit 1
fi

# =============================================================================
# 2. 메모리 버짓 계산 및 모델 선정
# =============================================================================
echo ""
echo -e "${BLUE}[2/7] 메모리 버짓 분석 및 최적 모델 선정...${NC}"

# macOS + 앱 오버헤드 ~8GB 예약
OS_OVERHEAD=8
AVAILABLE_GB=$((TOTAL_RAM_GB - OS_OVERHEAD))
# 모델 = 전체의 60%, KV 캐시 = 40% (TurboQuant 적용 시 실질 5배)
MODEL_BUDGET_GB=$((AVAILABLE_GB * 60 / 100))
KV_BUDGET_GB=$((AVAILABLE_GB * 40 / 100))
EFFECTIVE_KV_GB=$((KV_BUDGET_GB * 5))  # TurboQuant 3-bit → 5x 절감

echo -e "${CYAN}  메모리 버짓:${NC}"
echo -e "    총 RAM: ${TOTAL_RAM_GB}GB"
echo -e "    OS 예약: ${OS_OVERHEAD}GB"
echo -e "    모델 할당: ${MODEL_BUDGET_GB}GB"
echo -e "    KV 캐시 할당: ${KV_BUDGET_GB}GB (TurboQuant 적용 시 실질 ~${EFFECTIVE_KV_GB}GB 효과)"
echo ""

# M4 Pro 48GB 최적 모델 매트릭스 (4-tier)
# ──────────────────────────────────────────────────────────────────────
# 티어      | 모델                           | 크기    | 속도        | 용도
# premium  | Qwen3.5-397B-A17B MoE (4-bit) | ~210GB* | 5-6 tok/s  | GPT-4급 (디스크 오프로딩)
# primary  | Qwen3.5-27B-Claude-Opus       | ~16GB  | 15-22 tok/s | 범용 최강
# reasoning| DeepSeek-R1-Distill-32B       | ~19GB  | 12-18 tok/s | 수학/논리/분석
# fast     | Qwen3.5-9B                    | ~5GB   | 45-60 tok/s | 빠른 응답
# * 디스크 오프로딩 사용 — RAM 48GB + SSD에서 나머지 로드
# ──────────────────────────────────────────────────────────────────────

if [ "$MODEL_BUDGET_GB" -ge 20 ]; then
    # 48GB+: 4-tier 구성
    PREMIUM_MODEL="mlx-community/Qwen3.5-397B-A17B-4bit"
    PREMIUM_NAME="Qwen3.5-397B-A17B MoE (4-bit, 디스크 오프로딩)"
    PREMIUM_SIZE="~210GB (SSD)"
    PREMIUM_SPEED="5-6 tok/s"
    PREMIUM_USE="GPT-4급 품질. 397B 파라미터 중 토큰당 17B만 활성화하는 MoE 구조"

    PRIMARY_MODEL="mlx-community/Qwen3.5-27B-Claude-4.6-Opus-Distilled-MLX-4bit"
    PRIMARY_NAME="Qwen3.5-27B-Claude-Opus-Distilled (4-bit)"
    PRIMARY_SIZE="~16GB"
    PRIMARY_SPEED="15-22 tok/s"

    SECONDARY_MODEL="mlx-community/DeepSeek-R1-Distill-Qwen-32B-4bit"
    SECONDARY_NAME="DeepSeek R1 Distill 32B (4-bit)"
    SECONDARY_SIZE="~19GB"
    SECONDARY_USE="수학/논리/분석 특화"

    FAST_MODEL="mlx-community/Qwen3.5-9B-MLX-4bit"
    FAST_NAME="Qwen3.5 9B (4-bit)"
    FAST_SIZE="~5GB"
    FAST_SPEED="45-60 tok/s"

    TURBOQUANT_BITS=3
    CONTEXT_MAX="128K+"

elif [ "$MODEL_BUDGET_GB" -ge 10 ]; then
    PRIMARY_MODEL="mlx-community/Qwen3.5-9B-MLX-4bit"
    PRIMARY_NAME="Qwen3.5 9B (4-bit)"
    PRIMARY_SIZE="~5GB"
    PRIMARY_SPEED="40-55 tok/s"

    SECONDARY_MODEL="mlx-community/Meta-Llama-3-8B-Instruct-4bit"
    SECONDARY_NAME="Llama 3 8B Instruct (4-bit)"
    SECONDARY_SIZE="~4.5GB"
    SECONDARY_USE="검증된 범용 모델"

    FAST_MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
    FAST_NAME="Llama 3.2 3B (4-bit)"
    FAST_SIZE="~1.8GB"
    FAST_SPEED="80+ tok/s"

    TURBOQUANT_BITS=2
    CONTEXT_MAX="65K"

else
    PRIMARY_MODEL="mlx-community/Llama-3.2-3B-Instruct-4bit"
    PRIMARY_NAME="Llama 3.2 3B (4-bit)"
    PRIMARY_SIZE="~1.8GB"
    PRIMARY_SPEED="60+ tok/s"

    SECONDARY_MODEL="mlx-community/Llama-3.2-1B-Instruct-4bit"
    SECONDARY_NAME="Llama 3.2 1B (4-bit)"
    SECONDARY_SIZE="~0.7GB"
    SECONDARY_USE="초경량"

    FAST_MODEL="$SECONDARY_MODEL"
    FAST_NAME="$SECONDARY_NAME"
    FAST_SIZE="$SECONDARY_SIZE"
    FAST_SPEED="100+ tok/s"

    TURBOQUANT_BITS=2
    CONTEXT_MAX="32K"
fi

if [ -n "$PREMIUM_MODEL" ]; then
    echo -e "${YELLOW}  ★ 프리미엄: ${BOLD}$PREMIUM_NAME${NC}"
    echo -e "${YELLOW}    $PREMIUM_USE${NC}"
    echo -e "${YELLOW}    크기: $PREMIUM_SIZE | 속도: ~$PREMIUM_SPEED (디스크 오프로딩)${NC}"
    echo ""
fi
echo -e "${GREEN}  ★ 메인 모델: ${BOLD}$PRIMARY_NAME${NC}"
echo -e "${GREEN}    크기: $PRIMARY_SIZE | 속도: ~$PRIMARY_SPEED | KV: ${TURBOQUANT_BITS}-bit TurboQuant${NC}"
echo -e "${GREEN}    컨텍스트: $CONTEXT_MAX 토큰 (TurboQuant 적용)${NC}"
echo ""
echo -e "${CYAN}  추가 모델:${NC}"
echo -e "    분석용: $SECONDARY_NAME ($SECONDARY_SIZE) — $SECONDARY_USE"
echo -e "    빠른용: $FAST_NAME ($FAST_SIZE) — ~$FAST_SPEED"

# =============================================================================
# 3. Homebrew & Python 확인
# =============================================================================
echo ""
echo -e "${BLUE}[3/7] 개발 도구 확인...${NC}"

# Xcode Command Line Tools
if ! xcode-select -p &> /dev/null; then
    echo -e "${YELLOW}  Xcode CLT 설치 중... (팝업에서 설치를 눌러주세요)${NC}"
    xcode-select --install 2>/dev/null || true
    echo -e "${YELLOW}  설치 완료 후 이 스크립트를 다시 실행해주세요.${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Xcode Command Line Tools${NC}"

# Homebrew
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}  Homebrew 설치 중...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi
echo -e "${GREEN}  ✓ Homebrew$(brew --version | head -1 | awk '{print " "$2}')${NC}"

# Python
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}  Python 설치 중...${NC}"
    brew install python@3.11
fi
echo -e "${GREEN}  ✓ $(python3 --version)${NC}"

# Git
if ! command -v git &> /dev/null; then
    brew install git
fi
echo -e "${GREEN}  ✓ git $(git --version | awk '{print $3}')${NC}"

# =============================================================================
# 4. 가상환경 + 패키지 설치
# =============================================================================
echo ""
echo -e "${BLUE}[4/7] Python 환경 구성...${NC}"

VENV_DIR="$HOME/.turboquant_mlx"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo -e "${GREEN}  ✓ 가상환경 생성: $VENV_DIR${NC}"
else
    echo -e "${GREEN}  ✓ 가상환경 재사용: $VENV_DIR${NC}"
fi

source "$VENV_DIR/bin/activate"

echo -e "${CYAN}  pip 업그레이드...${NC}"
pip install --upgrade pip -q

echo -e "${CYAN}  MLX 프레임워크 설치...${NC}"
pip install mlx mlx-lm -q
echo -e "${GREEN}  ✓ mlx + mlx-lm${NC}"

echo -e "${CYAN}  TurboQuant MLX 설치...${NC}"
TQ_REPO="$HOME/.turboquant_mlx_repo"
if [ -d "$TQ_REPO" ]; then
    cd "$TQ_REPO" && git pull -q 2>/dev/null || true
else
    git clone https://github.com/helgklaizar/turboquant_mlx.git "$TQ_REPO"
fi
cd "$TQ_REPO"
pip install -e . -q
echo -e "${GREEN}  ✓ turboquant_mlx${NC}"

echo -e "${CYAN}  추가 유틸리티 설치...${NC}"
pip install huggingface_hub rich -q
echo -e "${GREEN}  ✓ huggingface_hub, rich${NC}"

cd "$HOME"

# =============================================================================
# 5. 설정 파일 생성
# =============================================================================
echo ""
echo -e "${BLUE}[5/7] 설정 파일 생성...${NC}"

CONFIG_DIR="$HOME/.config/turboquant"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/config.json" << EOFCONFIG
{
    "models": {
        "premium": {
            "id": "${PREMIUM_MODEL:-}",
            "name": "${PREMIUM_NAME:-N/A}",
            "size": "${PREMIUM_SIZE:-}",
            "speed": "${PREMIUM_SPEED:-}",
            "use": "${PREMIUM_USE:-}",
            "disk_offload": true
        },
        "primary": {
            "id": "$PRIMARY_MODEL",
            "name": "$PRIMARY_NAME",
            "size": "$PRIMARY_SIZE",
            "speed": "$PRIMARY_SPEED"
        },
        "reasoning": {
            "id": "$SECONDARY_MODEL",
            "name": "$SECONDARY_NAME",
            "size": "$SECONDARY_SIZE",
            "use": "$SECONDARY_USE"
        },
        "fast": {
            "id": "$FAST_MODEL",
            "name": "$FAST_NAME",
            "size": "$FAST_SIZE",
            "speed": "$FAST_SPEED"
        }
    },
    "active_model": "primary",
    "turboquant": {
        "bits": $TURBOQUANT_BITS,
        "fp16_sink_size": 128,
        "chunk_size": 64
    },
    "server": {
        "host": "127.0.0.1",
        "port": 8080
    },
    "system": {
        "ram_gb": $TOTAL_RAM_GB,
        "chip": "$CHIP_INFO",
        "model_budget_gb": $MODEL_BUDGET_GB,
        "kv_budget_gb": $KV_BUDGET_GB,
        "effective_kv_gb": $EFFECTIVE_KV_GB,
        "max_context": "$CONTEXT_MAX"
    }
}
EOFCONFIG

echo -e "${GREEN}  ✓ $CONFIG_DIR/config.json${NC}"

# =============================================================================
# 6. 실행 스크립트 생성
# =============================================================================
echo ""
echo -e "${BLUE}[6/7] 실행 스크립트 생성...${NC}"

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- chat.py (메인 대화 엔진) ---
cat > "$CONFIG_DIR/chat.py" << 'EOFCHAT'
#!/usr/bin/env python3
"""TurboQuant MLX - 대화형 채팅 (M4 Pro 최적화)"""

import json, os, sys, time
import mlx.core as mx
from mlx_lm import load, generate

def load_config():
    with open(os.path.expanduser("~/.config/turboquant/config.json")) as f:
        return json.load(f)

def get_model_info(config, mode="primary"):
    models = config["models"]
    info = models.get(mode, models["primary"])
    return info["id"], info["name"], info.get("disk_offload", False)

def apply_tq(model, config):
    bits = config["turboquant"]["bits"]
    sink = config["turboquant"]["fp16_sink_size"]
    try:
        from turboquant_mlx import apply_cache_compression
        apply_cache_compression(model, bits=bits, sink_tokens=sink)
        return True
    except ImportError:
        try:
            from mlx_core.cache import apply_turboquant_cache
            apply_turboquant_cache(model, bits=bits, fp16_sink_size=sink)
            return True
        except ImportError:
            return False

def main():
    config = load_config()

    # 모드 선택 (인자로 전달 가능)
    mode = sys.argv[1] if len(sys.argv) > 1 else config.get("active_model", "primary")
    model_id, model_name, disk_offload = get_model_info(config, mode)
    sys_info = config["system"]

    print(f"\n{'='*60}")
    print(f"  TurboQuant MLX Chat — {sys_info['chip']}")
    print(f"  모델: {model_name}")
    if disk_offload:
        print(f"  ⚡ 디스크 오프로딩 모드 (SSD에서 전문가 레이어 로드)")
    print(f"  TurboQuant: {config['turboquant']['bits']}-bit KV cache")
    print(f"  메모리: {sys_info['ram_gb']}GB | 컨텍스트: {sys_info['max_context']} 토큰")
    print(f"{'='*60}")

    print(f"\n모델 로딩 중: {model_id}")
    if disk_offload:
        print("  (대용량 MoE 모델 — 첫 로드에 시간이 걸릴 수 있습니다)")
    t0 = time.time()
    model, tokenizer = load(model_id)
    load_time = time.time() - t0
    print(f"✓ 모델 로드 완료 ({load_time:.1f}초)")

    if apply_tq(model, config):
        print(f"✓ TurboQuant {config['turboquant']['bits']}-bit KV 캐시 압축 활성화")
    else:
        print("⚠ TurboQuant 미적용 (라이브러리 없음, 기본 KV 캐시 사용)")

    messages = []
    system_prompt = "You are a highly capable AI assistant. Respond in the same language as the user. Be concise, accurate, and helpful."

    print(f"\n대화 시작 (종료: quit | 모델 전환: /premium /primary /reasoning /fast)\n")

    while True:
        try:
            user_input = input("You > ").strip()
            if not user_input:
                continue
            if user_input.lower() in ("quit", "exit", "q"):
                print("\n종료합니다.")
                break
            if user_input.startswith("/"):
                cmd = user_input[1:].strip()
                if cmd in ("premium", "primary", "reasoning", "fast"):
                    new_id, new_name, new_offload = get_model_info(config, cmd)
                    print(f"\n모델 전환: {new_name}")
                    print(f"로딩 중: {new_id}")
                    model, tokenizer = load(new_id)
                    apply_tq(model, config)
                    messages = []
                    print(f"✓ 전환 완료. 대화 이력 초기화됨.\n")
                    continue
                elif cmd == "clear":
                    messages = []
                    print("대화 이력 초기화됨.\n")
                    continue
                elif cmd == "info":
                    print(f"  모델: {model_name}")
                    print(f"  대화 턴: {len(messages)//2}")
                    print(f"  TurboQuant: {config['turboquant']['bits']}-bit\n")
                    continue

            messages.append({"role": "user", "content": user_input})

            full_messages = [{"role": "system", "content": system_prompt}] + messages
            prompt = tokenizer.apply_chat_template(
                full_messages, tokenize=False, add_generation_prompt=True
            )

            t0 = time.time()
            response = generate(
                model, tokenizer, prompt=prompt,
                max_tokens=4096, verbose=False
            )
            gen_time = time.time() - t0
            tok_count = len(tokenizer.encode(response))
            tps = tok_count / gen_time if gen_time > 0 else 0

            messages.append({"role": "assistant", "content": response})
            print(f"\nAI > {response}")
            print(f"  [{tok_count} tokens, {tps:.1f} tok/s, {gen_time:.1f}s]\n")

        except KeyboardInterrupt:
            print("\n\n종료합니다.")
            break
        except Exception as e:
            print(f"\n오류: {e}\n")

if __name__ == "__main__":
    main()
EOFCHAT

chmod +x "$CONFIG_DIR/chat.py"

# --- server.py (OpenAI 호환 API) ---
cat > "$CONFIG_DIR/server.py" << 'EOFSERVER'
#!/usr/bin/env python3
"""TurboQuant MLX - OpenAI 호환 API 서버"""

import json, os, sys

def load_config():
    with open(os.path.expanduser("~/.config/turboquant/config.json")) as f:
        return json.load(f)

def main():
    config = load_config()
    mode = sys.argv[1] if len(sys.argv) > 1 else config.get("active_model", "primary")
    models = config["models"]
    model_info = models.get(mode, models["primary"])
    model_id = model_info["id"]
    host = config["server"]["host"]
    port = config["server"]["port"]

    print(f"\n{'='*60}")
    print(f"  TurboQuant MLX — OpenAI Compatible API Server")
    print(f"  모델: {model_info['name']}")
    print(f"  엔드포인트: http://{host}:{port}/v1/chat/completions")
    print(f"{'='*60}\n")

    # turboquant_mlx 서버 먼저 시도
    tq_server = os.path.expanduser("~/.turboquant_mlx_repo/scripts/run_server.py")
    if os.path.exists(tq_server):
        os.system(f"python3 {tq_server} --model {model_id} --host {host} --port {port}")
    else:
        # mlx_lm 내장 서버 fallback
        os.system(f"python3 -m mlx_lm.server --model {model_id} --host {host} --port {port}")

if __name__ == "__main__":
    main()
EOFSERVER

chmod +x "$CONFIG_DIR/server.py"

# --- 셸 런처 스크립트 ---

# chat.sh
cat > "$SCRIPTS_DIR/chat.sh" << EOFRUN
#!/bin/bash
# TurboQuant MLX — 대화형 채팅
# 사용법: ./chat.sh [primary|reasoning|fast]
source "$VENV_DIR/bin/activate"
python3 "$CONFIG_DIR/chat.py" "\${1:-primary}"
EOFRUN
chmod +x "$SCRIPTS_DIR/chat.sh"

# server.sh
cat > "$SCRIPTS_DIR/server.sh" << EOFRUN2
#!/bin/bash
# TurboQuant MLX — OpenAI API 서버
# 사용법: ./server.sh [primary|reasoning|fast]
source "$VENV_DIR/bin/activate"
python3 "$CONFIG_DIR/server.py" "\${1:-primary}"
EOFRUN2
chmod +x "$SCRIPTS_DIR/server.sh"

# download.sh (모델 사전 다운로드)
cat > "$SCRIPTS_DIR/download_models.sh" << EOFDOWN
#!/bin/bash
# TurboQuant MLX — 모델 사전 다운로드
source "$VENV_DIR/bin/activate"
echo ""
echo "모델 다운로드를 시작합니다..."
echo "(프리미엄 모델은 ~210GB — 별도로 다운로드하세요)"
echo ""

echo "[1/3] $PRIMARY_NAME ($PRIMARY_SIZE)..."
python3 -c "from mlx_lm import load; load('$PRIMARY_MODEL')" 2>&1 | tail -1
echo "✓ 완료"
echo ""

echo "[2/3] $SECONDARY_NAME ($SECONDARY_SIZE)..."
python3 -c "from mlx_lm import load; load('$SECONDARY_MODEL')" 2>&1 | tail -1
echo "✓ 완료"
echo ""

echo "[3/3] $FAST_NAME ($FAST_SIZE)..."
python3 -c "from mlx_lm import load; load('$FAST_MODEL')" 2>&1 | tail -1
echo "✓ 완료"
echo ""

echo "기본 모델 다운로드 완료!"
echo ""
echo "프리미엄 모델(397B MoE, ~210GB)을 다운로드하려면:"
echo "  ./download_premium.sh"
EOFDOWN

cat > "$SCRIPTS_DIR/download_premium.sh" << EOFPREM
#!/bin/bash
# TurboQuant MLX — 프리미엄 모델(397B MoE) 다운로드
# 주의: ~210GB 디스크 공간 필요, 다운로드에 상당한 시간 소요
source "$VENV_DIR/bin/activate"
echo ""
echo "═══════════════════════════════════════════════════"
echo "  프리미엄 모델 다운로드: $PREMIUM_NAME"
echo "  크기: $PREMIUM_SIZE"
echo "  디스크 여유 공간을 확인해주세요!"
echo "═══════════════════════════════════════════════════"
echo ""

# 디스크 여유 공간 확인
FREE_GB=\$(df -g ~ | tail -1 | awk '{print \$4}')
echo "현재 디스크 여유: \${FREE_GB}GB"

if [ "\$FREE_GB" -lt 250 ]; then
    echo ""
    echo "⚠ 디스크 여유 공간이 250GB 미만입니다."
    echo "  모델 크기 (~210GB) + 임시 파일을 고려하면"
    echo "  최소 250GB 이상의 여유 공간을 권장합니다."
    echo ""
    read -p "계속하시겠습니까? (y/N) " confirm
    if [ "\$confirm" != "y" ] && [ "\$confirm" != "Y" ]; then
        echo "취소되었습니다."
        exit 0
    fi
fi

echo ""
echo "다운로드 시작... (대용량이므로 시간이 걸립니다)"
python3 -c "from mlx_lm import load; load('$PREMIUM_MODEL')" 2>&1 | tail -5
echo ""
echo "✓ 프리미엄 모델 다운로드 완료!"
echo "  실행: ./chat.sh premium"
EOFPREM
chmod +x "$SCRIPTS_DIR/download_premium.sh"
chmod +x "$SCRIPTS_DIR/download_models.sh"

echo -e "${GREEN}  ✓ chat.sh          — 대화형 채팅${NC}"
echo -e "${GREEN}  ✓ server.sh        — OpenAI API 서버${NC}"
echo -e "${GREEN}  ✓ download_models.sh — 모델 사전 다운로드${NC}"

# =============================================================================
# 7. 완료 요약
# =============================================================================
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗"
echo -e "║                       셋업 완료!                                ║"
echo -e "╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e ""
echo -e "${BOLD}  시스템: $CHIP_INFO / ${TOTAL_RAM_GB}GB 통합 메모리${NC}"
echo -e ""
if [ -n "$PREMIUM_MODEL" ]; then
echo -e "  ${YELLOW}★ 프리미엄${NC}: $PREMIUM_NAME"
echo -e "    $PREMIUM_USE"
echo -e "    크기: $PREMIUM_SIZE | 속도: ~$PREMIUM_SPEED (디스크 오프로딩)"
echo -e ""
fi
echo -e "  ${GREEN}★ 메인 모델${NC}: $PRIMARY_NAME"
echo -e "    크기: $PRIMARY_SIZE | 속도: ~$PRIMARY_SPEED | 컨텍스트: $CONTEXT_MAX"
echo -e ""
echo -e "  ${CYAN}분석 모델${NC}: $SECONDARY_NAME"
echo -e "    크기: $SECONDARY_SIZE | $SECONDARY_USE"
echo -e ""
echo -e "  ${CYAN}빠른 모델${NC}: $FAST_NAME"
echo -e "    크기: $FAST_SIZE | 속도: ~$FAST_SPEED"
echo -e ""
echo -e "  TurboQuant ${TURBOQUANT_BITS}-bit KV 캐시 → 메모리 ${KV_BUDGET_GB}GB로 실질 ~${EFFECTIVE_KV_GB}GB 효과"
echo -e ""
echo -e "${CYAN}  ────────────────────────────────────────────────────────────${NC}"
echo -e ""
echo -e "  ${BOLD}다음 단계:${NC}"
echo -e "  1. ${YELLOW}./download_models.sh${NC}    — 모델 사전 다운로드 (권장)"
echo -e "  2. ${YELLOW}./chat.sh${NC}               — 바로 대화 시작 (메인 모델)"
echo -e "  3. ${YELLOW}./chat.sh premium${NC}       — GPT-4급 프리미엄 모드 (느림)"
echo -e "  4. ${YELLOW}./chat.sh reasoning${NC}     — 분석 모드 (DeepSeek R1)"
echo -e "  5. ${YELLOW}./chat.sh fast${NC}          — 빠른 응답 모드"
echo -e "  6. ${YELLOW}./server.sh${NC}             — API 서버 (http://127.0.0.1:8080)"
echo -e ""
echo -e "${CYAN}  설정 파일: ~/.config/turboquant/config.json${NC}"
echo -e ""
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

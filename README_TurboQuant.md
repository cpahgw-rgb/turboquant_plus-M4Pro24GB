# TurboQuant MLX — M4 Pro 48GB 로컬 LLM 가이드

## 환경

- **칩**: Apple M4 Pro
- **메모리**: 48GB 통합 메모리
- **프레임워크**: Apple MLX + TurboQuant KV Cache 압축

## TurboQuant 핵심

Google Research (ICLR 2026)의 TurboQuant는 KV 캐시를 16비트 → 3비트로 압축합니다. PolarQuant(벡터 극좌표 변환)와 QJL(비편향 내적 추정)의 2단계를 통해 메모리 5배 절감, 정확도 손실 0을 달성합니다.

48GB Mac에서 실질적으로 KV 캐시 ~80GB 효과를 얻어, 128K+ 토큰 컨텍스트가 가능합니다.

---

## 모델 구성 (4-tier)

| 모드 | 모델 | 크기 | 속도 | 용도 |
|---|---|---|---|---|
| **premium** | Qwen3.5-397B-A17B MoE (4-bit) | ~210GB (SSD) | 5-6 tok/s | GPT-4급 품질. 디스크 오프로딩 |
| **primary** | Qwen3.5-27B-Claude-Opus-Distilled (4-bit) | ~16GB (RAM) | 15-22 tok/s | 범용 최강 (Claude Opus 증류) |
| **reasoning** | DeepSeek R1 Distill 32B (4-bit) | ~19GB (RAM) | 12-18 tok/s | 수학/논리/분석 |
| **fast** | Qwen3.5 9B (4-bit) | ~5GB (RAM) | 45-60 tok/s | 빠른 응답, 가벼운 작업 |

### Premium 모델 설명

Qwen3.5-397B-A17B는 총 397B 파라미터의 MoE(Mixture of Experts) 모델입니다. 토큰당 512개 전문가 중 10개만 활성화(17B 파라미터)하여 48GB RAM에서도 디스크 오프로딩으로 실행 가능합니다. 속도는 ~5-6 tok/s로 느리지만, 출력 품질이 GPT-4에 근접합니다. SSD에 ~210GB 여유 공간이 필요합니다.

메모리 버짓 (primary/reasoning/fast): 모델 ~24GB + KV 캐시 ~16GB (TurboQuant 3-bit → 실질 ~80GB) + OS 8GB

---

## 설치 & 사용

### 1단계: 설치

```bash
cd "Local LLM"
chmod +x setup_turboquant.sh
./setup_turboquant.sh
```

### 2단계: 모델 다운로드

```bash
# 기본 3종 다운로드 (~40GB)
./download_models.sh

# 프리미엄 모델 다운로드 (~210GB, 선택사항)
./download_premium.sh
```

### 3단계: 사용

```bash
# 대화형 채팅 (기본: primary 모델)
./chat.sh

# GPT-4급 프리미엄 모드 (느리지만 최고 품질)
./chat.sh premium

# 분석/추론 모드
./chat.sh reasoning

# 빠른 응답 모드
./chat.sh fast

# OpenAI 호환 API 서버
./server.sh
```

### 채팅 중 명령어

| 명령 | 기능 |
|---|---|
| `/premium` | GPT-4급 프리미엄 모델로 전환 |
| `/primary` | 메인 모델로 전환 |
| `/reasoning` | 분석 모델로 전환 |
| `/fast` | 빠른 모델로 전환 |
| `/clear` | 대화 이력 초기화 |
| `/info` | 현재 상태 확인 |
| `quit` | 종료 |

---

## API 서버 사용

서버 실행 후 `http://127.0.0.1:8080/v1/chat/completions`에서 OpenAI 호환 API를 사용할 수 있습니다. Chatbox, Continue.dev, Open WebUI 등 모든 OpenAI API 호환 도구에서 연결 가능합니다.

```bash
curl http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"local","messages":[{"role":"user","content":"Hello!"}]}'
```

---

## 설정 변경

`~/.config/turboquant/config.json`에서 모델, TurboQuant 비트, 서버 포트 등을 변경할 수 있습니다.

---

## 참고 자료

- [turboquant_mlx GitHub](https://github.com/helgklaizar/turboquant_mlx)
- [Google Research Blog](https://research.google/blog/turboquant-redefining-ai-efficiency-with-extreme-compression/)
- [Qwen3.5-27B-Claude-Opus-Distilled (HuggingFace)](https://huggingface.co/mlx-community/Qwen3.5-27B-Claude-4.6-Opus-Distilled-MLX-4bit)
- [turboquant.net](https://turboquant.net/)

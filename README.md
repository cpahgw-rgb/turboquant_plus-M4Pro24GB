# Local LLM on Apple Silicon

Apple Silicon Mac에서 로컬 LLM을 돌리기 위한 정리본입니다. 이 저장소는 조사 결과를 바탕으로 실제로 분리되어야 하는 경로를 세 가지로 정리합니다.

- `llama.cpp + TurboQuant`:
  48GB급 Mac에서 `Qwen3.5-35B-A3B` GGUF를 가장 현실적으로 돌리는 주력 경로입니다.
- `flash-moe`:
  `Qwen3.5-397B-A17B`를 SSD 스트리밍으로 돌리는 별도 전용 엔진입니다.
- `MLX TurboQuant`:
  상류 프로젝트를 써보는 실험용 보조 경로입니다. 기본 추천 경로는 아닙니다.

## 먼저 알아둘 점

이번 재검토에서 가장 중요했던 사실은 아래 둘입니다.

1. `TheTom/turboquant_plus`는 연구/프로토타입 저장소입니다.
2. 실제 `llama.cpp` 빌드 타깃은 `TheTom/llama-cpp-turboquant`의 `feature/turboquant-kv-cache` 브랜치입니다.

즉, `turboquant_plus`와 `llama-cpp-turboquant`를 같은 저장소처럼 취급하면 설치 스크립트가 틀어집니다.

## 추천 경로

### 1. `setup_turboquant_plus.sh` — 권장 경로

`llama.cpp` TurboQuant 포크를 Metal로 빌드하고, `Qwen3.5-35B-A3B` GGUF를 TurboQuant KV 캐시로 실행하는 경로입니다.

```bash
chmod +x setup_turboquant_plus.sh
./setup_turboquant_plus.sh
```

이 경로가 맞는 경우:
- 48GB급 Apple Silicon에서 가장 현실적인 균형점을 원할 때
- `llama-cli`, `llama-server` 기반의 로컬 추론이 필요할 때
- 긴 컨텍스트에서 KV 캐시 압축 이득을 바로 체감하고 싶을 때

생성되는 실행기:
- `./turboquant_chat.sh`
- `./turboquant_chat_turbo3.sh`
- `./turboquant_chat_long.sh`
- `./turboquant_server.sh`
- `./turboquant_bench.sh`

기존 `./tqp_*` 파일도 남아 있지만, 이제는 호환용 래퍼입니다. 새 이름 기준으로 사용하는 편이 더 직관적입니다.

기본 설치 위치:
- `~/.llama-cpp-turboquant`

추천 모델:
- `bartowski/Qwen_Qwen3.5-35B-A3B-GGUF`

### TurboQuant 런처 사용법

세 채팅 런처의 차이는 "모델"이 아니라 "KV cache 포맷"과 "기본 컨텍스트 길이"입니다.

| 실행기 | KV cache | 기본 컨텍스트 | 추천 사용처 |
|---|---|---|---|
| `./turboquant_chat.sh` | `turbo4` | `32768` | 기본 추천. 평소 대화와 일반적인 작업 |
| `./turboquant_chat_turbo3.sh` | `turbo3` | `65536` | `turbo3`와 `turbo4`를 비교하고 싶을 때 |
| `./turboquant_chat_long.sh` | `turbo4` | `65536` | `turbo4`를 유지한 채 더 긴 문맥이 필요할 때 |

빠르게 고르면:
- 평소에는 `./turboquant_chat.sh`
- 긴 문맥이 먼저 필요하면 `./turboquant_chat_long.sh`
- `turbo3` 실험은 `./turboquant_chat_turbo3.sh`

예시:

```bash
./turboquant_chat.sh
```

긴 문맥으로 실행:

```bash
TQP_CTX_SIZE=65536 ./turboquant_chat_long.sh
```

포트와 호스트를 바꿔 서버 실행:

```bash
./turboquant_server.sh 0.0.0.0 8080
```

환경변수로 덮어쓸 수 있는 주요 설정:
- `TQP_CTX_SIZE`
- `TQP_GPU_LAYERS`
- `TQP_TEMP`
- `TQP_TOP_P`
- `TQP_HOST`
- `TQP_PORT`

### TurboQuant 파일 설명

아래 파일들은 이름이 비슷해서 헷갈릴 수 있지만, 역할이 서로 다릅니다.

| 파일 | 역할 | 언제 쓰는지 |
|---|---|---|
| `./turboquant_chat.sh` | 기본 채팅 런처 | 평소 대화와 일반 작업 |
| `./turboquant_chat_turbo3.sh` | `turbo3` 비교용 채팅 런처 | `turbo3`와 `turbo4` 차이를 직접 보고 싶을 때 |
| `./turboquant_chat_long.sh` | 긴 문맥용 채팅 런처 | `turbo4` 기준으로 컨텍스트를 더 길게 쓰고 싶을 때 |
| `./turboquant_server.sh` | OpenAI 호환 서버 런처 | 다른 앱이나 스크립트에서 HTTP API로 붙이고 싶을 때 |
| `./turboquant_bench.sh` | 간단 벤치마크 런처 | `q8_0`, `turbo4`, `turbo3` 속도를 비교할 때 |
| `./turboquant_common.sh` | 공통 설정 파일 | 직접 실행하는 용도가 아니라, 다른 런처들이 공통으로 불러 쓰는 파일 |

#### `turboquant_server.sh`

이 파일은 대화형 채팅이 아니라 서버 실행용입니다.

이럴 때 씁니다:
- 로컬 앱에서 OpenAI 호환 엔드포인트로 붙이고 싶을 때
- 브라우저 UI, 자동화 스크립트, 다른 툴에서 HTTP 호출을 하고 싶을 때
- 매번 채팅 셸을 열지 않고 백그라운드 서버처럼 두고 싶을 때

기본값:
- 호스트: `127.0.0.1`
- 포트: `8080`
- KV cache: `turbo4`
- 기본 컨텍스트: `32768`

예시:

```bash
./turboquant_server.sh
```

외부 기기에서도 접근 가능하게 열기:

```bash
./turboquant_server.sh 0.0.0.0 8080
```

환경변수로도 조정할 수 있습니다:

```bash
TQP_CTX_SIZE=65536 TQP_PORT=8081 ./turboquant_server.sh
```

#### `turboquant_bench.sh`

이 파일은 실제 채팅용이 아니라 비교 측정용입니다.

무엇을 하냐면:
- 같은 모델에 대해
- `q8_0`
- `turbo4`
- `turbo3`
순서로 `llama-bench`를 돌려서 출력 속도를 비교합니다.

이럴 때 씁니다:
- 지금 Mac에서 어떤 KV cache 설정이 더 빠른지 보고 싶을 때
- `turbo3`와 `turbo4` 중 무엇을 기본값으로 둘지 판단할 때
- 추후 설정을 바꾼 뒤 전후 비교를 남기고 싶을 때

예시:

```bash
./turboquant_bench.sh
```

토큰 수를 줄여 빠르게 비교:

```bash
TQP_BENCH_PROMPT_TOKENS=256 TQP_BENCH_GEN_TOKENS=64 ./turboquant_bench.sh
```

#### `turboquant_common.sh`

이 파일은 직접 실행하는 런처가 아닙니다.

역할:
- 모델 파일 찾기
- 빌드된 `llama-cli`, `llama-server`, `llama-bench` 경로 공유
- 기본 환경변수 값 관리
- 공통 오류 메시지 처리

즉, `turboquant_chat.sh`, `turboquant_server.sh`, `turboquant_bench.sh`가 중복 코드를 각자 갖지 않도록 묶어둔 내부 파일입니다.

보통은 이 파일을 직접 실행하지 않습니다.

#### 호환용 `tqp_*`

기존 이름인 아래 파일들은 남아 있습니다.

- `./tqp_chat.sh`
- `./tqp_chat_turbo3.sh`
- `./tqp_server.sh`
- `./tqp_bench.sh`

이 파일들은 이제 예전 명령이 안 깨지도록 `turboquant_*` 파일을 호출해주는 호환용 래퍼입니다.

즉:
- 새로 쓸 때는 `turboquant_*`
- 예전 습관이나 기존 메모를 살릴 때는 `tqp_*`

이렇게 이해하면 됩니다.

### 2. `setup_flash_moe.sh` — 397B 전용 경로

`flash-moe`는 TurboQuant와 경쟁하는 엔진이 아니라, 훨씬 더 큰 모델의 가중치를 SSD에서 스트리밍하기 위한 별도 엔진입니다.

```bash
chmod +x setup_flash_moe.sh
./setup_flash_moe.sh
```

이 경로가 맞는 경우:
- `Qwen3.5-397B-A17B` 자체를 로컬에서 시도하고 싶을 때
- 속도보다 최고급 모델 품질이 더 중요할 때
- 200GB 이상 SSD 공간과 긴 준비 시간을 감수할 수 있을 때

생성되는 실행기:
- `./flash_chat.sh`
- `./flash_infer.sh`
- `./flash_bench.sh`

기본 설치 위치:
- `~/.flash-moe`

### 3. `setup_turboquant.sh` — 실험용 MLX 경로

이 스크립트는 상류 `turboquant_mlx` 프로젝트를 실험적으로 설치해볼 때만 사용하세요.

```bash
chmod +x setup_turboquant.sh
./setup_turboquant.sh
```

주의:
- 이 경로는 현재 이 저장소의 주력 경로가 아닙니다.
- 재검토 결과, 예전 스크립트처럼 `MLX + 397B + 48GB`를 기본 경로로 제시하는 것은 근거가 약했습니다.
- 이제는 작은/중간급 MLX 모델에 TurboQuant 캐시 압축을 붙여보는 실험용 도우미로만 정리했습니다.

## 비교표

| 경로 | 목적 | 장점 | 단점 |
|---|---|---|---|
| `llama.cpp + TurboQuant` | 35B-A3B 실사용 | 가장 현실적, OpenAI 호환 서버, 긴 컨텍스트 | 포크 빌드 필요 |
| `flash-moe` | 397B 실험 | 48GB급 Mac에서 397B 시도 가능 | 느림, 디스크 요구 큼 |
| `MLX TurboQuant` | 실험용 | 설치가 비교적 단순, MLX 기반 | 상류 호환성 변화가 큼 |

## 파일 안내

| 파일 | 설명 |
|---|---|
| `setup_turboquant_plus.sh` | `llama-cpp-turboquant` 빌드 + 실행기 생성 |
| `setup_flash_moe.sh` | `flash-moe` 빌드 + 실행기 생성 |
| `setup_turboquant.sh` | 실험용 `turboquant_mlx` 설치 도우미 |
| `verify_setup.sh` | 설치 상태 탐지 스크립트 |
| `ANALYSIS_fusion.md` | 재검토 후 정리한 사실관계 문서 |
| `README_TurboQuant.md` | 실험용 MLX 경로 안내 |

## 권장 순서

1. 보통은 `./setup_turboquant_plus.sh`부터 시작합니다.
2. 397B가 목표일 때만 `./setup_flash_moe.sh`로 갑니다.
3. MLX 쪽은 필요할 때만 `./setup_turboquant.sh`를 별도로 사용합니다.

## 참고 자료

- [Google Research TurboQuant](https://research.google/blog/turboquant-redefining-ai-efficiency-with-extreme-compression/)
- [TheTom/turboquant_plus](https://github.com/TheTom/turboquant_plus) — 연구/프로토타입 저장소
- [TheTom/llama-cpp-turboquant](https://github.com/TheTom/llama-cpp-turboquant/tree/feature/turboquant-kv-cache) — 실제 llama.cpp 빌드 포크
- [helgklaizar/turboquant_mlx](https://github.com/helgklaizar/turboquant_mlx) — MLX 실험 구현
- [danveloper/flash-moe](https://github.com/danveloper/flash-moe) — SSD expert streaming 엔진
- [Qwen/Qwen3.5-397B-A17B](https://huggingface.co/Qwen/Qwen3.5-397B-A17B)
- [bartowski/Qwen_Qwen3.5-35B-A3B-GGUF](https://huggingface.co/bartowski/Qwen_Qwen3.5-35B-A3B-GGUF)

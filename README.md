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
- `./tqp_chat.sh`
- `./tqp_chat_turbo3.sh`
- `./tqp_server.sh`
- `./tqp_bench.sh`

기본 설치 위치:
- `~/.llama-cpp-turboquant`

추천 모델:
- `bartowski/Qwen_Qwen3.5-35B-A3B-GGUF`

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

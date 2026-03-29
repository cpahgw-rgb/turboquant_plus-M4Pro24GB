# TurboQuant / flash-moe 재검토 메모

## 결론 요약

이번 재검토의 핵심은 아래 네 줄로 요약됩니다.

- TurboQuant는 주로 KV 캐시 문제를 다룹니다.
- flash-moe는 거대 MoE 가중치를 SSD에서 스트리밍하는 문제를 다룹니다.
- 두 기술은 서로 경쟁한다기보다 다른 병목을 겨냥합니다.
- 하지만 현재 공개된 자료만 보면, 두 기술이 이미 하나의 통합 엔진으로 묶여 있다고 보기는 어렵습니다.

## 확인된 사실

### 1. `TheTom/turboquant_plus`는 연구 저장소다

`TheTom/turboquant_plus`는 Python 프로토타입, 벤치마크, 논문 확장 아이디어를 포함하는 저장소입니다.

README도 설치를 두 층으로 분리합니다.

- Python 프로토타입 설치
- 별도 `llama.cpp` 포크 빌드

즉, 이 저장소 자체를 바로 `cmake`로 빌드하는 방식은 자연스럽지 않습니다.

### 2. 실제 `llama.cpp` 빌드는 별도 포크에서 한다

TurboQuant KV 캐시가 들어간 실제 실행 경로는 `TheTom/llama-cpp-turboquant`의 `feature/turboquant-kv-cache` 브랜치입니다.

이 포크는 `llama-cli`, `llama-server`, `ggml`, `CMakeLists.txt`를 포함하는 정식 `llama.cpp` 계열 구조를 갖고 있습니다.

그래서 `Qwen3.5-35B-A3B + TurboQuant KV 캐시`를 로컬에서 실행하려면 이 경로가 가장 직접적입니다.

### 3. flash-moe는 다른 문제를 푼다

`flash-moe`는 `Qwen3.5-397B-A17B`를 48GB급 Mac에서 돌리기 위해, 전문가 레이어를 SSD에서 필요할 때마다 읽어오는 커스텀 C/Metal 엔진입니다.

즉, focus는 아래와 같습니다.

- TurboQuant: 긴 대화에서 커지는 KV 캐시 압축
- flash-moe: RAM에 다 안 들어가는 초대형 모델의 가중치 스트리밍

### 4. `35B-A3B`와 `397B-A17B`는 운영 감각이 완전히 다르다

`Qwen3.5-35B-A3B`는 GGUF + llama.cpp 포크 조합으로 현실적인 실사용 후보입니다.

반면 `Qwen3.5-397B-A17B`는
- 전용 엔진이 필요하고
- 디스크 사용량이 매우 크고
- 속도도 훨씬 느립니다.

그래서 둘을 같은 "권장 경로"로 묶기보다, 서로 다른 운영 모드로 보는 편이 맞습니다.

## 확인되지 않은 것

### 1. 공개된 완성형 `flash-moe + TurboQuant` 통합 구현

현재 확인한 범위에서는,
- flash-moe 쪽에 TurboQuant KV 압축이 직접 들어갔다는 1차 자료
- TurboQuant 포크 쪽에 flash-moe식 SSD expert streaming이 들어갔다는 1차 자료
를 찾지 못했습니다.

그래서 "이미 누군가 둘을 합쳤다"고 단정하기는 어렵습니다.

### 2. `MLX + TurboQuant + 397B on 48GB`를 기본 경로로 제시할 근거

기존 스크립트는 MLX 쪽에서 `Qwen3.5-397B-A17B`를 바로 다루는 것처럼 구성돼 있었지만, 재검토 결과 이건 과감한 가정에 가까웠습니다.

상류 `turboquant_mlx`는 실험 구현으로 보는 편이 맞고, 대형 모델 호환성과 실제 메모리 조건은 계속 변할 수 있습니다.

따라서 이 저장소에서는 MLX 경로를 기본 주력 경로에서 내렸습니다.

## 실전 판단

### 1순위: `llama.cpp + TurboQuant`

추천 대상:
- 48GB Mac에서 실제로 가장 먼저 돌려볼 경로가 필요할 때
- 긴 컨텍스트와 실사용 속도의 균형이 중요할 때

왜:
- 저장소 구조가 명확하고
- OpenAI 호환 서버까지 바로 연결되며
- `Qwen3.5-35B-A3B`와 조합이 자연스럽습니다.

### 2순위: `flash-moe`

추천 대상:
- "어쨌든 397B를 내 맥에서 돌려보고 싶다"가 목표일 때

왜:
- 이 문제를 정면으로 푸는 전용 엔진이기 때문입니다.

주의:
- 준비 비용이 큽니다.
- 일반적인 데일리 로컬 LLM 경로로 보기엔 무겁습니다.

### 실험용: `turboquant_mlx`

추천 대상:
- MLX 생태계에서 TurboQuant 캐시 압축을 실험해보고 싶을 때

왜:
- 상류 구현을 빠르게 체험하기 좋기 때문입니다.

주의:
- 이 저장소에서는 더 이상 주력 경로로 취급하지 않습니다.

## 이 저장소에서 반영한 정리

이번 수정에서는 아래 방향으로 정리했습니다.

- `setup_turboquant_plus.sh`
  연구 저장소가 아니라 `llama-cpp-turboquant` 포크를 빌드하도록 수정
- `setup_flash_moe.sh`
  경로 계산과 안내 문구를 정리
- `setup_turboquant.sh`
  과장된 397B MLX 경로를 제거하고, 실험용 설치 도우미로 축소
- `README.md`
  주력 경로 2개 중심으로 재작성

## 최종 한 줄

이 프로젝트의 현실적인 축은 아래 두 개입니다.

- 실사용: `llama.cpp + TurboQuant + Qwen3.5-35B-A3B`
- 대형 실험: `flash-moe + Qwen3.5-397B-A17B`

그 사이를 한 번에 이어붙이는 "만능 통합 경로"는 아직 공개 자료 기준으로는 확인되지 않았습니다.

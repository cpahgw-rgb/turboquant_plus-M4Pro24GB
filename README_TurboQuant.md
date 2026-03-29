# TurboQuant MLX 실험 가이드

이 문서는 이 저장소의 주력 경로가 아니라, `turboquant_mlx`를 Apple Silicon에서 실험적으로 설치해보는 보조 경로를 설명합니다.

## 먼저 알아둘 점

- 기본 추천 경로는 `setup_turboquant_plus.sh` 입니다.
- 이 MLX 경로는 상류 `turboquant_mlx` 프로젝트를 빠르게 체험해보기 위한 보조 도구입니다.
- 예전 버전처럼 `397B + 48GB`를 기본 시나리오로 가정하지 않습니다.

## 설치

```bash
chmod +x setup_turboquant.sh
./setup_turboquant.sh
```

설치가 끝나면 아래 실행기가 생깁니다.

- `./mlx_tq_chat.sh`
- `./mlx_tq_server.sh`
- `./mlx_tq_apply.py`

## 기본 사용법

기본 모델은 `mlx-community/Meta-Llama-3-8B-Instruct-4bit`로 잡혀 있습니다.

```bash
./mlx_tq_chat.sh
```

다른 MLX 모델을 직접 넘길 수도 있습니다.

```bash
./mlx_tq_chat.sh mlx-community/Meta-Llama-3-8B-Instruct-4bit
```

OpenAI 호환 서버:

```bash
./mlx_tq_server.sh mlx-community/Meta-Llama-3-8B-Instruct-4bit 8080
```

## 설정 파일

설정은 `~/.config/turboquant_mlx/config.json`에 저장됩니다.

주요 항목:
- `default_model`
- `bits`
- `fp16_sink_size`
- `host`
- `port`

## 이 경로를 쓸 때의 기대치

좋은 점:
- MLX 환경에서 TurboQuant 캐시 압축을 실험하기 쉽습니다.
- 작은/중간급 모델에 붙여보기 편합니다.

주의할 점:
- 상류 프로젝트의 호환성 범위는 계속 변할 수 있습니다.
- 이 저장소는 MLX 쪽을 실험용 경로로만 유지합니다.
- 실사용의 1순위는 여전히 `llama.cpp + TurboQuant` 입니다.

## 참고 자료

- [helgklaizar/turboquant_mlx](https://github.com/helgklaizar/turboquant_mlx)
- [Google Research TurboQuant](https://research.google/blog/turboquant-redefining-ai-efficiency-with-extreme-compression/)

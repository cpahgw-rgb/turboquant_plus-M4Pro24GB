# flash-moe × TurboQuant 융합 분석 (업데이트)

## 이미 누군가 했다

검색 결과, **직접적인 flash-moe + TurboQuant 결합체**는 없지만, 거의 동일한 효과를 내는 프로젝트 **2개**가 이미 존재합니다.

---

## 발견 1: turboquant_plus (★ 핵심 발견)

> [github.com/TheTom/turboquant_plus](https://github.com/TheTom/turboquant_plus)

**llama.cpp 포크에 TurboQuant Metal 커널을 직접 구현한 프로젝트.**

| 항목 | 내용 |
|---|---|
| 기반 | llama.cpp + 커스텀 Metal 셰이더 |
| KV 캐시 압축 | turbo3 (3.25bit, 4.9x) / turbo4 (4.25bit, 3.8x) |
| MoE 지원 | **Qwen3.5-35B-A3B (MoE)에서 검증됨** |
| Apple Silicon | M1~M5 전체 지원, M4 전용 최적화(4-mag LUT, +38%) |
| 추가 최적화 | **Sparse V** — 어텐션 가중치가 낮은 V 역양자화 스킵 (+22.8% 속도) |
| 테스트 | 141개 유닛테스트, NIAH 9/9 통과 |
| 상태 | **프로덕션 레디** |

### 왜 이게 중요한가 (M4 Pro 48GB 기준)

Qwen3.5-35B-A3B 모델 = 35B 파라미터, 토큰당 **3B만 활성화**하는 MoE 구조.

```
모델 크기 (4-bit): ~20GB → 48GB RAM에 완전히 적재
활성 파라미터:      3B / 토큰 → 매우 빠른 추론
KV 캐시:           turbo3 = 4.9x 압축 → 128K+ 컨텍스트 가능
M4 최적화:         4-mag LUT 자동 감지 → +38% 디코드 속도
Sparse V:          +22.8% 추가 속도 (32K 컨텍스트)
```

**SSD 스트리밍이 필요 없다.** 35B 모델이 RAM에 통째로 들어가기 때문에 flash-moe의 디스크 오프로딩 없이도 전체가 작동합니다.

### 성능 비교

| 구성 | 속도 | 품질 | 컨텍스트 |
|---|---|---|---|
| flash-moe 397B (4-bit, SSD) | ~4.4 tok/s | GPT-4급 | ~128K (KV 제한) |
| **turboquant_plus 35B-A3B (turbo4)** | **~47 tok/s** | **우수** | **128K+ (turbo 압축)** |
| turboquant_plus 35B-A3B (turbo3) | ~57 tok/s (Sparse V) | 우수 | 128K+ |
| MLX 27B (TurboQuant 3-bit) | 15-22 tok/s | 우수 | 128K+ |

*참고: 47-57 tok/s는 M5 Max 128GB 벤치마크. M4 Pro 48GB에서는 30-40 tok/s 수준으로 예상.*

---

## 발견 2: Anemll/flash-moe (포크)

> [github.com/Anemll/flash-moe](https://github.com/Anemll/flash-moe)

**원본 flash-moe의 강화 포크.**

| 항목 | 내용 |
|---|---|
| 타겟 | M5 Max 128GB (원본은 M3 Max 48GB) |
| 전문가 양자화 | Unsloth Q3 GGUF (IQ3_XXS/IQ4_XS 혼합 정밀도) |
| 성능 | 12.9 tok/s (원본 4.4 tok/s 대비 3x) |
| 특징 | Metal 4 NAX, page-aligned pread, 하이브리드 MLX+GGUF |
| TurboQuant | **미적용** — 전문가 양자화 개선에 집중 |

이 포크는 TurboQuant KV 압축이 아닌 **전문가 레이어 양자화 개선**에 초점을 맞춘 프로젝트입니다.

---

## 최종 추천: M4 Pro 48GB 최적 구성

### ★ 1순위: turboquant_plus + Qwen3.5-35B-A3B

```
왜: RAM에 완전 적재 + TurboQuant KV 압축 + MoE 검증완료
속도: ~30-40 tok/s (M4 Pro 예상)
품질: 35B급 (3B 활성) — 매우 우수
컨텍스트: 128K+ (turbo3/4 압축)
설치: llama.cpp 빌드 → 모델 다운 → 실행
```

### 2순위: flash-moe + 397B (프리미엄)

```
왜: 최고 품질 (397B 전체 파라미터)
속도: ~4-5 tok/s (SSD 스트리밍)
품질: GPT-4급
조건: SSD 210GB 여유 공간
```

### 3순위: MLX + 27B Claude Opus Distilled

```
왜: 가장 쉬운 셋업, Python 생태계
속도: 15-22 tok/s
품질: Claude Opus 증류 — 우수
```

---

## 두 기술의 본질적 차이 (쉬운 설명)

```
┌─────────────────────────────────────────────────────┐
│                  당신의 Mac (48GB)                    │
│                                                     │
│  ┌─────────────┐                                    │
│  │ 모델 가중치  │ ← flash-moe가 해결 (SSD→RAM 스트리밍)│
│  │  (209GB)    │    turboquant_plus는 필요없음       │
│  └─────────────┘    (35B 모델은 RAM에 들어감)         │
│                                                     │
│  ┌─────────────┐                                    │
│  │ KV 캐시     │ ← TurboQuant가 해결 (16bit→3bit)   │
│  │ (대화 이력)  │    flash-moe에는 없는 기능          │
│  └─────────────┘                                    │
│                                                     │
│  turboquant_plus = 두 번째 문제를 llama.cpp에서 해결  │
│  flash-moe      = 첫 번째 문제를 C/Metal로 해결       │
│                                                     │
│  ★ 35B MoE는 RAM에 들어가므로,                       │
│    turboquant_plus 하나로 두 문제 모두 해결!           │
└─────────────────────────────────────────────────────┘
```

---

## 참고 자료

- [turboquant_plus](https://github.com/TheTom/turboquant_plus) — llama.cpp + TurboQuant Metal 커널
- [Tom Turney 트윗 (구현 발표)](https://x.com/no_stp_on_snek/status/2036792058854121601)
- [Anemll/flash-moe](https://github.com/Anemll/flash-moe) — flash-moe 강화 포크
- [flash-moe 원본](https://github.com/danveloper/flash-moe)
- [turboquant_plus Sparse V 문서](https://github.com/TheTom/turboquant_plus/blob/main/docs/papers/sparse-v-dequant.md)

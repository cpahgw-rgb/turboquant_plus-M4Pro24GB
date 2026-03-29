# turboquant_plus-M4Pro24GB

Local LLM setup optimized for **Apple M4 Pro 48GB** — combining TurboQuant KV cache compression with MoE models for maximum context length and speed.

## What is this?

A turnkey setup for running large language models locally on Apple Silicon Macs, leveraging:

- **TurboQuant** (Google, ICLR 2026): KV cache compression from 16-bit to 3-bit via PolarQuant + QJL. ~5x memory savings with zero accuracy loss.
- **Mixture of Experts (MoE)**: Qwen3.5-35B-A3B activates only ~3B parameters per token out of 35B total — high quality at low compute cost.
- **Metal-optimized kernels**: Native Apple Silicon acceleration with 4-mag LUT (+38% on M4) and Sparse V (+22.8% decode speed).

## Setup Options

### Option 1: turboquant_plus (Recommended for M4 Pro 48GB)

llama.cpp fork with TurboQuant Metal kernels. Best balance of speed (~30-40 tok/s) and quality.

```bash
chmod +x setup_turboquant_plus.sh
./setup_turboquant_plus.sh
```

**Target model**: Qwen3.5-35B-A3B (Q4_K_M, ~20GB) — fits entirely in 48GB unified memory.

Features:
- `turbo4` KV cache: 3.8x compression, 65K context
- `turbo3` KV cache: 4.9x compression, 131K context
- OpenAI-compatible API server
- Built-in benchmarking

### Option 2: MLX TurboQuant (Python, easier setup)

Pure Python/MLX implementation. Simpler but slightly slower.

```bash
chmod +x setup_turboquant.sh
./setup_turboquant.sh
```

Features:
- 4-tier model system (premium/primary/reasoning/fast)
- Interactive chat with model switching
- OpenAI-compatible API server

### Option 3: flash-moe (For 397B model)

Pure C/Metal engine for Qwen3.5-397B-A17B. Streams experts from SSD — runs a 397B model on 48GB RAM.

```bash
chmod +x setup_flash_moe.sh
./setup_flash_moe.sh
```

**Note**: Requires ~210GB SSD space. ~4.4 tok/s. Best raw quality but much slower.

## Architecture Comparison

| | turboquant_plus | MLX TurboQuant | flash-moe |
|---|---|---|---|
| Model | 35B-A3B | 9B-32B | 397B-A17B |
| Speed | ~30-40 tok/s | ~15-30 tok/s | ~4.4 tok/s |
| Context | 131K (turbo3) | 32K-65K | 8K-32K |
| RAM usage | ~20GB | ~5-20GB | ~42GB + SSD |
| Backend | C/Metal | Python/MLX | C/Metal |

## Key Insight

flash-moe and TurboQuant solve **different problems**:
- **flash-moe**: "Model doesn't fit in RAM" → SSD expert streaming
- **TurboQuant**: "KV cache grows with conversation length" → cache compression

For M4 Pro 48GB, the 35B-A3B model fits entirely in RAM, so **turboquant_plus alone** handles both model loading and KV compression — no SSD streaming needed.

## Files

| File | Description |
|---|---|
| `setup_turboquant_plus.sh` | llama.cpp + TurboQuant Metal kernels setup |
| `setup_turboquant.sh` | MLX-based TurboQuant setup (Python) |
| `setup_flash_moe.sh` | flash-moe C/Metal engine setup |
| `verify_setup.sh` | Environment verification script |
| `ANALYSIS_fusion.md` | Detailed fusion analysis document |
| `README_TurboQuant.md` | MLX setup usage guide |

## Requirements

- Apple Silicon Mac (M4 Pro 48GB recommended)
- macOS 14+ (Sonnet or later)
- Xcode Command Line Tools
- ~20GB free space (for 35B-A3B model)

## References

- [TurboQuant paper (ICLR 2026)](https://arxiv.org/abs/2501.06036)
- [turboquant_plus](https://github.com/TheTom/turboquant_plus) — llama.cpp fork with TurboQuant Metal kernels
- [turboquant_mlx](https://github.com/helgklaizar/turboquant_mlx) — Python/MLX implementation
- [flash-moe](https://github.com/danveloper/flash-moe) — SSD expert streaming for 397B MoE
- [Qwen3.5-35B-A3B](https://huggingface.co/bartowski/Qwen3.5-35B-A3B-GGUF) — GGUF quantized model

## License

MIT

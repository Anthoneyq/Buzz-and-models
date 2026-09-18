# Buzz Local AI — M1 Max 64GB

**Dan: open [START HERE](START%20HERE.md) first.**

A dedicated local AI machine for **Buzz.xyz**. Three paste-into-Terminal steps:

1. [Step 01 - Install everything](Step%2001%20-%20Install%20everything.sh) — Homebrew, Git, Node.js, Python, the oMLX app, Buzz, Desktop start/stop buttons.
2. [Step 02 - Download the AI models](Step%2002%20-%20Download%20the%20AI%20models.sh) — seven MLX models, about 121 GB. Safe to paste again if interrupted.
3. [Step 03 - Start and test](Step%2003%20-%20Start%20and%20test.sh) — starts oMLX, runs a tool-call test on every model, writes **Dan AI Notes** to the Desktop, opens Buzz.

## How it fits together

**Buzz → OpenAI-compatible API (`http://127.0.0.1:8000/v1`) → oMLX → MLX models → Apple Silicon GPU**

oMLX replaces Ollama. It loads models on demand and unloads the least recently used one when memory runs low, so all seven live on disk but only what fits stays in memory.

## Models

| Model | Job | Size |
|---|---|---|
| Qwen3.6 35B-A3B (oQ4e, MTP) | Everyday agent. Fast. Start here | 22 GB |
| Qwen3-Coder-Next 80B-A3B (4-bit) | Heavy coding. Let it run alone | 45 GB |
| Qwen3.8 27B (oQ4e, MTP) | Reasoning, architecture, planning | 17 GB |
| Devstral Small 2 24B (4-bit) | Independent code review | 15 GB |
| Gemma 4 12B instruct (QAT 4-bit) | Second worker, writing | 11 GB |
| Qwen3.5 9B (4-bit) | General worker | 6 GB |
| Qwen3.5 4B (8-bit) | Fast repetitive tasks | 5 GB |

Typical workflow: **Large Model → Workers → Reviewer → Final Verification**

## Why these builds

- An M1 Max reads memory at 400 GB/s, so speed is set by how many bytes each token touches. The two A3B models use only 3B parameters per token and stay fast. The dense 27B and 24B are 4-bit because their 8-bit builds run near 6 tokens a second, too slow for agents.
- The oMLX **app** is used instead of the Homebrew build because it ships the native Qwen kernels precompiled. The Homebrew build silently falls back to slower paths.
- The GPU memory limit is raised from macOS's default (about 48 GB) to 52 GB, leaving 12 GB for macOS and Buzz.
- Qwen3.8-Flash-Next is newer and stronger, but its smallest MLX build is 73 GB and does not fit in 64 GB.

Parallels/Windows must be closed while the models are in use. **Stop Dan AI** on the Desktop frees the memory.

# Buzz-and-models
# Buzz Local AI — M1 Max 64GB

## What This Setup Does

This Mac is being configured as a dedicated local AI machine for **Buzz.xyz**.

The terminal installer will automatically install:

* Buzz
* Ollama
* Required development tools
* Six local AI models
* Local model server
* Basic tool-calling tests

## Models

**Qwen3-Coder-Next 80B** — Heavy coding and major implementations
**Qwen3.8 27B** — Reasoning, architecture, and system analysis
**Devstral Small 2 24B** — Debugging and independent code review
**Qwen3.5 9B** — General worker
**Gemma 4 12B** — Secondary worker
**Qwen3.5 4B** — Fast repetitive tasks

## How It Works

The models do not all run simultaneously.

Typical workflow:

**Large Model → Workers → Reviewer → Final Verification**

Heavy models can use most of the Mac's 64GB RAM, then unload before other models take over.

## Installation

1. Plug the Mac into power.
2. Keep the lid open.
3. Open **Terminal**.
4. Paste the entire installation command.
5. Enter the Mac password if requested.
6. Wait for all downloads and tests to finish.
7. Open **Buzz AI Setup.txt** from the Desktop.
8. Follow the remaining Buzz instructions.

Use models marked **PASS** in the setup results.

#!/usr/bin/env bash
# Serve the base model with all role adapters loaded at once (vLLM multi-LoRA).
# One process, adapters selected per request by a2fp_agent/llm/adapters.py.
set -euo pipefail
echo "TODO(A4): vllm serve <base-model> --enable-lora --lora-modules <role>=<path> ..."

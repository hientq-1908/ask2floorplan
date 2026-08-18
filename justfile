# ask2floorplant — per-project targets.
# Each project has its own venv and lockfile; there is no workspace.

# --- setup ---------------------------------------------------------------
sync-contract:   ; cd contract   && uv sync
sync-dataprep:   ; cd dataprep   && uv sync
sync-agent:      ; cd agent      && uv sync
sync-agent-train:; cd agent      && uv sync --extra train
sync-diffusion:  ; cd diffusion  && uv sync
sync-pipeline:   ; cd pipeline   && uv sync
sync-all: sync-contract sync-dataprep sync-agent sync-diffusion sync-pipeline

# --- checks --------------------------------------------------------------
test:
    cd contract  && uv run pytest
    cd dataprep  && uv run pytest
    cd agent     && uv run pytest
    cd diffusion && uv run pytest
    cd pipeline  && uv run pytest

lint:
    uvx ruff check .
    uvx ruff format --check .

# Layering checks. If either fails, a dependency edge was added backwards.
check-layering:
    #!/usr/bin/env bash
    set -euo pipefail
    cd agent && uv sync
    if uv run python -c "import torch" 2>/dev/null; then
      echo "FAIL: agent runtime pulled torch. Training deps belong behind --extra train."; exit 1
    fi
    cd ../contract
    if uv pip list 2>/dev/null | grep -Eiq "torch|anthropic|openai"; then
      echo "FAIL: contract grew a heavy dependency. It is pydantic-only."; exit 1
    fi
    echo "OK: layering intact"

export-schema:  ; cd contract && uv run python -m a2fp_contract.export_schema

# --- data ----------------------------------------------------------------
build-artifact: ; cd dataprep && uv run python scripts/build_artifact.py

# --- module 1: agent (runtime flow) --------------------------------------
chat workflow="full": ; cd agent && uv run a2fp-agent chat --workflow {{workflow}}
train-drafter:        ; cd agent && uv run python lora_finetuning/scripts/train_role.py role=graph_drafter
serve:                ; cd agent && bash lora_finetuning/serving/serve_vllm.sh
eval-agent:           ; cd agent && uv run python scripts/evaluate.py

# --- module 1: lora_finetuning -------------------------------------------
datagen:
    cd agent && uv run python lora_finetuning/scripts/gen_backtranslation.py
    cd agent && uv run python lora_finetuning/scripts/gen_distill.py
    cd agent && uv run python lora_finetuning/scripts/gen_defects.py

# --- module 2: diffusion -------------------------------------------------
train-diffusion repr="boxes": ; cd diffusion && uv run python scripts/train.py representation={{repr}}
sample:                       ; cd diffusion && uv run python scripts/sample.py
eval-diffusion:               ; cd diffusion && uv run python scripts/evaluate.py

# --- end to end ----------------------------------------------------------
demo:
    cd pipeline && uv run a2fp generate \
      --query "2br apartment, 60m², kitchen next to living" \
      --backend solver --out ../runs/demo.svg

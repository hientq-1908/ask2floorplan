# `lora_finetuning`

Everything that turns the prompted agent into a fine-tuned one. Kept out of `src/a2fp_agent/` on purpose: the
runtime flow imports nothing from here, and nothing here belongs in the installed wheel.

```
src/a2fp_agent/     runtime — roles, workflows, retrieval, tools.  No torch, ever.
lora_finetuning/    training — datagen, SFT, serving.  Imports the runtime, not the reverse.
```

```bash
cd .. && uv sync --extra train    # torch, trl, peft live only in this extra
```

## What gets an adapter

| Role | Adapter? | Why | Order |
|---|---|---|---|
| **GraphDrafter** | yes | Verifiable target — the graph either matches the hidden spec or it doesn't | first |
| **Critic** | yes | Trained on injected defects: cheap, labelled, verifiable | second |
| **Interviewer** | maybe | Next-question prediction, weakest signal | last or never |
| **Retriever** | **no** | Retrieval is an embedding + index problem. Fine-tuning an 8B model to do nearest-neighbour lookup is strictly worse than a vector index. | — |

Ship the GraphDrafter adapter and **measure** before starting the next one. Three adapters means three datasets,
three runs, and three eval surfaces.

## Data synthesis

Two sources that compose into one pipeline. Back-translation supplies realistic targets, the simulator makes the
dialogue multi-turn, the validator makes the result filterable.

```
ground-truth FloorGraph (from datasets/rplan-graphs/vN)   =  HIDDEN SPEC
  └─ back_translation.py ──────────► opening query + persona
       └─ distill.py: frontier pipeline  ⇄  user_simulator.py
                                            (answers ONLY from the hidden spec)
            └─ trajectory ──► filters.py: final graph ≟ hidden spec ──► keep / discard
                 └─ to_sft.py ──► per-role SFT sets in data/
```

`defect_injection.py` builds the Critic's set separately: corrupt a ground-truth graph — drop an adjacency,
disconnect a room, oversize one past plausibility — and the Critic must find the defect.

## Run it

```bash
cd ../dataprep && uv run python scripts/build_artifact.py   # once
cd ../agent
uv run python lora_finetuning/scripts/gen_backtranslation.py
uv run python lora_finetuning/scripts/gen_distill.py
uv run python lora_finetuning/scripts/gen_defects.py
uv run python lora_finetuning/scripts/train_role.py role=graph_drafter
bash lora_finetuning/serving/serve_vllm.sh
```

## Layout

| Path | Owns |
|---|---|
| `datagen/` | back-translation, user simulator, distillation, defect injection, filtering, SFT formatting |
| `training/` | TRL + peft SFT loop, adapter registry (provenance: data version, config, base model), callbacks |
| `serving/` | vLLM multi-LoRA launch |
| `configs/` | `base_model/`, `role/`, `datagen/` — Hydra groups. The flow's own `workflow/` group stays in `../configs/`. |
| `scripts/` | entry points |
| `data/` | generated SFT sets. Gitignored — regenerate from the artifact. |

## Two things to be honest about

**SFT on distilled data cannot beat the teacher.** The win is cost, latency, and control — not quality. Exceeding
the frontier pipeline needs a rejection-sampling reward loop, deliberately out of scope. Say so in any writeup
rather than reporting a quality result.

**The user simulator caps trajectory realism.** It answers from a hidden spec, so it is more cooperative and more
precise than a real person. Never evaluate on simulator dialogues alone — that is what
`src/a2fp_agent/eval/datasets/golden_queries.jsonl` is for, and why that file must stay human-written.

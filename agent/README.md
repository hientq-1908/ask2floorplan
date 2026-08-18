# Module 1 — `agent`

**User query → `FloorGraph`.** A multi-role LLM agent that interviews the user, drafts a graph, criticises it,
and repairs it. Roles are fine-tuned as per-role LoRA adapters over one shared base model.

## Contract

**In:** a natural-language query, plus however many dialogue turns the Interviewer needs.

```
"I want a 2-bedroom apartment, around 60m², with the kitchen open to the living room
 and the bathroom off the hallway rather than a bedroom."
```

**Out:** a `FloorGraph` — the only thing Module 2 ever sees.

```json
{
  "schema_version": "0.1.0",
  "nodes": [
    {"id": 0, "type": "living_room", "hints": {"target_area_m2": [18.0, 26.0]}},
    {"id": 1, "type": "kitchen",     "hints": {"target_area_m2": [6.0, 10.0]}},
    {"id": 2, "type": "bedroom",     "hints": {"target_area_m2": [12.0, 16.0]}},
    {"id": 3, "type": "bedroom",     "hints": {"target_area_m2": [9.0, 12.0]}},
    {"id": 4, "type": "bathroom",    "hints": {"target_area_m2": [4.0, 6.0]}},
    {"id": 5, "type": "hallway",     "hints": {}}
  ],
  "edges": [
    {"source": 0, "target": 1, "kind": "open"},
    {"source": 0, "target": 5, "kind": "open"},
    {"source": 5, "target": 2, "kind": "door"},
    {"source": 5, "target": 3, "kind": "door"},
    {"source": 5, "target": 4, "kind": "door"}
  ],
  "size_hint": {"total_area_m2": 60.0, "room_count": 6}
}
```

> **`hints` and `size_hint` are recorded but not honoured in v0.** The reference architecture has no input for
> them — see [`diffusion/README.md`](../diffusion/README.md) *Graph → model input*. Collect them, store them,
> do not tell users they work. They become live only if hint-conditioning is built after D3.

## Roles

Adapted from [PaperBanana](https://github.com/dwzhu-pku/PaperBanana), which prompts everything and fine-tunes
nothing. We keep the decomposition and add training. See [ADR 0006](../docs/adr/0006-paperbanana-role-decomposition.md).

| Role | Owns | How it's built | Order |
|---|---|---|---|
| **Interviewer** | Elicits rooms, adjacencies, size. Decides what to ask next and when to stop. | LoRA — weakest signal, do last or never | A6 |
| **Retriever** | Nearest reference graphs as few-shot exemplars, conditioning output on the real data distribution. | **Embedding index — never a LoRA.** Fine-tuning an 8B model to do nearest-neighbour lookup is strictly worse than a vector index. | A1 |
| **GraphDrafter** | Dialogue state → structured `FloorGraph`. | LoRA — first adapter. Verifiable target, clearest win. | A4 |
| **Critic** | Deterministic validation first; the LLM only answers *"does this reflect what the user asked for?"* | LoRA — trained on injected defects | A5 |

PaperBanana's Critic is a VLM because no programmatic checker exists for "good diagram." We have one, so the
deterministic checker runs first and the model handles only what it can't.

## Workflow modes

Selected by Hydra config group, never by an `if` chain — that is what makes each role's contribution measurable.

| Mode | Sequence |
|---|---|
| `vanilla` | GraphDrafter only, single shot. The ablation floor. |
| `interview_draft` | Interviewer → GraphDrafter |
| `draft_critic` | GraphDrafter → Critic, N rounds |
| `full` | Retriever → Interviewer → GraphDrafter → Critic |

```bash
uv run a2fp-agent chat --workflow full
uv run python scripts/evaluate.py workflow=full,draft_critic,vanilla   # the ablation table
```

## Quickstart

```bash
uv sync                          # no torch — see the layering rule below
export VLLM_BASE_URL=...         # or a frontier API key
uv run a2fp-agent chat --workflow full
```

## Fine-tuning

All of it — datagen, SFT, serving — lives in **[`lora_finetuning/`](lora_finetuning/README.md)**, outside the
runtime package. `src/a2fp_agent/` never imports it; it imports `src/a2fp_agent/`.

```
src/a2fp_agent/     runtime flow — roles, workflows, retrieval, tools.  No torch, ever.
lora_finetuning/    datagen, LoRA SFT, vLLM multi-LoRA serving.
```

Adapters, in order: **GraphDrafter** (verifiable target, first), **Critic** (trained on injected defects),
**Interviewer** (weakest signal, last or never). The **Retriever never gets one** — retrieval is an embedding
index, not a fine-tuning problem.

```bash
uv sync --extra train
uv run python lora_finetuning/scripts/train_role.py role=graph_drafter
```

## Evaluation

Scored on query input alone, with no dependency on Module 2.

| Set | Origin | Measures |
|---|---|---|
| `eval/datasets/golden_queries.jsonl` | **~60 hand-written by you** | Whether the system is actually good |
| `eval/datasets/bench_test.jsonl` | Back-translated, held out | Scale, and teacher imitation |

> **Never regenerate the golden set with a model.** Training data and bench both come from the same model family;
> without human-authored held-out queries you are measuring how well the student imitates the teacher, not
> whether the output is any good. This file is the only honest signal in the project.

Retrieval draws from the bench **reference** split only. Reference and test never mix.

## Layering rule

`uv sync` must not install torch. The runtime speaks HTTP to vLLM; everything that needs a GPU lives behind
`--extra train`. CI enforces it:

```bash
just check-layering
```

If someone "helpfully" promotes torch to a base dependency, every agent experiment starts dragging CUDA behind it
and the split between this project and `diffusion/` stops meaning anything.

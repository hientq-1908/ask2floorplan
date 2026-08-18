# ask2floorplant

Natural-language query → floor graph → vector floorplan.

```
"2br apartment, 60m², kitchen next to the living room"
        │
        ▼
   ┌─────────┐   FloorGraph    ┌───────────┐   FloorPlan    ┌─────┐
   │  agent  │ ──────────────► │ diffusion │ ─────────────► │ SVG │
   └─────────┘  rooms + edges  └───────────┘ corner polygons└─────┘
    Module 1                     Module 2
```

## The four projects

| Project | Purpose | Input | Output |
|---|---|---|---|
| [`contract/`](contract/) | The shared definition of `FloorGraph` and `FloorPlan`. Pydantic only — no torch, no LLM SDK. | — | models, validators, SVG viz, JSON Schema |
| [`dataprep/`](dataprep/) | Turns raw RPLAN into a versioned, checksummed dataset. Run rarely, read often. | RPLAN raw | `datasets/rplan-graphs/vN/` |
| [`agent/`](agent/README.md) | **Module 1.** Multi-role LLM agent that interviews the user and emits a graph. Roles fine-tuned as per-role LoRA adapters. | user query + dialogue | `FloorGraph` |
| [`diffusion/`](diffusion/README.md) | **Module 2.** Diffusion model trained from scratch that turns a graph into room polygons. | `FloorGraph` | `FloorPlan` |
| [`pipeline/`](pipeline/) | Thin integration: a CLI chaining the two, plus a non-ML solver backend. Depends on both; nothing depends on it. | user query | SVG |

## Why the two modules are independent

Each is developed, versioned, and **evaluated on ground-truth input**. Module 2's quality is measured against
real extracted graphs, not against whatever Module 1 happened to produce that day — so a regression is
attributable to exactly one project.

Independence has one hard constraint: the two must not drift apart at the seam. Two mechanisms enforce that,
and there is no other shared code.

**1. One definition of the contract.** `contract/` is a tiny pydantic-only package that every other project
path-depends on. It must never grow a heavy dependency; CI asserts this.

**2. Extraction is an artifact, not a library.** `dataprep/` runs RPLAN → graphs + plans **once** and writes a
versioned, checksummed dataset. Both modules read it as *data* and pin its version in config. Neither imports
extraction code, so neither can quietly re-tune it.

```
RPLAN raw ──► dataprep ──► datasets/rplan-graphs/v1/  (graphs, plans, splits, manifest)
                                    │
                    ┌───────────────┴───────────────┐
              agent/ (targets)              diffusion/ (inputs + targets)
```

Changing extraction rules mints `v2`. Migration is deliberate, and every result traces to the artifact that
produced it.

## Quickstart

This runs end-to-end **before any model exists**, using the rectangular-dissection solver as the graph→plan
backend. If this works, the repo is real.

```bash
git init
cd contract && uv sync && uv run pytest && cd ..
cd pipeline && uv sync

uv run a2fp generate \
    --query "2br apartment, 60m², kitchen next to living" \
    --backend solver --out ../runs/demo.svg
```

Or just `just demo`.

Everything else — RPLAN, torch, vLLM — comes later. See the milestones below.

## Repo map

| Path | What lives there |
|---|---|
| `contract/` | `FloorGraph`, `FloorPlan`, validators, SVG viz, exported JSON Schema |
| `dataprep/` | RPLAN parsing, graph/plan extraction, splits, artifact manifests |
| `agent/` | Module 1: roles, workflows, retrieval, datagen, LoRA training, eval |
| `diffusion/` | Module 2: datasets, representations, denoisers, training, eval |
| `pipeline/` | CLI, solver baseline, end-to-end integration tests |
| `datasets/` | Artifact store. Manifests and splits committed; payloads gitignored. |
| `data/raw/` | Raw RPLAN. Never committed. |
| `runs/` | Checkpoints, adapters, samples, logs. Never committed. |
| `docs/adr/` | Why decisions were made, dated. Start here when something looks odd. |
| `notebooks/` | Exploration only. Nothing imports from here. |

## Documentation

- [`docs/graph-schema.md`](docs/graph-schema.md) — the contract, with worked examples and extraction rules
- [`docs/coordinate-conventions.md`](docs/coordinate-conventions.md) — units, origin, winding order
- [`docs/adr/`](docs/adr/) — architecture decision records
- [`docs/experiments.md`](docs/experiments.md) — running log of what was tried and what happened

## Status

| Track | Milestone | State |
|---|---|---|
| Foundation | F0 contract + viz + READMEs | scaffolded |
| Foundation | F1 end-to-end with solver backend | not started |
| Foundation | F2 RPLAN artifact v1 | not started |
| A — agent | A1 prompted `full` workflow | not started |
| D — diffusion | D0 run HouseDiffusion as-is | not started |

Keep this table current or delete it. A stale status table is worse than none.

## Reference work

- **HouseDiffusion** ([paper](https://arxiv.org/abs/2211.13287), [code](https://github.com/aminshabani/house_diffusion)) —
  Module 2's reference architecture. Graph-conditioned, outputs polygon loops for rooms and doors.
- **PaperBanana** ([repo](https://github.com/dwzhu-pku/PaperBanana)) — Module 1's role decomposition, retrieval-driven
  ICL, and the practice of making ablation modes first-class config.

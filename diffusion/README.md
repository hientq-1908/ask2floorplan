# Module 2 — `diffusion`

**`FloorGraph` → `FloorPlan`.** A diffusion model, trained from scratch, that turns a room graph into vector
room polygons. Reference architecture: [HouseDiffusion](https://arxiv.org/abs/2211.13287)
([code](https://github.com/aminshabani/house_diffusion)).

## Contract

**In:** a `FloorGraph`. It cannot tell whether that came from Module 1 or straight out of the dataprep artifact —
which is exactly why this project can be evaluated without Module 1 existing.

```json
{
  "schema_version": "0.1.0",
  "nodes": [
    {"id": 0, "type": "living_room", "hints": {}},
    {"id": 1, "type": "kitchen",     "hints": {}}
  ],
  "edges": [{"source": 0, "target": 1, "kind": "open"}],
  "size_hint": {"total_area_m2": 60.0, "room_count": 2}
}
```

**Out:** a `FloorPlan`. Rooms *and doors* are polygon loops — a door is a component in its own right, not an
annotation on a wall.

```json
{
  "schema_version": "0.1.0",
  "units": "mm",
  "rooms": [
    {"node_id": 0, "type": "living_room",
     "corners": [[0, 0], [5200, 0], [5200, 4600], [0, 4600]]},
    {"node_id": 1, "type": "kitchen",
     "corners": [[5200, 0], [8100, 0], [8100, 3000], [5200, 3000]]}
  ],
  "doors": [
    {"between": [0, 1], "corners": [[5200, 900], [5300, 900], [5300, 1800], [5200, 1800]]}
  ]
}
```

> `hints` and `size_hint` arrive on every graph and are **ignored in v0**. There is no input for them in the
> reference architecture — see the open gap at the end of the encoding section.

## The three seams

The plug-and-play contract. Each is an ABC selected by a Hydra config group; adding an implementation should
require no edits outside its own directory.

| Seam | ABC | Now | Add one by |
|---|---|---|---|
| **Dataset** | `data/base.py` | `artifact.py` (RPLAN), `cubicasa.py` (stub) | Implementing the ABC, adding `configs/data/<name>.yaml` |
| **Representation** | `representation/base.py` | `corners.py` (v0), `boxes.py` (debug) | Same — but note it bundles encode/decode/loss/metrics, because swapping changes all four together |
| **Denoiser** | `models/base.py` | `transformer.py` | Same, via `configs/model/<name>.yaml` |

```bash
uv run python scripts/train.py representation=boxes model=transformer data=rplan
```

## Graph → model input

There is **no GNN and no graph embedding vector.** The graph enters in two separate places. Read this before
touching `representation/` or `models/conditioning/`.

**Nodes → token features.** The plan is flattened into one sequence of *corner tokens*: every room and every door
contributes `N_i` corners, so `T = Σ N_i`.

| Feature | Source | Purpose |
|---|---|---|
| `(x, y)` normalized to `[-1, 1]` | polygon corner | **the only thing diffused** |
| room-type embedding | node type | which category of room |
| room-index embedding | node id | keeps two bedrooms distinct |
| corner-index embedding | position in loop | cyclic ordering within a component |

**Edges → attention masks.** Three attention types; the adjacency matrix *is* the third one's mask:

1. **Component-wise self-attention** — corners attend only within their own room. Learns room shape.
2. **Global self-attention** — all corners attend to all. Global coherence.
3. **Relational cross-attention** — cross-room attention **only where a graph edge exists**. This is the exact
   point at which the `FloorGraph` constraint enters the network.

**Shapes:**

| | Train | Inference |
|---|---|---|
| `T` | from ground-truth polygons | from `representation/corner_count.py` |
| coordinates | ground truth `x₀ ∈ ℝ^{T×2}` | Gaussian noise `x_T` |
| embeddings / masks | from the graph | from the graph |

This is **why corner count is an input, not a prediction**: it sets the sequence length, and you cannot sample
noise into a tensor whose shape you don't know. `corner_count.py` draws it from artifact statistics conditioned
on room type and area. Get that distribution wrong and rooms come out systematically too simple or too jagged
while every conformance metric still reads green — so compare sampled against empirical as a standing check.

**Open gap — soft geometry hints have nowhere to go.** Honouring `target_area_m2` means adding per-token features
concatenated onto that room's corner embeddings: a deviation from the reference, same class as boundary
conditioning. Defer past D3, then ablate against the reproduced baseline so the effect is measurable.

## What v0 deliberately does not do

- **No boundary conditioning.** The reference conditions on the graph alone and generates the footprint itself.
  `models/conditioning/boundary_encoder.py` is an empty seam. Consequence: **the user cannot specify plot shape
  or size.** ([ADR 0005](../docs/adr/0005-no-boundary-conditioning-in-v0.md))
- **No footprint filtering.** Trains on full RPLAN. `dataprep/boundary_filter.py` exists for ablations only.
- **No hint conditioning.** See above.

Each of these, once added, costs comparability with the reproduced baseline. Keep the D3 checkpoint and ablate
against it — not against the paper's table.

## Artifact pinning

This project reads `datasets/rplan-graphs/vN/` as **data**. It does not import extraction code, by design: if
both modules could re-tune extraction, they would drift and the split would be worthless.

```yaml
# configs/data/rplan.yaml
artifact: rplan-graphs/v1
```

Changing extraction rules mints `v2` in `dataprep/`. Migration is a deliberate config change, and every result
traces back to the artifact version that produced it.

## Quickstart

```bash
uv sync
uv run python scripts/train.py representation=boxes    # minutes, not hours
uv run python scripts/sample.py
uv run python scripts/evaluate.py data.artifact=v1 split=test
```

Start on `boxes`. It trains fast enough to catch pipeline bugs before you spend a GPU-day on `corners`.

## Training

- Config groups compose the run; **a run must be reproducible from its config alone.**
- W&B behind `tracking/`, so MLflow can replace it without touching the training loop.
- Checkpoints and EMA weights under `runs/`, stamped with the config and the artifact version.

## Evaluation

Scored on **ground-truth graphs** from the artifact — Module 1's errors never contaminate these numbers.

| Metric | Question |
|---|---|
| Conformance-to-graph | Does the plan realize the requested rooms and adjacencies? |
| Validity | Overlaps, coverage, connectivity, polygon simplicity |
| Per-room IoU | Geometric agreement with ground truth |
| Realism (FID, diversity) | Does it look like real floorplans? |

**FID on vector output is not standard.** It requires rasterizing first, and the settings change the number.
`eval/rasterize.py` pins them; keep them printed here so runs stay comparable:

```
resolution: 256x256   line width: 2px   antialias: off   normalize: per-plan bbox
```

## Milestones

| # | Deliverable | Gate |
|---|---|---|
| D0 | Run HouseDiffusion as-is | Their code trains on your machine; confirm from their data whether any outline is supplied |
| D1 | Eval suite on ground truth | Conformance/validity ≈ perfect on real RPLAN plans |
| D2 | Own implementation, `boxes` | Trains, samples, beats the solver baseline |
| D3 | `corners` + transformer | **Matches D0's numbers.** The reproduction gate. |
| D4 | *(v1)* boundary conditioning | Only after D3, knowing what it costs |

Reproducing a published model routinely takes longer than writing one. Treat D0 — their code, your machine, your
data — as the reference you diff against, never the paper's table.

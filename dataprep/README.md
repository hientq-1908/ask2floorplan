# `dataprep`

Turns raw RPLAN into a versioned, checksummed artifact that both modules consume as **data**.

```
RPLAN raw ──► dataprep ──► datasets/rplan-graphs/v1/  (graphs, plans, splits, manifest)
```

Neither `agent/` nor `diffusion/` imports this package. That is deliberate: sharing extraction *code* would mean
sharing geometry, then config, then a common library — and the two projects would stop being independent.
Sharing an *artifact* means both read immutable, checksummed data.

```bash
uv sync
uv run python scripts/download_rplan.py           # access is request-gated — do this first
uv run python scripts/measure_boundary_shapes.py  # footprint statistics
uv run python scripts/build_artifact.py           # emits datasets/rplan-graphs/vN/
```

**`graph_extraction.py` is the highest-risk file in the repo.** RPLAN ships plans, not graphs — you synthesize
the labels, and those rules silently define the distribution the agent must learn to match. Document them in
`docs/graph-schema.md`, mirror them in the agent's prompts, and review a few hundred outputs through
`report.py` before trusting any of them.

Changing the rules mints a new artifact version. Never edit `v1` in place.

# ask2floorplant — project context

Natural-language query → floor graph → vector floorplan. Read `README.md` first, then the module READMEs.

## Layout
Four independent projects (`contract`, `dataprep`, `agent`, `diffusion`) plus a thin `pipeline`. Each has its own
`pyproject.toml`, lockfile, and venv. **There is no uv workspace** — `cd` into a project before running anything.

## Commands
- `just sync-all` — install every project
- `just test` — run all test suites
- `just check-layering` — the two rules below, enforced
- `just demo` — end-to-end SVG via the solver backend, no ML required
- `just export-schema` — regenerate the contract's JSON Schema

## Invariants — do not break these
1. **`contract/` is pydantic-only.** No torch, no LLM SDK. Everything depends on it.
2. **`agent/` runtime installs without torch.** Training deps live behind the `train` extra.
3. **Training code is quarantined.** `agent/lora_finetuning/` holds all datagen, SFT, and serving. The
   runtime `src/a2fp_agent/` never imports it.
4. **Extraction is an artifact, not a library.** `agent/` and `diffusion/` read `datasets/rplan-graphs/vN/` as
   data and never import `dataprep`. Rule changes mint a new version; `v1` is immutable.
5. **Bench reference and test splits never mix.** Reference feeds retrieval; test evaluates.
6. **`golden_queries.jsonl` is human-written.** Never regenerate it with a model.
7. **Workflow modes and the three diffusion seams are Hydra config groups**, not `if` chains.

## Conventions
- Python 3.12, `uv` for everything. Never bare `pip`.
- Millimetres and CCW winding in `FloorPlan`; see `docs/coordinate-conventions.md`.
- Decisions with a rationale go in `docs/adr/`; experiment outcomes in `docs/experiments.md`.

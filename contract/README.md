# `contract`

The single definition of the interface between Module 1 and Module 2: `FloorGraph`, `FloorPlan`, their
validators, and SVG rendering.

**Hard rule: pydantic only.** No torch, no LLM SDK, no shapely. Every other project path-depends on this one, so
a heavy dependency here leaks everywhere. `just check-layering` asserts it.

Scaffold only — every module is a docstring stub. Implementing this package is
milestone **F0**, and nothing else can be built first.

```bash
uv sync                                        # works now
uv run pytest                                  # F0: no tests yet
uv run python -m a2fp_contract.export_schema   # F0: regenerates json_schema/
```

`json_schema/` does double duty: pydantic validation *and* the agent's constrained decoding read the same
exported artifact, so the two cannot silently desync. CI fails on any drift between the models and the committed
schema.

`validation/` is imported by three separate consumers — the agent's repair loop, the datagen accept/reject
filter, and both eval suites. It lives here so those three cannot disagree about what "valid" means.

Bump `SCHEMA_VERSION` on any breaking change.

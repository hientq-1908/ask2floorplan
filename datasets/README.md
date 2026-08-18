# `datasets` — artifact store

Versioned outputs of `dataprep/`. **Manifests and splits are committed; payloads are gitignored.**

```
rplan-graphs/
└── v1/
    ├── graphs/         FloorGraph JSON, one per plan   (gitignored)
    ├── plans/          FloorPlan JSON, one per plan    (gitignored)
    ├── splits.json     train/val/test + bench reference/test
    └── manifest.json   checksums, extraction-rule hash, provenance
```

Rebuild with `cd dataprep && uv run python scripts/build_artifact.py`.

**Versions are immutable.** Changing extraction rules mints `v2`; you do not edit `v1`. Both modules pin a
version in config, so every experimental result traces back to the exact data that produced it.

The bench **reference** split feeds the agent's retrieval exemplars. The **test** split evaluates. They never mix.

# FloorGraph schema

The contract between Module 1 and Module 2. Authoritative models live in `contract/src/a2fp_contract/`;
this document explains the intent and the extraction rules behind them.

## TODO(F0)
- Room type vocabulary and its mapping to RPLAN labels
- Edge semantics: what exactly counts as `door` vs `open` vs `wall`
- **Extraction rules** — the thresholds `dataprep/graph_extraction.py` uses to decide an adjacency exists.
  These define the distribution the agent must match; they must be mirrored in the agent's prompts.
- Worked examples: a real query, the graph it should produce, and the RPLAN plan it was back-translated from
- Which soft hints carry signal in RPLAN and which do not (answered empirically at F2)

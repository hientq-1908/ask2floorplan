# Per-role LoRA adapters

- **Date:** 2026-08-18
- **Status:** accepted

## Context

TODO

## Decision

Fine-tune GraphDrafter, then Critic, then optionally Interviewer, as separate adapters over one base model, served together by vLLM multi-LoRA.

## Consequences

Roles improve independently and serving stays one process. Costs: datasets, runs, and evals multiply per role — so the Retriever stays an embedding index, and A4 must be measured before A5 begins.

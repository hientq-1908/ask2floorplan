# PaperBanana role decomposition for Module 1

- **Date:** 2026-08-18
- **Status:** accepted

## Context

TODO

## Decision

Adopt Retriever / Interviewer / GraphDrafter / Critic with a closed critic loop, and make workflow modes a config group.

## Consequences

Per-role contribution becomes measurable by ablation. Divergence from the reference: the Critic runs deterministic validation first, because unlike diagram generation we have a programmatic checker.

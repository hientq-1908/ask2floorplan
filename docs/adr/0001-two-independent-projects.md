# Two independent projects, not a workspace

- **Date:** 2026-08-18
- **Status:** accepted

## Context

TODO

## Decision

`agent/` and `diffusion/` are separate projects with their own lockfiles, venvs, and CI jobs, sharing only the `contract/` package.

## Consequences

Each module is evaluated on ground-truth input, so a regression is attributable to exactly one project. Cost: cross-cutting changes touch several lockfiles.

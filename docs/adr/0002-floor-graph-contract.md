# FloorGraph as the single interface

- **Date:** 2026-08-18
- **Status:** accepted

## Context

TODO

## Decision

One pydantic-only package defines `FloorGraph` and `FloorPlan`; every project path-depends on it.

## Consequences

The two modules cannot drift apart at the seam. The contract package must never grow a heavy dependency.

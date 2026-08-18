# Vector corner polygons, not raster masks

- **Date:** 2026-08-18
- **Status:** accepted

## Context

TODO

## Decision

Module 2 outputs room and door polygon loops, following HouseDiffusion.

## Consequences

No raster-to-vector stage and sharper geometry, but FID requires rasterization with pinned settings, and no standard metric applies directly.

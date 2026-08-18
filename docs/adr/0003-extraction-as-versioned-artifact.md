# Extraction ships as data, not as a library

- **Date:** 2026-08-18
- **Status:** accepted

## Context

TODO

## Decision

`dataprep/` writes a versioned, checksummed dataset; both modules read it and pin a version.

## Consequences

Neither module can quietly re-tune extraction. Every result traces to an artifact version. Rule changes mint a new version rather than mutating an old one.

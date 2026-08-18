# No boundary conditioning in v0

- **Date:** 2026-08-18
- **Status:** accepted

## Context

TODO

## Decision

Follow the reference architecture: condition on the graph alone and let the model generate the footprint.

## Consequences

Gains a published baseline to reproduce and beat, and removes the out-of-distribution risk of user-supplied outlines. Cost: the user cannot specify plot shape or size, and the Interviewer's size hints are recorded but unused.

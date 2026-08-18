# Coordinate conventions

- **Units:** integer millimetres in `FloorPlan`; square metres in user-facing hints.
- **Origin:** top-left of the plan bounding box; +x right, +y down (raster convention, so rasterization needs no flip).
- **Winding:** polygon loops counter-clockwise.
- **Model space:** corners normalized to `[-1, 1]` per plan bounding box.

## TODO(F0)
- Exact normalization: per-plan bbox vs global dataset scale, and what that does to FID comparability
- Rounding and grid-snapping policy on decode

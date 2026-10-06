# Changelog

## DonutMap 0.2.0

- Interactive vector layers retain fractional screen coordinates by
  default, reducing stair-step artifacts in curves, arrowheads and donut
  borders.
- Interactive curves now use 96 points by default and preserve their
  vertices.
- Automatic arrowheads keep a 14-pixel length across zoom levels and
  adapt their width to the trajectory weight. Use `flow_arrow_pixels` to
  adjust this length, or `flow_arrow_size` to retain lengths in
  projected map units.
- Arrowheads follow the actual curved trajectory, and the line ends at
  the head base instead of extending beyond the point towards the donut
  center.
- Added `smooth_rendering = FALSE` to request Leaflet’s standard
  projection.
- Maps without a tile provider no longer show a spurious `null` base
  layer.

## DonutMap 0.1.0

CRAN release: 2026-06-08

- Initial CRAN submission.
- Added static donut maps with `ggplot2`.
- Added interactive donut maps with `leaflet`.
- Added `sf` donut polygon generation.
- Added straight and curved origin-destination flow geometries.

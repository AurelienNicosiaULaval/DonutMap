# DonutMap

DonutMap is an R package for drawing donut charts on static and interactive
maps with `sf`, `ggplot2`, and `leaflet`. It is inspired by
[`mtennekes/donutmaps`](https://github.com/mtennekes/donutmaps), but starts from
a simpler tidy-data interface and avoids the older `odf`/`tmap` workflow.

## Installation

```r
# From GitHub
devtools::install_github("AurelienNicosiaULaval/DonutMap")

# From this local repository
devtools::install()
```

## Example

```r
library(DonutMap)
library(ggplot2)

demo <- data.frame(
  place = rep(c("A", "B", "C"), each = 3),
  lon = rep(c(-71.35, -71.20, -71.05), each = 3),
  lat = rep(c(46.75, 46.82, 46.73), each = 3),
  category = rep(c("Walking", "Transit", "Car"), times = 3),
  value = c(10, 20, 5, 5, 15, 10, 12, 4, 9)
)

flows <- data.frame(
  from = c("A", "B"),
  to = c("B", "C"),
  trips = c(30, 10)
)

donut_map(
  demo,
  place,
  category,
  value,
  lon = lon,
  lat = lat,
  flows = flows,
  from = from,
  to = to,
  flow_value = trips,
  colours = c(Walking = "#1b9e77", Transit = "#7570b3", Car = "#d95f02")
)
```

Interactive maps use the same tidy interface:

```r
donut_leaflet(
  demo,
  place,
  category,
  value,
  lon = lon,
  lat = lat,
  flows = flows,
  from = from,
  to = to,
  flow_value = trips,
  colours = c(Walking = "#1b9e77", Transit = "#7570b3", Car = "#d95f02")
)
```

## Main functions

`donut_polygons()` computes an `sf` polygon layer with one donut segment per
non-zero location-category pair.

`flow_lines()` computes straight origin-destination `sf` line geometries.

`donut_map()` combines the two into a ready-to-print `ggplot2` map.

`donut_leaflet()` creates an interactive `leaflet` map with clickable donut
segments, popups, labels, legends, and optional flow lines.

See `vignette("donut-maps", package = "DonutMap")` for a complete worked
example.

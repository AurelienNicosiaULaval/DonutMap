# Compute origin-destination flow lines

`flow_lines()` creates `sf` line geometries joining origin and
destination locations. Lines can be straight or curved trajectories.

## Usage

``` r
flow_lines(
  flows,
  locations,
  from,
  to,
  value = NULL,
  id,
  group = NULL,
  lon = NULL,
  lat = NULL,
  input_crs = 4326,
  crs = NULL,
  drop_self = TRUE,
  flow_curvature = 0,
  flow_n = 30
)
```

## Arguments

- flows:

  A data frame containing origin-destination pairs.

- locations:

  A data frame or `sf` object containing one or more rows per location.
  Repeated locations are reduced to the first geometry per `id`.

- from, to:

  Unquoted columns in `flows` identifying origin and destination ids.

- value:

  Optional unquoted numeric column in `flows` used as flow value. If
  omitted, each flow receives value 1.

- id:

  Unquoted location id column in `locations`.

- group:

  Optional unquoted column in `flows` used to group or colour flow
  lines.

- lon, lat:

  Unquoted longitude and latitude columns in `locations`. Required when
  `locations` is not an `sf` object.

- input_crs:

  Coordinate reference system for `lon` and `lat`, or for an `sf` object
  with missing CRS. Defaults to EPSG:4326.

- crs:

  Target projected CRS. If `NULL`, a projected CRS is selected from
  `locations` or an estimated UTM zone.

- drop_self:

  Should self-flows be removed?

- flow_curvature:

  Numeric curvature for trajectory lines. Use `0` for straight lines,
  positive values for one bend direction, and negative values for the
  opposite direction.

- flow_n:

  Number of points used to approximate each curved trajectory.

## Value

An `sf` object with one line per retained flow.

## Examples

``` r
locations <- data.frame(
  place = c("A", "B"),
  lon = c(-71.3, -71.1),
  lat = c(46.75, 46.85)
)
flows <- data.frame(from = "A", to = "B", trips = 15)

lines <- flow_lines(flows, locations, from, to, trips, place, lon = lon, lat = lat)
plot(lines["value"])
```

test_that("flow_lines creates straight lines and drops self-flows", {
  locations <- data.frame(
    place = c("A", "B", "C"),
    lon = c(-71.3, -71.1, -71.2),
    lat = c(46.75, 46.85, 46.8)
  )

  flows <- data.frame(
    from = c("A", "B", "C"),
    to = c("B", "B", "A"),
    trips = c(15, 99, 10)
  )

  out <- flow_lines(
    flows,
    locations,
    from,
    to,
    trips,
    place,
    lon = lon,
    lat = lat
  )

  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 2L)
  expect_true(all(sf::st_geometry_type(out) == "LINESTRING"))
  expect_equal(out$value, c(15, 10))
})

test_that("flow_lines creates curved trajectories", {
  locations <- data.frame(
    place = c("A", "B"),
    lon = c(-71.3, -71.1),
    lat = c(46.75, 46.85)
  )

  flows <- data.frame(from = "A", to = "B", trips = 15)

  out <- flow_lines(
    flows,
    locations,
    from,
    to,
    trips,
    place,
    lon = lon,
    lat = lat,
    flow_curvature = 0.25,
    flow_n = 9
  )

  coords <- sf::st_coordinates(out)

  expect_equal(nrow(coords), 9L)
  expect_false(
    all(coords[, "Y"] == seq(coords[1, "Y"], coords[9, "Y"], length.out = 9))
  )
})

test_that("flow_lines preserves optional flow groups", {
  locations <- data.frame(
    place = c("A", "B", "C"),
    lon = c(-71.3, -71.1, -71.2),
    lat = c(46.75, 46.85, 46.8)
  )

  flows <- data.frame(
    from = c("A", "B", "C"),
    to = c("B", "B", "A"),
    trips = c(15, 99, 10),
    kind = factor(c("x", "y", "x"), levels = c("x", "y"))
  )

  out <- flow_lines(
    flows,
    locations,
    from,
    to,
    trips,
    place,
    group = kind,
    lon = lon,
    lat = lat
  )

  expect_equal(nrow(out), 2L)
  expect_equal(as.character(out$group), c("x", "x"))
  expect_equal(levels(out$group), c("x", "y"))
})

test_that("flow_lines validates trajectory settings", {
  locations <- data.frame(
    place = c("A", "B"),
    lon = c(-71.3, -71.1),
    lat = c(46.75, 46.85)
  )

  flows <- data.frame(from = "A", to = "B", trips = 15)

  expect_error(
    flow_lines(
      flows,
      locations,
      from,
      to,
      trips,
      place,
      lon = lon,
      lat = lat,
      flow_curvature = Inf
    ),
    "flow_curvature"
  )
})

test_that("flow_lines validates drop_self", {
  locations <- data.frame(
    place = c("A", "B"),
    lon = c(-71.3, -71.1),
    lat = c(46.75, 46.85)
  )

  flows <- data.frame(from = "A", to = "A", trips = 15)

  expect_error(
    flow_lines(
      flows,
      locations,
      from,
      to,
      trips,
      place,
      lon = lon,
      lat = lat,
      drop_self = NA
    ),
    "drop_self"
  )
})

test_that("flow_lines rejects inconsistent repeated locations", {
  locations <- data.frame(
    place = c("A", "A", "B"),
    lon = c(-71.3, -71.2, -71.1),
    lat = c(46.75, 46.8, 46.85)
  )

  flows <- data.frame(from = "A", to = "B", trips = 15)

  expect_error(
    flow_lines(flows, locations, from, to, trips, place, lon = lon, lat = lat),
    "multiple locations"
  )
})

test_that("flow_lines reports missing locations", {
  locations <- data.frame(
    place = "A",
    lon = -71.3,
    lat = 46.75
  )

  flows <- data.frame(from = "A", to = "B", trips = 15)

  expect_error(
    flow_lines(
      flows,
      locations,
      from,
      to,
      trips,
      place,
      lon = lon,
      lat = lat
    ),
    "No location found"
  )
})

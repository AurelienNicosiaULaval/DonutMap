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

  out <- flow_lines(flows, locations, from, to, trips, place, lon = lon, lat = lat)

  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 2L)
  expect_true(all(sf::st_geometry_type(out) == "LINESTRING"))
  expect_equal(out$value, c(15, 10))
})

test_that("flow_lines reports missing locations", {
  locations <- data.frame(
    place = "A",
    lon = -71.3,
    lat = 46.75
  )

  flows <- data.frame(from = "A", to = "B", trips = 15)

  expect_error(
    flow_lines(flows, locations, from, to, trips, place, lon = lon, lat = lat),
    "No location found"
  )
})

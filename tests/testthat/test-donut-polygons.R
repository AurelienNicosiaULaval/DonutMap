test_that("donut_polygons returns one polygon per non-zero category", {
  demo <- data.frame(
    place = rep(c("A", "B"), each = 3),
    lon = rep(c(-71.3, -71.1), each = 3),
    lat = rep(c(46.75, 46.85), each = 3),
    category = rep(c("x", "y", "z"), times = 2),
    value = c(10, 20, 0, 5, 15, 10)
  )

  out <- donut_polygons(demo, place, category, value, lon = lon, lat = lat)

  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 5L)
  expect_true(all(sf::st_geometry_type(out) == "POLYGON"))
  expect_true(all(sf::st_is_valid(out)))
  expect_equal(
    as.numeric(tapply(out$proportion, out$id, sum)),
    c(1, 1),
    tolerance = 1e-8
  )
})

test_that("donut_polygons rejects invalid values", {
  demo <- data.frame(
    place = "A",
    lon = -71.3,
    lat = 46.75,
    category = "x",
    value = -1
  )

  expect_error(
    donut_polygons(demo, place, category, value, lon = lon, lat = lat),
    "cannot contain negative"
  )
})

test_that("donut_polygons rejects inconsistent repeated locations", {
  demo <- data.frame(
    place = c("A", "A"),
    lon = c(-71.3, -71.2),
    lat = c(46.75, 46.8),
    category = c("x", "y"),
    value = c(10, 20)
  )

  expect_error(
    donut_polygons(demo, place, category, value, lon = lon, lat = lat),
    "multiple locations"
  )
})

test_that("donut_polygons works with sf input", {
  demo <- data.frame(
    place = rep(c("A", "B"), each = 2),
    lon = rep(c(-71.3, -71.1), each = 2),
    lat = rep(c(46.75, 46.85), each = 2),
    category = rep(c("x", "y"), times = 2),
    value = c(10, 20, 5, 15)
  )

  demo_sf <- sf::st_as_sf(demo, coords = c("lon", "lat"), crs = 4326)
  out <- donut_polygons(demo_sf, place, category, value)

  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 4L)
})

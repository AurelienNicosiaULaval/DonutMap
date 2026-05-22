test_that("donut_map returns a ggplot object", {
  demo <- data.frame(
    place = rep(c("A", "B"), each = 2),
    lon = rep(c(-71.3, -71.1), each = 2),
    lat = rep(c(46.75, 46.85), each = 2),
    category = rep(c("x", "y"), times = 2),
    value = c(10, 20, 5, 15)
  )

  p <- donut_map(demo, place, category, value, lon = lon, lat = lat)

  expect_s3_class(p, "ggplot")
})

test_that("donut_map supports curved trajectories with arrows", {
  demo <- data.frame(
    place = rep(c("A", "B"), each = 2),
    lon = rep(c(-71.3, -71.1), each = 2),
    lat = rep(c(46.75, 46.85), each = 2),
    category = rep(c("x", "y"), times = 2),
    value = c(10, 20, 5, 15)
  )

  flows <- data.frame(from = "A", to = "B", trips = 12)

  p <- donut_map(
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
    flow_curvature = 0.25,
    flow_arrow = TRUE
  )

  expect_s3_class(p, "ggplot")
})

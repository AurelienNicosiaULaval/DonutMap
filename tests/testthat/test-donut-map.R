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

test_that("donut_map supports coloured flow groups", {
  demo <- data.frame(
    place = rep(c("A", "B", "C"), each = 2),
    lon = rep(c(-71.3, -71.1, -71.2), each = 2),
    lat = rep(c(46.75, 46.85, 46.8), each = 2),
    category = rep(c("x", "y"), times = 3),
    value = c(10, 20, 5, 15, 8, 12)
  )

  flows <- data.frame(
    from = c("A", "B"),
    to = c("B", "C"),
    trips = c(12, 6),
    kind = c("x", "y")
  )

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
    flow_group = kind,
    flow_colours = c(x = "#111111", y = "#222222")
  )

  colour_scales <- vapply(
    p$scales$scales,
    function(scale) "colour" %in% scale$aesthetics,
    logical(1)
  )

  expect_s3_class(p, "ggplot")
  expect_true(any(colour_scales))
})

test_that("donut_map validates flow_arrow", {
  demo <- data.frame(
    place = "A",
    lon = -71.3,
    lat = 46.75,
    category = "x",
    value = 10
  )

  expect_error(
    donut_map(
      demo,
      place,
      category,
      value,
      lon = lon,
      lat = lat,
      flow_arrow = "yes"
    ),
    "flow_arrow"
  )
})

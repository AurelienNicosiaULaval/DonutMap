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

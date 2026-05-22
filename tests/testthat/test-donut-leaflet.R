test_that("donut_leaflet returns a leaflet htmlwidget", {
  demo <- data.frame(
    place = rep(c("A", "B"), each = 2),
    lon = rep(c(-71.3, -71.1), each = 2),
    lat = rep(c(46.75, 46.85), each = 2),
    category = rep(c("x", "y"), times = 2),
    value = c(10, 20, 5, 15)
  )

  widget <- donut_leaflet(demo, place, category, value, lon = lon, lat = lat)

  expect_s3_class(widget, "leaflet")
  expect_s3_class(widget, "htmlwidget")
  expect_false(widget$x$options$preferCanvas)

  polygon_calls <- Filter(
    function(call) identical(call$method, "addPolygons"),
    widget$x$calls
  )
  donut_call <- polygon_calls[[length(polygon_calls)]]
  donut_options <- donut_call$args[[4]]
  expect_identical(donut_options$smoothFactor, 0)
})

test_that("donut_leaflet supports flow lines", {
  demo <- data.frame(
    place = rep(c("A", "B"), each = 2),
    lon = rep(c(-71.3, -71.1), each = 2),
    lat = rep(c(46.75, 46.85), each = 2),
    category = rep(c("x", "y"), times = 2),
    value = c(10, 20, 5, 15)
  )

  flows <- data.frame(from = "A", to = "B", trips = 12)

  widget <- donut_leaflet(
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

  expect_s3_class(widget, "leaflet")

  call_methods <- vapply(
    widget$x$calls,
    function(call) call$method,
    character(1)
  )

  expect_gte(sum(call_methods == "addPolygons"), 2L)
})

test_that("donut_leaflet supports canvas rendering when requested", {
  demo <- data.frame(
    place = rep(c("A", "B"), each = 2),
    lon = rep(c(-71.3, -71.1), each = 2),
    lat = rep(c(46.75, 46.85), each = 2),
    category = rep(c("x", "y"), times = 2),
    value = c(10, 20, 5, 15)
  )

  widget <- donut_leaflet(
    demo,
    place,
    category,
    value,
    lon = lon,
    lat = lat,
    prefer_canvas = TRUE
  )

  expect_true(widget$x$options$preferCanvas)
})

test_that("donut_leaflet validates interactive arrowhead size", {
  demo <- data.frame(
    place = rep(c("A", "B"), each = 2),
    lon = rep(c(-71.3, -71.1), each = 2),
    lat = rep(c(46.75, 46.85), each = 2),
    category = rep(c("x", "y"), times = 2),
    value = c(10, 20, 5, 15)
  )

  flows <- data.frame(from = "A", to = "B", trips = 12)

  expect_error(
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
      flow_arrow_size = -1
    ),
    "flow_arrow_size"
  )

  expect_error(
    donut_leaflet(
      demo,
      place,
      category,
      value,
      lon = lon,
      lat = lat,
      donut_smooth_factor = -1
    ),
    "donut_smooth_factor"
  )

  expect_error(
    donut_leaflet(
      demo,
      place,
      category,
      value,
      lon = lon,
      lat = lat,
      prefer_canvas = NA
    ),
    "prefer_canvas"
  )
})

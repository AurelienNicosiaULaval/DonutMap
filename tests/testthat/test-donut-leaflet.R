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

test_that("donut_leaflet attaches escaped popups and labels", {
  demo <- data.frame(
    place = rep(c("A & B", "C"), each = 2),
    lon = rep(c(-71.3, -71.1), each = 2),
    lat = rep(c(46.75, 46.85), each = 2),
    category = rep(c("x < 1", "y"), times = 2),
    value = c(10, 20, 5, 15)
  )

  widget <- donut_leaflet(demo, place, category, value, lon = lon, lat = lat)
  polygon_calls <- Filter(
    function(call) identical(call$method, "addPolygons"),
    widget$x$calls
  )
  donut_call <- polygon_calls[[length(polygon_calls)]]

  expect_true(any(grepl("A &amp; B", donut_call$args[[5]], fixed = TRUE)))
  expect_true(any(grepl("x &lt; 1", donut_call$args[[5]], fixed = TRUE)))
  expect_length(donut_call$args[[7]], 4L)

  widget_hidden <- donut_leaflet(
    demo,
    place,
    category,
    value,
    lon = lon,
    lat = lat,
    popup = FALSE,
    label = FALSE
  )
  hidden_polygon_calls <- Filter(
    function(call) identical(call$method, "addPolygons"),
    widget_hidden$x$calls
  )
  hidden_donut_call <- hidden_polygon_calls[[length(hidden_polygon_calls)]]

  expect_null(hidden_donut_call$args[[5]])
  expect_null(hidden_donut_call$args[[7]])
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
  flow_call <- Filter(
    function(call) identical(call$method, "addPolylines"),
    widget$x$calls
  )[[1L]]

  expect_gte(sum(call_methods == "addPolygons"), 2L)
  expect_identical(
    flow_call$args[[5]],
    "<strong>A &rarr; B</strong><br/>Flow: 12"
  )
  expect_identical(flow_call$args[[7]], "A -&gt; B: 12")
})

test_that("donut_leaflet colours flow groups and arrowheads", {
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
    flow_group = kind,
    flow_colours = c(x = "#111111", y = "#222222"),
    flow_arrow = TRUE
  )

  polyline_call <- Filter(
    function(call) identical(call$method, "addPolylines"),
    widget$x$calls
  )[[1L]]
  flow_options <- polyline_call$args[[4]]

  flow_arrow_call <- Filter(
    function(call) {
      identical(call$method, "addPolygons") &&
        identical(call$args[[3]], "Flows")
    },
    widget$x$calls
  )[[1L]]
  arrow_options <- flow_arrow_call$args[[4]]

  legend_calls <- Filter(
    function(call) identical(call$method, "addLegend"),
    widget$x$calls
  )
  flow_legend <- legend_calls[[2L]]$args[[1L]]

  expect_identical(flow_options$color, c("#111111", "#222222"))
  expect_identical(arrow_options$fillColor, c("#111111", "#222222"))
  expect_identical(flow_legend$title, "kind")
  expect_identical(as.character(flow_legend$colors), c("#111111", "#222222"))
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

test_that("donut_leaflet validates boolean controls", {
  demo <- data.frame(
    place = "A",
    lon = -71.3,
    lat = 46.75,
    category = "x",
    value = 10
  )

  expect_error(
    donut_leaflet(
      demo,
      place,
      category,
      value,
      lon = lon,
      lat = lat,
      popup = NA
    ),
    "popup"
  )

  expect_error(
    donut_leaflet(
      demo,
      place,
      category,
      value,
      lon = lon,
      lat = lat,
      label = "yes"
    ),
    "label"
  )

  expect_error(
    donut_leaflet(
      demo,
      place,
      category,
      value,
      lon = lon,
      lat = lat,
      flow_arrow = c(TRUE, FALSE)
    ),
    "flow_arrow"
  )

  expect_error(
    donut_leaflet(
      demo,
      place,
      category,
      value,
      lon = lon,
      lat = lat,
      flow_legend = NA
    ),
    "flow_legend"
  )
})

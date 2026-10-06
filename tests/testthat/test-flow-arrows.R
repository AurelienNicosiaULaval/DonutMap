test_that("arrow tips follow the path and stems meet the head base", {
  path <- sf::st_sf(
    from = "A", to = "B", value = 1,
    geometry = sf::st_sfc(sf::st_linestring(rbind(c(0, 0), c(10, 0), c(10, 10))),
      crs = 3857)
  )
  # Walking back 15 units from the destination crosses the bend.
  visuals <- build_flow_arrows(path, arrow_size = 2, tip_offset = 15)
  # Offsets are capped at 45% of length: the tip lies one unit past the bend.
  head <- sf::st_coordinates(visuals$arrowheads)[, c("X", "Y")]
  stem <- sf::st_coordinates(visuals$lines)[, c("X", "Y")]
  expect_equal(unname(head[1L, ]), c(10, 1))
  expect_equal(unname((head[2L, ] + head[3L, ]) / 2), c(9, 0))
  expect_equal(unname(tail(stem, 1L)[1L, ]), c(9, 0))
  expect_true(all(sf::st_is_valid(visuals$arrowheads)))
  expect_identical(visuals$lines$from, path$from)
  expect_identical(sf::st_crs(visuals$lines), sf::st_crs(path))
})

test_that("straight arrow geometry preserves size and repeated flow identity", {
  line <- sf::st_linestring(rbind(c(0, 0), c(100, 0)))
  paths <- sf::st_sf(from = c("A", "A"), to = c("B", "B"), render_id = 1:2,
    geometry = sf::st_sfc(line, line, crs = 3857))
  visuals <- build_flow_arrows(paths, 10, c(20, 30))
  first <- sf::st_coordinates(sf::st_geometry(visuals$arrowheads)[[1L]])[, c("X", "Y")]
  expect_equal(unname(first[1L, ]), c(80, 0))
  expect_equal(unname(first[2L, ]), c(70, 3.5))
  expect_identical(visuals$arrowheads$render_id, 1:2)
  ends <- lapply(sf::st_geometry(visuals$lines), function(line) tail(line, 1L)[1L, ])
  expect_equal(unname(ends[[1L]]), c(70, 0))
  expect_equal(unname(ends[[2L]]), c(60, 0))
})

test_that("duplicate vertices and zero-length flows do not break arrows", {
  paths <- sf::st_sf(id = 1:2, geometry = sf::st_sfc(
    sf::st_linestring(rbind(c(0, 0), c(0, 0), c(100, 0))),
    sf::st_linestring(rbind(c(5, 5), c(5, 5))), crs = 3857))
  visuals <- build_flow_arrows(paths, 10)
  expect_identical(visuals$arrowheads$id, 1L)
  expect_equal(nrow(visuals$lines), 2L)
  expect_equal(unname(sf::st_coordinates(visuals$arrowheads)[1L, c("X", "Y")]), c(100, 0))
  expect_error(build_flow_arrows(paths, 10, 0), "one value per flow")
})

test_that("interactive rendering controls survive widget serialization", {
  demo <- data.frame(place = c("A", "B"), lon = c(-71.3, -71.1),
    lat = c(46.75, 46.85), category = "x", value = 10)
  flows <- data.frame(from = "A", to = "B")
  widget <- donut_leaflet(demo, place, category, value, lon = lon, lat = lat,
    flows = flows, from = from, to = to, flow_arrow_pixels = 18,
    provider_tiles = NULL)
  expect_s3_class(widget$x$options$mapFactory, "JS_EVAL")
  expect_identical(widget$jsHooks$render[[1L]]$data$size, 18)
  line <- Filter(function(call) identical(call$method, "addPolylines"), widget$x$calls)[[1L]]
  expect_identical(line$args[[4L]]$smoothFactor, 0)
  expect_identical(line$args[[4L]]$lineCap, "butt")
  expect_identical(line$args[[4L]]$className, "donutmap-flow-1")
  layers <- Filter(function(call) identical(call$method, "addLayersControl"), widget$x$calls)[[1L]]
  expect_length(layers$args[[1L]], 0L)
  explicit <- donut_leaflet(demo, place, category, value, lon = lon, lat = lat,
    flows = flows, from = from, to = to, flow_arrow_size = 100,
    provider_tiles = NULL, smooth_rendering = FALSE)
  expect_null(explicit$x$options$mapFactory)
  expect_length(explicit$jsHooks$render, 0L)
  for (bad in list(0, -1, NA_real_, Inf, "large", c(10, 20))) {
    expect_error(donut_leaflet(demo, place, category, value, lon = lon, lat = lat,
      flow_arrow_pixels = bad), "flow_arrow_pixels")
  }
  expect_error(donut_leaflet(demo, place, category, value, lon = lon, lat = lat,
    smooth_rendering = NA), "smooth_rendering")
})

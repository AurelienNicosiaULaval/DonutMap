# Read the packaged JavaScript functions without changing Leaflet globally.
leaflet_rendering_script <- function(filename) {
  path <- system.file("htmlwidgets", filename, package = "DonutMap", mustWork = TRUE)
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

donut_leaflet_options <- function(prefer_canvas, smooth_rendering) {
  options <- leaflet::leafletOptions(preferCanvas = prefer_canvas)
  if (isTRUE(smooth_rendering)) {
    options$mapFactory <- htmlwidgets::JS(
      leaflet_rendering_script("precise-map.js")
    )
  }
  options
}

#' Compute donut polygons
#'
#' `donut_polygons()` turns tidy category values at spatial locations into an
#' `sf` polygon layer. Each row of `data` represents one category for one
#' location.
#'
#' @param data A data frame or `sf` object. If `data` is not an `sf` object,
#'   `lon` and `lat` must be supplied.
#' @param id Unquoted column identifying each donut location.
#' @param category Unquoted column identifying donut categories.
#' @param value Unquoted numeric column giving non-negative category values.
#' @param lon,lat Unquoted longitude and latitude columns. Required when `data`
#'   is not an `sf` object.
#' @param input_crs Coordinate reference system for `lon` and `lat`, or for an
#'   `sf` object with missing CRS. Defaults to EPSG:4326.
#' @param crs Target projected CRS used to build the donut polygons. If `NULL`,
#'   a projected CRS is chosen from `map`, `data`, or an estimated UTM zone.
#' @param map Optional `sf` object used only to choose the working CRS and
#'   default donut radius range.
#' @param radius_range Numeric vector of length 2 giving minimum and maximum
#'   donut radii in map units. If `NULL`, a range is derived from the map
#'   extent.
#' @param inner_radius Numeric value in `(0, 1)` giving the inner radius as a
#'   proportion of the outer radius.
#' @param n Number of points used to approximate a complete outer circle.
#' @param start_angle Start angle in radians. The default starts at 12 o'clock.
#'
#' @return An `sf` object with one polygon per non-zero location-category pair.
#' @export
#'
#' @examples
#' demo <- data.frame(
#'   place = rep(c("A", "B"), each = 3),
#'   lon = rep(c(-71.3, -71.1), each = 3),
#'   lat = rep(c(46.75, 46.85), each = 3),
#'   category = rep(c("x", "y", "z"), times = 2),
#'   value = c(10, 20, 5, 5, 15, 10)
#' )
#'
#' donuts <- donut_polygons(demo, place, category, value, lon = lon, lat = lat)
#' plot(donuts["category"])
donut_polygons <- function(data,
                           id,
                           category,
                           value,
                           lon = NULL,
                           lat = NULL,
                           input_crs = 4326,
                           crs = NULL,
                           map = NULL,
                           radius_range = NULL,
                           inner_radius = 0.55,
                           n = 96,
                           start_angle = pi / 2) {
  id_col <- column_name(rlang::enquo(id), "id")
  category_col <- column_name(rlang::enquo(category), "category")
  value_col <- column_name(rlang::enquo(value), "value")
  lon_col <- column_name(rlang::enquo(lon), "lon", required = FALSE)
  lat_col <- column_name(rlang::enquo(lat), "lat", required = FALSE)

  build_donut_polygons(
    data = data,
    id_col = id_col,
    category_col = category_col,
    value_col = value_col,
    lon_col = lon_col,
    lat_col = lat_col,
    input_crs = input_crs,
    crs = crs,
    map = map,
    radius_range = radius_range,
    inner_radius = inner_radius,
    n = n,
    start_angle = start_angle
  )
}

build_donut_polygons <- function(data,
                                 id_col,
                                 category_col,
                                 value_col,
                                 lon_col = NULL,
                                 lat_col = NULL,
                                 input_crs = 4326,
                                 crs = NULL,
                                 map = NULL,
                                 radius_range = NULL,
                                 inner_radius = 0.55,
                                 n = 96,
                                 start_angle = pi / 2) {
  data_tbl <- tibble::as_tibble(sf::st_drop_geometry(data))
  check_columns(data_tbl, c(id_col, category_col, value_col))
  check_numeric_non_negative(data_tbl[[value_col]], value_col)

  if (any(is.na(data_tbl[[id_col]]))) {
    stop("`", id_col, "` cannot contain missing values.", call. = FALSE)
  }

  if (any(is.na(data_tbl[[category_col]]))) {
    stop("`", category_col, "` cannot contain missing values.", call. = FALSE)
  }

  if (!is.numeric(inner_radius) || length(inner_radius) != 1L) {
    stop("`inner_radius` must be a single numeric value.", call. = FALSE)
  }

  if (!is.finite(inner_radius) || inner_radius <= 0 || inner_radius >= 1) {
    stop("`inner_radius` must be in the interval (0, 1).", call. = FALSE)
  }

  if (!is.numeric(n) || length(n) != 1L || !is.finite(n) || n < 16) {
    stop(
      "`n` must be a single number greater than or equal to 16.",
      call. = FALSE
    )
  }

  n <- as.integer(n)

  category_raw <- data_tbl[[category_col]]
  category_levels <- if (is.factor(category_raw)) {
    levels(category_raw)
  } else {
    unique(as.character(category_raw))
  }

  locations <- as_location_sf(
    data = data,
    id_col = id_col,
    lon_col = lon_col,
    lat_col = lat_col,
    input_crs = input_crs
  )

  work_crs <- choose_work_crs(locations, map = map, crs = crs)
  locations <- sf::st_transform(locations, work_crs)

  map_projected <- NULL
  if (!is.null(map)) {
    map_projected <- sf::st_transform(map, work_crs)
  }

  if (is.null(radius_range)) {
    radius_range <- default_radius_range(locations, map = map_projected)
  } else {
    radius_range <- check_radius_range(radius_range)
  }

  value_tbl <- tibble::tibble(
    id = as.character(data_tbl[[id_col]]),
    category = as.character(data_tbl[[category_col]]),
    value = data_tbl[[value_col]],
    .row = seq_len(nrow(data_tbl))
  ) |>
    dplyr::group_by(.data$id, .data$category) |>
    dplyr::summarise(
      value = sum(.data$value),
      .row = min(.data$.row),
      .groups = "drop"
    ) |>
    dplyr::arrange(.data$id, .data$.row)

  totals <- value_tbl |>
    dplyr::group_by(.data$id) |>
    dplyr::summarise(total = sum(.data$value), .groups = "drop")

  if (any(totals$total <= 0)) {
    bad_ids <- totals$id[totals$total <= 0]
    stop(
      "Each donut must have a positive total. Problem id(s): ",
      paste(bad_ids, collapse = ", "),
      call. = FALSE
    )
  }

  totals <- totals |>
    dplyr::mutate(radius = scale_radii(.data$total, radius_range))

  coord <- sf::st_coordinates(locations)
  location_tbl <- tibble::tibble(
    id = locations$id,
    x = coord[, "X"],
    y = coord[, "Y"]
  )

  missing_locations <- setdiff(totals$id, location_tbl$id)
  if (length(missing_locations) > 0L) {
    stop(
      "No location found for id(s): ",
      paste(missing_locations, collapse = ", "),
      call. = FALSE
    )
  }

  plot_tbl <- value_tbl |>
    dplyr::filter(.data$value > 0) |>
    dplyr::left_join(totals, by = "id") |>
    dplyr::left_join(location_tbl, by = "id") |>
    dplyr::group_by(.data$id) |>
    dplyr::arrange(.data$.row, .by_group = TRUE) |>
    dplyr::mutate(
      proportion = .data$value / .data$total,
      end_prop = cumsum(.data$proportion),
      start_prop = dplyr::lag(.data$end_prop, default = 0),
      start_angle = .env$start_angle - 2 * pi * .data$start_prop,
      end_angle = .env$start_angle - 2 * pi * .data$end_prop,
      inner_map_radius = .data$radius * inner_radius
    ) |>
    dplyr::ungroup()

  polygons <- vector("list", nrow(plot_tbl))

  for (i in seq_len(nrow(plot_tbl))) {
    polygons[[i]] <- make_wedge_polygon(
      x = plot_tbl$x[[i]],
      y = plot_tbl$y[[i]],
      outer_radius = plot_tbl$radius[[i]],
      inner_radius = plot_tbl$inner_map_radius[[i]],
      start = plot_tbl$start_angle[[i]],
      end = plot_tbl$end_angle[[i]],
      proportion = plot_tbl$proportion[[i]],
      n = n
    )
  }

  out <- dplyr::select(
    plot_tbl,
    "id",
    "category",
    "value",
    "total",
    "proportion",
    "radius",
    "start_angle",
    "end_angle"
  )

  out$category <- factor(out$category, levels = category_levels)

  sf::st_sf(
    out,
    geometry = sf::st_sfc(polygons, crs = work_crs)
  )
}

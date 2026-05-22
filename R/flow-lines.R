#' Compute origin-destination flow lines
#'
#' `flow_lines()` creates `sf` line geometries joining origin and destination
#' locations. Lines can be straight or curved trajectories.
#'
#' @param flows A data frame containing origin-destination pairs.
#' @param locations A data frame or `sf` object containing one or more rows per
#'   location. Repeated locations are reduced to the first geometry per `id`.
#' @param from,to Unquoted columns in `flows` identifying origin and
#'   destination ids.
#' @param value Optional unquoted numeric column in `flows` used as flow value.
#'   If omitted, each flow receives value 1.
#' @param id Unquoted location id column in `locations`.
#' @param lon,lat Unquoted longitude and latitude columns in `locations`.
#'   Required when `locations` is not an `sf` object.
#' @param input_crs Coordinate reference system for `lon` and `lat`, or for an
#'   `sf` object with missing CRS. Defaults to EPSG:4326.
#' @param crs Target projected CRS. If `NULL`, a projected CRS is selected from
#'   `locations` or an estimated UTM zone.
#' @param drop_self Should self-flows be removed?
#' @param flow_curvature Numeric curvature for trajectory lines. Use `0` for
#'   straight lines, positive values for one bend direction, and negative values
#'   for the opposite direction.
#' @param flow_n Number of points used to approximate each curved trajectory.
#'
#' @return An `sf` object with one line per retained flow.
#' @export
#'
#' @examples
#' locations <- data.frame(
#'   place = c("A", "B"),
#'   lon = c(-71.3, -71.1),
#'   lat = c(46.75, 46.85)
#' )
#' flows <- data.frame(from = "A", to = "B", trips = 15)
#'
#' lines <- flow_lines(flows, locations, from, to, trips, place, lon = lon, lat = lat)
#' plot(lines["value"])
flow_lines <- function(flows,
                       locations,
                       from,
                       to,
                       value = NULL,
                       id,
                       lon = NULL,
                       lat = NULL,
                       input_crs = 4326,
                       crs = NULL,
                       drop_self = TRUE,
                       flow_curvature = 0,
                       flow_n = 30) {
  from_col <- column_name(rlang::enquo(from), "from")
  to_col <- column_name(rlang::enquo(to), "to")
  value_col <- column_name(rlang::enquo(value), "value", required = FALSE)
  id_col <- column_name(rlang::enquo(id), "id")
  lon_col <- column_name(rlang::enquo(lon), "lon", required = FALSE)
  lat_col <- column_name(rlang::enquo(lat), "lat", required = FALSE)

  build_flow_lines(
    flows = flows,
    locations = locations,
    from_col = from_col,
    to_col = to_col,
    value_col = value_col,
    id_col = id_col,
    lon_col = lon_col,
    lat_col = lat_col,
    input_crs = input_crs,
    crs = crs,
    drop_self = drop_self,
    flow_curvature = flow_curvature,
    flow_n = flow_n
  )
}

build_flow_lines <- function(flows,
                             locations,
                             from_col,
                             to_col,
                             value_col = NULL,
                             id_col,
                             lon_col = NULL,
                             lat_col = NULL,
                             input_crs = 4326,
                             crs = NULL,
                             drop_self = TRUE,
                             flow_curvature = 0,
                             flow_n = 30) {
  check_flow_curvature(flow_curvature)
  flow_n <- check_flow_n(flow_n)

  flow_tbl_raw <- tibble::as_tibble(flows)
  check_columns(flow_tbl_raw, c(from_col, to_col), data_arg = "flows")

  if (!is.null(value_col)) {
    check_columns(flow_tbl_raw, value_col, data_arg = "flows")
    check_numeric_non_negative(flow_tbl_raw[[value_col]], value_col)
    flow_value <- flow_tbl_raw[[value_col]]
  } else {
    flow_value <- rep(1, nrow(flow_tbl_raw))
  }

  flow_tbl <- tibble::tibble(
    from = as.character(flow_tbl_raw[[from_col]]),
    to = as.character(flow_tbl_raw[[to_col]]),
    value = flow_value
  )

  if (any(is.na(flow_tbl$from)) || any(is.na(flow_tbl$to))) {
    stop("`from` and `to` cannot contain missing values.", call. = FALSE)
  }

  if (isTRUE(drop_self)) {
    flow_tbl <- dplyr::filter(flow_tbl, .data$from != .data$to)
  }

  location_sf <- as_location_sf(
    data = locations,
    id_col = id_col,
    lon_col = lon_col,
    lat_col = lat_col,
    input_crs = input_crs,
    data_arg = "locations"
  )

  work_crs <- choose_work_crs(location_sf, crs = crs)
  location_sf <- sf::st_transform(location_sf, work_crs)
  coords <- sf::st_coordinates(location_sf)

  location_tbl <- tibble::tibble(
    id = location_sf$id,
    x = coords[, "X"],
    y = coords[, "Y"]
  )

  missing_locations <- setdiff(unique(c(flow_tbl$from, flow_tbl$to)), location_tbl$id)
  if (length(missing_locations) > 0L) {
    stop(
      "No location found for id(s): ",
      paste(missing_locations, collapse = ", "),
      call. = FALSE
    )
  }

  from_tbl <- dplyr::transmute(
    location_tbl,
    from = .data$id,
    x_from = .data$x,
    y_from = .data$y
  )

  to_tbl <- dplyr::transmute(
    location_tbl,
    to = .data$id,
    x_to = .data$x,
    y_to = .data$y
  )

  line_tbl <- flow_tbl |>
    dplyr::left_join(from_tbl, by = "from") |>
    dplyr::left_join(to_tbl, by = "to")

  lines <- vector("list", nrow(line_tbl))

  for (i in seq_len(nrow(line_tbl))) {
    lines[[i]] <- make_flow_linestring(
      x_from = line_tbl$x_from[[i]],
      y_from = line_tbl$y_from[[i]],
      x_to = line_tbl$x_to[[i]],
      y_to = line_tbl$y_to[[i]],
      curvature = flow_curvature,
      n = flow_n
    )
  }

  sf::st_sf(
    dplyr::select(line_tbl, "from", "to", "value"),
    geometry = sf::st_sfc(lines, crs = work_crs)
  )
}

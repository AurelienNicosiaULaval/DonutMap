column_name <- function(quo, arg, required = TRUE) {
  if (rlang::quo_is_missing(quo) || rlang::quo_is_null(quo)) {
    if (required) {
      stop("`", arg, "` must be supplied.", call. = FALSE)
    }
    return(NULL)
  }

  tryCatch(
    rlang::as_name(quo),
    error = function(cnd) {
      stop("`", arg, "` must be an unquoted column name.", call. = FALSE)
    }
  )
}

check_columns <- function(data, cols, data_arg = "data") {
  missing_cols <- setdiff(cols, names(data))

  if (length(missing_cols) > 0L) {
    stop(
      "`", data_arg, "` is missing required column(s): ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(data)
}

check_numeric_non_negative <- function(x, arg) {
  if (!is.numeric(x)) {
    stop("`", arg, "` must be numeric.", call. = FALSE)
  }

  if (any(is.na(x))) {
    stop("`", arg, "` cannot contain missing values.", call. = FALSE)
  }

  if (any(!is.finite(x))) {
    stop("`", arg, "` must contain only finite values.", call. = FALSE)
  }

  if (any(x < 0)) {
    stop("`", arg, "` cannot contain negative values.", call. = FALSE)
  }

  invisible(x)
}

check_bool <- function(x, arg) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    stop("`", arg, "` must be `TRUE` or `FALSE`.", call. = FALSE)
  }

  invisible(x)
}

as_location_sf <- function(data,
                           id_col,
                           lon_col = NULL,
                           lat_col = NULL,
                           input_crs = 4326,
                           data_arg = "data") {
  data_tbl <- tibble::as_tibble(sf::st_drop_geometry(data))
  check_columns(data_tbl, id_col, data_arg = data_arg)

  if (any(is.na(data_tbl[[id_col]]))) {
    stop("`", id_col, "` cannot contain missing values.", call. = FALSE)
  }

  if (inherits(data, "sf")) {
    location_data <- sf::st_as_sf(data)

    if (is.na(sf::st_crs(location_data))) {
      sf::st_crs(location_data) <- input_crs
    }

    geometry_type <- as.character(sf::st_geometry_type(location_data))
    point_like <- geometry_type %in% c("POINT", "MULTIPOINT")

    if (!all(point_like)) {
      geometry <- sf::st_point_on_surface(sf::st_geometry(location_data))
      location_data <- sf::st_sf(
        id = data_tbl[[id_col]],
        geometry = geometry,
        crs = sf::st_crs(location_data)
      )
    } else {
      location_data <- sf::st_sf(
        id = data_tbl[[id_col]],
        geometry = sf::st_geometry(location_data),
        crs = sf::st_crs(location_data)
      )
    }
  } else {
    if (is.null(lon_col) || is.null(lat_col)) {
      stop(
        "`lon` and `lat` must be supplied when `", data_arg,
        "` is not an sf object.",
        call. = FALSE
      )
    }

    check_columns(data_tbl, c(lon_col, lat_col), data_arg = data_arg)

    if (!is.numeric(data_tbl[[lon_col]]) || !is.numeric(data_tbl[[lat_col]])) {
      stop("`lon` and `lat` must be numeric columns.", call. = FALSE)
    }

    if (any(is.na(data_tbl[[lon_col]])) || any(is.na(data_tbl[[lat_col]]))) {
      stop("`lon` and `lat` cannot contain missing values.", call. = FALSE)
    }

    location_data <- sf::st_as_sf(
      dplyr::transmute(
        data_tbl,
        id = .data[[id_col]],
        lon = .data[[lon_col]],
        lat = .data[[lat_col]]
      ),
      coords = c("lon", "lat"),
      crs = input_crs
    )
  }

  location_data <- dplyr::mutate(location_data, id = as.character(.data$id))
  geometry_key <- sf::st_as_text(sf::st_geometry(location_data))
  location_keys <- tibble::tibble(
    id = location_data$id,
    geometry_key = geometry_key
  )

  conflicting_ids <- location_keys |>
    dplyr::distinct() |>
    dplyr::count(.data$id, name = "n_locations") |>
    dplyr::filter(.data$n_locations > 1L) |>
    dplyr::pull(.data$id)

  if (length(conflicting_ids) > 0L) {
    stop(
      "`", data_arg, "` contains multiple locations for id(s): ",
      paste(conflicting_ids, collapse = ", "),
      ". Each id must have exactly one location.",
      call. = FALSE
    )
  }

  location_data |>
    dplyr::group_by(.data$id) |>
    dplyr::slice(1L) |>
    dplyr::ungroup()
}

has_known_crs <- function(x) {
  !is.na(sf::st_crs(x))
}

is_projected_sf <- function(x) {
  has_known_crs(x) && isFALSE(sf::st_is_longlat(x))
}

estimate_utm_crs <- function(points) {
  if (!has_known_crs(points)) {
    return(sf::st_crs(3857))
  }

  points_4326 <- sf::st_transform(points, 4326)
  centroid <- sf::st_centroid(sf::st_union(sf::st_geometry(points_4326)))
  xy <- sf::st_coordinates(centroid)[1L, ]

  lon <- xy[["X"]]
  lat <- xy[["Y"]]

  if (!is.finite(lon) || !is.finite(lat) || lon < -180 || lon > 180) {
    return(sf::st_crs(3857))
  }

  zone <- floor((lon + 180) / 6) + 1
  zone <- max(1, min(60, zone))
  epsg <- if (lat >= 0) 32600 + zone else 32700 + zone

  sf::st_crs(epsg)
}

choose_work_crs <- function(points, map = NULL, crs = NULL) {
  if (!is.null(crs)) {
    return(sf::st_crs(crs))
  }

  if (!is.null(map)) {
    if (!inherits(map, "sf")) {
      stop("`map` must be an sf object.", call. = FALSE)
    }

    if (is_projected_sf(map)) {
      return(sf::st_crs(map))
    }
  }

  if (is_projected_sf(points)) {
    return(sf::st_crs(points))
  }

  estimate_utm_crs(points)
}

default_radius_range <- function(points, map = NULL) {
  bbox_source <- if (!is.null(map)) map else points
  bbox <- sf::st_bbox(bbox_source)
  width <- as.numeric(bbox[["xmax"]] - bbox[["xmin"]])
  height <- as.numeric(bbox[["ymax"]] - bbox[["ymin"]])
  span <- min(width, height)

  if (!is.finite(span) || span <= 0) {
    point_bbox <- sf::st_bbox(points)
    width <- as.numeric(point_bbox[["xmax"]] - point_bbox[["xmin"]])
    height <- as.numeric(point_bbox[["ymax"]] - point_bbox[["ymin"]])
    span <- max(width, height)
  }

  if (!is.finite(span) || span <= 0) {
    span <- 1000
  }

  c(span * 0.018, span * 0.05)
}

check_radius_range <- function(radius_range) {
  if (!is.numeric(radius_range) || length(radius_range) != 2L) {
    stop("`radius_range` must be a numeric vector of length 2.", call. = FALSE)
  }

  if (any(is.na(radius_range)) || any(!is.finite(radius_range))) {
    stop("`radius_range` must contain finite values.", call. = FALSE)
  }

  if (any(radius_range <= 0)) {
    stop("`radius_range` values must be positive.", call. = FALSE)
  }

  sort(as.numeric(radius_range))
}

scale_radii <- function(total, radius_range) {
  if (length(unique(total)) == 1L) {
    return(rep(radius_range[[2L]], length(total)))
  }

  total_sqrt <- sqrt(total)
  total_min <- min(total_sqrt)
  total_max <- max(total_sqrt)

  radius_range[[1L]] +
    (total_sqrt - total_min) /
      (total_max - total_min) *
      diff(radius_range)
}

make_wedge_polygon <- function(x,
                               y,
                               outer_radius,
                               inner_radius,
                               start,
                               end,
                               proportion,
                               n) {
  full_circle <- proportion >= 1 - sqrt(.Machine$double.eps)

  if (full_circle) {
    theta <- seq(0, 2 * pi, length.out = n + 1L)
    outer <- cbind(
      x + outer_radius * cos(theta),
      y + outer_radius * sin(theta)
    )
    inner <- cbind(
      x + inner_radius * cos(rev(theta)),
      y + inner_radius * sin(rev(theta))
    )

    return(sf::st_polygon(list(outer, inner)))
  }

  n_slice <- max(4L, ceiling(n * proportion))
  theta_outer <- seq(start, end, length.out = n_slice)
  theta_inner <- rev(theta_outer)

  coords <- rbind(
    cbind(
      x + outer_radius * cos(theta_outer),
      y + outer_radius * sin(theta_outer)
    ),
    cbind(
      x + inner_radius * cos(theta_inner),
      y + inner_radius * sin(theta_inner)
    )
  )

  coords <- rbind(coords, coords[1L, ])
  sf::st_polygon(list(coords))
}

line_width_range_is_valid <- function(x) {
  is.numeric(x) &&
    length(x) == 2L &&
    all(is.finite(x)) &&
    all(x >= 0)
}

check_flow_curvature <- function(curvature) {
  if (!is.numeric(curvature) || length(curvature) != 1L) {
    stop("`flow_curvature` must be a single numeric value.", call. = FALSE)
  }

  if (!is.finite(curvature)) {
    stop("`flow_curvature` must be finite.", call. = FALSE)
  }

  invisible(curvature)
}

check_flow_n <- function(flow_n) {
  if (!is.numeric(flow_n) || length(flow_n) != 1L || !is.finite(flow_n)) {
    stop("`flow_n` must be a single finite number.", call. = FALSE)
  }

  if (flow_n < 2) {
    stop("`flow_n` must be greater than or equal to 2.", call. = FALSE)
  }

  as.integer(flow_n)
}

check_flow_arrow_size <- function(flow_arrow_size) {
  if (is.null(flow_arrow_size)) {
    return(NULL)
  }

  invalid_flow_arrow_size <- !is.numeric(flow_arrow_size) ||
    length(flow_arrow_size) != 1L ||
    !is.finite(flow_arrow_size) ||
    flow_arrow_size <= 0

  if (invalid_flow_arrow_size) {
    stop(
      "`flow_arrow_size` must be `NULL` or a single positive number.",
      call. = FALSE
    )
  }

  as.numeric(flow_arrow_size)
}

default_flow_arrow_size <- function(donuts) {
  radii <- unique(donuts$radius)
  radii <- radii[is.finite(radii) & radii > 0]

  if (length(radii) > 0L) {
    return(stats::median(radii) * 0.45)
  }

  bbox <- sf::st_bbox(donuts)
  width <- as.numeric(bbox[["xmax"]] - bbox[["xmin"]])
  height <- as.numeric(bbox[["ymax"]] - bbox[["ymin"]])
  span <- min(width, height)

  if (is.finite(span) && span > 0) {
    return(span * 0.015)
  }

  100
}

make_flow_linestring <- function(x_from,
                                 y_from,
                                 x_to,
                                 y_to,
                                 curvature = 0,
                                 n = 30) {
  if (isTRUE(all.equal(curvature, 0))) {
    return(sf::st_linestring(
      rbind(
        c(x_from, y_from),
        c(x_to, y_to)
      )
    ))
  }

  dx <- x_to - x_from
  dy <- y_to - y_from
  distance <- sqrt(dx^2 + dy^2)

  if (!is.finite(distance) || distance == 0) {
    return(sf::st_linestring(
      rbind(
        c(x_from, y_from),
        c(x_to, y_to)
      )
    ))
  }

  midpoint_x <- (x_from + x_to) / 2
  midpoint_y <- (y_from + y_to) / 2
  control_x <- midpoint_x - dy / distance * distance * curvature
  control_y <- midpoint_y + dx / distance * distance * curvature
  t <- seq(0, 1, length.out = n)

  coords <- cbind(
    (1 - t)^2 * x_from + 2 * (1 - t) * t * control_x + t^2 * x_to,
    (1 - t)^2 * y_from + 2 * (1 - t) * t * control_y + t^2 * y_to
  )

  sf::st_linestring(coords)
}

line_path_length <- function(coords) {
  if (nrow(coords) < 2L) {
    return(0)
  }

  coord_diff <- coords[-1L, , drop = FALSE] -
    coords[-nrow(coords), , drop = FALSE]
  sum(sqrt(rowSums(coord_diff^2)))
}

build_flow_arrowheads <- function(flow_sf,
                                  arrow_size,
                                  tip_offset = NULL,
                                  width_ratio = 0.7) {
  if (is.null(tip_offset)) {
    tip_offset <- rep(0, nrow(flow_sf))
  }

  if (length(tip_offset) != nrow(flow_sf)) {
    stop("`tip_offset` must have one value per flow.", call. = FALSE)
  }

  polygons <- vector("list", nrow(flow_sf))
  keep <- rep(FALSE, nrow(flow_sf))

  for (i in seq_len(nrow(flow_sf))) {
    coords <- sf::st_coordinates(sf::st_geometry(flow_sf)[[i]])
    coords <- coords[, c("X", "Y"), drop = FALSE]

    if (nrow(coords) < 2L) {
      next
    }

    line_length <- line_path_length(coords)
    if (!is.finite(line_length) || line_length <= 0) {
      next
    }

    end <- coords[nrow(coords), ]
    previous <- NULL

    for (j in seq.int(nrow(coords) - 1L, 1L)) {
      candidate <- coords[j, ]
      direction <- end - candidate
      segment_length <- sqrt(sum(direction^2))

      valid_segment <- is.finite(segment_length) &&
        segment_length > sqrt(.Machine$double.eps)

      if (valid_segment) {
        previous <- candidate
        break
      }
    }

    if (is.null(previous)) {
      next
    }

    direction <- end - previous
    direction <- direction / sqrt(sum(direction^2))
    offset <- tip_offset[[i]]

    if (!is.finite(offset) || offset < 0) {
      offset <- 0
    }

    offset <- min(offset, line_length * 0.45)
    local_arrow_size <- min(arrow_size, line_length * 0.25)

    if (!is.finite(local_arrow_size) || local_arrow_size <= 0) {
      next
    }

    tip <- end - direction * offset
    base <- tip - direction * local_arrow_size
    perpendicular <- c(-direction[[2L]], direction[[1L]])
    half_width <- local_arrow_size * width_ratio / 2
    left <- base + perpendicular * half_width
    right <- base - perpendicular * half_width

    polygons[[i]] <- sf::st_polygon(list(rbind(tip, left, right, tip)))
    keep[[i]] <- TRUE
  }

  sf::st_sf(
    sf::st_drop_geometry(flow_sf)[keep, , drop = FALSE],
    geometry = sf::st_sfc(polygons[keep], crs = sf::st_crs(flow_sf))
  )
}

resolve_colours <- function(categories, colours = NULL) {
  categories <- as.character(categories)

  if (is.null(colours)) {
    colours <- scales::hue_pal()(length(categories))
    names(colours) <- categories
    return(colours)
  }

  if (is.null(names(colours))) {
    if (length(colours) < length(categories)) {
      stop(
        "`colours` must provide at least one colour per category.",
        call. = FALSE
      )
    }

    colours <- colours[seq_along(categories)]
    names(colours) <- categories
    return(colours)
  }

  missing_colours <- setdiff(categories, names(colours))
  if (length(missing_colours) > 0L) {
    stop(
      "`colours` is missing colour(s) for category value(s): ",
      paste(missing_colours, collapse = ", "),
      call. = FALSE
    )
  }

  colours[categories]
}

values_in_display_order <- function(x) {
  if (is.factor(x)) {
    return(levels(droplevels(x)))
  }

  unique(as.character(x))
}

resolve_flow_colours <- function(flow_groups,
                                 flow_colours = NULL,
                                 donut_colours = NULL) {
  groups <- values_in_display_order(flow_groups)

  if (!is.null(flow_colours)) {
    return(resolve_colours(groups, flow_colours))
  }

  if (!is.null(donut_colours) && all(groups %in% names(donut_colours))) {
    return(donut_colours[groups])
  }

  resolve_colours(groups)
}

format_map_number <- function(x) {
  format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
}

format_map_percent <- function(x) {
  paste0(format(round(100 * x, 1), trim = TRUE), "%")
}

scale_to_range <- function(x, range) {
  range <- sort(range)

  if (length(x) == 0L) {
    return(numeric(0))
  }

  if (length(unique(x)) == 1L) {
    return(rep(mean(range), length(x)))
  }

  range[[1L]] + (x - min(x)) / (max(x) - min(x)) * diff(range)
}

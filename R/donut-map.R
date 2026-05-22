#' Draw a donut map
#'
#' `donut_map()` returns a `ggplot2` map with donut charts located on top of an
#' optional `sf` background map. It can also add origin-destination links or
#' curved trajectories between donut locations.
#'
#' @param data A data frame or `sf` object. Each row is one category for one
#'   donut location.
#' @param id Unquoted column identifying each donut location.
#' @param category Unquoted column identifying donut categories.
#' @param value Unquoted numeric column giving non-negative category values.
#' @param map Optional `sf` object used as a background layer.
#' @param lon,lat Unquoted longitude and latitude columns. Required when `data`
#'   is not an `sf` object.
#' @param input_crs Coordinate reference system for `lon` and `lat`, or for an
#'   `sf` object with missing CRS. Defaults to EPSG:4326.
#' @param crs Target projected CRS used to build the map.
#' @param radius_range Numeric vector of length 2 giving minimum and maximum
#'   donut radii in map units. If `NULL`, a range is derived from the map extent.
#' @param inner_radius Numeric value in `(0, 1)` giving the inner radius as a
#'   proportion of the outer radius.
#' @param n Number of points used to approximate a complete outer circle.
#' @param colours Optional category colours. Use a named vector for stable
#'   category-colour matching.
#' @param flows Optional data frame of origin-destination flows.
#' @param from,to Unquoted columns in `flows` identifying origin and destination
#'   ids. Required when `flows` is supplied.
#' @param flow_value Optional unquoted numeric column in `flows` used to scale
#'   line widths. If omitted, each flow receives value 1.
#' @param flow_group Optional unquoted column in `flows` used to colour flow
#'   lines and arrowheads by group.
#' @param flow_colours Optional colours for `flow_group`. Use a named vector for
#'   stable group-colour matching. If omitted and flow groups match donut
#'   categories, `colours` is reused.
#' @param flow_min Optional minimum flow value to draw.
#' @param flow_linewidth_range Numeric vector of length 2 controlling flow line
#'   widths.
#' @param flow_curvature Numeric curvature for trajectory lines. Use `0` for
#'   straight lines, positive values for one bend direction, and negative values
#'   for the opposite direction.
#' @param flow_n Number of points used to approximate each curved trajectory.
#' @param flow_arrow Should static flow trajectories include arrows?
#' @param flow_arrow_length Arrow length in inches when `flow_arrow = TRUE`.
#' @param flow_colour,flow_alpha Flow line colour and alpha. `flow_colour` is
#'   used when `flow_group` is not supplied.
#' @param map_fill,map_colour Background map fill and outline colours.
#' @param donut_colour,donut_linewidth Donut segment border colour and linewidth.
#'
#' @return A `ggplot` object.
#' @export
#'
#' @examples
#' demo <- data.frame(
#'   place = rep(c("A", "B", "C"), each = 3),
#'   lon = rep(c(-71.35, -71.2, -71.05), each = 3),
#'   lat = rep(c(46.75, 46.82, 46.73), each = 3),
#'   category = rep(c("x", "y", "z"), times = 3),
#'   value = c(10, 20, 5, 5, 15, 10, 12, 4, 9)
#' )
#'
#' flows <- data.frame(
#'   from = c("A", "B"),
#'   to = c("B", "C"),
#'   trips = c(30, 10)
#' )
#'
#' donut_map(
#'   demo,
#'   place,
#'   category,
#'   value,
#'   lon = lon,
#'   lat = lat,
#'   flows = flows,
#'   from = from,
#'   to = to,
#'   flow_value = trips
#' )
donut_map <- function(data,
                      id,
                      category,
                      value,
                      map = NULL,
                      lon = NULL,
                      lat = NULL,
                      input_crs = 4326,
                      crs = NULL,
                      radius_range = NULL,
                      inner_radius = 0.55,
                      n = 96,
                      colours = NULL,
                      flows = NULL,
                      from = NULL,
                      to = NULL,
                      flow_value = NULL,
                      flow_group = NULL,
                      flow_colours = NULL,
                      flow_min = NULL,
                      flow_linewidth_range = c(0.2, 2.5),
                      flow_curvature = 0.18,
                      flow_n = 30,
                      flow_arrow = TRUE,
                      flow_arrow_length = 0.12,
                      flow_colour = "grey35",
                      flow_alpha = 0.45,
                      map_fill = "grey96",
                      map_colour = "white",
                      donut_colour = "white",
                      donut_linewidth = 0.15) {
  id_col <- column_name(rlang::enquo(id), "id")
  category_col <- column_name(rlang::enquo(category), "category")
  value_col <- column_name(rlang::enquo(value), "value")
  lon_col <- column_name(rlang::enquo(lon), "lon", required = FALSE)
  lat_col <- column_name(rlang::enquo(lat), "lat", required = FALSE)

  donuts <- build_donut_polygons(
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
    n = n
  )

  categories <- levels(donuts$category)
  colour_values <- resolve_colours(categories, colours)

  map_projected <- NULL
  if (!is.null(map)) {
    if (!inherits(map, "sf")) {
      stop("`map` must be an sf object.", call. = FALSE)
    }

    map_projected <- sf::st_transform(map, sf::st_crs(donuts))
  }

  flow_sf <- NULL
  flow_group_col <- NULL
  flow_colour_values <- NULL
  if (!is.null(flows)) {
    if (!is.numeric(flow_arrow_length) ||
        length(flow_arrow_length) != 1L ||
        !is.finite(flow_arrow_length) ||
        flow_arrow_length <= 0) {
      stop("`flow_arrow_length` must be a single positive number.", call. = FALSE)
    }

    from_col <- column_name(rlang::enquo(from), "from")
    to_col <- column_name(rlang::enquo(to), "to")
    flow_value_col <- column_name(
      rlang::enquo(flow_value),
      "flow_value",
      required = FALSE
    )
    flow_group_col <- column_name(
      rlang::enquo(flow_group),
      "flow_group",
      required = FALSE
    )

    if (is.null(flow_group_col) && !is.null(flow_colours)) {
      stop("`flow_colours` can only be used when `flow_group` is supplied.", call. = FALSE)
    }

    flow_sf <- build_flow_lines(
      flows = flows,
      locations = data,
      from_col = from_col,
      to_col = to_col,
      value_col = flow_value_col,
      group_col = flow_group_col,
      id_col = id_col,
      lon_col = lon_col,
      lat_col = lat_col,
      input_crs = input_crs,
      crs = sf::st_crs(donuts),
      flow_curvature = flow_curvature,
      flow_n = flow_n
    )

    if (!is.null(flow_min)) {
      if (!is.numeric(flow_min) || length(flow_min) != 1L || !is.finite(flow_min)) {
        stop("`flow_min` must be a single finite number.", call. = FALSE)
      }

      flow_sf <- dplyr::filter(flow_sf, .data$value >= flow_min)
    }

    if (!line_width_range_is_valid(flow_linewidth_range)) {
      stop(
        "`flow_linewidth_range` must be a non-negative numeric vector of length 2.",
        call. = FALSE
      )
    }

    if (!is.null(flow_group_col) && nrow(flow_sf) > 0L) {
      flow_colour_values <- resolve_flow_colours(
        flow_groups = flow_sf$group,
        flow_colours = flow_colours,
        donut_colours = colour_values
      )
    }
  }

  p <- ggplot2::ggplot()

  if (!is.null(map_projected)) {
    p <- p +
      ggplot2::geom_sf(
        data = map_projected,
        fill = map_fill,
        colour = map_colour,
        linewidth = 0.2
      )
  }

  if (!is.null(flow_sf) && nrow(flow_sf) > 0L) {
    flow_arrow_spec <- NULL
    if (isTRUE(flow_arrow)) {
      flow_arrow_spec <- grid::arrow(
        length = grid::unit(flow_arrow_length, "inches"),
        type = "closed"
      )
    }

    if (!is.null(flow_group_col)) {
      p <- p +
        ggplot2::geom_sf(
          data = flow_sf,
          ggplot2::aes(linewidth = .data$value, colour = .data$group),
          alpha = flow_alpha,
          lineend = "round",
          arrow = flow_arrow_spec
        ) +
        ggplot2::scale_colour_manual(
          values = flow_colour_values,
          name = flow_group_col,
          drop = FALSE
        )
    } else {
      p <- p +
        ggplot2::geom_sf(
          data = flow_sf,
          ggplot2::aes(linewidth = .data$value),
          colour = flow_colour,
          alpha = flow_alpha,
          lineend = "round",
          arrow = flow_arrow_spec
        )
    }

    p <- p +
      ggplot2::scale_linewidth_continuous(
        range = sort(flow_linewidth_range),
        name = if (!is.null(flow_value_col)) flow_value_col else "flow"
      )
  }

  p <- p +
    ggplot2::geom_sf(
      data = donuts,
      ggplot2::aes(fill = .data$category),
      colour = donut_colour,
      linewidth = donut_linewidth
    ) +
    ggplot2::coord_sf(datum = NA) +
    ggplot2::labs(fill = category_col)

  p <- p +
    ggplot2::scale_fill_manual(values = colour_values, drop = FALSE)

  p +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      panel.grid.major = ggplot2::element_line(
        colour = "grey88",
        linewidth = 0.2
      ),
      panel.grid.minor = ggplot2::element_blank()
    )
}

#' Draw an interactive donut map
#'
#' `donut_leaflet()` returns a `leaflet` htmlwidget with clickable donut
#' segments, optional origin-destination links or curved trajectories, popups,
#' labels, a legend, and layer controls.
#'
#' @inheritParams donut_map
#' @param crs Target projected CRS used to build interactive donut and trajectory
#'   geometries. Defaults to EPSG:3857, Leaflet's default display projection, so
#'   donut circles and sector separators remain visually regular on screen.
#' @param flow_weight_range Numeric vector of length 2 controlling interactive
#'   flow line weights.
#' @param flow_curvature Numeric curvature for trajectory lines. Use `0` for
#'   straight lines, positive values for one bend direction, and negative values
#'   for the opposite direction.
#' @param flow_n Number of points used to approximate each curved trajectory.
#' @param flow_arrow Should interactive flow trajectories include arrowheads?
#' @param flow_arrow_size Arrowhead length in projected map units. If `NULL`,
#'   a size is derived from the donut radii.
#' @param flow_colour Flow line colour.
#' @param flow_opacity Flow line opacity.
#' @param provider_tiles Leaflet provider tiles. Use `NULL` to skip tile layers.
#' @param popup Should popups be attached to donut segments and flow lines?
#' @param label Should hover labels be attached to donut segments and flow lines?
#' @param prefer_canvas Should Leaflet prefer Canvas over SVG for vector
#'   rendering? The default `FALSE` gives crisper small donut separators.
#' @param donut_colour Donut segment border colour.
#' @param donut_weight Donut segment border weight.
#' @param donut_opacity Donut segment fill opacity.
#' @param map_weight Background map border weight.
#' @param map_opacity Background map opacity.
#'
#' @return A `leaflet` htmlwidget.
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
#' donut_leaflet(demo, place, category, value, lon = lon, lat = lat)
donut_leaflet <- function(data,
                          id,
                          category,
                          value,
                          map = NULL,
                          lon = NULL,
                          lat = NULL,
                          input_crs = 4326,
                          crs = 3857,
                          radius_range = NULL,
                          inner_radius = 0.55,
                          n = 96,
                          colours = NULL,
                          flows = NULL,
                          from = NULL,
                          to = NULL,
                          flow_value = NULL,
                          flow_min = NULL,
                          flow_weight_range = c(1, 8),
                          flow_curvature = 0.18,
                          flow_n = 30,
                          flow_arrow = TRUE,
                          flow_arrow_size = NULL,
                          flow_colour = "grey35",
                          flow_opacity = 0.55,
                          provider_tiles = "CartoDB.Positron",
                          popup = TRUE,
                          label = TRUE,
                          prefer_canvas = FALSE,
                          map_fill = "#f3f4f6",
                          map_colour = "#ffffff",
                          map_weight = 1,
                          map_opacity = 0.9,
                          donut_colour = "#ffffff",
                          donut_weight = 1,
                          donut_opacity = 0.9) {
  id_col <- column_name(rlang::enquo(id), "id")
  category_col <- column_name(rlang::enquo(category), "category")
  value_col <- column_name(rlang::enquo(value), "value")
  lon_col <- column_name(rlang::enquo(lon), "lon", required = FALSE)
  lat_col <- column_name(rlang::enquo(lat), "lat", required = FALSE)

  if (!is.logical(prefer_canvas) ||
      length(prefer_canvas) != 1L ||
      is.na(prefer_canvas)) {
    stop("`prefer_canvas` must be `TRUE` or `FALSE`.", call. = FALSE)
  }

  if (!line_width_range_is_valid(flow_weight_range)) {
    stop(
      "`flow_weight_range` must be a non-negative numeric vector of length 2.",
      call. = FALSE
    )
  }

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
  donuts$fill_colour <- unname(colour_values[as.character(donuts$category)])

  donuts$popup <- paste0(
    "<strong>", htmltools::htmlEscape(donuts$id), "</strong><br/>",
    htmltools::htmlEscape(as.character(donuts$category)), ": ",
    format_map_number(donuts$value), "<br/>",
    "Total: ", format_map_number(donuts$total), "<br/>",
    "Share: ", format_map_percent(donuts$proportion)
  )

  donuts$label <- paste0(
    htmltools::htmlEscape(donuts$id),
    " - ",
    htmltools::htmlEscape(as.character(donuts$category)),
    ": ",
    format_map_percent(donuts$proportion)
  )

  map_projected <- NULL
  if (!is.null(map)) {
    if (!inherits(map, "sf")) {
      stop("`map` must be an sf object.", call. = FALSE)
    }

    map_projected <- sf::st_transform(map, sf::st_crs(donuts))
  }

  flow_sf <- NULL
  flow_arrow_sf <- NULL
  if (!is.null(flows)) {
    from_col <- column_name(rlang::enquo(from), "from")
    to_col <- column_name(rlang::enquo(to), "to")
    flow_value_col <- column_name(
      rlang::enquo(flow_value),
      "flow_value",
      required = FALSE
    )

    flow_sf <- build_flow_lines(
      flows = flows,
      locations = data,
      from_col = from_col,
      to_col = to_col,
      value_col = flow_value_col,
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

    flow_sf$weight <- scale_to_range(flow_sf$value, flow_weight_range)
    flow_sf$popup <- paste0(
      "<strong>",
      htmltools::htmlEscape(flow_sf$from),
      " &rarr; ",
      htmltools::htmlEscape(flow_sf$to),
      "</strong><br/>",
      "Flow: ",
      format_map_number(flow_sf$value)
    )
    flow_sf$label <- paste0(
      htmltools::htmlEscape(flow_sf$from),
      " -> ",
      htmltools::htmlEscape(flow_sf$to),
      ": ",
      format_map_number(flow_sf$value)
    )

    if (isTRUE(flow_arrow) && nrow(flow_sf) > 0L) {
      flow_arrow_size <- check_flow_arrow_size(flow_arrow_size)

      if (is.null(flow_arrow_size)) {
        flow_arrow_size <- default_flow_arrow_size(donuts)
      }

      donut_radius_tbl <- sf::st_drop_geometry(donuts) |>
        dplyr::group_by(.data$id) |>
        dplyr::summarise(radius = max(.data$radius), .groups = "drop")

      destination_radius <- donut_radius_tbl$radius[
        match(flow_sf$to, donut_radius_tbl$id)
      ]

      flow_arrow_sf <- build_flow_arrowheads(
        flow_sf = flow_sf,
        arrow_size = flow_arrow_size,
        tip_offset = destination_radius * 1.25
      )
    }
  }

  donuts_leaflet <- sf::st_transform(donuts, 4326)
  leaflet_map <- leaflet::leaflet(
    options = leaflet::leafletOptions(preferCanvas = prefer_canvas)
  )

  if (!is.null(provider_tiles)) {
    leaflet_map <- leaflet::addProviderTiles(
      leaflet_map,
      provider = provider_tiles,
      group = "Tiles"
    )
  }

  if (!is.null(map_projected)) {
    map_leaflet <- sf::st_transform(map_projected, 4326)
    leaflet_map <- leaflet::addPolygons(
      leaflet_map,
      data = map_leaflet,
      fillColor = map_fill,
      fillOpacity = map_opacity,
      color = map_colour,
      weight = map_weight,
      opacity = map_opacity,
      group = "Map"
    )
  }

  if (!is.null(flow_sf) && nrow(flow_sf) > 0L) {
    flow_leaflet <- sf::st_transform(flow_sf, 4326)
    leaflet_map <- leaflet::addPolylines(
      leaflet_map,
      data = flow_leaflet,
      color = flow_colour,
      opacity = flow_opacity,
      weight = ~weight,
      popup = if (isTRUE(popup)) ~popup else NULL,
      label = if (isTRUE(label)) ~label else NULL,
      group = "Flows"
    )

    if (!is.null(flow_arrow_sf) && nrow(flow_arrow_sf) > 0L) {
      flow_arrow_leaflet <- sf::st_transform(flow_arrow_sf, 4326)
      leaflet_map <- leaflet::addPolygons(
        leaflet_map,
        data = flow_arrow_leaflet,
        stroke = FALSE,
        fill = TRUE,
        fillColor = flow_colour,
        fillOpacity = flow_opacity,
        popup = if (isTRUE(popup)) ~popup else NULL,
        label = if (isTRUE(label)) ~label else NULL,
        group = "Flows"
      )
    }
  }

  leaflet_map <- leaflet::addPolygons(
    leaflet_map,
    data = donuts_leaflet,
    fillColor = ~fill_colour,
    fillOpacity = donut_opacity,
    color = donut_colour,
    weight = donut_weight,
    opacity = 1,
    popup = if (isTRUE(popup)) ~popup else NULL,
    label = if (isTRUE(label)) ~label else NULL,
    group = "Donuts",
    highlightOptions = leaflet::highlightOptions(
      weight = donut_weight + 2,
      color = "#111827",
      bringToFront = TRUE
    )
  )

  bounds <- sf::st_bbox(donuts_leaflet)
  leaflet_map <- leaflet::fitBounds(
    leaflet_map,
    lng1 = bounds[["xmin"]],
    lat1 = bounds[["ymin"]],
    lng2 = bounds[["xmax"]],
    lat2 = bounds[["ymax"]]
  )

  leaflet_map <- leaflet::addLegend(
    leaflet_map,
    position = "bottomright",
    colors = unname(colour_values),
    labels = names(colour_values),
    title = category_col,
    opacity = donut_opacity
  )

  overlay_groups <- c(if (!is.null(map_projected)) "Map", if (!is.null(flow_sf)) "Flows", "Donuts")

  leaflet::addLayersControl(
    leaflet_map,
    baseGroups = if (!is.null(provider_tiles)) "Tiles" else NULL,
    overlayGroups = overlay_groups,
    options = leaflet::layersControlOptions(collapsed = TRUE)
  ) |>
    leaflet::addScaleBar(position = "bottomleft")
}

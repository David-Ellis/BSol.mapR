options(warn=-1)

`%>%` = dplyr::`%>%`

check_type_and_area <- function(map_type, area_name) {
  # Check for valid map type
  if (!(map_type %in% c(
    "Locality", "Constituency", "Constituency24", "Ward",
    "Postal District","Postal Sector",
    "LSOA11", "MSOA11", "LSOA21", "MSOA21"
    ))
    )
    {
    stop(paste("Error: Unexpected map type. Given `", map_type,"`", sep = ""))
    }
  # Check for valid area name
  if (!(area_name %in% c("BSol", "Birmingham", "Solihull"))) {
    stop(
      paste(
        "Error: Unexpected area type. Available options: 'BSol', 'Birmingham', 'Solihull'\nGiven: `",
        area_name,"`", sep = "")
    )
  }
}

load_shape_file <- function(map_type) {
  # Load lazy loaded shape file
  shape <- switch(
    map_type,
    "Constituency" = Constituency,
    "Constituency24" = const24_shape,
    "Locality" = Locality,
    "LSOA11" = LSOA11,
    "LSOA21" = LSOA21,
    "MSOA11" = MSOA11,
    "MSOA21" = MSOA21,
    "Postal District" = `Postal District`,
    "Postal Sector" = `Postal Sector`,
    "Ward" = Ward,
    stop("Unknown map type.")
  )

  return(shape)
}

add_const_lines <- function(
    map,
    area_name = "Birmingham",
    const_names = "None",
    verbose = FALSE
) {
  constituencies <- load_shape_file("Constituency")
  constituencies <- filter_shape(constituencies, area_name)

  # TODO: Update lazy loaded data to prevent this
  colnames(constituencies@data)[1] = "Constituency"

  # Add lines to map
  map <- map +
    tmap::tm_shape(constituencies) +
    tmap::tm_borders(col = "grey40", lwd = 1.5)

  if (const_names %in% c("None", "Yes", TRUE)){
    map <- map + tmap::tm_text(text = "Constituency", size = 0.8)
  }

  return(map)
}

add_locality_lines <- function(
    map,
    area_name = "Birmingham",
    locality_names = "None",
    verbose = FALSE
) {

  localities <- load_shape_file("Locality")
  localities <- filter_shape(localities, area_name)

  map <- map +
    tmap::tm_shape(localities) +
    tmap::tm_borders(col = "grey40", lwd = 1.5)

  if (locality_names %in% c("None", "Yes", TRUE)){
    map <- map + tmap::tm_text(text = "Locality", size = 0.6)
  }

  return(map)
}


add_compass <- function(map) {
  map <- map +
    tmap::tm_compass(type = "8star", size = 4,
               position = c("RIGHT", "bottom"))
  return(map)
}

filter_shape <- function(
    input_shape,
    area_name
) {

  # Cut the shape file down to the correct area
  if (
    (tolower(area_name) == "bsol")
    ) {
    # Do nothing
    output_shape <- input_shape
  } else if (
    tolower(area_name) %in% c("birmingham", "solihull")
    ) {
    # Filter for Birmingham or Solihull
    output_shape <- subset(input_shape, input_shape@data$Area == area_name)
  }

  return(output_shape)
}

remove_nas <- function(
    shape,
    value_header
) {
  # filter shape down to areas we have data for
  mask <- !is.na(shape@data[[value_header]])
  shape <- shape[mask,]

  return(shape)
}


add_credits<- function(map, credits, credits_size) {
  map <- map +
    tmap::tm_credits(credits, size = credits_size,
               position = c(0, 0))
  return(map)
}


plot_base_map <- function(
    area_data,
    value_header,
    map_title = "",
    fill_title = "",
    area_name = "Birmingham",
    map_type = "Ward",
    fill_missing = NA,
    palette= "Blues",
    style = "pretty",
    breaks = NULL,
    labels = NULL,
    verbose = FALSE
) {
  # Check for valid map type and area name
  check_type_and_area(map_type, area_name)

  # Load base shape - to get correct map zoom
  base_shape <- load_shape_file("Locality")
  base_shape <- filter_shape(base_shape, area_name)

  shape <- load_shape_file(map_type)

  # TODO: Update lazy loaded data to prevent this
  if (map_type == "Constituency") {
    colnames(shape@data)[1] = "Constituency"
  } else if (map_type == "Postal District") {
    colnames(shape@data)[1] = "Postal District"
  } else if (map_type == "Postal Sector") {
    colnames(shape@data)[1] = "Postal Sector"
  }

  # join data
  shape@data <- shape@data %>%
    dplyr::left_join(area_data, by = map_type)

  # Fill missing values (default with NA - i.e. no change)
  na_mask = is.na(shape@data[value_header])
  shape@data[value_header][na_mask] <- fill_missing

  # Filter shape file
  if (map_type %in% c("Postal District", "Postal Sector")) {
    shape <- remove_nas(shape, value_header)
  } else {
    shape <- filter_shape(shape, area_name)
  }

  # Turn off borders for LSOA maps
  if (map_type %in% c("LSOA11", "LSOA21")) {
    alpha = 0
  } else {
    alpha = 1
  }

  #### plot map ####
  map <- tmap::tm_shape(base_shape) +
    # Invisible base layer to fix map zoom
    tmap::tm_borders(lwd = 0, alpha = 0) +
    tmap::tm_shape(shape) +
    tmap::tm_fill(
      value_header,
      title = fill_title,
      palette = palette,
      style = style,
      breaks = breaks,
      labels = labels
    ) +
    tmap::tm_borders(col = "grey80", lwd = 0.4, alpha = alpha) +
    tmap::tm_layout(legend.position = c("LEFT", "TOP"),
              legend.width = 0.5,
              legend.height = 0.5,
              legend.frame = FALSE,
              inner.margins = 0.08,
              main.title = map_title,
              main.title.size = 0.8,
              frame = FALSE)

  return(map)
}


#' Plot Empty Map
#'
#' @param map_title Title for the map
#' @param area_name Name of area to be plotted: BSol, Birmingham, or Solihull
#' @param map_type Map geography type: Constituency, Ward, LSOA21, etc
#' @param paletteColour palette
#' @param const_lines Include constituency lines: TRUE/FALSE
#' @param const_names Include constituency names: TRUE/FALSE
#' @param locality_lines Include locality lines: TRUE/FALSE
#' @param locality_names Include locality names: TRUE/FALSE
#' @param compass Include compass: TRUE/FALSE
#' @param credits Credit text to be shown at bottom of the map
#' @param credits_size Credit size
#' @param verbose Print debugging text
#'
#' @return
#' @export
#'
#' @examples
plot_empty_map <- function(
    map_title = "",
    area_name = "BSol",
    map_type = "Ward",
    palette= "Blues",
    const_lines = "None",
    const_names = "None",
    locality_lines = "None",
    locality_names = "None",
    compass = TRUE,
    credits = "default",
    credits_size = 0.6,
    verbose = FALSE
) {

  # Check for valid map type and area name
  check_type_and_area(map_type, area_name)

  # Wrap title text
  if (area_name == "Birmingham") {
    map_title <- stringr::str_wrap(map_title, width = 60)
  } else {
    map_title <- stringr::str_wrap(map_title, width = 73)
  }

  # Load base shape - to get correct map zoom
  base_shape <- load_shape_file("Locality")

  #print("-----1-----")
  base_shape <- filter_shape(base_shape, area_name)
  #print("-----2-----")
  shape <- load_shape_file(map_type)

  if (!(map_type %in% c("Postal District", "Postal Sector"))) {
    shape <- filter_shape(shape, area_name)
  }

  # TODO: Update lazy loaded data to prevent this
  if (map_type == "Constituency") {
    colnames(shape@data)[1] = "Constituency"
  } else if (map_type == "Postal District") {
    colnames(shape@data)[1] = "Postal District"
  }

  #### plot map ####
  map <- tmap::tm_shape(base_shape) +
    # Invisible base layer to fix map zoom
    tmap::tm_borders(lwd = 0, alpha = 0) +
    tmap::tm_shape(shape) +
    tmap::tm_borders(col = "grey80", lwd = 0.65) +
    tmap::tm_layout(legend.position = c("LEFT", "TOP"),
              legend.width = 0.5,
              legend.height = 0.5,
              legend.frame = FALSE,
              inner.margins = 0.08,
              main.title = map_title,
              main.title.size = 0.8,
              frame = FALSE)

  # Add constituency lines
  if (
    const_lines %in% c("Yes", TRUE) |
    (map_type %in% c("Ward", "Constituency", "Postal District", "Postal Sector",
                     "LSOA11", "MSOA11", "LSOA21", "MSOA21") &
     locality_lines == "None" &
     !(const_lines %in% c("No", FALSE))
    )
  ) {
    map <- add_const_lines(map,
                           area_name = area_name,
                           const_names = const_names,
                           verbose = verbose)
  }

  if (locality_lines %in% c("Yes", TRUE) |
      (map_type == "Locality")) {
    map <- add_locality_lines(map,
                              area_name = area_name,
                              locality_names = locality_names,
                              verbose = verbose)
  }

  # Add compass
  if (compass %in% c("Yes", TRUE)){
    map <- add_compass(map)
  }

  if (credits != FALSE) {
    if (credits == "default") {
      # Set credits to default
      credits <- paste("Contains OS data \u00A9 Crown copyright and database right",
                       # Get current year
                       format(Sys.Date(), "%Y"),
                       ". Source:\nOffice for National Statistics licensed under the Open Government Licence v.3.0."
      )
    }
    map <- add_credits(map, credits,
                       credits_size = credits_size)
  }


  return(map)
}

#' Plot map
#'
#' @param data Data frame containing area IDs and plot value
#' @param value_header Header name for the value to be plotted
#' @param area_name Name of area to be plotted: BSol, Birmingham, or Solihull
#' @param map_type Map geography type: Constituency, Ward, LSOA21, etc
#' @param map_title Title for the map
#' @param fill_title Title for the fill variable
#' @param fill_missing Fill missing values (default = NA)
#' @param paletteColour palette
#' @param style Colour style: pretty/fixed
#' @param breaks Value plotting range
#' @param labels Custom value labels
#' @param const_lines Include constituency lines: TRUE/FALSE
#' @param const_names Include constituency names: TRUE/FALSE
#' @param locality_lines Include locality lines: TRUE/FALSE
#' @param locality_names Include locality names: TRUE/FALSE
#' @param compass Include compass: TRUE/FALSE
#' @param credits Credit text to be shown at bottom of the map
#' @param credits_size Credit size
#' @param verbose Print debugging text
#'
#' @return
#' @export
#'
#' @examples
plot_map <- function(
    data,
    value_header,
    map_type,
    area_name = "BSol",
    map_title = "",
    fill_title = "",
    fill_title_wrap = 40,
    fill_missing = NA,
    palette = "Blues",
    style = "pretty",
    breaks = NULL,
    labels = NULL,
    const_lines = "None",
    const_names = "None",
    locality_lines = "None",
    locality_names = "None",
    compass = TRUE,
    credits = "default",
    credits_size = 0.6,
    verbose = FALSE
) {

  # Wrap title text
  if (area_name == "Birmingham") {
    map_title <- stringr::str_wrap(map_title, width = 60)
  } else {
    map_title <- stringr::str_wrap(map_title, width = 73)
  }
  # Wrap fill title text
  fill_title <- stringr::str_wrap(fill_title, width = fill_title_wrap)

  tmap::tmap_options(show.messages = verbose)

  map <- plot_base_map(
    data,
    value_header,
    area_name = area_name,
    map_type = map_type,
    map_title = map_title,
    fill_title = fill_title,
    fill_missing = fill_missing,
    palette= palette,
    style = style,
    breaks = breaks,
    labels = labels,
    verbose = verbose
  )

  # Add constituency lines
  if (
    const_lines %in% c("Yes", TRUE) |
    (map_type %in% c("Ward", "Constituency", "Postal District", "Postal Sector",
                     "LSOA11", "MSOA11", "LSOA21", "MSOA21") &
     locality_lines == "None" &
     !(const_lines %in% c("No", FALSE))
    )
  ) {
    map <- add_const_lines(map,
                           area_name = area_name,
                           const_names = const_names,
                           verbose = verbose)
  }

  if (locality_lines %in% c("Yes", TRUE) |
      (map_type == "Locality")) {
    map <- add_locality_lines(map,
                              area_name = area_name,
                              locality_names = locality_names,
                              verbose = verbose)
  }

  # Add compass
  if (compass %in% c("Yes", TRUE)){
    map <- add_compass(map)
  }

  if (credits != FALSE) {
    if (credits == "default") {
      # Set credits to default
      credits <- paste("Contains OS data \u00A9 Crown copyright and database right",
                       # Get current year
                       format(Sys.Date(), "%Y"),
                       ". Source:\nOffice for National Statistics licensed under the Open Government Licence v.3.0."
                       )
      }
    map <- add_credits(map, credits,
                       credits_size = credits_size)
  }


  return(map)
}

#' Gets the longitude and latitude from West Midlands postcodes if LONG and LAT
#' columns are not already present
#'
#' Columns must be labelled exactly as "Postcode" or "LONG" and "LAT".
#'
#' Function only works with West Midlands Postcodes.
#' @param points_data Data frame containing postcodes and/or longitude and
#' latitude data
#'
#' @return
#' @export
#'
#' @examples
#'
get_long_lat <- function(
    points_data
) {
  if (
    ! ("LONG" %in% colnames(points_data) &
       "LAT" %in% colnames(points_data))
  ) {
    # No LONG and LAT so check that Postcode exists
    if (!"Postcode" %in% colnames(points_data)) {
      stop("Error: Expected column named `Postcode`")
    }
    else {
      # Load postcode look-up and join
      points_data <- points_data %>%
        # standardise postcodes
        dplyr::mutate(
          # Upper case
          Postcode = stringr::str_to_upper(Postcode),
          # Trim leading and trailing white space
          Postcode = trimws(Postcode),
          # Replace 1+ white space with single space
          Postcode = gsub("\\s+", " ", Postcode)
        ) %>%
        dplyr::left_join(
          # Lazy loaded postcode data
          WM_Postcodes
        )
      # Check for postcodes without coords
      missing_coords <- points_data$Postcode[is.na(points_data$LONG)]
      if (length(missing_coords) > 0) {
        print("The following postcodes could not be found.")
        print(missing_coords)
        # Remove postcodes with missing coordinates
        points_data <- points_data[!is.na(points_data$LONG),]
      }
    }
  }
  return(points_data)
}

#' Converts data frame with longitude and latitude
#'
#' Longitude and latitude columns names must be exactly "LONG" and "LAT"
#'
#' @param points_data Data frame containing longitude and latitude data
#'
#' @return
#' @export
#'
#' @examples
get_points_shape <- function(
    points_data
) {

  if (
    ! ("LONG" %in% colnames(points_data) &
       "LAT" %in% colnames(points_data))
  ) {
    stop("Error: get_points_shape() expected columns named `LONG` and `LAT`")
  }

  point_locs <- sp::SpatialPointsDataFrame(
    data.frame(points_data$LONG, points_data$LAT),
    points_data,
    proj4string = sp::CRS("+proj=longlat +datum=WGS84"))

  # Update coordinate system
  point_locs <- sp::spTransform(point_locs, "+proj=tmerc +lat_0=49 +lon_0=-2 +k=0.9996012717 +x_0=400000 +y_0=-100000 +ellps=airy +units=m +no_defs")

  return(point_locs)
}

#' Add points to map
#'
#' @param map Map object returned from plot_map(), plot_empty_map() or add_points()
#' @param points_data data frame containing LONG and LAT of each point
#' @param size Point plotting size
#' @param alpha Point alpha (transparency) value. Default = 1 (Solid)
#' @param shape Point shape. Default = 21 (Circle).
#' @param color Point plotting colour (Set to category column name for variable colour plotting)
#' @param palette Colour palette
#'
#' @return
#' @export
#'
#' @examples
add_points <- function(
    map,
    points_data,
    size = 0.1,
    alpha = 1,
    shape = 21,
    color = "orange",
    palette = "Dark2"
) {

  # If colnames don't include LONG and LAT - Pull from postcode
  points_data <- get_long_lat(points_data)

  # Create new shape with high street points
  points_shape <- get_points_shape(points_data)

  # Fix column names
  colnames(points_shape@data) = colnames(points_data)

  map <- map +
    tmap::tm_shape(points_shape) +
    tmap::tm_dots(
      size = size,
      col = color,
      palette = palette,
      alpha = alpha,
      shape = shape
      )

  return(map)
}

#' Create radii shape object
#'
#' Creates shape file for circles centered on the given coordinates with the
#' defined radii
#'
#' @param points_data data frame containing LONG and LAT of each point
#' @param radii radii of the circles
#' @param units units of the radii (Must be "km", "m", or "miles")
#'  Other units might be okay, but they haven't been tested
#'  TODO: Test these 3
#'
#' @return
#' @export
#'
#' @examples
get_radii_shapes <- function(
    points_shape,
    radii,
    units = "km"
){
  # Update units mode to allow for variable units
  units::units_options(set_units_mode = "standard")

  points_shape_sf <- sf::st_as_sf(points_shape)

  # Radii are contained in column in the given data
  if (class(radii) == "character") {
    radii_shape <-sf::st_buffer(
      points_shape_sf,
      units::set_units(
        points_shape@data[[radii]],
        units
      )
    )
  }
  # Radii are single single given value
  else {
    radii_shape <-
      sf::st_buffer(
        points_shape_sf,
        units::set_units(
          radii,
          units
        )
      )
  }

  return(radii_shape)

}

#' Add circles with specified radii to map
#'
#' @param map Map object returned from plot_map(), plot_empty_map() or add_points()
#' @param points_data data frame containing LONG and LAT of each point
#' @param radii radii of the circles
#' @param unit units for radius ("km", "m", "miles")
#' @param alpha Point alpha (transparency) value. Default = 1 (Solid)
#' @param shape Point shape. Default = 21 (Circle).
#' @param color Point plotting colour (Set to category column name for variable colour plotting)
#' @param palette Colour palette
#'
#' @return
#' @export
#'
#' @examples
#'
add_radii <- function(
    map,
    points_data,
    radii,
    units = "km",
    alpha = 0.5,
    color = "orange",
    palette = "Dark2"
) {
  # If colnames don't include LONG and LAT - Pull from postcode
  points_data <- get_long_lat(points_data)

  # Create new shape with high street points
  points_shape <- get_points_shape(points_data)

  # Fix column names
  colnames(points_shape@data) = colnames(points_data)

  radii_shape <- get_radii_shapes(points_shape, radii, units)

  #TODO: Get this mapping to work (this is stackoverflow guess work)
  map <- map +
    tmap::tm_shape(radii_shape) +
    tmap::tm_polygons(
      col = color,
      palette = palette,
      alpha = alpha
      )

  return(map)
}
#' Save map object
#'
#' @param map Map object returned from plot_map(), plot_empty_map() or add_points()
#' @param save_name File save name
#' @param height Map figure height (inches)
#' @param width Map figure width (inches)
#'
#' @return
#' @export
#'
#' @examples
save_map <- function(
    map,
    save_name = "new_map.png",
    height = 5,
    width = 5
){

  tmap::tmap_save(map,
            filename = save_name,
            height = height,
            width = width)

  print(paste("Map saved to:", save_name))
}


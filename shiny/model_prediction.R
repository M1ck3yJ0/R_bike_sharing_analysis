# Developed with assistance from Claude (Anthropic)
# https://claude.ai


require(tidyverse)
require(httr)

# OpenWeather API key
api_key <- "my_api_key"

# Fetch 5-day, 3-hourly weather forecasts for a list of cities
get_weather_forecaset_by_cities <- function(city_names) {

  city              <- c()
  weather           <- c()
  temperature       <- c()
  visibility        <- c()
  humidity          <- c()
  wind_speed        <- c()
  dew_point         <- c()
  solar_radiation   <- c()
  rainfall          <- c()
  snowfall          <- c()
  seasons           <- c()
  hours             <- c()
  forecast_date     <- c()
  weather_labels    <- c()
  weather_detail_labels <- c()

  for (city_name in city_names) {
    url_get        <- "https://api.openweathermap.org/data/2.5/forecast"
    forecast_query <- list(q = city_name, appid = api_key, units = "metric")
    response       <- GET(url_get, query = forecast_query)
    json_list      <- content(response, as = "parsed")
    results        <- json_list$list

    for (result in results) {
      forecast_datetime <- result$dt_txt
      hour  <- as.numeric(strftime(forecast_datetime, format = "%H"))
      month <- as.numeric(strftime(forecast_datetime, format = "%m"))

      season <- if (month >= 3 && month <= 5) {
        "SPRING"
      } else if (month >= 6 && month <= 8) {
        "SUMMER"
      } else if (month >= 9 && month <= 11) {
        "AUTUMN"
      } else {
        "WINTER"
      }

      # Rain and snow only appear in the response when non-zero
      rain_val <- ifelse(is.null(result$rain[["3h"]]), 0, result$rain[["3h"]])
      snow_val <- ifelse(is.null(result$snow[["3h"]]), 0, result$snow[["3h"]])

      weather_label <- paste0(
        "<b>", city_name, "</b><br/>",
        "<b>", result$weather[[1]]$main, "</b>"
      )

      weather_detail_label <- paste0(
        "<b>", city_name, "</b><br/>",
        "<b>", result$weather[[1]]$main, "</b><br/>",
        "Temperature: ", round(result$main$temp, 1), " °C<br/>",
        "Humidity: ", result$main$humidity, "%<br/>",
        "Wind Speed: ", result$wind$speed, " m/s<br/>",
        "Visibility: ", ifelse(is.null(result$visibility), "N/A", result$visibility), " m<br/>",
        "Rainfall: ", rain_val, " mm<br/>",
        "Snowfall: ", snow_val, " mm<br/>",
        "Datetime: ", forecast_datetime
      )

      city            <- c(city,            city_name)
      weather         <- c(weather,         result$weather[[1]]$main)
      temperature     <- c(temperature,     result$main$temp)
      visibility      <- c(visibility,      ifelse(is.null(result$visibility), NA, result$visibility))
      humidity        <- c(humidity,        result$main$humidity)
      wind_speed      <- c(wind_speed,      result$wind$speed)
      dew_point       <- c(dew_point,       0)  # Not available on free API tier
      solar_radiation <- c(solar_radiation, 0)  # Not available on free API tier
      rainfall        <- c(rainfall,        rain_val)
      snowfall        <- c(snowfall,        snow_val)
      seasons         <- c(seasons,         season)
      hours           <- c(hours,           hour)
      forecast_date   <- c(forecast_date,   forecast_datetime)
      weather_labels        <- c(weather_labels,        weather_label)
      weather_detail_labels <- c(weather_detail_labels, weather_detail_label)
    }
  }

  tibble(
    CITY_ASCII            = city,
    WEATHER               = weather,
    TEMPERATURE           = temperature,
    VISIBILITY            = visibility,
    HUMIDITY              = humidity,
    WIND_SPEED            = wind_speed,
    DEW_POINT_TEMPERATURE = dew_point,
    SOLAR_RADIATION       = solar_radiation,
    RAINFALL              = rainfall,
    SNOWFALL              = snowfall,
    SEASONS               = seasons,
    HOURS                 = hours,
    FORECASTDATETIME      = forecast_date,
    LABEL                 = weather_labels,
    DETAILED_LABEL        = weather_detail_labels
  )
}

# Load model coefficients from CSV
load_saved_model <- function(model_name) {
  model <- read_csv(model_name, show_col_types = FALSE)
  model <- model %>% mutate(Variable = gsub('"', '', Variable))
  setNames(model$Coef, as.list(model$Variable))
}

# Apply model coefficients to weather data to predict bike demand
predict_bike_demand <- function(TEMPERATURE, HUMIDITY, WIND_SPEED, VISIBILITY,
                                DEW_POINT_TEMPERATURE, SOLAR_RADIATION,
                                RAINFALL, SNOWFALL, SEASONS, HOURS) {
  model <- load_saved_model("model.csv")

  weather_terms <- model["Intercept"] +
    TEMPERATURE           * model["TEMPERATURE"] +
    HUMIDITY              * model["HUMIDITY"] +
    WIND_SPEED            * model["WIND_SPEED"] +
    VISIBILITY            * model["VISIBILITY"] +
    DEW_POINT_TEMPERATURE * model["DEW_POINT_TEMPERATURE"] +
    SOLAR_RADIATION       * model["SOLAR_RADIATION"] +
    RAINFALL              * model["RAINFALL"] +
    SNOWFALL              * model["SNOWFALL"]

  season_terms <- sapply(SEASONS, function(season) model[season])

  # Hours stored as HOUR_0, HOUR_1, etc. in model.csv
  hour_terms <- sapply(HOURS, function(hour) {
    key <- paste0("HOUR_", hour)
    val <- model[key]
    if (is.null(val) || is.na(val)) 0 else val
  })

  predictions <- pmax(0, weather_terms + season_terms + hour_terms)
  as.integer(predictions)
}

# Assign demand level labels based on prediction magnitude
calculate_bike_prediction_level <- function(predictions) {
  sapply(predictions, function(p) {
    if (is.na(p))   return("small")
    if (p <= 1000)  return("small")
    if (p <= 3000)  return("medium")
    return("large")
  })
}

# Main function: fetch weather, predict demand, join city coordinates
generate_city_weather_bike_data <- function() {
  cities_df  <- read_csv("selected_cities.csv", show_col_types = FALSE)
  weather_df <- get_weather_forecaset_by_cities(cities_df$CITY_ASCII)

  weather_df %>%
    mutate(
      BIKE_PREDICTION = predict_bike_demand(
        TEMPERATURE, HUMIDITY, WIND_SPEED, VISIBILITY,
        DEW_POINT_TEMPERATURE, SOLAR_RADIATION,
        RAINFALL, SNOWFALL, SEASONS, HOURS
      ),
      BIKE_PREDICTION_LEVEL = calculate_bike_prediction_level(BIKE_PREDICTION)
    ) %>%
    left_join(cities_df, by = "CITY_ASCII")
}

# Test function to verify data generation
test_weather_data_generation <- function() {
  city_weather_bike_df <- generate_city_weather_bike_data()
  stopifnot(nrow(city_weather_bike_df) > 0)
  print(city_weather_bike_df)
  return(city_weather_bike_df)
}


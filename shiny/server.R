# Server-side reactive logic and plot theming developed with Claude (Anthropic)
# https://claude.ai


require(shiny)
require(ggplot2)
require(leaflet)
require(tidyverse)
require(httr)
require(scales)

source("model_prediction.R")

# ── Theme ──────────────────────────────────────────────────────────────────────
bg_dark    <- "#0a0c12"
bg_panel   <- "#0f1117"
border_col <- "#2a2d3e"
text_muted <- "#7b7f96"
accent     <- "#4f6ef7"

# Residual standard error from raw model
model_rse <- 377.9

plot_theme <- theme_minimal(base_family = "sans") +
  theme(
    plot.background  = element_rect(fill = bg_dark, color = NA),
    panel.background = element_rect(fill = bg_dark, color = NA),
    panel.grid.major = element_line(color = border_col, size = 0.3),
    panel.grid.minor = element_blank(),
    axis.text        = element_text(color = text_muted, size = 7),
    axis.title       = element_text(color = text_muted, size = 8),
    plot.title       = element_blank(),
    plot.margin      = margin(6, 10, 6, 10)
  )

# ── Server ─────────────────────────────────────────────────────────────────────
shinyServer(function(input, output) {

  color_levels <- colorFactor(
    c("#34c97a", "#f5c842", "#f25c5c"),
    levels = c("small", "medium", "large")
  )

  # Load weather + prediction data
  city_weather_bike_df <- reactive({
    generate_city_weather_bike_data()
  })

  # Max prediction per city
  cities_max_bike <- reactive({
    req(city_weather_bike_df())
    city_weather_bike_df() %>%
      group_by(CITY_ASCII, LAT, LNG) %>%
      summarise(
        BIKE_PREDICTION       = max(BIKE_PREDICTION, na.rm = TRUE),
        BIKE_PREDICTION_LEVEL = BIKE_PREDICTION_LEVEL[which.max(BIKE_PREDICTION)],
        LABEL                 = LABEL[which.max(BIKE_PREDICTION)],
        DETAILED_LABEL        = DETAILED_LABEL[which.max(BIKE_PREDICTION)],
        .groups = "drop"
      )
  })

  # Load static correlation data
  cor_df <- read_csv("weather_demand_correlations.csv", show_col_types = FALSE)

  # ── Timestamp ─────────────────────────────────────────────────────────────────
  output$fetch_timestamp <- renderText({
    city_weather_bike_df()
    format(Sys.time(), "%d %b %Y %H:%M UTC")
  })

  # ── Initial map ───────────────────────────────────────────────────────────────
  output$city_bike_map <- renderLeaflet({
    df <- cities_max_bike()
    req(nrow(df) > 0)

    radius_map <- c(small = 6, medium = 10, large = 14)
    radii <- unname(radius_map[df$BIKE_PREDICTION_LEVEL])

    leaflet(df) %>%
      addProviderTiles(providers$CartoDB.DarkMatter) %>%
      addProviderTiles(providers$CartoDB.PositronOnlyLabels) %>%
      setView(lng = 118, lat = 33, zoom = 4) %>%
      addCircleMarkers(
        lng         = ~LNG,
        lat         = ~LAT,
        radius      = radii,
        color       = ~color_levels(BIKE_PREDICTION_LEVEL),
        fillColor   = ~color_levels(BIKE_PREDICTION_LEVEL),
        fillOpacity = 0.85,
        stroke      = TRUE,
        weight      = 1.5,
        opacity     = 1,
        popup       = ~LABEL
      ) %>%
      addLegend(
        position = "bottomright",
        colors   = c("#34c97a", "#f0b429", "#e07b54"),
        labels   = c("Small demand", "Medium demand", "Large demand"),
        title    = "Max 5-day prediction",
        opacity  = 0.9,
        className = "small-legend"
      )
  })

  # ── Regional bar chart ────────────────────────────────────────────────────────
  output$city_demand_bar <- renderPlot({
    df <- cities_max_bike()
    req(nrow(df) > 0)

    ggplot(df, aes(x = reorder(CITY_ASCII, BIKE_PREDICTION),
                   y = BIKE_PREDICTION,
                   fill = BIKE_PREDICTION_LEVEL)) +
      geom_bar(stat = "identity", width = 0.7, alpha = 0.7) +
      scale_fill_manual(
        values = c(small = "#34c97a", medium = "#f0b429", large = "#e07b54"),
        guide  = "none"
      ) +
      geom_text(
        aes(label = BIKE_PREDICTION),
        hjust  = -0.2,
        color  = text_muted,
        size   = 2.5
      ) +
      coord_flip() +
      scale_y_continuous(expand = expansion(mult = c(0, 0.2))) +
      labs(x = NULL, y = "Max predicted rentals") +
      plot_theme
  }, bg = bg_dark)

  # ── Correlation heatmap ───────────────────────────────────────────────────────
  output$correlation_heatmap <- renderPlot({
    df <- cor_df %>%
      mutate(
        variable = str_replace_all(variable, "_", " "),
        variable = str_to_title(variable),
        label    = round(RENTED_BIKE_COUNT, 2),
        bar_col  = ifelse(RENTED_BIKE_COUNT >= 0, "#34c97a", "#f25c5c")
      ) %>%
      arrange(RENTED_BIKE_COUNT)

    ggplot(df, aes(x = reorder(variable, RENTED_BIKE_COUNT),
                   y = RENTED_BIKE_COUNT,
                   fill = RENTED_BIKE_COUNT)) +
      geom_bar(stat = "identity", width = 0.7) +
      geom_text(
        aes(label = label,
            hjust = ifelse(RENTED_BIKE_COUNT >= 0, -0.2, 1.2)),
        color = text_muted,
        size  = 2.5
      ) +
      scale_fill_gradient2(
        low      = "#f25c5c",
        mid      = border_col,
        high     = "#34c97a",
        midpoint = 0,
        guide    = "none"
      ) +
      geom_hline(yintercept = 0, color = border_col, size = 0.4) +
      coord_flip() +
      scale_y_continuous(
        limits = c(-0.35, 0.75),
        expand = expansion(mult = c(0.1, 0.15))
      ) +
      labs(x = NULL, y = "Correlation with demand") +
      plot_theme
  }, bg = bg_dark)

  # ── Map update on dropdown ────────────────────────────────────────────────────
  observeEvent(input$city_dropdown, {
    if (input$city_dropdown == "All") {
      df <- cities_max_bike()
      req(nrow(df) > 0)

      radius_map <- c(small = 6, medium = 10, large = 14)
      radii <- unname(radius_map[df$BIKE_PREDICTION_LEVEL])

      leafletProxy("city_bike_map", data = df) %>%
        clearMarkers() %>%
        clearControls() %>%
        setView(lng = 118, lat = 33, zoom = 4) %>%
        addCircleMarkers(
          lng         = ~LNG,
          lat         = ~LAT,
          radius      = radii,
          color       = ~color_levels(BIKE_PREDICTION_LEVEL),
          fillColor   = ~color_levels(BIKE_PREDICTION_LEVEL),
          fillOpacity = 0.85,
          stroke      = TRUE,
          weight      = 1.5,
          opacity     = 1,
          popup       = ~LABEL
        ) %>%
        addLegend(
          position = "bottomright",
          colors   = c("#34c97a", "#f0b429", "#e07b54"),
          labels   = c("Small demand", "Medium demand", "Large demand"),
          title    = "Max 5-day prediction",
          opacity  = 0.9,
          className = "small-legend"
        )
    }
  })

  # ── City drill-down ───────────────────────────────────────────────────────────
  observeEvent(input$city_dropdown, {
    req(input$city_dropdown != "All")

    df <- cities_max_bike() %>%
      filter(CITY_ASCII == input$city_dropdown)
    req(nrow(df) > 0)

    leafletProxy("city_bike_map", data = df) %>%
      clearMarkers() %>%
      clearControls() %>%
      setView(lng = df$LNG, lat = df$LAT, zoom = 11) %>%
      addMarkers(
        lng   = ~LNG,
        lat   = ~LAT,
        popup = ~DETAILED_LABEL
      )

    city_df <- city_weather_bike_df() %>%
      filter(CITY_ASCII == input$city_dropdown) %>%
      mutate(
        FORECASTDATETIME = as.POSIXct(FORECASTDATETIME),
        PRED_UPPER       = BIKE_PREDICTION + 1.96 * model_rse,
        PRED_LOWER       = pmax(0, BIKE_PREDICTION - 1.96 * model_rse)
      )

    # Temperature trend
    output$temp_line <- renderPlot({
      ggplot(city_df, aes(x = FORECASTDATETIME, y = TEMPERATURE)) +
        geom_line(color = "#4f6ef7", size = 0.8) +
        geom_point(color = "#4f6ef7", size = 1.6) +
        geom_text(
          aes(label = round(TEMPERATURE, 1)),
          color = text_muted, size = 2.3, vjust = -1
        ) +
        scale_x_datetime(date_labels = "%d %b", date_breaks = "1 day") +
        labs(x = NULL, y = "°C") +
        plot_theme
    }, bg = bg_dark)

    # Bike demand trend with confidence interval
    output$bike_line <- renderPlot({
      ggplot(city_df, aes(x = FORECASTDATETIME)) +
        geom_ribbon(
          aes(ymin = PRED_LOWER, ymax = PRED_UPPER),
          fill = "#34c97a", alpha = 0.12
        ) +
        geom_line(aes(y = BIKE_PREDICTION), color = "#34c97a", size = 0.8) +
        geom_point(aes(y = BIKE_PREDICTION), color = "#34c97a", size = 1.6) +
        geom_text(
          aes(y = BIKE_PREDICTION, label = BIKE_PREDICTION),
          color = text_muted, size = 2.3, vjust = -1
        ) +
        scale_x_datetime(date_labels = "%d %b", date_breaks = "1 day") +
        labs(x = NULL, y = "Predicted rentals") +
        plot_theme
    }, bg = bg_dark)

    # Click output
    output$bike_date_output <- renderText({
      click <- input$plot_click
      if (is.null(click)) return("Click a point on the trend to see details")
      clicked_time <- as.POSIXct(click$x, origin = "1970-01-01")
      paste0(
        "Datetime: ", format(clicked_time, "%d %b %Y %H:%M"),
        "  |  Predicted demand: ", round(click$y, 0), " bikes"
      )
    })

    # Humidity vs demand
    output$humidity_pred_chart <- renderPlot({
      ggplot(city_df, aes(x = HUMIDITY, y = BIKE_PREDICTION)) +
        geom_point(color = "#34c97a", alpha = 0.7, size = 1.6) +
        geom_smooth(
          method  = "lm",
          formula = y ~ poly(x, 4),
          color   = accent,
          se      = TRUE,
          fill    = paste0(accent, "33"),
          size    = 0.8
        ) +
        labs(x = "Humidity (%)", y = "Predicted rentals") +
        plot_theme
    }, bg = bg_dark)
  })
})


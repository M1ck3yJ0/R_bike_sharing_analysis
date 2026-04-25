# Dashboard UI layout and CSS architecture developed with Claude (Anthropic)
# https://claude.ai

require(leaflet)
require(shiny)

shinyUI(
  fluidPage(
    tags$head(
      tags$style(HTML("
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600&family=DM+Mono:wght@400;500&display=swap');

        * { font-family: 'DM Sans', sans-serif; box-sizing: border-box; }
        
        .small-legend {
          font-size: 9px !important;
          line-height: 1.3 !important;
          padding: 4px 8px !important;
        }
        
        .small-legend .legend-title {
          font-size: 9px !important;
          margin-bottom: 3px !important;
        }
        
        .small-legend i {
          display: inline-block !important;
          width: 10px !important;
          height: 10px !important;
          margin-right: 4px !important;
          vertical-align: middle !important;
          border-radius: 50% !important;
          opacity: 0.95 !important;
          border: 1px solid rgba(255,255,255,0.15) !important;
        }
        
        html, body {
          background-color: #0a0c12;
          color: #e8eaf0;
          margin: 0;
          padding: 0;
          overflow: hidden;
        }

        .container-fluid { padding: 0 !important; }

        /* ── Title bar ── */
        .title-bar {
          background: linear-gradient(135deg, #0f1117 0%, #1a1d2e 100%);
          border-bottom: 1px solid #2a2d3e;
          padding: 14px 14px;
          display: flex;
          justify-content: space-between;
          align-items: center;
          height: 68px;
          width: 100%;
        }

        .title-bar h1 {
          font-size: 19px;
          font-weight: 600;
          color: #ffffff;
          letter-spacing: -0.3px;
          margin: 0 0 2px 0;
        }

        .title-bar p {
          font-size: 11px;
          color: #7b7f96;
          margin: 0;
          font-weight: 300;
        }

        .timestamp-label {
          font-size: 9px;
          font-weight: 600;
          letter-spacing: 1.2px;
          text-transform: uppercase;
          color: #4a5080;
          margin-bottom: 2px;
          text-align: right;
        }

        .timestamp-value {
          font-family: 'DM Mono', monospace;
          font-size: 11px;
          color: #7b7f96;
          text-align: right;
        }

        /* ── Outer wrapper ── */
        .outer-wrapper {
          display: flex;
          flex-direction: row;
          width: 100vw;
          height: calc(100vh - 68px);
          padding: 10px 10px 0 10px;
          gap: 10px;
          overflow: hidden;
        }

        /* ── Left column ── */
        .left-column {
          flex: 1;
          min-width: 50%;
          display: flex;
          flex-direction: column;
          gap: 1px;
          overflow: hidden;
        }

        /* ── Right column: relative so scroll wrapper can be absolute ── */
        .right-column {
          width: 40%;
          min-width: 320px;
          max-width: 420px;
          position: relative;
          flex-shrink: 0;
        }

        /* ── Scroll wrapper fills right column exactly ── */
        .right-scroll {
          position: absolute;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          overflow-y: auto;
          padding-bottom: 5px;
        }

        .right-scroll::-webkit-scrollbar { width: 3px; }
        .right-scroll::-webkit-scrollbar-track { background: transparent; }
        .right-scroll::-webkit-scrollbar-thumb { background: #2a2d3e; border-radius: 2px; }

        /* ── Panels ── */
        .panel {
          background: #0f1117;
          border: 1px solid #2a2d3e;
          border-radius: 10px;
          overflow: hidden;
          display: flex;
          flex-direction: column;
        }

        .panel-header {
          font-size: 9px;
          font-weight: 600;
          letter-spacing: 1.5px;
          text-transform: uppercase;
          color: #4a5080;
          padding: 10px 14px 8px 14px;
          border-bottom: 1px solid #2a2d3e;
          flex-shrink: 0;
        }

        /* ── Map panel ── */
        .map-panel {
          flex: 1;
          min-height: 0;
        }

        .map-panel .panel-body {
          flex: 1;
          min-height: 0;
          position: relative;
        }

        .map-panel .leaflet-container {
          position: absolute !important;
          top: 0; left: 0; right: 0; bottom: 0;
        }

        /* ── Regional panel ── */
        .regional-panel {
          height: 240px;
          flex-shrink: 0;
          margin-bottom: 5px;
        }

        .regional-charts {
          display: flex;
          flex-direction: row;
          height: 195px;
        }

        .regional-chart-item {
          flex: 1;
          padding: 6px 10px;
          border-right: 1px solid #2a2d3e;
          overflow: hidden;
        }

        .regional-chart-item:last-child { border-right: none; }

        .regional-chart-label {
          font-size: 9px;
          font-weight: 600;
          letter-spacing: 1.2px;
          text-transform: uppercase;
          color: #4a5080;
          margin-bottom: 4px;
        }

        /* ── City panel (right column inner) ── */
        .city-inner {
          background: #0f1117;
          border: 1px solid #2a2d3e;
          border-radius: 10px;
          padding: 6px 6px 0 12px;
          min-height: 100%;
        }

        .section-label {
          font-size: 9px;
          font-weight: 600;
          letter-spacing: 1.5px;
          text-transform: uppercase;
          color: #4a5080;
          margin-bottom: 5px;
          margin-top: 14px;
        }

        .section-label:first-child { margin-top: 0; }

        .selectize-input {
          background-color: #0a0c12 !important;
          border: 1px solid #2a2d3e !important;
          border-radius: 6px !important;
          color: #e8eaf0 !important;
          font-size: 12px !important;
          padding: 1px 10px !important;
          min-height: 22px !important;
          box-shadow: none !important;
        }

        .selectize-input.focus {
          border-color: #4f6ef7 !important;
          box-shadow: 0 0 0 3px rgba(79,110,247,0.15) !important;
        }

        .selectize-dropdown {
          background-color: #1a1d2e !important;
          border: 1px solid #2a2d3e !important;
          border-radius: 6px !important;
          color: #e8eaf0 !important;
          font-size: 12px !important;
        }

        .selectize-dropdown-content .option:hover,
        .selectize-dropdown-content .option.active {
          background-color: #2a2d3e !important;
          color: #ffffff !important;
        }

        .chart-box {
          background: #0a0c12;
          border: 1px solid #2a2d3e;
          border-radius: 8px;
          padding: 4px;
          margin-bottom: 8px;
        }
        
        .chart-box .shiny-plot-output {
          height: 100% !important;
        }
        
        .temp-box {
          height: clamp(150px, 22vh, 260px);
        }
        
        .bike-box {
          height: clamp(170px, 26vh, 320px);
        }
        
        .humidity-box {
          height: clamp(160px, 22vh, 260px);
        }

        .click-output {
          font-family: 'DM Mono', monospace;
          font-size: 10px;
          color: #7b7f96;
          background: #0a0c12;
          border: 1px solid #2a2d3e;
          border-radius: 6px;
          padding: 6px 10px;
          margin-bottom: 8px;
          min-height: 26px;
        }

        .ci-note {
          font-size: 10px;
          color: #4a5080;
          margin-bottom: 8px;
          line-height: 1.5;
        }

        pre {
          background-color: transparent !important;
          border: none !important;
          color: #7b7f96;
          font-family: 'DM Mono', monospace;
          font-size: 10px;
          margin: 0;
          padding: 0;
        }
      "))
    ),

    # ── Title bar ────────────────────────────────────────────────────────────────
    div(class = "title-bar",
      div(
        h1("East Asia Bike Sharing Demand Forecast"),
        p("5-day demand predictions across 10 cities, powered by weather forecasts and a regression model trained on Seoul data")
      ),
      div(
        div(class = "timestamp-label", "Forecast fetched"),
        div(class = "timestamp-value", textOutput("fetch_timestamp", inline = TRUE))
      )
    ),

    # ── Outer wrapper ─────────────────────────────────────────────────────────────
    div(class = "outer-wrapper",

      # ── Left column ───────────────────────────────────────────────────────────
      div(class = "left-column",

        # Map panel
        div(class = "panel map-panel",
          div(class = "panel-header", "Regional Map"),
          div(class = "panel-body",
            leafletOutput("city_bike_map", width = "100%", height = "100%")
          )
        ),

        # Regional charts panel
        div(class = "panel regional-panel",
          div(class = "panel-header", "Regional Overview"),
          div(class = "regional-charts",
            div(class = "regional-chart-item",
              div(class = "regional-chart-label", "Max Predicted Demand by City"),
              plotOutput("city_demand_bar", height = "175px")
            ),
            div(class = "regional-chart-item",
              div(class = "regional-chart-label", "Weather-Demand Correlations — Seoul training data"),
              plotOutput("correlation_heatmap", height = "175px")
            )
          )
        )
      ),

      # ── Right column ──────────────────────────────────────────────────────────
      div(class = "right-column",
        div(class = "right-scroll",
          div(class = "city-inner",

            div(class = "section-label", "Select City"),
            selectInput(
              inputId  = "city_dropdown",
              label    = NULL,
              choices  = c("All", "Seoul", "Tokyo", "Shanghai", "Beijing",
                           "Hangzhou", "Shenzhen", "Osaka", "Chengdu",
                           "Hong Kong", "Taipei"),
              selected = "All"
            ),

            div(class = "section-label", "Temperature Trend"),
            div(class = "chart-box temp-box",
                plotOutput("temp_line", height = "100%")
            ),
            
            div(class = "section-label", "Predicted Bike Demand"),
            div(class = "chart-box bike-box",
                plotOutput("bike_line", height = "100%", click = "plot_click")
            ),
            
            div(class = "click-output",
                verbatimTextOutput("bike_date_output")
            ),
            
            div(class = "ci-note",
                "95% confidence interval shown. Width reflects model uncertainty when applying Seoul-trained coefficients to other cities."
            ),
            
            div(class = "section-label", "Humidity vs Demand"),
            div(class = "chart-box humidity-box",
                plotOutput("humidity_pred_chart", height = "100%")
            )
          )
        )
      )
    )
  )
)


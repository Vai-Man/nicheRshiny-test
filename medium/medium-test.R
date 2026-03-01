library(shiny)
library(terra)
library(geodata)

ui <- fluidPage(
  titlePanel("BIO1 Workflow – South America"),
  sidebarLayout(
    sidebarPanel(
      actionButton("run_workflow", "Run Workflow", class = "btn-primary btn-lg", width = "100%"),
      hr(),
      p("Note: Initial run downloads data and may take 1-2 minutes. Subsequent runs are instant.", style = "font-size: 12px; color: #666;")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("BIO1 Global", plotOutput("plot_global", height = "500px")),
        tabPanel("BIO1 Cropped", plotOutput("plot_cropped", height = "500px")),
        tabPanel("BIO1 Masked", plotOutput("plot_masked", height = "500px")),
        tabPanel("Stats", verbatimTextOutput("stats_output"))
      )
    )
  )
)

server <- function(input, output, session) {
  
  cached_data <- reactiveVal(NULL)
  
  workflow_data <- eventReactive(input$run_workflow, {
    
    if (!is.null(cached_data())) {
      return(cached_data())
    }
    
    withProgress(message = "Running workflow...", value = 0, {
      
      local_cache <- file.path(getwd(), "geodata_cache")
      cache_path <- ifelse(dir.exists(local_cache), local_cache, 
                           tools::R_user_dir("geodata", which = "cache"))
      dir.create(cache_path, showWarnings = FALSE, recursive = TRUE)
      
      incProgress(0.15, detail = "Step 1: Downloading WorldClim")
      bio_stack <- geodata::worldclim_global(var = "bio", res = 10, path = cache_path)
      bio1_global <- bio_stack[[1]]
      
      incProgress(0.2, detail = "Step 2: Cropping extent")
      sa_bbox <- ext(-85, -30, -60, 15)
      bio1_cropped <- crop(bio1_global, sa_bbox)
      
      incProgress(0.3, detail = "Step 3: Loading boundaries")
      sa_continent_file <- file.path(cache_path, "south_america_continent.rds")
      
      if (file.exists(sa_continent_file)) {
        sa_polygons <- readRDS(sa_continent_file)
      } else {
        sa_countries <- c("ARG","BOL","BRA","CHL","COL","ECU","GUF","GUY","PRY","PER","SUR","URY","VEN")
        polys_list <- lapply(sa_countries, function(code) {
          geodata::gadm(code, level = 0, path = cache_path)
        })
        sa_polygons <- aggregate(do.call(rbind, polys_list))
        saveRDS(sa_polygons, sa_continent_file)
      }
      
      incProgress(0.7, detail = "Step 4: CRS alignment")
      if (!same.crs(bio1_cropped, sa_polygons)) {
        sa_polygons <- project(sa_polygons, crs(bio1_cropped))
      }
      
      incProgress(0.85, detail = "Step 5: Masking")
      bio1_masked <- mask(bio1_cropped, sa_polygons)
      
      incProgress(0.95, detail = "Step 6: Statistics")
      stats <- global(bio1_masked, fun = c("min","max","mean","sd"), na.rm = TRUE)
      
      result <- list(
        bio1_global = bio1_global,
        bio1_cropped = bio1_cropped,
        bio1_masked = bio1_masked,
        stats = stats
      )
      
      cached_data(result)
      result
    })
  })
  
  output$plot_global <- renderPlot({
    req(workflow_data())
    plot(workflow_data()$bio1_global, main = "BIO1 – Global")
  })
  
  output$plot_cropped <- renderPlot({
    req(workflow_data())
    plot(workflow_data()$bio1_cropped, main = "BIO1 – Cropped")
  })
  
  output$plot_masked <- renderPlot({
    req(workflow_data())
    plot(workflow_data()$bio1_masked, main = "BIO1 – Masked")
  })
  
  output$stats_output <- renderPrint({
    req(workflow_data())
    print(workflow_data()$stats)
  })
}

shinyApp(ui = ui, server = server)

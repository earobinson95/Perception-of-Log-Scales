library(shiny)
# library(shinysense)
library(r2d3)
library(tidyverse)
library(gridSVG)
# library(plotly)


# Redefine drawr function
drawr <- function(data, linear = "true", draw_start = mean(data$x),
          title = "", x_range = NULL, y_range = NULL,
          x_lab = "", y_lab = "", drawn_line_color = "orangered",
          data_line_color = "steelblue", x_axis_buffer = 0.01, y_axis_buffer = 0.05,
          # show_finished = F,
          shiny_message_loc = NULL) {
    plot_data <- dplyr::select(data, x, y)
    x_min <- min(plot_data$x)
    x_max <- max(plot_data$x)
    y_min <- min(plot_data$y)
    y_max <- max(plot_data$y)
    if (is.null(x_range)) {
        x_buffer <- (x_max - x_min) * x_axis_buffer
        x_range <- c(x_min - x_buffer, x_max + x_buffer)
    }
    if (is.null(y_range)) {
        y_buffer <- (y_max - y_min) * y_axis_buffer
        y_range <- c(y_min - y_buffer, y_max + y_buffer)
        if (linear != "true") {
            if (y_range[1] <= 0) {
                y_range[1] <- min(y_min, y_axis_buffer)
            }
        }
    } else {
        if (y_range[1] > y_min | y_range[2] < y_max) {
            stop("Supplied y range doesn't cover data fully.")
        }
    }

    if ((draw_start <= x_min) | (draw_start >= x_max)) {
        stop("Draw start is out of data range.")
    }

    r2d3::r2d3(plot_data, "main.js",
               dependencies = c("d3-jetpack"),
               options = list(draw_start = draw_start, linear = as.character(linear),
                              pin_start = T, x_range = x_range, y_range = y_range,
                              line_style = NULL,
                              data_line_color = data_line_color, drawn_line_color = drawn_line_color,
                              free_draw = F, shiny_message_loc = shiny_message_loc))
}


# Define UI for application that draws a histogram
ui <- navbarPage(
    "Testing Graphics",
    tabPanel(
        title = "You Draw It",
        # icon = "pencil-alt",
        tags$head(
            tags$link(rel = "stylesheet", type = "text/css", href = "d3.css")
        ),
        fluidRow(
            column(
                width = 9,
                d3Output("shinydrawr")
            ),
            column(
                width = 3,
                checkboxInput("drawr_linear_axis", "Linear Y Axis?", value = T),
                hr(),
                tableOutput("drawrmessage")
            )
        )
    ),
    tabPanel(
        title = "Lineup",
        fluidRow(
            column(
                width = 6, offset = 2,
                div(style="text-align:center;display:inline-block;",
                    plotOutput("lineup", width = "800px", height = "600px"))
            ),
            column(
                width = 4,
                checkboxInput("lineup_linear_axis", "Linear Y Axis?", value = T),
                h3("Selected Plot"),
                selectInput("lineup_panel", "Most Different Panel(s)", choices = 1:20, multiple = T),
                textInput(inputId = "lineup_reason", "Why did you choose the plot?")
            )
        )
    ),
    tabPanel(
        title = "Estimation"#,
        # icon = "ruler-combined"
    ),
    includeScript("www/js/action.js")
)

# Define server logic required to draw a histogram
server <- function(input, output, session) {
    # ---- Tab 1 ---------------------------------------------------------------
    data_tab1 <- tibble(x = 1:30, y = exp((x-15)/5))

    y_range <- range(data_tab1$y) * c(.7, 1.1)

    draw_start <- 20

    message_loc <- session$ns("drawr_message")
    drawn_data <- shiny::reactiveVal()

    output$shinydrawr <- r2d3::renderD3({
        islinear <- ifelse(input$drawr_linear_axis, "true", "false")
        # Use redef'd drawr function
        drawr(data = data_tab1,
              linear = islinear,
              draw_start = draw_start,
              shiny_message_loc = message_loc,
              x_range = range(data_tab1$x), y_range = y_range,
              drawn_line_color = "skyblue", data_line_color = "blue")
    })

    shiny::observeEvent(input$drawr_linear_axis, {
        drawn_data(NULL)
    })

    shiny::observeEvent(input$drawr_message, {
        data_tab1 %>%
            dplyr::filter(x >= draw_start) %>%
            dplyr::mutate(drawn = input$drawr_message) %>%
            drawn_data()
    })

    output$drawrmessage <- renderTable({
        drawn_data()
    })

    # ---- Tab 2 ---------------------------------------------------------------


    data_tab2 <- reactive({
        input$lineup_submit
        gen_exp_data <- function(coef, n = 30) {
            tibble(
                x = seq(-15, 15, length.out = n),
                y = coef * x,
                err = rnorm(n, 1, .25)
            )
        }

        tibble(c1 = rnorm(20, 1, .05),
                 c2 = c(1.3, rep(1, 19)),
                 .id = 1:20,
                 pos = sample(.id, 20)) %>%
        pivot_longer(cols = c("c1", "c2"), names_to = "group", values_to = "coef") %>%
        mutate(data = map(coef, gen_exp_data)) %>%
        unnest(data) %>%
        group_by(.id) %>%
        # Scaling is done by plot, not by group within plot
        mutate(yfix = exp((y - mean(y))/sd(y)) + err) %>%
        ungroup()
    })

    output$lineup <- renderPlot({
        df <- data_tab2()
        lineup_plot <- ggplot(df, aes(x = x, y = yfix, color = group)) +
            geom_point() +
            facet_wrap(~pos, ncol = 5) +
            scale_color_discrete(guide = F) +
            theme(axis.text = element_blank(), axis.title = element_blank())

        if (!input$lineup_linear_axis)  lineup_plot <- lineup_plot + scale_y_log10()

        lineup_plot
    })

}

# Run the application
shinyApp(ui = ui, server = server)

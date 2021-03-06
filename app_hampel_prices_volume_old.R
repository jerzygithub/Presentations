##############################
# This is a shiny app for simulating a contrarian strategy 
# using the Hampel filter over prices and trading volume.
# This version doesn't work as well as the one only over prices.
# 
# Just press the "Run App" button on upper right of this panel.
##############################

## Below is the setup code that runs once when the shiny app is started

# Load R packages
library(HighFreq)
library(shiny)
library(dygraphs)

# Model and data setup

## VTI ETF daily bars
# sym_bol <- "VTI"
# clos_e <- log(Cl(rutils::etf_env$VTI))

## SPY ETF minute bars - works really well !!!
sym_bol <- "SPY"
oh_lc <- HighFreq::SPY["2011"]["T09:31:00/T15:59:00"]
n_rows <- NROW(oh_lc)
clos_e <- log(Cl(oh_lc))
vol_ume <- Vo(oh_lc)


## Load QM futures 5-second bars
# sym_bol <- "ES"  # S&P500 Emini futures
# sym_bol <- "QM"  # oil
# load(file=paste0("C:/Develop/data/ib_data/", sym_bol, "_ohlc.RData"))
# clos_e <- log(Cl(oh_lc))
# Or random prices
# clos_e <- xts(cumsum(rnorm(n_rows)), index(oh_lc))

## Load combined futures data
# com_bo <- HighFreq::SPY
# load(file="C:/Develop/data/combined.RData")
# sym_bol <- "UX1"
# symbol_s <- unique(rutils::get_name(colnames(com_bo)))
# clos_e <- log(na.omit(com_bo[, "UX1.Close"]))
# TU1: look_back=14, thresh_old=2.0, lagg=1
# TU1: look_back=30, thresh_old=9.2, lagg=1


## Load VX futures daily bars
# sym_bol <- "VX"
# load(file="C:/Develop/data/vix_data/vix_cboe.RData")
# clos_e <- log(Cl(vix_env$chain_ed))

re_turns <- rutils::diff_it(clos_e)

cap_tion <- paste("Contrarian Strategy for", sym_bol, "Using the Hampel Filter Over Prices")

## End setup code


## Create elements of the user interface
inter_face <- shiny::fluidPage(
  titlePanel(cap_tion),
  
  fluidRow(
    # The Shiny App is recalculated when the actionButton is clicked and the re_calculate variable is updated
    column(width=12,
           h4("Click the button 'Recalculate the Model' to Recalculate the Shiny App."),
           actionButton("re_calculate", "Recalculate the Model"))
  ),  # end fluidRow
  
  # Create single row with two slider inputs
  fluidRow(
    # Input end points interval
    # column(width=2, selectInput("inter_val", label="End points Interval",
    #                             choices=c("days", "weeks", "months", "years"), selected="days")),
    # Input look-back interval
    column(width=2, sliderInput("look_back", label="Lookback", min=3, max=30, value=9, step=1)),
    # Input lag trade parameter
    column(width=2, sliderInput("lagg", label="lagg", min=1, max=5, value=2, step=1)),
    # Input threshold interval
    column(width=2, sliderInput("thresh_old", label="threshold", min=1.0, max=10.0, value=1.8, step=0.2))
    # Input the weight decay parameter
    # column(width=2, sliderInput("lamb_da", label="Weight decay:",
    #                             min=0.01, max=0.99, value=0.1, step=0.05)),
    # Input model weights type
    # column(width=2, selectInput("typ_e", label="Portfolio weights type",
    #                             choices=c("max_sharpe", "min_var", "min_varpca", "rank"), selected="rank")),
    # Input number of eigenvalues for regularized matrix inverse
    # column(width=2, sliderInput("max_eigen", "Number of eigenvalues", min=2, max=20, value=15, step=1)),
    # Input the shrinkage intensity
    # column(width=2, sliderInput("al_pha", label="Shrinkage intensity",
    #                             min=0.01, max=0.99, value=0.1, step=0.05)),
    # Input the percentile
    # column(width=2, sliderInput("percen_tile", label="percentile:", min=0.01, max=0.45, value=0.1, step=0.01)),
    # Input the strategy coefficient: co_eff=1 for momentum, and co_eff=-1 for contrarian
    # column(width=2, selectInput("co_eff", "Coefficient:", choices=c(-1, 1), selected=(-1))),
    # Input the bid-offer spread
    # column(width=2, numericInput("bid_offer", label="bid-offer:", value=0.001, step=0.001))
  ),  # end fluidRow
  
  # Create output plot panel
  mainPanel(dygraphs::dygraphOutput("dy_graph"), width=12)
  
)  # end fluidPage interface


## Define the server code
ser_ver <- function(input, output) {
  
  # Recalculate the data and rerun the model
  da_ta <- reactive({
    # Get model parameters from input argument
    look_back <- isolate(input$look_back)
    lagg <- isolate(input$lagg)
    # max_eigen <- isolate(input$max_eigen)
    thresh_old <- isolate(input$thresh_old)
    # look_lag <- isolate(input$look_lag
    # lamb_da <- isolate(input$lamb_da)
    # typ_e <- isolate(input$typ_e)
    # al_pha <- isolate(input$al_pha)
    # percen_tile <- isolate(input$percen_tile)
    # co_eff <- as.numeric(isolate(input$co_eff))
    # bid_offer <- isolate(input$bid_offer)
    # Model is recalculated when the re_calculate variable is updated
    input$re_calculate

    # look_back <- 11
    # half_window <- look_back %/% 2
    
    ## Rerun the model
    # Calculate z_scores for prices
    medi_an <- TTR::runMedian(clos_e, n=look_back)
    medi_an[1:look_back, ] <- 1
    ma_d <- TTR::runMAD(re_turns, n=look_back)
    ma_d[1:look_back, ] <- 1
    z_scores <- ifelse(ma_d != 0, (clos_e-medi_an)/ma_d, 0)
    z_scores[1:look_back, ] <- 0
    mad_zscores <- TTR::runMAD(z_scores, n=look_back)
    mad_zscores[1:look_back, ] <- 0
    z_scores <- ifelse(mad_zscores != 0, z_scores/mad_zscores, 0)

    # Calculate z_scores for volumes
    medi_an <- TTR::runMedian(vol_ume, n=look_back)
    medi_an[1:look_back, ] <- 1
    ma_d <- TTR::runMAD(rutils::diff_it(vol_ume), n=look_back)
    ma_d[1:look_back, ] <- 1
    v_scores <- ifelse(ma_d != 0, (vol_ume-medi_an)/ma_d, 0)
    v_scores[1:look_back, ] <- 0
    mad_zscores <- TTR::runMAD(v_scores, n=look_back)
    mad_zscores[1:look_back, ] <- 0
    v_scores <- ifelse(mad_zscores != 0, v_scores/mad_zscores, 0)
    
    # Plot histogram of z_scores
    # range(z_scores)
    # z_scores <- z_scores[z_scores > quantile(z_scores, 0.05)]
    # z_scores <- z_scores[z_scores < quantile(z_scores, 0.95)]
    # x11(width=6, height=5)
    # hist(z_scores, xlim=c(quantile(z_scores, 0.05), quantile(z_scores, 0.95)), breaks=50, main=paste("Z-scores for", "look_back =", look_back))
    
    # Determine dates when the z_scores have exceeded the thresh_old
    in_dic <- rep(0, n_rows)
    # in_dic[1] <- 0
    in_dic <- ifelse((z_scores > thresh_old) & (v_scores > thresh_old), -1, in_dic)
    in_dic <- ifelse((z_scores < (-thresh_old)) & (v_scores > thresh_old), 1, in_dic)
    # Calculate number of consecutive indicators in same direction.
    # This is designed to avoid trading on microstructure noise.
    # in_dic <- ifelse(in_dic == indic_lag, in_dic, in_dic)
    # indic_sum <- HighFreq::roll_vec(se_ries=in_dic, look_back=lagg)
    # indic_sum[1:lagg] <- 0
    
    # Calculate position_s and pnls from indic_sum.
    # position_s <- rep(NA_integer_, n_rows)
    # position_s[1] <- 0
    # thresh_old <- 3*mad(z_scores)
    # Flip position only if the indic_sum is at least equal to lagg.
    # Otherwise keep previous position.
    position_s <- rep(NA_integer_, n_rows)
    position_s[1] <- 0
    # position_s <- ifelse(indic_sum >= lagg, 1, position_s)
    # position_s <- ifelse(indic_sum <= (-lagg), -1, position_s)
    position_s <- ifelse(in_dic == 1, 1, position_s)
    position_s <- ifelse(in_dic == (-1), (-1), position_s)
    position_s <- zoo::na.locf(position_s, na.rm=FALSE)
    positions_lag <- rutils::lag_it(position_s, lagg=1)
    
    re_turns <- rutils::diff_it(clos_e)
    pnl_s <- cumsum(positions_lag*re_turns)
    pnl_s <- cbind(pnl_s, cumsum(re_turns))
    colnames(pnl_s) <- c("Strategy", "Index")
    # pnl_s[rutils::calc_endpoints(pnl_s, inter_val="minutes")]
    # pnl_s[rutils::calc_endpoints(pnl_s, inter_val="hours")]
    pnl_s
  })  # end reactive code
  
  # Return to the output argument a dygraph plot with two y-axes
  output$dy_graph <- dygraphs::renderDygraph({
    col_names <- colnames(da_ta())
    dygraphs::dygraph(da_ta(), main=cap_tion) %>%
      dyAxis("y", label=col_names[1], independentTicks=TRUE) %>%
      dyAxis("y2", label=col_names[2], independentTicks=TRUE) %>%
      dySeries(name=col_names[1], axis="y", label=col_names[1], strokeWidth=1, col="red") %>%
      dySeries(name=col_names[2], axis="y2", label=col_names[2], strokeWidth=1, col="blue")
  })  # end output plot
  
}  # end server code

## Return a Shiny app object
shiny::shinyApp(ui=inter_face, server=ser_ver)

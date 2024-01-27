## --------------------------- 04_SI_figure.R ---------------------------
## Supplementary figure describing ITN insecticide resistance smoothing and extrapolation options
##  1. historical_trend_plots
##  2. timetrends_smooth
##     a) flattrend -  Option 1
##     b) forwardtrend_2010 - Option 2, 3
##  3. resistance_map
##  4. Description, for text
##------------------------------------------------------------

library(dplyr)
library(data.table)
library(tidyr)
library(glue)

source(file.path('Math_Modelling', 'itn_effect_sizes', 'itn_dtk_block_kill_functions.R'))
source(file.path('Math_Modelling', 'itn_effect_sizes', 'r_helper.R'))
theme_set(theme_cowplot())

box_dir <- file.path(Sys.getenv('USERPROFILE'), 'NU Malaria Modeling Dropbox', 'projects')
project_dir <- file.path(box_dir, 'hbhi_guinea')
itnres_dir <- file.path(project_dir, 'ento', 'insecticide_resistance_extract2022')

out_dir <- file.path('Math_Modelling', 'itn_effect_sizes', 'figures')
if (!dir.exists(out_dir))dir.create(out_dir)
layer_cols <- c('#f7a7a2', '#a9d050', '#57c6d2', '#d3b1d4')
insecticide_col <- 'mean.Permethrin_mortality'
insecticide <- tolower(unlist(strsplit(insecticide_col, "[._]+"))[[2]])

# Flags for plots
historical_trend_plots <- T
timetrends <- T # using unadjusted trend
timetrends_smooth <- T  #using rolling average smoothed trend
resistance_map <- T
fortext <- T

### Country DS dat
DSpop <- fread(file.path(project_dir, 'guinea_DS_pop.csv')) |>
  dplyr::select(DS_Name, seasonality_archetype_2) |>
  rename(NAME_2 = DS_Name, archetype = seasonality_archetype_2)
#mutate(seasonality_archetype=gsub('Dukreka','Dubreka',seasonality_archetype))
table(DSpop$archetype, exclude = NULL)

##------------------------------------------------------------ 1. historical_trend_plots

if (historical_trend_plots) {
  res_dat2 <- fread(file.path(itnres_dir, 'insecticide_resistance_extract_admin2.csv'))
  res_dat2 <- res_dat2 |> left_join(DSpop)
  table(res_dat2$archetype, exclude = NULL)
  res_dat2 <- res_dat2 |>
    group_by(archetype) |>
    mutate(drop = min(get(insecticide_col)) / max(get(insecticide_col)))
  res_dat2$drop_grp <- cut(res_dat2$drop, c(-Inf, quantile(res_dat2$drop, 0.34), quantile(res_dat2$drop, 0.67), Inf), right = F)
  DSpop <- DSpop |> left_join(unique(res_dat2[, c('NAME_2', 'drop_grp')]))

  pplot1 <- res_dat2 |>
    filter(year >= 2010) |>
    ggplot() +
    geom_line(aes(x = year, y = get(insecticide_col), group = NAME_2), col = 'deepskyblue3', alpha = 0.7) +
    #facet_wrap(~drop_grp, nrow = 1) +
    geom_vline(xintercept = c(2010), linetype = 'dashed', col = 'grey') +
    scale_y_continuous(lim = c(0, 1), breaks = seq(0, 1, 0.2), labels = seq(0, 1, 0.2) * 100) +
    scale_x_continuous(lim = c(2010, 2017), breaks = seq(2010, 2017, 2), labels = seq(2010, 2017, 2)) +
    theme(panel.spacing = unit(2.5, "lines")) +
    labs(y = paste0(insecticide, 'mortality (%)'), x = '', color = '', fill = '',
         caption = 'Extracted estimates based on Hancock et al 2020') +
    theme(legend.position = 'none',
          panel.spacing = unit(1.5, "lines")) +
    f_getCustomTheme()
  pplot1

  #### smooth
  res_dat2 <- fread(file.path(itnres_dir, 'insecticide_resistance_extract_admin2_smooth.csv'))
  res_dat2 <- res_dat2 |> left_join(DSpop)
  table(res_dat2$archetype, exclude = NULL)

  pplot2 <- res_dat2 |>
    filter(year > 2005) |>
    ggplot() +
    geom_line(aes(x = year, y = get(insecticide_col), group = NAME_2), col = 'deepskyblue3', alpha = 0.7) +
    #facet_wrap(~drop_grp, nrow = 1) +
    geom_vline(xintercept = c(2010), linetype = 'dashed', col = 'grey') +
    scale_y_continuous(lim = c(0, 1), breaks = seq(0, 1, 0.2), labels = seq(0, 1, 0.2) * 100) +
    scale_x_continuous(lim = c(2005, 2017), breaks = seq(2005, 2017, 2), labels = seq(2005, 2017, 2)) +
    theme(panel.spacing = unit(2.5, "lines")) +
    #scale_color_manual(values = layer_cols) +
    labs(y = paste0(insecticide, 'mortality (%)'), x = '', color = '', fill = '',
         caption = 'Extracted estimates based on Hancock et al 2020') +
    theme(legend.position = 'none', panel.spacing = unit(1.5, "lines")) +
    f_getCustomTheme()
  pplot2

  f_save_plot(pplot2, glue('mortality_{insecticide}_smoothtrend'), file.path(out_dir), width = 12, height = 5,
              device_format = c('png', 'pdf'))

}

##------------------------------------------------------------ 2. timetrends_smooth

if (timetrends_smooth) {

  res_dat2 <- fread(file.path(itnres_dir, 'insecticide_resistance_extract_admin2_smooth.csv'))
  res_dat2 <- res_dat2 |> left_join(DSpop)
  table(res_dat2$archetype, exclude = NULL)

  ### flags to collapse code lines
  flattrend = TRUE # Option 1
  forwardtrend_2010 = TRUE # Option 2a, 2b, and 3

  if (flattrend) {

    res_dat2_adj <- res_dat2 |>
      pivot_longer(cols = -c(year, NAME_1, NAME_2, archetype, drop_grp), names_to = 'insecticide') |>
      dplyr::select(year, NAME_1, NAME_2, archetype, drop_grp, insecticide, value) |>
      group_by(NAME_1, NAME_2, archetype, drop_grp, insecticide) |>
      group_modify(~add_row(.x, year = 2018)) |>
      group_modify(~add_row(.x, year = 2019)) |>
      group_modify(~add_row(.x, year = 2020)) |>
      group_modify(~add_row(.x, year = 2021)) |>
      group_modify(~add_row(.x, year = 2022)) |>
      fill(value, .direction = "down") |>
      pivot_wider(names_from = insecticide, values_from = value)

   pplot1 <- ggplot(data = res_dat2_adj) +
      geom_line(data = subset(res_dat2, year > 2009),
                aes(x = year, y = get(insecticide_col), group = NAME_2), col = 'deepskyblue3', alpha = 0.75) +
      geom_line(data = subset(res_dat2_adj, year >= 2017),
                aes(x = year, y = get(insecticide_col), group = NAME_2), col = 'deepskyblue3', alpha = 0.75, linetype = 'dashed') +
      #facet_wrap(~drop_grp, nrow = 1) +
      scale_y_continuous(lim = c(0, 1), breaks = seq(0, 1, 0.2), labels = seq(0, 1, 0.2) * 100) +  #, expand = c(0, 0)
      scale_x_continuous(lim = c(2010, 2022), breaks = seq(2010, 2022, 2), labels = seq(2010, 2022, 2)) +
      theme(panel.spacing = unit(2.5, "lines")) +
      #scale_color_manual(values = layer_cols) +
      labs(y = 'mortality (%)', x = '', color = '', fill = '',
           caption = 'Extracted estimates based on Hancock et al 2020') +
      f_getCustomTheme() +
      theme(legend.position = 'none', panel.spacing = unit(1.5, "lines"))

  }

  if (forwardtrend_2010) {

    df <- res_dat2 |>
      dplyr::select(-drop_grp) |>
      pivot_longer(cols = -c(year, NAME_1, NAME_2, archetype), names_to = 'insecticide') |>
      as.data.frame()

    dfGLM <- df |>
      filter(year >= 2010) |>
      dplyr::rename(
        x = year,
        y = value,
      ) |>
      dplyr::group_by(NAME_1, NAME_2, archetype, insecticide) |>
      do(fitglm = glm(y ~ x, family = 'gaussian', data = .))

    ### Make predictions
    pred_list <- list()
    for (i in c(1:nrow(dfGLM))) {
      pred_dat <- data.frame('x' = c(2010:2022), 'y_pred' = NA)
      glmmodel <- dfGLM[i, 'fitglm'][[1]]
      pred_dat$y_pred <- predict(glmmodel[[1]], newdata = pred_dat, type = "response")
      pred_dat$NAME_1 <- dfGLM[i, 'NAME_1'][[1]]
      pred_dat$NAME_2 <- dfGLM[i, 'NAME_2'][[1]]
      pred_dat$archetype <- dfGLM[i, 'archetype'][[1]]
      pred_dat$insecticide <- dfGLM[i, 'insecticide'][[1]]
      pred_list[[length(pred_list) + 1]] <- pred_dat
    }

    ### Combine data-list
    pred_dat <- pred_list |>
      bind_rows() |>
      dplyr::rename(year = x, value = y_pred) |>
      mutate(value = ifelse(value < 0.01, 0.01, value)) |>
      pivot_wider(names_from = insecticide, values_from = value) |>
      left_join(DSpop[, c('NAME_2', 'drop_grp')])

    # ggplot() +
    #   geom_line(data = res_dat2, aes(x = year, y = get(insecticide_col), group = NAME_2)) +
    #   geom_line(data = subset(pred_dat, year > 2016), aes(x = year, y = get(insecticide_col), group = NAME_2), col = 'blue') +
    #   facet_wrap(~drop_grp, nrow = 1)

    #---------------------------------------------------  OPTION 2a
    df_out <- res_dat2 |>
      dplyr::select(colnames(pred_dat)) |>
      bind_rows(pred_dat[pred_dat$year > 2017,])

    pplot2a <- ggplot(data = df_out) +
      geom_line(data = subset(df_out, year <= 2017),
                aes(x = year, y = get(insecticide_col), group = NAME_2), col = 'deepskyblue3', , alpha = 0.75) +
      geom_line(data = subset(df_out, year >= 2017),
                aes(x = year, y = get(insecticide_col), group = NAME_2), col = 'deepskyblue3', , alpha = 0.75, linetype = 'dashed') +
      #facet_wrap(~drop_grp, nrow = 1) +
      scale_y_continuous(lim = c(0, 1), breaks = seq(0, 1, 0.2), labels = seq(0, 1, 0.2) * 100) +  #, expand = c(0, 0)
      scale_x_continuous(lim = c(2010, 2022), breaks = seq(2010, 2022, 2), labels = seq(2010, 2022, 2)) +
      theme(panel.spacing = unit(2.5, "lines")) +
      #scale_color_manual(values = layer_cols) +
      labs(y = 'mortality (%)', x = '', color = '', fill = '',
           caption = 'Extracted estimates based on Hancock et al 2020\n linear forward prediction from 2010') +
      f_getCustomTheme() +
      theme(legend.position = 'none', panel.spacing = unit(1.5, "lines"))


    #---------------------------------------------------  OPTION 2b
    pred_dat_adj <- pred_dat |>
      pivot_longer(cols = -c(year, NAME_1, NAME_2, archetype, drop_grp), names_to = 'insecticide') |>
      filter(year == 2017) |>
      rename(value_pred = value) |>
      left_join(df[df$year == 2017, c('NAME_2', 'insecticide', 'value')], by = c('NAME_2', 'insecticide')) |>
      mutate(ratio = value / value_pred,
             diff = value - value_pred) |>
      dplyr::select(NAME_2, archetype, drop_grp, insecticide, ratio, diff)

    pred_dat_adj2 <- pred_dat |>
      pivot_longer(cols = -c(year, NAME_1, NAME_2, archetype, drop_grp), names_to = 'insecticide') |>
      filter(year > 2017) |>
      left_join(pred_dat_adj) |>
      mutate(value = value * ratio) |>
      dplyr::select(year, archetype, NAME_1, NAME_2, drop_grp, insecticide, value) |>
      pivot_wider(names_from = insecticide, values_from = value)

    df_out <- res_dat2 |>
      dplyr::select(colnames(pred_dat_adj2)) |>
      bind_rows(pred_dat_adj2[pred_dat_adj2$year > 2017,])

    pplot2b <- ggplot(data = df_out) +
      geom_line(data = subset(df_out, year <= 2017),
                aes(x = year, y = get(insecticide_col), group = NAME_2), col = 'deepskyblue3', , alpha = 0.75) +
      geom_line(data = subset(df_out, year >= 2017),
                aes(x = year, y = get(insecticide_col), group = NAME_2), col = 'deepskyblue3', , alpha = 0.75, linetype = 'dashed') +
      #facet_wrap(~drop_grp, nrow = 1) +
      scale_y_continuous(lim = c(0, 1), breaks = seq(0, 1, 0.2), labels = seq(0, 1, 0.2) * 100) +  #, expand = c(0, 0)
      scale_x_continuous(lim = c(2010, 2022), breaks = seq(2010, 2022, 2), labels = seq(2010, 2022, 2)) +
      theme(panel.spacing = unit(2.5, "lines")) +
      # scale_color_manual(values = layer_cols) +
      labs(y = 'mortality (%)', x = '', color = '', fill = '',
           caption = 'Extracted estimates based on Hancock et al 2020\n linear forward prediction from 2010 adjusted') +
      f_getCustomTheme() +
      theme(legend.position = 'none', panel.spacing = unit(1.5, "lines"))


    #---------------------------------------------------  OPTION 3
    # or mean to constant
    pred_dat_adj <- pred_dat |>
      pivot_longer(cols = -c(year, NAME_1, NAME_2, archetype, drop_grp), names_to = 'insecticide') |>
      filter(year == 2017) |>
      rename(value_pred = value) |>
      left_join(df[df$year == 2017, c('NAME_2', 'insecticide', 'value')], by = c('NAME_2', 'insecticide')) |>
      mutate(ratio = value / value_pred,
             diff = value - value_pred) |>
      rename(value_2017 = value) |>
      dplyr::select(NAME_2, archetype, insecticide, drop_grp, ratio, diff, value_2017)

    pred_dat_adj2 <- pred_dat |>
      pivot_longer(cols = -c(year, NAME_1, NAME_2, archetype, drop_grp), names_to = 'insecticide') |>
      filter(year > 2017) |>
      left_join(pred_dat_adj) |>
      mutate(value = value * ratio,
             value = (value + value_2017) / 2) |>
      dplyr::select(year, archetype, NAME_1, NAME_2, drop_grp, insecticide, value) |>
      pivot_wider(names_from = insecticide, values_from = value)

    df_out <- res_dat2 |>
      dplyr::select(colnames(pred_dat_adj2)) |>
      bind_rows(pred_dat_adj2[pred_dat_adj2$year > 2017,])

    pplot3 <- ggplot(data = df_out) +
      geom_line(data = subset(df_out, year <= 2017),
                aes(x = year, y = get(insecticide_col), group = NAME_2), col = 'deepskyblue3', , alpha = 0.75) +
      geom_line(data = subset(df_out, year >= 2017),
                aes(x = year, y = get(insecticide_col), group = NAME_2), col = 'deepskyblue3', , alpha = 0.75, linetype = 'dashed') +
      #facet_wrap(~drop_grp, nrow = 1) +
      scale_y_continuous(lim = c(0, 1), breaks = seq(0, 1, 0.2), labels = seq(0, 1, 0.2) * 100) +  #, expand = c(0, 0)
      scale_x_continuous(lim = c(2010, 2022), breaks = seq(2010, 2022, 2), labels = seq(2010, 2022, 2)) +
      theme(panel.spacing = unit(2.5, "lines")) +
      #scale_color_manual(values = layer_cols) +
      labs(y = 'mortality (%)', x = '', color = '', fill = '',
           caption = 'Extracted estimates based on Hancock et al 2020\n linear forward prediction from 2010 adjusted') +
      f_getCustomTheme() +
      theme(legend.position = 'none', panel.spacing = unit(1.5, "lines"))

    #---------------------------------------------------  Plot OPTION 1,2b, 3
    pplot <- plot_grid(pplot1, pplot2b, pplot3)

    f_save_plot(pplot, glue('mortality_{insecticide}_smoothedtrend_2010continued_v3'),
                file.path(out_dir), width = 12, height = 6)

  }

}

##------------------------------------------------------------ 3. resistance_map

if (resistance_map) {
  library(raster)
  library(sp)
  shp_dir <- file.path(gsub('projects', 'data', box_dir), 'guinea_shapefiles')

  shp_admin0 <- shapefile(file.path(shp_dir, 'GIN_adm_shp', 'GIN_adm0.shp'))
  shp_admin1 <- shapefile(file.path(shp_dir, 'GIN_adm_shp', 'GIN_adm1.shp'))
  shp_admin2 <- shapefile(file.path(shp_dir, 'Guinea_Health_District', 'GIN_adm2.shp'))

  shp_admin2$NAME_1 <- iconv(shp_admin2$NAME_1, from = 'UTF-8', "ASCII//TRANSLIT")
  shp_admin2$NAME_2 <- iconv(shp_admin2$NAME_2, from = 'UTF-8', "ASCII//TRANSLIT")
  shp_admin2$NAME_2[shp_admin2$NAME_2 == 'Yamou'] <- 'Yomou'

  res_dat2 <- fread(file.path(itnres_dir, 'insecticide_resistance_extract_admin2.csv')) |>
    filter(year %in% seq(2010, 2017, 2))

  admin2_sp.f <- fortify(shp_admin2, region = "NAME_2") |>
    dplyr::mutate(NAME_2 = id)

  unique(res_dat2$NAME_2)[!(unique(res_dat2$NAME_2)) %in% unique(admin2_sp.f$NAME_2)]
  unique(admin2_sp.f$NAME_2)[!(unique(admin2_sp.f$NAME_2)) %in% unique(res_dat2$NAME_2)]

  plot_dat <- admin2_sp.f |> left_join(res_dat2)

  pplot_map <- ggplot(warnings = FALSE) +
    geom_polygon(
      data = plot_dat,
      aes(x = long, y = lat, group = group, fill = get(insecticide_col) * 100), col = "black", size = 0.2) +
    facet_wrap(~year, nrow = 2) +
    theme_map() +
    theme(legend.position = 'right',
          strip.text.x = element_text(size = 12, face = "bold"),
          strip.text.y = element_text(size = 12, face = "bold"),
          strip.background = element_blank()) +
    labs(fill = paste0(insecticide, '\nmortality (%)')) +
    scale_fill_viridis_c(option = 'H', limits = c(0, 100), begin = 0, end = 1, direction = -1)

  f_save_plot(pplot_map, glue('GN_resistance_{insecticide}_map'), file.path(out_dir), width = 12, height = 6)
}


##------------------------------------------------------------ 4.  Description, for text
if (fortext) {

  ITN_insecticide <- 'Permethrin'

  net_effects_2022 <- data.table::fread(
    file.path(project_dir, 'simulation_priors/_itn_effect_param',
              glue('net_effect_{tolower(ITN_insecticide)}_2010-2022.csv'))) |>
    mutate(pyrethroid_resistance = ITN_insecticide) |>
    filter(year == 2022)

  ig2_effects_2022 <- data.table::fread(
    file.path(project_dir, 'simulation_priors/_itn_effect_param',
              glue('IG2_effect_{tolower(ITN_insecticide)}_2010-2022.csv'))) |>
    filter(year == 2022)

  outdir <- file.path(project_dir, "simulation_inputs/_scenarios_2023/itn")
  nsp <- fread(file.path(outdir, glue("itn80_ig2p1_2023-2029.csv")))|>
    filter(year == 2025)

  summary(net_effects_2022$blocking_rate)
  summary(ig2_effects_2022$blocking_rate)
  tapply(nsp$blocking_rate, nsp$llin_type, summary)

  summary(net_effects_2022$kill_rate)
  summary(ig2_effects_2022$kill_rate)
  tapply(nsp$kill_rate, nsp$llin_type, summary)

  pdat <- ig2_effects_2022 |> bind_rows(net_effects_2022)
  pdat$llin_type <- factor(pdat$llin_type, levels = c('LLIN', 'IG2'), labels = c('LLIN', 'IG2'))

  pplot <- pdat |> filter(year == 2022) |>
    ggplot() +
    geom_jitter(aes(x = llin_type, y = blocking_rate), width = 0.2, height = 0.01, col = 'brown') +
    geom_jitter(aes(x = llin_type, y = kill_rate), width = 0.2, height = 0.01, col = 'deepskyblue3') +
    scale_y_continuous(lim = c(0, 1))

  f_save_plot(pplot, glue('mortality_scatter'), file.path(out_dir), width = 5, height = 4)

}
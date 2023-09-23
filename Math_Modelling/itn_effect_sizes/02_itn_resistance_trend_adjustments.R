## --------------------------- 02_itn_resistance_trend_adjustments.R  ---------------------------
## Read in insecticide mortality estimates from MAP per district and years and add corresponding ITN effect sizes
## Adjustment methods combinations of:
##           - continuedTrend  or constantTrend
##           - smoothTrend  FALSE or TRUE
## Input: 'insecticide_resistance_extract_admin2.csv'
## Output: dataframe (CSV) with extracted adjusted ITN resistance values, for all insecticdes in input csv
##          ('insecticide_resistance_extract_admin2_smooth_', trendmethod, '.csv')
##------------------------------------------------------------

library(dplyr)
library(tidyr)
library(zoo)
library(data.table)

source(file.path('Math_Modeling', 'itn_effect_sizes', 'itn_dtk_block_kill_functions.R'))
source(file.path('Math_Modeling', 'itn_effect_sizes', 'r_helper.R'))

box_dir <- file.path(Sys.getenv('USERPROFILE'), 'NU Malaria Modeling Dropbox', 'projects')
project_dir <- file.path(box_dir, 'hbhi_guinea')
itnres_dir <- file.path(project_dir, 'ento', 'insecticide_resistance_extract2022')

# Load master csv
gn_dat <- fread(file.path(project_dir, 'guinea_DS_pop.csv')) |>
  dplyr::select(DS_Name, seasonality_archetype_2) |>
  rename(NAME_2 = DS_Name, archetype = seasonality_archetype_2)

##------------------------------------------------------------

# Trend options
trendmethod <- 'continuedTrend'  #'constantTrend'  'continuedTrend'
insecticde_col <- 'mean.Permethrin_mortality'
smoothTrend <- T

##------------------------------------------------------------

res_dat2 <- fread(file.path(itnres_dir, 'insecticide_resistance_extract_admin2.csv'))
table(res_dat2$NAME_1, res_dat2$year, exclude = NULL)

# Run options on resistance trend
if (smoothTrend) {
  res_dat2 <- fread(file.path(itnres_dir, 'insecticide_resistance_extract_admin2.csv'))
  table(res_dat2$NAME_1, res_dat2$year, exclude = NULL)

  df_out <- res_dat2 |>
    pivot_longer(cols = -c(year, NAME_1, NAME_2), names_to = 'insecticide') |>
    dplyr::group_by(NAME_1, NAME_2, insecticide) |>
    arrange(year) |>
    dplyr::mutate(value_roll = rollapply(value, 2, mean, align = 'right', fill = NA),
                  value = ifelse(year >= 2010, value_roll, value)) |>
    dplyr::select(-value_roll) |>
    pivot_wider(names_from = insecticide, values_from = value)

  # ggplot(data = df_out) +
  #   geom_line(data = subset(df_out, year <= 2010), aes(x = year, y = get(insecticde_col), group = NAME_2),
  #             alpha = 0.75) +
  #   geom_line(data = subset(df_out, year >= 2010), aes(x = year, y = get(insecticde_col), group = NAME_2),
  #             alpha = 0.75, linetype = 'dashed') +
  #   labs(y = insecticde_col) +
  #   facet_wrap(~NAME_1)

  fwrite(df_out, file.path(itnres_dir, 'insecticide_resistance_extract_admin2_smooth.csv'))


}

##------------------------------------------------------------

if (trendmethod == 'constantTrend') {
  fname_out <- paste0('insecticide_resistance_extract_admin2_smooth_', trendmethod, '.csv')
  res_dat2 <- fread(file.path(itnres_dir, 'insecticide_resistance_extract_admin2_smooth.csv'))

  df_out <- res_dat2 |>
    pivot_longer(cols = -c(year, NAME_1, NAME_2), names_to = 'insecticide') |>
    dplyr::select(year, NAME_1, NAME_2, insecticide, value) |>
    group_by(NAME_1, NAME_2, insecticide) |>
    group_modify(~add_row(.x, year = 2018)) |>
    group_modify(~add_row(.x, year = 2019)) |>
    group_modify(~add_row(.x, year = 2020)) |>
    group_modify(~add_row(.x, year = 2021)) |>
    group_modify(~add_row(.x, year = 2022)) |>
    fill(value, .direction = "down") |>
    pivot_wider(names_from = insecticide, values_from = value)

  # ggplot(data = df_out) +
  #   geom_hline(yintercept = 0, alpha = 0) +
  #   geom_line(data = subset(df_out, year <= 2017), aes(x = year, y = get(insecticde_col), group = NAME_2),
  #             alpha = 0.75) +
  #   geom_line(data = subset(df_out, year >= 2017), aes(x = year, y = get(insecticde_col), group = NAME_2),
  #             alpha = 0.75, linetype = 'dashed') +
  #   labs(y = insecticde_col) +
  #   facet_wrap(~NAME_1)

  table(df_out$year)

  df_out$trendmethod <- trendmethod
  fwrite(df_out, file.path(itnres_dir, fname_out))

}

##------------------------------------------------------------

if (trendmethod == 'continuedTrend') {
  fname_out <- paste0('insecticide_resistance_extract_admin2_smooth_', trendmethod, '.csv')
  res_dat2 <- fread(file.path(itnres_dir, 'insecticide_resistance_extract_admin2_smooth.csv'))

  df <- res_dat2 |>
    pivot_longer(cols = -c(year, NAME_1, NAME_2), names_to = 'insecticide')

  dfGLM <- df |>
    filter(year >= 2010) |>
    dplyr::rename(
      x = year,
      y = value,
    ) |>
    dplyr::group_by(NAME_1, NAME_2, insecticide) |>
    do(fitglm = glm(y ~ x, family = 'gaussian', data = .))

  ### Make predictions
  pred_list <- list()
  for (i in c(1:nrow(dfGLM))) {
    pred_dat <- data.frame('x' = c(2010:2022), 'y_pred' = NA)
    glmmodel <- dfGLM[i, 'fitglm'][[1]]
    pred_dat$y_pred <- predict(glmmodel[[1]], newdata = pred_dat, type = "response")
    pred_dat$NAME_1 <- dfGLM[i, 'NAME_1'][[1]]
    pred_dat$NAME_2 <- dfGLM[i, 'NAME_2'][[1]]
    pred_dat$insecticide <- dfGLM[i, 'insecticide'][[1]]
    pred_list[[length(pred_list) + 1]] <- pred_dat
  }

  # or mean to constant
  pred_dat_adj <- pred_list |>
    bind_rows() |>
    dplyr::rename(year = x, value = y_pred) |>
    mutate(value = ifelse(value < 0, 0, value)) |>
    filter(year == 2017) |>
    rename(value_pred = value) |>
    left_join(df[df$year == 2017, c('NAME_2', 'value', 'insecticide')], by = c('NAME_2', 'insecticide')) |>
    mutate(ratio = value / value_pred,
           diff = value - value_pred) |>
    rename(value_2017 = value) |>
    dplyr::select(NAME_2, insecticide, ratio, diff, value_2017)

  pred_dat_adj2 <- pred_list |>
    bind_rows() |>
    dplyr::rename(year = x, value = y_pred) |>
    mutate(value = ifelse(value < 0, 0, value)) |>
    filter(year > 2017) |>
    left_join(pred_dat_adj) |>
    mutate(value = value * ratio,
           value = (value + value_2017) / 2) |>
    dplyr::select(year, NAME_1, NAME_2, insecticide, value)

  df_out <- df |>
    dplyr::select(colnames(pred_dat_adj2)) |>
    bind_rows(pred_dat_adj2[pred_dat_adj2$year > 2017,]) |>
    pivot_wider(names_from = insecticide, values_from = value)

  # ggplot(data = df_out) +
  #   geom_hline(yintercept = 0, alpha = 0) +
  #   geom_line(data = subset(df_out, year <= 2017), aes(x = year, y = get(insecticde_col), group = NAME_2),
  #             alpha = 0.75) +
  #   geom_line(data = subset(df_out, year >= 2017), aes(x = year, y = get(insecticde_col), group = NAME_2),
  #             alpha = 0.75, linetype = 'dashed') +
  #   labs(y = insecticde_col) +
  #   facet_wrap(~NAME_1)

  head(df_out)
  table(df_out$year)

  df_out$trendmethod <- trendmethod
  fwrite(df_out, file.path(itnres_dir, fname_out))

}

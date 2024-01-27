## --------------------------- 03_country_resistance_scaling.R ---------------------------
## Read in insecticide mortality estimates per district and years and add corresponding ITN effect sizes
## CSV files:
##  'LLIN_effect_<insecticide>_2010-2022.csv', 2010 -2022 standard ITNs for each district
##  'PBO_effect_<insecticide>_2010-2022.csv', 2010 -2022 PBO ITNs for each district
##  'IG2_effect_<insecticide>_2010-2022.csv', 2010 -2022 IG2 ITNs for each district
##  'net_effect_<insecticide>_2010-2022.csv', 2010 -2022 different ITNs dependinging deployment district and year
##------------------------------------------------------------

library('dplyr')
library('data.table')

box_dir <- file.path(Sys.getenv('USERPROFILE'), '/NU Malaria Modeling Dropbox/projects/')
project_dir <- file.path(box_dir, 'hbhi_guinea')
ento_dir <- file.path(project_dir, 'ento/insecticide_resistance_extract2022')
itneff_dir <- file.path(project_dir, 'simulation_priors/_itn_effect_param')

source(file.path('Math_Modeling', 'itn_effect_sizes', 'itn_dtk_block_kill_functions.R'))
fig_dir <- file.path('Math_Modeling', 'itn_effect_sizes', 'figures')

# Flags on what to run
flags <- list(llin = T, pbo = T, ig2 = T, GNnets = F, compare_nets = T)
set.seed(125)

# Options to choose
scale_to_dtk_baseITN <- TRUE # whether to rescale to base dtk ITN parameter at full susceptibiliy
dtk_killrate_scl <- 0.6589696 # fitted, see ITN calibration in emod_itn_exploration repository
insecticide_col <- 'mean.Permethrin_mortality'

#fname_IR  <- 'insecticide_resistance_extract_admin2.csv'
fname_IR <- 'insecticide_resistance_extract_admin2_smooth_continuedTrend.csv'

# Define output filenames
insecticide <- tolower(unlist(strsplit(insecticide_col, "[._]+"))[[2]])
fname_itn <- paste0('LLIN_effect_', insecticide, '_2010-2022.csv')
fname_pbo <- paste0('PBO_effect_', insecticide, '_2010-2022.csv')
fname_ig2 <- paste0('IG2_effect_', insecticide, '_2010-2022.csv')
fname_countrynets <- paste0('net_effect_', insecticide, '_2010-2022.csv')

DSpop <- fread(file.path(project_dir, 'guinea_DS_pop.csv')) |>
  dplyr::select(DS_Name, seasonality_archetype_2)

dat <- fread(file.path(ento_dir, fname_IR)) |>
  filter(year >= 2010) |>  ## assume no or fully effective (base ITN) parameters prior 2010 if any
  mutate(DS_Name = match_names(NAME_2, DSpop$DS_Name)) |>
  dplyr::select(DS_Name, everything(), -NAME_1, -NAME_2)

##------------------------------------------------------------

if (flags$llin) {

  itn_effect_df <- dat |>
    dplyr::select(year, DS_Name, !!!insecticide_col, trendmethod) |>
    arrange(DS_Name, year) |>
    mutate(blocking_rate = f_get_dtk_block_kill(get(insecticide_col))[[1]],
           kill_rate_unadj = f_get_dtk_block_kill(get(insecticide_col))[[2]]) |>
    arrange(year) |>
    mutate(llin_type = 'LLIN')

  if (scale_to_dtk_baseITN) {
    itn_effect_df <- itn_effect_df |>
      mutate(kill_rate = f_get_dtk_block_kill(get(insecticide_col), mort_fit_version = '2022_snt_BFA')[[2]],
             kill_rate_adjustment = 'down-re-scaled')
  }else {
    itn_effect_df <- itn_effect_df |>
      mutate(kill_rate = f_get_dtk_block_kill(get(insecticide_col))[[2]] * dtk_killrate_scl,
             kill_rate_adjustment = 'downscaled')
  }

  itn_effect_df <- itn_effect_df |> relocate(trendmethod, .after = last_col())
  fwrite(itn_effect_df, file.path(itneff_dir, fname_itn))
} #llin_nets

##------------------------------------------------------------

if (flags$pbo) {

  itn_effect_df <- dat |>
    dplyr::select(year, DS_Name, !!!insecticide_col, trendmethod) |>
    arrange(DS_Name, year) |>
    mutate(
      blocking_rate = f_get_dtk_block_kill_PBO(get(insecticide_col))[[1]],
      kill_rate_unadj = f_get_dtk_block_kill_PBO(get(insecticide_col))[[2]]
    ) |>
    arrange(year) |>
    mutate(llin_type = 'PBO')

  ## Apply same relative scaling on kill rate as for standard LLIN
  if (scale_to_dtk_baseITN) {
    itn_effect_df <- itn_effect_df |>
      mutate(kill_rate = f_get_dtk_block_kill_PBO(get(insecticide_col), mort_fit_version = '2022_snt_BFA')[[2]],
             kill_rate_adjustment = 'down-re-scaled')
  }else {
    itn_effect_df <- itn_effect_df |>
      mutate(kill_rate = f_get_dtk_block_kill_PBO(get(insecticide_col))[[2]] * dtk_killrate_scl,
             kill_rate_adjustment = 'downscaled')
  }

  itn_effect_df <- itn_effect_df |> relocate(trendmethod, .after = last_col())
  fwrite(itn_effect_df, file.path(itneff_dir, fname_pbo))

} #pbo_nets

##------------------------------------------------------------

if (flags$ig2) {
  pbo_to_ig2_blocking_scl = 0.885

  itn_effect_df <- dat |>
    dplyr::select(year, DS_Name, !!!insecticide_col, trendmethod) |>
    arrange(DS_Name, year) |>
    mutate(
      blocking_rate = f_get_dtk_block_kill_PBO(get(insecticide_col))[[1]],
      blocking_rate = blocking_rate * pbo_to_ig2_blocking_scl,
      kill_rate = 0.75
    ) |>
    arrange(year) |>
    mutate(llin_type = 'IG2')


  itn_effect_df <- itn_effect_df |> relocate(trendmethod, .after = last_col())
  fwrite(itn_effect_df, file.path(itneff_dir, fname_ig2))

} #ig2_nets

##------------------------------------------------------------

### All nets prior 2023 were standard nets
if (flags$GNnets) {

  itn_effect_df <- fread(file.path(itneff_dir, fname_itn)) |>
    filter(year <= 2022) |>
    arrange(DS_Name, year)

  table(itn_effect_df$year, itn_effect_df$llin_type, exclude = NULL)
  if (any(is.na(itn_effect_df)))message('NAs found in dataset')
  fwrite(itn_effect_df, file.path(itneff_dir, fname_countrynets))

} #GN_country_nets

if (flags$compare_nets) {
  library('tidyr')
  source(file.path('Math_Modeling', 'itn_effect_sizes', 'r_helper.R'))
  theme_set(theme_bw())

  ### Same source raster files, but slightly differente xtract
  mort_df_2022 <- fread(file.path(project_dir, 'ento/insecticide_resistance_extract2022',
                                  'insecticide_resistance_extract_admin2.csv')) |>
    mutate(DS_Name = match_names(NAME_2, DSpop$DS_Name)) |>
    dplyr::select(DS_Name, year, !!!insecticide_col)

  itn_df_llin <- fread(file.path(itneff_dir, fname_itn)) |>
    mutate(llin_type = 'LLIN_2022fit') |>  # to distinguish from initial ITN or 2019 fit
    dplyr::select(DS_Name, year, kill_rate, blocking_rate, llin_type, !!!insecticide_col)

  itn_df_pbo <- fread(file.path(itneff_dir, fname_pbo)) |>
    mutate(llin_type = 'PBO') |>
    dplyr::select(DS_Name, year, kill_rate, blocking_rate, llin_type, !!!insecticide_col)

  itn_df_ig2 <- fread(file.path(itneff_dir, fname_ig2)) |>
    mutate(llin_type = 'IG2') |>
    dplyr::select(DS_Name, year, kill_rate, blocking_rate, llin_type, !!!insecticide_col)

  itn_df <- itn_df_llin |>
    bind_rows(itn_df_pbo, itn_df_ig2) |>
    arrange(!!!insecticide_col)

  table(itn_df$llin_type, itn_df$year, exclude = NULL)

  p1 <- ggplot(data = itn_df) +
    geom_hline(yintercept = 0.6, linetype = 'dashed', col = 'grey') +
    geom_line(aes(x = get(insecticide_col), y = kill_rate, col = llin_type), size = 1.1) +
    scale_y_continuous(lim = c(0, 1)) +
    scale_x_continuous(lim = c(0, 1)) +
    labs(x = insecticide_col) +
    scale_color_brewer(palette = 'Set2') +
    f_getCustomTheme()

  p2 <- ggplot(data = itn_df) +
    geom_hline(yintercept = 0.9, linetype = 'dashed', col = 'grey') +
    geom_line(aes(x = get(insecticide_col), y = blocking_rate, col = llin_type), size = 1.1) +
    scale_y_continuous(lim = c(0, 1)) +
    scale_x_continuous(lim = c(0, 1)) +
    labs(x = insecticide_col) +
    scale_color_brewer(palette = 'Set2') +
    f_getCustomTheme()

  (pplot <- plot_combine(list(p2, p1), ncol = 2))
  f_save_plot(pplot, paste0('country_resistance_scaling_fig'),
              file.path(fig_dir), width = 10, height = 3.5)

} #compare_all_nets



## --------------------------- 04_fit_itn_kill_rate.R ---------------------------
## Fit initial itn killing parameter to reduction in clinical cases corresponding to Tiono et al 2018 study
## Reduction in clinical cases based on control arm of Olyset Duo study together with DHIS2 case estimates (outside this script)
## 1) Fit using linear regression model, 2) rescale relationship using scaling factor from estimated and fitted kill rate
## ---------------------------

###__________________________________ directories
source(file.path('Math_Modelling', 'itn_effect_sizes', 'itn_dtk_block_kill_functions.R'))
source(file.path('Math_Modelling', 'itn_effect_sizes', 'r_helper.R'))
theme_set(theme_cowplot())

box_dir <- file.path(Sys.getenv('USERPROFILE'), 'NU Malaria Modeling Dropbox', 'projects')
project_dir <- file.path(box_dir, 'emod_itn_exploration')
sim_out_dir <- file.path(box_dir, 'emod_itn_exploration/simulation_outputs/_banfora_snt_itncalib')
out_dir <- file.path('Math_Modelling', 'itn_effect_sizes',  'figures')

###__________________________________ simulation experiment specification
exp_name <- 'mrm9534_banfora_itncalib_20132014_v6'
exp_name_counterfactual <- paste0(exp_name, '_counterfactual')
sample_df_name <- 'selected_particles_ITNextended_20221115.csv'

grp_params <- c('DS_Name', 'initial_blocking')
fit_param <- 'initial_killing'

###__________________________________ custom functions
f_pred_lm <- function(x, y, ref) {
  new <- data.frame(x = ref)
  pred <- predict(lm(y ~ x), new, se.fit = TRUE)
  return(pred$fit)
}

###__________________________________ setting specifications
itn_type <- 'pyrethroid_tiono'
w <- c(97, 99, 167) / 363 ## Tiono et al supplement, total N
r <- c(13.4, 10.1, 19.2)  ## Tiono et al supplement
(bioassay_mort <- weighted.mean(r, w) / 100)

estimated_blocking <- round(f_get_dtk_block_kill(bioassay_mort)[[1]], 3)
estimated_killing <- round(f_get_dtk_block_kill(bioassay_mort)[[2]], 3)
DS_name_ref = 'Banfora'
perc_red_clinicalcases = 0.1264645 ## 2014 only, ref  2.1235 , weighted based on LLIN vs PPF nets

###__________________________________ read in simulation data
sample_df <- fread(file.path(project_dir, 'simulation_inputs', sample_df_name)) |>
  rename(Sample_ID = id, initial_blocking = blocking_rate, initial_killing = kill_rate) |>
  dplyr::select(DS_Name, Sample_ID, initial_blocking, initial_killing)

## add additional group variables
simdat_c <- fread(file.path(sim_out_dir, exp_name_counterfactual, 'U5_PfPR_ClinicalIncidence.csv')) |> mutate(scen = 'external')
simdat <- fread(file.path(sim_out_dir, exp_name, 'U5_PfPR_ClinicalIncidence.csv')) |>
  mutate(scen = 'studyarea') |>
  bind_rows(simdat_c) |>
  left_join(sample_df) |>
  mutate(month = ifelse(month < 10, paste0(0, month), month),
         date = as.Date(paste0(year, '-', month, '-01'))) |>
  group_by_at(.vars = c(grp_params, fit_param, 'Sample_ID', 'date', 'year', 'scen')) |>
  summarize(`Cases U5` = mean(`Cases U5`)) |> ## aggregate runs
  filter((date %in% seq(as.Date('2014-06-01'), as.Date('2014-12-31'), 'month'))) |>
  group_by(DS_Name, initial_killing, initial_blocking, scen) |>
  summarize(`Cases U5` = sum(`Cases U5`, na.rm = TRUE)) |>
  mutate(perc_red_incidence = (1 - (`Cases U5` / `Cases U5`[scen == 'external']))) |>
  filter(scen == 'studyarea')

###__________________________________  fit and plot
fdat <- simdat |>
  group_by(initial_blocking) |>  ## compare different initial_blockings if simulated
  mutate(pred_k = f_pred_lm(perc_red_incidence, initial_killing, perc_red_clinicalcases))

estimated_blocking
estimated_killing
fdat |>
  select(initial_blocking, pred_k) |>
  unique()

estimated_killing
fdat_sub <- fdat |> filter(initial_blocking == estimated_blocking)
lm(fdat_sub$initial_killing ~ fdat_sub$perc_red_incidence)  ## show model coefficients

dtk_killing <- unique(fdat_sub$pred_k)
print(dtk_killing)


# For exploration of multiple simulated initial blocking rates
create_plot_facets = FALSE
if (create_plot_facets) {
  title_txt <- ''
  subtitle_txt <- paste0('blocking: ', round(estimated_blocking, 3),
                         '; kill_rate: ', round(estimated_killing, 3),
                         '; kill_rate fit: ', round(dtk_killing, 3),
                         '; scl: ', round(dtk_killing / estimated_killing, 3))
  caption_txt <- paste0('ITN type: ', itn_type, '; bioassay mortality: ', round(bioassay_mort, 3))

  pplot <- ggplot(data = fdat, aes(x = initial_killing, y = perc_red_incidence)) +
    geom_hline(yintercept = perc_red_clinicalcases, col = 'red') +
    geom_vline(aes(xintercept = pred_k), col = 'red') +
    geom_rect(aes(xmin = pred_k, ymin = -Inf, ymax = Inf, xmax = Inf), fill = 'white') +
    geom_rect(ymin = perc_red_clinicalcases + 0.01, ymax = Inf, xmin = -Inf, xmax = Inf, fill = 'white') +
    geom_point() +
    geom_text(aes(y = perc_red_clinicalcases, x = pred_k + 0.06, label = round(pred_k, 3))) +
    geom_smooth(method = 'lm', se = F) +
    scale_y_continuous(lim = c(0, 0.6), breaks = seq(0, 1, 0.1)) +
    scale_x_continuous(lim = c(0, 0.6), breaks = seq(0, 1, 0.1)) +
    labs(title = title_txt, subtitle = subtitle_txt, caption = caption_txt,
         x = fit_param,
         y = '% reduction in clinical cases \nat 12 months after ITN deployment') +
    theme_cowplot() +
    f_getCustomTheme() +
    facet_wrap(~initial_blocking, scale = 'free')

  print(pplot)
  f_save_plot(pplot, paste0('fit_', itn_type, '_', fit_param, '_facets'), file.path(out_dir), width = 8, height = 6)
}

create_plot = TRUE
if (create_plot) {
  title_txt <- ''
  subtitle_txt <- paste0('blocking: ', round(estimated_blocking, 3),
                         '; kill_rate: ', round(estimated_killing, 3),
                         '; kill_rate fit: ', round(dtk_killing, 3),
                         '; scl: ', round(dtk_killing / estimated_killing, 3))
  caption_txt <- paste0('ITN type: ', itn_type, '; bioassay mortality: ', round(bioassay_mort, 3))

  pplot <- ggplot(data = subset(fdat, initial_blocking == estimated_blocking), aes(x = initial_killing, y = perc_red_incidence)) +
    geom_hline(yintercept = perc_red_clinicalcases, col = 'red') +
    geom_vline(aes(xintercept = pred_k), col = 'red') +
    geom_rect(aes(xmin = pred_k, ymin = -Inf, ymax = Inf, xmax = Inf), fill = 'white') +
    geom_rect(ymin = perc_red_clinicalcases + 0.01, ymax = Inf, xmin = -Inf, xmax = Inf, fill = 'white') +
    geom_point() +
    geom_text(aes(y = perc_red_clinicalcases, x = pred_k + 0.06, label = round(pred_k, 3))) +
    geom_smooth(method = 'lm', se = F) +
    scale_y_continuous(lim = c(0, 0.6), breaks = seq(0, 1, 0.1)) +
    scale_x_continuous(lim = c(0, 0.6), breaks = seq(0, 1, 0.1)) +
    labs(title = title_txt, subtitle = subtitle_txt, caption = caption_txt,
         x = fit_param,
         y = '% reduction in clinical cases \nat 12 months after ITN deployment') +
    theme_cowplot() +
    f_getCustomTheme()

  print(pplot)
  f_save_plot(pplot, paste0('fit_', itn_type, '_', fit_param), file.path(out_dir), width = 6, height = 4)
}


###__________________________________ rescaled relationship
rescale_EHT_to_dtk_relationship = TRUE
if (rescale_EHT_to_dtk_relationship) {

  (scl <- dtk_killing / estimated_killing)

  mort_bioassay <- seq(0, 1, 0.01)
  dtk_blocking <- f_get_dtk_block_kill(mort_bioassay)[[1]]
  dtk_killrate <- f_get_dtk_block_kill(mort_bioassay)[[2]]
  dtk_killrate_scl <- dtk_killrate * scl

  pplot_b <- cbind(mort_bioassay, dtk_blocking) |>
    as.data.frame() |>
    ggplot() +
    scale_y_continuous(lim = c(0, 1), breaks = seq(0, 1, 0.2)) +
    scale_x_continuous(lim = c(0, 1), breaks = seq(0, 1, 0.2)) +
    geom_hline(yintercept = 0.9, col = 'grey', linetype = 'dashed') +
    geom_text(y = 0.93, x = 0.15, label = 'dtk baseline ITN', col = 'grey') +
    geom_rect(xmin = -Inf, xmax = Inf, ymin = 0.32, ymax = 0.47, fill = 'grey', alpha = 0.02) +
    geom_text(y = 0.45, x = 0.35, label = 'untreated net West African EHTs*', col = 'darkgrey') +
    geom_line(aes(x = mort_bioassay, y = dtk_blocking)) +
    theme_cowplot() +
    labs(y = 'ITN initial blocking rate',
         x = 'Bioassay permethrin mortality',
         subtitle = '(Statistical relationship from Nash et al 2021)',
         title = 'ITN blocking: logistic model, no scaling',
         caption = '* Ngufor 2014, Bayili 2017, 2019, Toe 2018') +
    theme(legend.position = 'None') +
    f_getCustomTheme()

  pplot_k <- cbind(mort_bioassay, dtk_killrate) |>
    as.data.frame() |>
    ggplot() +
    geom_hline(yintercept = c(estimated_killing, dtk_killing), linetype = 'dashed') +
    geom_vline(xintercept = bioassay_mort, linetype = 'dashed') +
    geom_rect(xmin = bioassay_mort + 0.001, xmax = Inf, ymin = -Inf, ymax = Inf, fill = 'white') +
    geom_rect(xmin = -Inf, xmax = Inf, ymin = max(estimated_killing, dtk_killing) + 0.005, ymax = Inf, fill = 'white') +
    geom_hline(yintercept = 0.6, col = 'grey', linetype = 'dashed') +
    geom_text(y = 0.63, x = 0.08, label = 'dtk baseline ITN', col = 'grey') +
    geom_line(aes(x = mort_bioassay, y = dtk_killrate, col = 'Reference from hut trials)')) +
    geom_line(aes(x = mort_bioassay, y = dtk_killrate * scl, col = 'Simulation equivalent in dtk')) +
    scale_y_continuous(lim = c(0, 1), breaks = seq(0, 1, 0.2)) +
    scale_x_continuous(lim = c(0, 1), breaks = seq(0, 1, 0.2)) +
    labs(y = 'ITN initial killing rate',
         x = 'Bioassay permethrin mortality',
         color = '',
         subtitle = '(Statistical relationship from Nash et al 2021)',
         caption = paste0('Bioassay mortality used: ', round(bioassay_mort * 100, 1), ' in 2014 (Tiono et al 2018)'),
         title = paste0('ITN kill rate: loglogistic model with scaling factor ', round(scl, 3))) +
    scale_color_manual(values = c('dodgerblue3', 'orange')) +
    theme_cowplot() +
    f_getCustomTheme() +
    theme(legend.position = c(0.1, 0.87))

  pplot <- plot_grid(pplot_k, pplot_b, rel_widths = c(1, 0.7), rel_heights = c(1, 1), align = 'h')
  pplot

  f_save_plot(pplot, paste0('rescaled_relationship_bioassay_mort_to_EHT-dtk_killing'),
              file.path(out_dir), width = 12, height = 5)

  #### Consideration of rescaling to base-ITN effects in dtk
  add_rescaled_to_basedtk <- T
  if (add_rescaled_to_basedtk) {
    dtk_scl <- dtk_killrate * scl
    dtk_rscl <- rescale(dtk_scl, c(min(dtk_scl), 0.6), c(min(dtk_scl), max(dtk_scl)))

    rescale_to_dtk_baseITNkilling_df <- as.data.frame(cbind(mort_bioassay, scl, dtk_rscl / dtk_scl)) |>
      rename(dtk_scl_factor = scl, baseITN_scl_factor = V3)
    fwrite(rescale_to_dtk_baseITNkilling_df, file.path(out_dir, 'rescale_to_dtk_baseITNkilling.csv'))

    pplot_k <- pplot_k +
      geom_line(aes(x = mort_bioassay, y = dtk_rscl, col = 'Simulation equivalent in dtk rescaled'),
                linetype = 'dotdash') +
      scale_color_manual(values = c('dodgerblue3', 'orange', 'orange', 'dodgerblue3'))

    pplot <- plot_grid(pplot_k, pplot_b, rel_widths = c(1, 0.7), rel_heights = c(1, 1), align = 'h')
    pplot
    f_save_plot(pplot, paste0('rescaled_relationship_bioassay_mort_to_EHT-dtk_killing_v2'),
                file.path(out_dir), width = 12, height = 5)

  }

}
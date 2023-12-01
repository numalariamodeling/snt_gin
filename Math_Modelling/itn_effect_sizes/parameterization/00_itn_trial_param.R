## --------------------------- 00_itn_trial_param.R  ---------------------------
## Reproduced figures showing the relationships from Nash et al 2021, for EMOD
##------------------------------------------------------------

library(dplyr)
library(tidyr)
library(data.table)
library(ggplot2)
library(cowplot)
library(scales)

source(file.path('Math_Modelling', 'itn_effect_sizes', 'itn_dtk_block_kill_functions.R'))
source(file.path('Math_Modelling', 'itn_effect_sizes', 'r_helper.R'))
theme_set(theme_bw())

box_dir <- file.path(Sys.getenv('USERPROFILE'), 'NU Malaria Modeling Dropbox', 'projects')
project_dir <- file.path(box_dir, 'emod_itn_exploration')
out_dir <- file.path('Math_Modelling', 'itn_effect_sizes', 'figures')


f_get_parameters <- function(mort_bioassay, insecticide = 'permethrin') {
  mort_EHT1 <- get_hut_mortality_from_bioassay_mortality(mort_bioassay, fit_version = 'logistic_Nash', fit_location = 'west_huts')
  mort_EHT2 <- get_hut_mortality_from_bioassay_mortality(mort_bioassay, fit_version = 'logistic_Nash')
  mort_EHT3 <- get_hut_mortality_from_bioassay_mortality(mort_bioassay, fit_version = 'loglogistic_Nash')
  mort_EHT <- c(mort_EHT1, mort_EHT2, mort_EHT3) ## sensitivity analysis, compare differences in assumptions made
  bloodfed_EHT <- get_hut_BF_from_hut_mortality(hut_mortality = mort_EHT, fit_version_BF = 'Nash_2021')
  dtk_block_kill <- get_dtk_block_kill_from_hut_mort_BF(mort_EHT, bloodfed_EHT, frac_reassign_feed_survive)[[1]]

  param_df <- list('insecticide' = rep(insecticide, 3),
                   'mort_bioassay' = rep(mort_bioassay, 3),
                   'fit_version' = c('logistic_Nash_westHuts', 'logistic_Nash', 'loglogistic_Nash'),
                   'mort_EHT' = mort_EHT,
                   'bloodfed_EHT' = bloodfed_EHT,
                   'dtk_block' = dtk_block_kill[[1]], 'dtk_kill' = dtk_block_kill[[2]]) %>% bind_rows()
  return(param_df)
}

permethrin_mort_bioassay <- seq(0, 1, 0.01)
permethrin_mort_EHT <- get_hut_mortality_from_bioassay_mortality(permethrin_mort_bioassay, fit_version = 'loglogistic_Nash')
permethrin_bloodfed_EHT <- get_hut_BF_from_hut_mortality(hut_mortality = permethrin_mort_EHT, fit_version_BF = 'Nash_2021')

permethrin_mort_EHT_loglogistic_all <- get_hut_mortality_from_bioassay_mortality(permethrin_mort_bioassay, fit_version = 'loglogistic_Nash')
permethrin_mort_EHT_loglogistic_west <- get_hut_mortality_from_bioassay_mortality(permethrin_mort_bioassay, fit_version = 'loglogistic_Nash', fit_location = 'west_huts')
permethrin_mort_EHT_loglogistic_east <- get_hut_mortality_from_bioassay_mortality(permethrin_mort_bioassay, fit_version = 'loglogistic_Nash', fit_location = 'east_huts')

permethrin_mort_EHT_logistic_all <- get_hut_mortality_from_bioassay_mortality(permethrin_mort_bioassay, fit_version = 'logistic_Nash')
permethrin_mort_EHT_logistic_west <- get_hut_mortality_from_bioassay_mortality(permethrin_mort_bioassay, fit_version = 'logistic_Nash', fit_location = 'west_huts')
permethrin_mort_EHT_logistic_east <- get_hut_mortality_from_bioassay_mortality(permethrin_mort_bioassay, fit_version = 'logistic_Nash', fit_location = 'east_huts')

p0 <- cbind(permethrin_mort_bioassay,
            permethrin_mort_EHT_loglogistic_all, permethrin_mort_EHT_loglogistic_west, permethrin_mort_EHT_loglogistic_east,
            permethrin_mort_EHT_logistic_all, permethrin_mort_EHT_logistic_west, permethrin_mort_EHT_logistic_east) %>%
  as.data.frame() %>%
  pivot_longer(cols = -permethrin_mort_bioassay) %>%
  mutate(name = gsub('permethrin_mort_EHT_', '', name)) %>%
  separate(name, into = c('model', 'location'), sep = '_') %>%
  rename(permethrin_mort_EHT = value) %>%
  ggplot() +
  geom_line(aes(x = permethrin_mort_bioassay, y = permethrin_mort_EHT, col = model, linetype = location)) +
  scale_y_continuous(lim = c(0, 1)) +
  scale_x_continuous(lim = c(0, 1)) +
  scale_color_brewer(palette = 'Dark2') +
  labs(x = 'permethrin bioassay mortality',
       y = 'permethrin EHT mortality') +
  f_getCustomTheme() +
  theme(legend.position = c(0.2, 0.7))

params_and_fractions <- get_dtk_block_kill_from_hut_mort_BF(permethrin_mort_EHT_logistic_west, permethrin_bloodfed_EHT, frac_reassign_feed_survive)

dtk_params <- params_and_fractions[[1]] %>%
  bind_cols() %>%
  bind_cols(permethrin_mort_bioassay) %>%
  setNames(c('dtk_blocking_rate', 'dtk_killing_rate', 'permethrin_mort_bioassay')) %>%
  pivot_longer(-permethrin_mort_bioassay)

p1 <- cbind(permethrin_mort_bioassay, permethrin_mort_EHT_logistic_west, permethrin_bloodfed_EHT) %>%
  as.data.frame() %>%
  pivot_longer(-permethrin_mort_bioassay) %>%
  bind_rows(dtk_params) %>%
  mutate(name = gsub('permethrin_', '  ', name)) %>%
  mutate(name = gsub('dtk_', ' dtk_', name)) %>%
  ggplot() +
  #geom_point(aes(x = permethrin_mort_bioassay, y = value, group = name)) +
  geom_line(aes(x = permethrin_mort_bioassay, y = value)) +
  scale_y_continuous(lim = c(0, 1)) +
  scale_x_continuous(lim = c(0, 1)) +
  scale_color_brewer(palette = 'Dark2') +
  labs(title = '', color = '') +
  f_getCustomTheme() +
  theme(legend.position = 'none', panel.spacing = unit(2, "lines")) + #legend.position = 'top',
  facet_wrap(~name, ncol = 2)

p2 <- params_and_fractions[[2]] %>%
  bind_cols() %>%
  bind_cols(permethrin_mort_bioassay) %>%
  setNames(c('ab_BF_survive', 'c_noBF_survive', 'd_noBF_die', 'permethrin_mort_bioassay')) %>%
  pivot_longer(-permethrin_mort_bioassay) %>%
  ggplot() +
  geom_area(aes(x = permethrin_mort_bioassay, y = (-1 * value), fill = name)) +
  scale_y_continuous(breaks = seq(-1, 0, 0.2), labels = rev(seq(-1, 0, 0.2) * -1)) +
  scale_x_continuous(lim = c(0, 1)) +
  scale_fill_manual(values = c('#003f5c', '#ef5675', '#ffa600')) +
  labs(fill = '', y = 'probability') +
  f_getCustomTheme()

p3 <- params_and_fractions[[3]] %>%
  bind_cols() %>%
  bind_cols(permethrin_mort_bioassay) %>%
  setNames(c('a_BF_survive', 'b_BF_die', 'c_noBF_survive', 'd_noBF_die', 'permethrin_mort_bioassay')) %>%
  pivot_longer(-permethrin_mort_bioassay) %>%
  ggplot() +
  geom_area(aes(x = permethrin_mort_bioassay, y = (-1 * value), fill = name)) +
  scale_y_continuous(breaks = seq(-1, 0, 0.2), labels = rev(seq(-1, 0, 0.2) * -1)) +
  scale_x_continuous(lim = c(0, 1)) +
  scale_fill_manual(values = c('#003f5c', '#7a5195', '#ef5675', '#ffa600')) +
  labs(fill = '', y = 'probability') +
  f_getCustomTheme()


p32 <- plot_grid(p3, p2, ncol = 2)
pplot <- plot_grid(p0, p1, ncol = 2, rel_widths = c(1, 0.6))
pplot <- plot_grid(pplot, p32, ncol = 1, rel_heights = c(1, 0.6))

pplot
f_save_plot(pplot, paste0('replotted_relationships_Nash2021'), file.path(out_dir), width = 10, height = 6)


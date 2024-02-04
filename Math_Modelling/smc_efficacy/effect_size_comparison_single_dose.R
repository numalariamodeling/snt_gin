library(dplyr)
library(data.table)
library(tidyr)
library(ggplot2)
library(stringr)
library(lubridate)
library(cowplot)
source(file.path("Math_Modelling", "load_path_lib.R"))
theme_set(theme_cowplot())


simoutdir <- file.path(projdir, "simulation_output")
milligan_ref <- data.frame(Week = 0:9, eff = c(97, 94, 90, 81, 60, 25, 0, 0, 0, 0))
ref_df_cum <- fread(file.path(projdir, 'ref_dat', 'access_SMC_PE_values.csv')) %>%
  filter(SMC != "43+ days ago")

exp_name <- "milligan_vaccSMC_eirsweep_v2"

out_milligan <- fread(file.path(simoutdir, exp_name, 'cases.csv')) %>%
  filter(Age == 5) %>%
  dplyr::select(-V1) %>%
  rename(Week = Interval) %>%
  mutate(annual_EIR = round(annual_EIR, 0), SMCcov = ifelse(Sample_id == 99, 0, 1))

out_milligan_counterfactual <- out_milligan %>%
  filter(SMCcov == 0) %>%
  select(-Sample_id)

out_milligan <- out_milligan %>%
  group_by(Week, annual_EIR) %>%
  mutate(efficacy = ((Case[SMCcov == 0] - Case) / Case[SMCcov == 0]) * 100) %>%
  group_by(Sample_id, annual_EIR) %>%
  arrange(Week) %>%
  mutate(efficacy_cum = cummean(efficacy))


describe_timeline <- T
if (describe_timeline) {
  ggplot(data = subset(out_milligan, Sample_id %in% c(0, 99))) +
    geom_vline(xintercept = 365 / 7, linetype = 'dashed') +
    geom_line(aes(x = Week, y = Case, col = as.factor(Sample_id))) +
    geom_ribbon(aes(x = Week, ymin = Case_min, ymax = Case_max, fill = as.factor(Sample_id), group = Sample_id), alpha = 0.3) +
    labs(y = 'Cases per person per year U5', col = '', fill = '') +
    scale_y_continuous(expand = c(0, 0)) +
    facet_wrap(~annual_EIR, ncol = 1)


  ggplot(data = subset(out_milligan, Week <= 20 & Sample_id == 0)) +
    geom_line(data = subset(out_milligan_counterfactual, Week <= 20), aes(x = Week, y = Case, col = 'no SMC')) +
    geom_line(aes(x = Week, y = Case, col = 'SMC')) +
    geom_ribbon(aes(x = Week, ymin = Case_min, ymax = Case_max, group = Sample_id), fill = 'darkorange', alpha = 0.3) +
    labs(y = 'Cases per person per year U5', col = '', fill = '') +
    scale_x_continuous(breaks = c(0:20)) +
    geom_hline(yintercept = 0) +
    scale_color_manual(values = c('grey', 'darkorange')) +
    facet_wrap(~annual_EIR, ncol = 1)


  xmax <- 20
  ggplot(data = subset(out_milligan, Week <= xmax & Sample_id != 99)) +
    geom_line(data = subset(out_milligan_counterfactual, Week <= xmax), aes(x = Week, y = Case)) +
    geom_line(aes(x = Week, y = Case, col = as.factor(Sample_id))) +
    labs(y = 'Cases per person per year U5', col = '', fill = '') +
    facet_wrap(~annual_EIR, scales = 'free_y')

  ggplot(data = subset(out_milligan, Week <= 15 & Sample_id != 99)) +
    geom_point(data = milligan_ref, aes(x = Week, y = eff)) +
    geom_line(aes(x = Week, y = efficacy, col = as.factor(Sample_id))) +
    labs(y = 'Cases per person per year U5', col = '', fill = '') +
    facet_wrap(~annual_EIR)

  out_milligan_simpleVacc <- out_milligan
  fwrite(out_milligan_simpleVacc, file.path('out_milligan_simpleVacc.csv'))

  ggplot(data = subset(out_milligan, Week <= 15 & Sample_id %in% c(6, 7, 8, 9, 10))) +  #4,
    geom_hline(yintercept = 0) +
    geom_point(data = milligan_ref, aes(x = Week, y = eff)) +
    geom_line(aes(x = Week, y = efficacy, col = as.factor(Sample_id))) +
    labs(y = 'Cases per person per year U5', col = '', fill = '') +
    facet_wrap(~annual_EIR, labeller = label_both)

  pplot <- ggplot(data = subset(out_milligan, Week <= 52 & Sample_id %in% c(0, 6, 7, 8))) +  #4,
    geom_hline(yintercept = 0) +
    geom_vline(xintercept = 4) +
    geom_line(aes(x = Week, y = efficacy_cum, col = as.factor(Sample_id))) +
    labs(y = 'Cumulative efficacy (%)', col = '', fill = '') +
    scale_y_continuous() +
    scale_x_continuous(breaks = seq(0, 52, 4)) +
    theme_bw() +
    facet_wrap(~annual_EIR, labeller = label_both)

  print(pplot)
  pplot <- ggplot(data = subset(out_milligan, Sample_id != 99 & Week <= 10)) +  #4,
    geom_hline(yintercept = 0) +
    geom_line(aes(x = Week, y = efficacy_cum, group = Sample_id, linetype = as.factor(Sample_id), col = 'Simulation samples')) +
    scale_y_continuous(lim = c(-40, 100), breaks = seq(-40, 100, 10), expand = c(0, 0)) +
    theme_bw() +
    geom_errorbar(aes(x = 3.9, y = 74, ymin = 62, ymax = 87), col = '#80aaff', width = 0) +
    geom_point(aes(x = 3.9, y = 74, col = 'IPTc cochrane'), shape = 5) +
    geom_point(data = subset(ref_df_cum, SMC == 'within previous 28 days'),
               aes(x = 4, y = PE, col = 'Cairns 2021')) +
    geom_errorbar(aes(x = 4, ymin = 79, ymax = 94), col = '#ff9999', width = 0, alpha = 0.6) +
    geom_point(data = subset(ref_df_cum, SMC == 'within previous 28 days'),
               aes(x = 4, y = 88, col = 'Cairns 2021 pooled'), shape = 4, size = 1.3) +
    geom_point(data = subset(ref_df_cum, SMC == '29-42 days ago'),
               aes(x = 6, y = PE, col = 'Cairns 2021')) +
    scale_color_manual(values = c('#ff6600', 'red', '#3366ff', '#4d4d4d')) +
    scale_x_continuous(breaks = c(1:12)) +
    labs(title = 'Cumulative SMC efficacy, SMC (100% coverage, single round)\nCM = 50%',
         x = 'Weeks since first round SMC',
         y = 'Cumulative efficacy (%)', color = '', linetype = 'Sample ID') +
    facet_wrap(~annual_EIR, labeller = label_both)

  print(pplot)
  ### Cumulative
  subset(out_milligan, Week == 4) %>%
    dplyr::select(Sample_id, efficacy_cum)


}

eff_during_SMCperiod1 = F
if (eff_during_SMCperiod1) {

  df28 <- out_milligan %>%
    filter(Week <= 4) %>%
    group_by(Sample_id, SMCcov) %>%
    summarize(Case = sum(Case),
              efficacy_mean = mean(efficacy)) %>%
    ungroup() %>%
    mutate(efficacy = ((Case[SMCcov == 0] - Case) / Case[SMCcov == 0]) * 100) %>%
    mutate(week = 'within previous 28 days') %>%
    filter(SMCcov != 0)

  df42 <- out_milligan %>%
    filter(Week > 4 & Week <= 6) %>%
    group_by(Sample_id, SMCcov) %>%
    summarize(Case = sum(Case),
              efficacy_mean = mean(efficacy)) %>%
    ungroup() %>%
    mutate(efficacy = ((Case[SMCcov == 0] - Case) / Case[SMCcov == 0]) * 100) %>%
    mutate(week = '29-42 days ago') %>%
    filter(SMCcov != 0)


  df <- bind_rows(df28, df42)

  ggplot(data = df) +
    geom_point(aes(x = as.factor(week), y = efficacy, col = as.factor(Sample_id)),
               position = position_dodge(width = 0.6), width = 0.6) +
    geom_point(data = ref_df_cum,
               aes(x = SMC, y = PE))

}


eff_during_SMCperiod2 = F
if (eff_during_SMCperiod2) {

  df_list <- list()
  for (w in c(4:10)) {
    df_list[[w]] <- out_milligan %>%
      filter(Week <= w & SMCcov != 0) %>%
      group_by(Sample_id) %>%
      summarize(efficacy = mean(efficacy)) %>%
      mutate(week = w)
  }
  df <- bind_rows(df_list)

  ggplot(data = df) +
    geom_col(aes(x = as.factor(week), y = efficacy, fill = as.factor(Sample_id)),
             position = position_dodge(width = 0.6), width = 0.6) +
    geom_hline(yintercept = c(0, 25, 50, 75)) +
    labs(fill = '') +
    scale_y_continuous(lim = c(0, 100), breaks = seq(0, 100, 25), expand = c(0, 0)) +
    scale_fill_brewer(palette = 'Set2')

}




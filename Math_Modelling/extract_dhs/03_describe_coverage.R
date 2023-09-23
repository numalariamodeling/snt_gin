## --------------------------- 03_describe_coverage.R ---------------------------
## Describe RTS,S and PMC coverages, based on 2018 DHS for Guinea
## Read in crude and modified EPI coverages per admin1 and admin2 (from script 01_ and 02_)
## Input: cluster_DS_DHS2018.csv, rtss_EPIcov_2023-2029.csv, pmc3_EPIcov_2023-2029.csv
## Output: Plots and maps describing RTS,S and PMC coverages
##------------------------------------------------------------

source("Math_Modelling/load_path_lib.R")
source("Math_Modelling/extract_dhs/functions.R")

scendir <- file.path(projdir, "simulation_inputs/_scenarios_2023")
dhsepi_dir <- file.path(projdir, 'DS_DHS_estimates', 'EPI')
fig_dir <- file.path(getwd(), 'Math_Modelling/extract_dhs', 'figures')

library(tidyr)
library(cowplot)
theme_set(theme_cowplot())

##------------------------------------------------------------

# Load and transform shapefiles
myproj <- "+proj=longlat +datum=WGS84 +no_defs"
shp_dir <- file.path(boxdir, 'data', 'guinea_shapefiles')
shp_admin1 <- shapefile(file.path(shp_dir, 'GIN_adm_shp', 'GIN_adm1.shp'))
shp_admin2 <- shapefile(file.path(shp_dir, 'Guinea_Health_District', 'GIN_adm2.shp'))
spTransform(shp_admin1, myproj)
spTransform(shp_admin2, myproj)
admin2_sp.f <- fortify(shp_admin2, region = "NAME_2") |>
  dplyr::mutate(NAME_2 = id)

# Load master csv files
DSpop <- data.table::fread(master_csv) |>
  dplyr::select(DS_Name, NAME_2, seasonality_archetype, seasonality_archetype_2) |>
  unique()

clusterDS <- data.table::fread(file.path(projdir, 'DS_DHS_estimates', 'cluster_DS_DHS2018.csv')) |>
  dplyr::select(NAME_1, NAME_2, DS_Name, seasonality_archetype, seasonality_archetype_2)  |>
  unique()

clusterDS$NAME_2[clusterDS$NAME_2 == 'Yamou'] <- 'Yomou'

DSpop <- DSpop |>
  left_join(clusterDS[, c('NAME_1', 'NAME_2')]) |>
  mutate(admin1 = NAME_1)

##------------------------------------------------------------

describeRTSScov <- TRUE
describePMCcov <- TRUE

if (describeRTSScov) {
  rtss_df <- data.table::fread(file.path(scendir, 'rtss', 'rtss_EPIcov_2023-2029.csv')) |>
    filter(vaccine == 'simple')|>
    mutate(coverage_levels = coverage_levels * 100)

  rtss_df$NAME_2 <- (rtss_df$DS_Name)
  unique(rtss_df$NAME_2[!(rtss_df$NAME_2 %in% unique(admin2_sp.f$NAME_2))])
  rtss_df$NAME_2 <- iconv(rtss_df$NAME_2, from = 'UTF-8', "ASCII//TRANSLIT")
  admin2_sp.f$NAME_2 <- iconv(admin2_sp.f$NAME_2, from = 'UTF-8', "ASCII//TRANSLIT")
  admin2_sp.f$NAME_2[admin2_sp.f$NAME_2 == 'Yamou'] <- 'Yomou'
  sort(unique(rtss_df$NAME_2))
  sort(unique(shp_admin2$NAME_2))

  plot_dat <- admin2_sp.f |>
    left_join(rtss_df) |>
    filter(!is.na(coverage_levels))

  plot_dat$coverage_levels_fct <- cut(plot_dat$coverage_levels, c(-Inf, 20, 40, 60, 80, 100, Inf))
  table(plot_dat$coverage_levels_fct)

  pplot_map <- ggplot(warnings = FALSE) +
    geom_polygon(
      data = admin2_sp.f,
      aes(x = long, y = lat, group = group), fill = '#e6e7e8', col = "black", linewidth = 0.2) +
    geom_polygon(
      data = subset(plot_dat),
      aes(x = long, y = lat, group = group, fill = coverage_levels), col = "black", linewidth = 0.2) +
    theme_map() +
    theme(legend.position = 'right',
          strip.text.x = element_text(size = 12, face = "bold"),
          strip.text.y = element_text(size = 12, face = "bold"),
          strip.background = element_blank()) +
    labs(fill = 'RTS,S coverage (%)\nprimary sequence using measles as proxy', caption = 'DHS 2018') +
    theme(strip.text.y.left = element_text(angle = -360)) +
    scale_fill_viridis_c(option = 'D', limits = c(0, 100), begin = 0, end = 1, direction = 1)

  f_save_plot(pplot_map, 'RTSS-measles_cov_map', file.path(fig_dir), width = 10, height = 7)

  # DS level
  rtss_df_DS <- fread(file.path(dhsepi_dir, 'vacc_cov_DS_DHS2018.csv')) |> filter(vaccine == 'measles')
  rtss_df_DS$NAME_2 <- (rtss_df_DS$DS_Name)
  unique(rtss_df$NAME_2[!(rtss_df_DS$NAME_2 %in% unique(admin2_sp.f$NAME_2))])
  rtss_df_DS$NAME_2 <- iconv(rtss_df_DS$NAME_2, from = 'UTF-8', "ASCII//TRANSLIT")
  rtss_df_DS$coverage_levels <- rtss_df_DS$mean * 100

  plot_dat <- admin2_sp.f |>
    left_join(rtss_df_DS) |>
    filter(!is.na(coverage_levels))

  plot_dat$coverage_levels_fct <- cut(plot_dat$coverage_levels, c(-Inf, 20, 40, 60, 80, 100, Inf))
  table(plot_dat$coverage_levels_fct)

  pplot_map <- ggplot(warnings = FALSE) +
    geom_polygon(
      data = admin2_sp.f,
      aes(x = long, y = lat, group = group), fill = '#e6e7e8', col = "black", linewidth = 0.2) +
    geom_polygon(
      data = subset(plot_dat),
      aes(x = long, y = lat, group = group, fill = coverage_levels), col = "black", linewidth = 0.2) +
    theme_map() +
    theme(legend.position = 'right',
          strip.text.x = element_text(size = 12, face = "bold"),
          strip.text.y = element_text(size = 12, face = "bold"),
          strip.background = element_blank()) +
    labs(fill = 'RTS,S coverage (%)\nprimary sequence using measles as proxy', caption = 'DHS 2018') +
    theme(strip.text.y.left = element_text(angle = -360)) +
    scale_fill_viridis_c(option = 'D', limits = c(0, 100), begin = 0, end = 1, direction = 1)

  f_save_plot(pplot_map, 'RTSS-measles_cov_map_DS', file.path(fig_dir), width = 10, height = 7)


}

##------------------------------------------------------------

if (describePMCcov) {
  pmc_df_eligible <- data.table::fread(file.path(scendir, 'pmc', 'pmc3_EPIcov_2023-2029.csv'))

  pmc_df <- data.table::fread(file.path(dhsepi_dir, 'pmc3_cov_DS.csv')) |>
    filter(DS_Name %in% pmc_df_eligible$DS_Name) |>
    mutate(pmc_coverage = pmc_coverage * 100,
           pmc_coverage_adj = pmc_coverage_adj * 100)

  pmc_df$vaccine <- factor(pmc_df$vaccine,
                           levels = c('DPT-2', 'DPT-3', 'measles'),
                           labels = c('DPT-2', 'DPT-3', 'measles'))

  pmc_df$NAME_2 <- (pmc_df$DS_Name)
  unique(pmc_df$NAME_2[!(pmc_df$NAME_2 %in% unique(admin2_sp.f$NAME_2))])
  pmc_df$NAME_2 <- iconv(pmc_df$NAME_2, from = 'UTF-8', "ASCII//TRANSLIT")
  sort(unique(pmc_df$NAME_2))
  sort(unique(shp_admin2$NAME_2))

  pmc_df$pmc_coverage_fct <- cut(pmc_df$pmc_coverage, c(-Inf, 20, 40, 60, 80, 100, Inf))
  pmc_df$pmc_coverage_adj_fct <- cut(pmc_df$pmc_coverage_adj, c(-Inf, 20, 40, 60, 80, 100, Inf))
  table(pmc_df$pmc_coverage_fct)

  plot_dat <- admin2_sp.f |>
    left_join(pmc_df) |>
    filter(!is.na(pmc_coverage))

  pplot_map <- ggplot(warnings = FALSE) +
    geom_polygon(
      data = admin2_sp.f,
      aes(x = long, y = lat, group = group), fill = '#e6e7e8', col = "black", linewidth = 0.2) +
    geom_polygon(
      data = subset(plot_dat),
      aes(x = long, y = lat, group = group, fill = pmc_coverage_adj), col = "black", linewidth = 0.2) +  #value_fct
    facet_grid(~pmc_dose, switch = 'y') +
    theme_map() +
    theme(legend.position = 'right',
          strip.text.x = element_text(size = 12, face = "bold"),
          strip.text.y = element_text(size = 12, face = "bold"),
          strip.background = element_blank()) +
    labs(fill = 'PMC coverage per dose (%)n/in eligible areas', caption = 'DHS 2018') +
    theme(strip.text.y.left = element_text(angle = -360)) +
    scale_fill_viridis_c(option = 'D', limits = c(0, 100), begin = 0, end = 1, direction = 1)

  f_save_plot(pplot_map, 'pmc_cov_map', fig_dir, width = 16, height = 6)

  # DS level
  sclalefactors <- c(0.8383085, 0.9556575, 0.6973180)
  pmc_df_DS <- fread(file.path(dhsepi_dir, 'vacc_cov_DS_DHS2018.csv')) |>
    filter(DS_Name %in% pmc_df_eligible$DS_Name) |>
    filter(vaccine %in% unique(pmc_df$vaccine)) |>
    mutate(pmc_coverage = mean * 100)

  pmc_df_DS <- pmc_df_DS |>
    mutate(pmc_coverage_adj = case_when(vaccine == 'DPT-2' ~ pmc_coverage * sclalefactors[1],
                                        vaccine == 'DPT-3' ~ pmc_coverage * sclalefactors[2],
                                        vaccine == 'measles' ~ pmc_coverage * sclalefactors[3]),
           pmc_coverage_adj = ifelse(pmc_coverage_adj < 0.2, 0.2, pmc_coverage_adj)) |>
    relocate(pmc_coverage, .before = pmc_coverage_adj)

  pmc_df_DS$pmc_coverage_fct <- cut(pmc_df_DS$pmc_coverage, c(-Inf, 20, 40, 60, 80, 100, Inf))

  ps <- ggplot() +
    geom_point(data = pmc_df_DS, aes(x = pmc_coverage, y = pmc_coverage_adj, group = pmc_coverage_fct), alpha = 0.5) +
    geom_point(data = pmc_df, aes(x = pmc_coverage, y = pmc_coverage_adj, col = as.factor(pmc_dose))) +
    geom_abline(intercept = 0, slope = 1) +
    scale_y_continuous(lim = c(0, 100)) +
    scale_x_continuous(lim = c(0, 100)) +
    labs(color = '')

  f_save_plot(ps, 'pmc_scatter', fig_dir, width = 6, height = 4)

}


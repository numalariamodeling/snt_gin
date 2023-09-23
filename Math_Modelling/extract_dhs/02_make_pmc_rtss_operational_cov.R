## --------------------------- 02_make_pmc_rtss_operational_cov.R ---------------------------
## Transform EPI extracted coverage to appropriate input for RTS,S and PMC coverages files
## Input: cluster_DS_DHS2018.csv, vacc_cov_admin1_DHS2018.csv  (use admin 1)
## Output: pmc3_cov_DS.csv, rtss_cov_DS.csv per admin2 (apply to admin2 areas)
##------------------------------------------------------------

source("Math_Modeling/load_path_lib.R")
source("Math_Modeling/extract_dhs/functions.R")
library(tidyr)

### Load admin1 DHS data and repeat per admin2 level for scenario input csvs
dhsepi_dir <- file.path(projdir, 'DS_DHS_estimates', 'EPI')

DSpop <- data.table::fread(master_csv) |> dplyr::select(DS_Name, NAME_2)

clusterDS <- data.table::fread(file.path(projdir, 'DS_DHS_estimates', 'cluster_DS_DHS2018.csv')) |>
  dplyr::select(NAME_1, NAME_2, DS_Name)  |>
  unique()
clusterDS$NAME_2[clusterDS$NAME_2 == 'Yamou'] <- 'Yomou'

DSpop <- DSpop |>
  left_join(clusterDS[, c('NAME_1', 'NAME_2')]) |>
  dplyr::select(DS_Name, NAME_1, NAME_2)


# Custom functions to get EPI to PMC downscaling factors
EPI_to_pmc_cov <- function() {
  #https://malariajournal.biomedcentral.com/articles/10.1186/s12936-021-03615-3
  epicov_mean <- c(0.804, 0.654, 0.522)
  ipticov_mean <- c(0.674, 0.625, 0.364)
  downscaling <- ipticov_mean / epicov_mean
  return(downscaling)
}

# Read in EPI coverage data and adjust for PMC , keep original one as an option too
# Raw estimates DHS 2018 , use ADMIN 1 data extract
pmc_cov_DHS <- data.table::fread(file.path(dhsepi_dir, 'vacc_cov_admin1_DHS2018.csv')) |>
  mutate(NAME_1 = match_names(NAME_1, DSpop$NAME_1)) |>
  filter(vaccine %in% c('DPT-2', 'DPT-3', 'measles')) |>
  dplyr::select(NAME_1, vaccine, recommended_age, mean) |>
  group_by(vaccine) |>
  mutate(pmc_dose = cur_group_id()) |>  # for PMC with 3 rounds matched to DTP2, 3 and measles
  rename(pmc_age_days = recommended_age,
         pmc_coverage = mean)

pmc_cov_DHS <- DSpop |> left_join(pmc_cov_DHS)

# Adjust  DHS 2018 EPI  to PMC
sclalefactors <- EPI_to_pmc_cov()

pmc_cov_DHS <- pmc_cov_DHS |>
  mutate(pmc_coverage_adj = case_when(vaccine == 'DPT-2' ~ pmc_coverage * sclalefactors[1],
                                      vaccine == 'DPT-3' ~ pmc_coverage * sclalefactors[2],
                                      vaccine == 'measles' ~ pmc_coverage * sclalefactors[3]),
         pmc_coverage_adj = ifelse(pmc_coverage_adj < 0.2, 0.2, pmc_coverage_adj)) |>
  relocate(pmc_coverage, .before = pmc_coverage_adj)

# Write out for PMC
pmc_cov_DHS |>
  data.table::fwrite(file.path(projdir, 'DS_DHS_estimates', 'EPI', 'pmc3_cov_DS.csv'))

# Write out for RTS,S
pmc_cov_DHS |>
  filter(vaccine == 'measles')  |>
  rename_with(~gsub('pmc', 'rtss', .x)) |>
  rename(epi_vaccine = vaccine,
         age_days = rtss_age_days) |>
  data.table::fwrite(file.path(projdir, 'DS_DHS_estimates', 'EPI', 'rtss_cov_DS.csv'))


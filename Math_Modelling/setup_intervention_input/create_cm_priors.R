####
# This script is used to put together the health seeking rate and ACT usage,
# and calculate the mean, upper and lower CI of case management rate for each
# DHS year. Then based on this information, the mean and sd for a Normal
# distribution in logit scale is created for each district.
####

library(dplyr)

master_csv <- "data/guinea_DS_pop.csv"
intdir <- "data/intermediate_data"
master_df <- data.table::fread(master_csv)

# Functions
calc_msd <- function (mean, lower, upper) {
  mlogit <- arm::logit(mean)
  tmp <- (mlogit - arm::logit(lower)) + (arm::logit(upper) - mlogit)
  sdlogit <- tmp/2 / 1.96
  
  return(data.frame(mlogit = mlogit, sdlogit = sdlogit))
}

load_cm_by_ds <- function (indir, year) {
  cm_fname <- paste0("cm_by_ds_", year, ".csv")
  cm_fname <- file.path(intdir, cm_fname)
  cm_df <- data.table::fread(cm_fname)
  cm_df$year <- year
  
  return(cm_df)
}

make_cm_priors <- function (cm_df) {
  cm_priors <- cm_df %>%
    mutate(calc_msd(cm_cov, cm_cov_lci, cm_cov_uci)) %>%
    mutate(Var_Name = paste0("CM_cov_", year),
           Distribution = "normal",
           Transform = "invlogit") %>%
    dplyr::select(DS_Name, Var_Name, Distribution, Transform, 
                  Param1 = mlogit, Param2 = sdlogit)
  
  return(cm_priors)
}

# Putting together
act_use <- data.table::fread(file.path(intdir, "act_perc.csv")) # National rate

cm_df <- data.frame()
for (yr in c(2012, 2018, 2021)) {
  cm_df <- bind_rows(cm_df, load_cm_by_ds(intdir, yr))
}

cm_df1 <- cm_df |>
  left_join(act_use, by = "year") |>
  mutate(across(starts_with("cm_cov"),
                .fns = ~ .x * act_perc))

CM_priors <- make_cm_priors(cm_df1)
CM_priors <- CM_priors |>
  group_by(Var_Name) |>
  mutate(Param1 = ifelse(Param1 == -Inf, min(Param1[Param1 != -Inf]), Param1),
         Param2 = ifelse(is.na(Param2), max(Param2, na.rm = T), Param2))

outfile <- file.path(projdir, "simulation_priors", "CM_priors.csv")
data.table::fwrite(CM_priors, outfile)

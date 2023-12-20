####
# This script is used to covert Loua's SMC data to a dataframe of U5 and O5
# per cycle coverage for each district in each year (with data available)
####

library(dplyr)
library(tidyr)

indir <- "data/smc/"
outdir <- "data/simulation_priors"

# Score function to estimate binomial probability
score_u5 <- function(p, mean_trt, propdose) {
  # p[1] is per cycle coverage for high access
  # p[2] is proportion of low access
  m <- p[1] * 4 * (1 - p[2])
  pd1 <- pbinom((-1):4, 4, p[1]) |> diff()
  pd <- pd1 * (1 - p[2]) + c(p[2], rep(0, 4))
  
  mse1 <- ((m - mean_trt)/4)^2
  mse2 <- mean((pd - propdose)^2)
  
  return(mse1+mse2)
}

# U5 calculation
u5_loua <- file.path(indir, "Loua_2015-2020.csv") |>
  data.table::fread(header = T) |>
  pivot_longer(-DS_Name, names_to = "year", names_transform = as.numeric,
               values_to = "mean_treatment", values_drop_na = T)

u5_cyc_rec <- file.path(indir, "cycle_received_2015-2020.csv") |>
  data.table::fread(header = T)

u5_target <- u5_loua |>
  left_join(u5_cyc_rec, by = c("DS_Name", "year"))

mean_trt <- u5_target$mean_treatment
propdose <- u5_target |>
  select(dose_0:dose_4) |>
  as.matrix()

u5_par <- data.frame()
for (i in 1:nrow(u5_target)) {
  tmp <- optim(c(0.5, 0.5), score_u5, 
               mean_trt = mean_trt[i],
               propdose = propdose[i,],
               method = c("L-BFGS-B"),
               lower = c(0.0001, 0.0001),
               upper = c(0.9999, 0.9999))
  df <- data.frame(coverage_high_access_u5 = tmp$par[1],
                   high_access_u5 = 1 - tmp$par[2])
  u5_par <- bind_rows(u5_par, df)
}

u5_par <- bind_cols(u5_target[,c("DS_Name", "year")], u5_par)

# O5 calculations
o5_loua <- file.path(indir, "Loua_o5_2015-2020.csv") |>
  data.table::fread(header = T) |>
  mutate(ratio = mean_trt_o5 / mean_trt_u5)

o5_estim <- u5_loua |>
  left_join(o5_loua) |>
  mutate(coverage_high_access_o5 = mean_treatment * ratio / 4)

o5_par <- o5_estim |>
  select(DS_Name, year, coverage_high_access_o5) |>
  mutate(high_access_o5 = 1)


# Combine and output to csv
all_estimates <- left_join(u5_par, o5_par,
                           by = c("DS_Name", "year"))
data.table::fwrite(all_estimates,
                   file.path(outdir, "smc_coverages.csv"))

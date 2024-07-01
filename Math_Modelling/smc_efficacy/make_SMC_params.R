library(dplyr)
library(ggplot2)
library(stringr)
library(arm)

wdir <- file.path(getwd(), "Math_Modelling/smc_efficacy")


rnd <- 1
annual_eir <- 30
params_name <- c("vacc_initial_effect", "vacc_box_duration", "vacc_decay_duration")
prior_min <- c(0.8, 7, 2)
prior_max <- c(1, 20, 40)
npar <- 500
nsel <- 50

eff_df <- data.frame(Week = 1:9, eff = c(97, 94, 90, 81, 60, 25, 0, 0, 0))

set.seed(4326)

if (rnd == 1) {
  mat <- matrix(NA, nrow = npar, ncol = length(params_name))
  for (i in 1:length(params_name)) {
    mat[,i] <- runif(npar, prior_min[i], prior_max[i])
    # if (i == 1) mat[,i] <- arm::invlogit(mat[,i])
  }

  colnames(mat) <- params_name
  mat <- rbind(rep(0, 5), mat) # Add control
  df <- as.data.frame(mat)
  df$samp_id <- 1:nrow(df)
  print(head(df))
} else {
  set.seed(4326+rnd)
  simoutdir <- file.path(projectpath, 'simulation_outputs',paste0("vaccSMC_milligan_eir",annual_eir,"_rnd", rnd-1))
  outcsv <- file.path(simoutdir, 'cases.csv')
  df <- data.table::fread(outcsv)

  df1 <- df %>% 
    filter(Age == 5) %>%
    group_by(Interval) %>%
    mutate(base = Case[vacc_initial_effect == 0],
           efficacy = (base - Case)/base)

  df2 <- df1 %>%
    filter(vacc_initial_effect != 0) %>%
    ungroup() %>%
    mutate(Week = Interval - 4) %>%
    select(Week, vacc_initial_effect, vacc_box_duration, vacc_decay_duration, efficacy)

  rank_df <- eff_df %>%
    left_join(df2) %>%
    mutate(se = (eff/100 - efficacy)^2) %>%
    group_by(vacc_initial_effect, vacc_box_duration, vacc_decay_duration) %>%
    summarise(mse = mean(se)) %>%
    arrange(mse)
  
  sel_df <- rank_df[1:50,]
  pplot <- sel_df %>%
    left_join(df1) %>% 
    filter(Interval >= 5, Interval <= 16) %>%
    ggplot() +
    geom_line(aes(x=Interval-4, y=efficacy * 100, 
                  group=interaction(vacc_initial_effect, vacc_box_duration, vacc_decay_duration)),
              alpha = 0.1) +
    geom_point(aes(x=Week, y=eff), eff_df, colour="red") +
    # facet_wrap(~ SMC_cov) +
    theme(legend.title = element_blank())  
  
  ggsave(paste0("vaccsmc_single_param_plot_rnd",rnd-1,".pdf"),plot=pplot, width = 16, height = 12, unit="cm")

  sel_df[,"vacc_initial_effect"] <- arm::logit(sel_df[,"vacc_initial_effect"])
  m <- sel_df[,params_name] %>%
    colMeans
  cat("Mean\n")
  m %>% print

  cat("Marginal SD\n")
  sel_df[,params_name] %>%
    as.matrix() %>%
    cov %>%
    diag %>%
    sqrt %>%
    print

  cat("Correlation matrix\n")
  sel_df[,params_name] %>%
    as.matrix() %>%
    cor %>%
    print
  
  V <- sel_df[,params_name] %>%
    as.matrix() %>%
    cov

  mat <- mvtnorm::rmvnorm(npar, m, V)
  mat[,1] <- arm::invlogit(mat[,1])
  mat <- rbind(rep(0, 3), mat) # Add control
  colnames(mat) <- params_name
  df <- as.data.frame(mat)
  df$samp_id <- 1:nrow(df)
  print(head(df))
}

## working directory at vaccSMC/vaccsmc_single/
if(!(dir.exists(file.path(wdir,"par_out"))))dir.create(file.path(wdir,"par_out"))
fname <-  paste0("rnd", rnd, ".csv")
data.table::fwrite(df, file.path(wdir, "par_out", fname))
print(paste0(fname ,' saved under ', wdir, "/par_out" ))

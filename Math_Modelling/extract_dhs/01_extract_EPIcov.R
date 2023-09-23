## --------------------------- 01_extract_EPIcov.R ---------------------------
# https://dhsprogram.com/data/Guide-to-DHS-Statistics/Vaccination.htm
# Numerator: Number of living children between age 12 and 23 months at the time of the survey who received the specified vaccine.
# Denominator: Number of living children age 12–23 months (b5 = 1 & b19 in 12:23)
# 1) Percentage of children age 12-23 months who received specific vaccines at any time before the survey
#    according to either vaccination card or mother’s report.
# 2) Percentage of children age 12-23 months who received specific vaccines by appropriate age.
# A vaccination is considered to have been given at the appropriate age
# if the vaccination was given within the first 12 months for vaccines scheduled to be given in the first year of life
##------------------------------------------------------------
# Percentage of children 12-23 months who had received no vaccinations (CH_VACS_C_NON)
# Indicator	Received no vaccinations
# Denominator	Children age 12-23 months
# variable h10  "Ever had vaccination"
##------------------------------------------------------------

pckg <- c("haven", "rdhs", "survey", "data.table", "tidyverse", "naniar", "sjlabelled", "stringr", "expss", "xlsx", "glue")
lapply(pckg, require, character.only = TRUE)

options(survey.lonely.psu = "adjust")
source("Math_Modelling/load_path_lib.R")
source("Math_Modelling/extract_dhs/functions.R")

dhs_name <- "GN_2018_DHS_05212020_1029_148964"
KR_fname <- "GNKR71DT/GNKR71FL.DTA"

####__________custom functions_______________
prepare_dat <- function(dat, varname, filterAlive = TRUE, filterAge = c(12, 23), according_to = 'all', Class = '') {
  # Prepare raw KR DHS dataset for analysis
  # @param  dat raw children dataset
  # @param  varname name of vaccine variable to analyse, used to filter the dataframe
  # @param  filterAlive exclude children that died
  # @param  filterAge exclude children not 12-23 years old
  # @param  according_to valid options 'all', 'hbr', 'recall'
  #
  # TODO: allow to filter for vaccinated at appropiate age
  if (filterAlive)dat <- dat |> filter(b5 == 1)
  if (!is.null(filterAge))dat <- dat |> filter(b19 %in% c(filterAge[1]:filterAge[2]))
  dat <- dat |> mutate(w = v005 / 1e6)
  dat <- dat |> as.data.frame()
  dat$vacc_var <- dat[, which(colnames(dat) == varname)]
  dat$vacc_var <- as.numeric(dat$vacc_var)

  keepVars <- dat |>
    dplyr::select(SurveyId, sstate, v001, v005, b5, b19, vacc_var, w, starts_with(varname)) |>
    colnames()

  if (according_to == 'hbr') {
    dat <- dat |>
      dplyr::mutate(vacc_var = ifelse(vacc_var %in% c(2, 8), NA, ifelse(vacc_var == 0, 0, 1))) |>
      dplyr::filter(!is.na(vacc_var)) |>
      dplyr::select_at(.vars = keepVars)
  }
  if (according_to == 'recall') {
    dat <- dat |>
      dplyr::mutate(vacc_var = ifelse(vacc_var %in% c(1, 3, 8), NA, ifelse(vacc_var == 0, 0, 1))) |>
      dplyr::filter(!is.na(vacc_var)) |>
      dplyr::select_at(.vars = keepVars)
  }
  if (according_to == 'all') {
    dat <- dat |>
      dplyr::mutate(vacc_var = ifelse(vacc_var > 3, NA, ifelse(vacc_var == 0, 0, 1))) |>
      dplyr::filter(!is.na(vacc_var)) |>
      dplyr::select_at(.vars = keepVars)
  }

  dat[, varname] <- dat$vacc_var
  dat <- dat |> dplyr::select(-vacc_var)

  if (Class == 'DS' |
    Class == 'DS_Name' |
    Class == 'seasonality_archetype_2') {
    dat <- dat |>
      left_join(clusterDS) |>
      filter(!is.na(DS_Name)) #!!

  }

  return(as.data.table(dat))
}

get_coverage <- function(dat, varname, Class, method = "svyciprop") {
  # Calculate proportion of children vaccinated
  # @param  dat processed children dataset, returned from prepare_dat
  # @param  varname name of vaccine variable to analyse, used to filter the dataframe
  # @param  Class name of variable to group by
  # @param  method svyci method
  dat <- as.data.frame(dat)
  dat$Class <- dat[, colnames(dat) == Class]
  dat$vacc_var <- dat[, colnames(dat) == varname]
  dat <- as.data.table(dat)

  N_raw <- dat |>
    group_by(Class) |>
    summarize(vacc_var = sum(vacc_var), b5 = sum(b5))

  des <- svydesign(~v001 + Class, data = dat, weights = ~w)
  if (method == "svyciprop")cov <- svyby(~vacc_var, ~Class, des, svyciprop, na.rm = TRUE, vartype = "ci")
  if (method == "svymean")cov <- svyby(~vacc_var, ~Class, des, svymean, na.rm = TRUE, vartype = "se")
  denom <- svyby(~b5, ~Class, des, svytotal, na.rm = TRUE)
  cov <- cov |> rename(mean = vacc_var)
  denom <- denom |>
    rename(denom_b5_wt = b5) |>
    dplyr::select(-se)

  out_cov <- cov |> left_join(denom) |> left_join(N_raw)
  return(out_cov)
}

get_rb_adjratio <- function(KRdat, Class, filterAlive, filterAge, method) {
  # Calculations according to
  # An_examination_of_a_recall_bias_adjustment_applied_to_survey-based_coverage_estimates_for_multi-dose_vaccines
  # from Brown et al, 2015. DOI: 10.13140/RG.2.1.2086.2883

  dat1_hbr <- prepare_dat(KRdat, "h3", filterAlive, filterAge, "hbr", Class = Class)
  dat3_hbr <- prepare_dat(KRdat, "h7", filterAlive, filterAge, "hbr", Class = Class)
  dat1_all <- prepare_dat(KRdat, "h3", filterAlive, filterAge, "all", Class = Class)
  dat3_all <- prepare_dat(KRdat, "h7", filterAlive, filterAge, "all", Class = Class)

  cov1_hbr <- get_coverage(dat1_hbr, "h3", Class, method)
  cov3_hbr <- get_coverage(dat3_hbr, "h7", Class, method)
  cov1_all <- get_coverage(dat1_all, "h3", Class, method)
  cov3_all <- get_coverage(dat3_all, "h7", Class, method)

  cov3_all_adj <- cov3_hbr['mean'] * (cov1_all['mean'] / cov1_hbr['mean'])
  dpt3_adjratio <- cov3_all_adj / cov3_all['mean']
  return(data.frame('Class' = cov3_hbr$Class, 'rb_adjratio' = dpt3_adjratio$mean))
}

f_epi_cov <- function(KRdat, Class, filterAlive = TRUE, filterAge = c(12, 23),
                      method = "svyciprop", according_to = 'all', recall_bias_adj = FALSE) {
  # Wrapper function for prepare_dat and get_coverage
  # @param  KRdat raw KRdat from DHS
  # @param  Class name of variable to group by
  # @param  filterAlive exclude children that died
  # @param  filterAge filterAge exclude children not 12-23 years old
  # @param  method svyci method
  # @param  according_to all, hbr, recall
  # @param  recall_bias_adj add recall bias adjustment ratio TRUE or FALSE (DPT-3 only)
  state_dic = KRdat |>
    distinct(sstate) |>
    mutate(NAME_1 = as.character(haven::as_factor(sstate)),
           sstate = as.numeric(sstate))

  vacc_vars <- c("h10", "h2", "h3", "h5", "h7", "h33", "h9") #, "h9a"
  vacc_labels <- c('any', "BCG", "DPT-1", "DPT-2", "DPT-3", "vitaminA", "measles") #, "measles 2"
  vacc_ages_days <- round(c(NA, 0, 1.5, 2.5, 3.5, 6, 9, 15) * (365 / 12), 0)

  vacc_cov_list <- list()
  for (i in c(1:length(vacc_vars))) {
    var <- vacc_vars[i]
    label <- vacc_labels[i]
    age <- vacc_ages_days[i]
    dat <- prepare_dat(KRdat, var, filterAlive, filterAge, according_to, Class = Class)
    if (Class == 'DS' |
      Class == 'DS_Name' |
      Class == 'seasonality_archetype_2') {
      dat <- dat |> left_join(clusterDS)
      dat <- dat |> filter(!is.na(DS_Name)) #!!
    }
    cov <- get_coverage(dat, var, Class, method)
    vacc_cov_list[[length(vacc_cov_list) + 1]] <- cov |> mutate(var = var, vaccine = label, recommended_age = age)
  }

  vacc_cov <- vacc_cov_list |>
    bind_rows() |>
    mutate(filterAlive = filterAlive,
           filterAge = paste0(filterAge, collapse = '-'),
           source = according_to)

  if (Class == 'sstate') {
    vacc_cov <- vacc_cov |>
      mutate(sstate = as.numeric(Class)) |>
      left_join(state_dic) |>
      mutate(NAME_1 = as.character(NAME_1)) |>
      arrange(NAME_1)
  }
  if (Class == 'seasonality_archetype_2') {
    vacc_cov <- vacc_cov |>
      mutate(seasonality_archetype_2 = Class) |>
      arrange(seasonality_archetype_2)
  }
  if (Class == 'DS_Name') {
    vacc_cov <- vacc_cov |>
      mutate(DS_Name = Class)
  }
  if (recall_bias_adj) {
    vacc_cov <- vacc_cov |>
      left_join(get_rb_adjratio(KRdat, Class, filterAlive, filterAge, method))
  }
  return(as.data.table(vacc_cov))
}

low_sample_adjustment <- function(df, df_fill, N_min = 20) {
  # Replace low sample estimates with lower resolution estimate
  # @param  df dataframe with extracted values from DHS to check for low sample sizes
  # @param  df_fill dataframe with extracted values from DHS  used to replace low sample size derived estimates in df
  # @param  N_min thresholds for defining 'low sample size'

  #b5 = N children in eligible age range (see filterAge column)
  if (min(df$b5) <= N_min) {
    message(glue('Adjusting for low sample sizes ({ nrow(df[df$b5 <=N_min, ])} rows <={N_min})'))
    df <- df |> mutate(mean_raw = mean,
                       ci_l_raw = ci_l,
                       ci_u_raw = ci_u,
                       mean = ifelse(b5 <= N_min, NA, mean),
                       ci_l = ifelse(b5 <= N_min, NA, ci_l),
                       ci_u = ifelse(b5 <= N_min, NA, ci_u))

    keep_vrs <- c('vaccine', 'source', 'filterAge', 'mean', 'ci_l', 'ci_u')
    if ('NAME_1' %in% colnames(df_fill)) {
      df_fill <- df_fill |> mutate(admin1 = match_names(NAME_1, DSpop$admin1))
      keep_vrs <- c(keep_vrs, 'NAME_1', 'admin1')
    }
    df_fill <- df_fill |> dplyr::select_at(.vars = keep_vrs)

    if ('DS_Name' %in% colnames(df)) {
      df <- df |> left_join(DSpop)
    }

    dfNA <- df |>
      filter(is.na(mean)) |>
      dplyr::select(-c(mean, ci_l, ci_u)) |>
      left_join(df_fill) |>
      dplyr::select(colnames(df)) |> ## reorder columnns
      mutate(low_sample_adjustment = 1)  ## add flag for rows with replaced values

    df <- df |>
      filter(!is.na(mean)) |>
      mutate(low_sample_adjustment = 0) |>
      bind_rows(dfNA)
    df <- unique(df)
  }else { message(glue('All sample sizes are greater than {N_min}'))
  }
  return(as.data.table(df))
}

missing_DS_adjustment <- function(df, df_fill, adminlvl = 'DS_Name') {
  # Check dataset for missing districts and add these to data frame with regional estimates
  # @param  df dataframe with extracted values from DHS to check for low sample sizes
  # @param  df_fill dataframe with extracted values from DHS used to fill estimates of missing districts in df
  # @param  adminlvl  admin level at which to check for missing units

  df <- as.data.frame(df)
  DSpop <- as.data.frame(DSpop)
  if (!(n_distinct(df[, adminlvl]) == n_distinct(DSpop[, adminlvl]))) {
    message(glue('Adding missing admin units ({n_distinct(df[, adminlvl])} of {n_distinct(DSpop[, adminlvl])})'))

    keep_vrs <- qc(vaccine, source, filterAge, var, recommended_age, filterAlive, mean, ci_l, ci_u)
    if ('NAME_1' %in% colnames(df_fill)) {
      df_fill <- df_fill |> mutate(admin1 = match_names(NAME_1, DSpop$NAME_1))
      keep_vrs <- c(keep_vrs, 'admin1')
    }
    df_fill <- df_fill |> dplyr::select_at(.vars = keep_vrs)

    if ('DS_Name' %in% colnames(df)) {
      df <- df |> left_join(DSpop)
    }

    ## Add missing DS with region of country mean
    DS_missing <- unique(DSpop[, adminlvl][!(DSpop[, adminlvl] %in% df[, adminlvl])])
    DS_missing_df <- DSpop |>
      filter(get(adminlvl) %in% DS_missing) |>
      dplyr::select(admin1, DS_Name, seasonality_archetype_2) |>
      left_join(unique(df[, c('vaccine', 'source', 'filterAge')]), by = character()) |>
      mutate(denom_b5_wt = NA, vacc_var = NA, b5 = NA) |>
      left_join(df_fill, all.x = T) |>
      mutate(Class = get(adminlvl), missing_DS_adjustment = 1)

    df <- df |>
      mutate(missing_DS_adjustment = 0) |>
      bind_rows(DS_missing_df)
    df <- unique(df)
  }else { message(glue('No missing admin units found (N={n_distinct(df[, adminlvl])})')) }
  return(as.data.table(df))
}

missing_value_adjustment_DS <- function(df) {
  # Check dataset for missing values and fill these by group mean across regions
  # @param  df dataframe with extracted values from DHS to check for missing values

  df <- as.data.frame(df)
  if (anyNA(df$mean[df$vaccine != 'any'])) {
    message(glue('Missing coverage values found, replace with State mean'))

    df <- df |>
      group_by(NAME_1, vaccine, recommended_age) |>
      mutate(mean = ifelse(is.na(mean), mean(mean, na.rm = TRUE), mean))

  }else { message(glue('No missing coverage values found')) }
  return(as.data.table(df))
}

##------------------------------------------------------------


##------------------------------------------------------------ Load data
yr <- 2018 # 2021 is MIS, no EPI variables
DSpop <- fread(master_csv) |>
  dplyr::select(DS_Name, NAME_2, seasonality_archetype, seasonality_archetype_2) |>
  unique()

clusterDS <- fread(file.path(projdir, 'DS_DHS_estimates', 'cluster_DS_DHS2018.csv')) |>
  dplyr::select(v001, DHSCLUST, NAME_1, NAME_2, DS_Name, seasonality_archetype, seasonality_archetype_2)
clusterDS$NAME_2[clusterDS$NAME_2 == 'Yamou'] <- 'Yomou'

DSpop <- DSpop |>
  left_join(clusterDS[, c('NAME_1', 'NAME_2')]) |>
  mutate(admin1 = NAME_1)

# pentavaccines <- c(h3, h5,h7 )
KRdat <- read_dta(file.path(dhsdir, dhs_name, KR_fname),
                  col_select = c("b5", "b19", "h1", "h10", "v005", "v001", "v024",
                                 starts_with("h2"), #BCG
                                 starts_with("h3"), #DPT 1
                                 starts_with("h5"), #DPT 2
                                 starts_with("h33"), # Vitamin A1
                                 starts_with("h40d"), #  Vitamin A2
                                 starts_with("h7"), #DPT 3
                                 starts_with("h9"), #MEASLES 1
                                 starts_with("h9a") #MEASLES 2
                  )) |>
  mutate(SurveyId = "GN2018DHS") |>
  rename(sstate = v024)


##------------------------------------------------------------ Calculate vaccine coverages
##------------ NATIONAL
print("running for COUNTRY")
vacc_cov_GN <- f_epi_cov(KRdat, according_to = 'all', Class = 'SurveyId', recall_bias_adj = TRUE)
vacc_hbr_GN <- f_epi_cov(KRdat, according_to = 'hbr', Class = 'SurveyId', recall_bias_adj = TRUE)
vacc_recall_GN <- f_epi_cov(KRdat, according_to = 'recall', Class = 'SurveyId', recall_bias_adj = TRUE)

vacc_cov_GN <- vacc_cov_GN |>
  bind_rows(vacc_hbr_GN) |>
  bind_rows(vacc_recall_GN)
summary(vacc_cov_GN$b5) ## range of sample sizes

n_distinct(vacc_cov_GN$Class)
fwrite(vacc_cov_GN, file.path(projdir, 'DS_DHS_estimates', 'EPI', 'vacc_cov_DHS2018.csv'))

##------------ ADMIN1
print("running per NAME_1")
# incl. sensitivity analysis on data subsets and svymethod
vacc_cov_state <- f_epi_cov(KRdat, Class = 'sstate', recall_bias_adj = TRUE) |>
  dplyr::select(NAME_1, sstate, everything())

# Encoding might differ depending on local machine and system used
vacc_cov_state$NAME_1 <- iconv(vacc_cov_state$NAME_1, from = 'UTF-8', "ASCII//TRANSLIT")
vacc_cov_state <- missing_DS_adjustment(vacc_cov_state, vacc_cov_GN, adminlvl = 'NAME_1') #
fwrite(vacc_cov_state, file.path(projdir, 'DS_DHS_estimates', 'EPI', 'vacc_cov_admin1_DHS2018.csv'))

# Check vaccine coverage by informarion source (all, hbr, recall)
vacc_hbr_state <- f_epi_cov(KRdat, according_to = 'hbr', Class = 'sstate', recall_bias_adj = TRUE)
vacc_recall_state <- f_epi_cov(KRdat, according_to = 'recall', Class = 'sstate', recall_bias_adj = TRUE)
vacc_cov_state |>
  bind_rows(vacc_hbr_state) |>
  bind_rows(vacc_recall_state) |>
  mutate(mean = round(mean * 100, 1)) |>
  dplyr::select(NAME_1, source, vaccine, mean) |>
  pivot_wider(names_from = source, values_from = mean) |>
  mutate(NAME_1 <- iconv(NAME_1, from = 'UTF-8', "ASCII//TRANSLIT")) |>
  fwrite(file.path(projdir, 'DS_DHS_estimates', 'EPI', 'vacc_cov_mean_by_source_DHS2018.csv'))
rm(vacc_hbr_state, vacc_recall_state)

##------------ ARCHETYPE
print("running per Archetype")
vacc_cov_arch <- f_epi_cov(KRdat, Class = 'seasonality_archetype_2')  # per default  filterAge = c(12, 23)
length(unique(vacc_cov_arch$seasonality_archetype_2)) == length(unique(DSpop$seasonality_archetype_2))
lenlga = length(unique(vacc_cov_arch$seasonality_archetype_2))
tapply(vacc_cov_arch$mean, vacc_cov_arch$vaccine, summary)
tapply(vacc_cov_arch$denom_b5_wt, vacc_cov_arch$vaccine, summary)

vacc_cov_arch <- low_sample_adjustment(vacc_cov_arch, vacc_cov_GN)
vacc_cov_arch <- missing_DS_adjustment(vacc_cov_arch, vacc_cov_GN, adminlvl = 'seasonality_archetype_2') #
fwrite(vacc_cov_arch, file.path(projdir, 'DS_DHS_estimates', 'EPI', paste0('vacc_cov_seasonArch_DHS2018.csv')))

##------------ ADMIN2 (districts)
print("running per DS")
vacc_cov_lga_mean <- f_epi_cov(KRdat, Class = 'DS_Name')  # per default  filterAge = c(12, 23)

length(unique(vacc_cov_lga_mean$DS_Name)) == length(unique(DSpop$DS_Name))
lenlga = length(unique(vacc_cov_lga_mean$DS_Name))
tapply(vacc_cov_lga_mean$mean, vacc_cov_lga_mean$vaccine, summary)
tapply(vacc_cov_lga_mean$denom_b5_wt, vacc_cov_lga_mean$vaccine, summary)

vacc_cov_lga_mean <- low_sample_adjustment(vacc_cov_lga_mean, vacc_cov_state)
vacc_cov_lga_mean <- missing_DS_adjustment(vacc_cov_lga_mean, vacc_cov_state, adminlvl = 'DS_Name') #
vacc_cov_lga_mean <- missing_value_adjustment_DS(vacc_cov_lga_mean)
fwrite(vacc_cov_lga_mean, file.path(projdir, 'DS_DHS_estimates', 'EPI', paste0('vacc_cov_DS_DHS2018.csv')))

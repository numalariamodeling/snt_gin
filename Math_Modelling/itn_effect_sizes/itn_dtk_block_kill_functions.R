## --------------------------- get_dtk_block_kill_functions.R ---------------------------
# Extended and adapted from dtk_net_vals_from_bioassay_mortality.R, created: 2021 by Monique Ambrose (published in Ozodiegwu et al 2023)
# Edited and extended: 2022 by Manuela Runge for SNT Guinea
# Contents: functions that calculate blood-feeding and killing rates for PBO and non-PBO nets given permethrin bioassay mortality
#           and translates the values into DTK-killing and DTK-blocking

frac_reassign_feed_survive = 1
## ---------------------------------------------------------------------------------
# functions for getting dtk parameters from bioassay mortality
## ---------------------------------------------------------------------------------
get_hut_mortality_from_bioassay_mortality = function(bioassay_mortality, fit_version = 'loglogistic_Nash', fit_location = 'all') {
    #' Given a bioassay mortality, get the hut mortality using one of several possible functions
    #' @param bioassay_mortality the bioassay mortality value (can be a scalar or vector)
    #' @param fit_version string corresponding to the relationship to use to calculate hut mortality from bioassay mortality
    #' @param fit_location string corresponding to the location (all, west_huts, east_huts) of data used to fit the relationship between hut mortality from bioassay mortality

  if (fit_version == 'loglogistic_Nash' | fit_version == 'logistic_Nash') {
    loglogistic_Nash <- list()
    loglogistic_Nash[['west_huts']] <- c(0.88, 0.72)
    loglogistic_Nash[['east_huts']] <- c(0.36, 1.05)
    loglogistic_Nash[['all']] <- c(0.47, 0.89)
    logistic_Nash <- list()
    logistic_Nash[['west_huts']] <- c(0.73, 3.78)
    logistic_Nash[['east_huts']] <- c(0.66, 3.29)
    logistic_Nash[['all']] <- c(0.7, 3.57)
    fit_param_Nash <- list('loglogistic_Nash' = loglogistic_Nash, 'logistic_Nash' = logistic_Nash)

    a = fit_param_Nash[[fit_version]][[fit_location]][1]
    b = fit_param_Nash[[fit_version]][[fit_location]][2]
  }
  if (fit_version == 'loglogistic_Nash') {
    return((1 / (1 + ((bioassay_mortality) / b)^(-a))))  # log-logistic fit from Nash et al. 2021
  } else if (fit_version == 'logistic_Nash') {
    return(1 / (1 + exp(-1 * ((bioassay_mortality) - a) * b)))  # logistic fit from Nash et al. 2021
  } else if (fit_version == 'linear_fit') {
    return(0.25 + 0.44 * bioassay_mortality)  # linear fit data-grabbed from presentation
  } else if (fit_version == '2021_pres') {
    return(0.53 - 0.1 * (1 - bioassay_mortality) / (0.2 + bioassay_mortality))  # rough guess of log logit from the presentation
  } else if (fit_version == '2016_Churcher') {
    return(1 / (1 + exp(-1 * (0.63 + 4.0 * (bioassay_mortality - 0.5)))))  # parameters from Churcher et al 2016
  } else if (fit_version == '2022_snt_BFA') {
    return((1 / (1 + exp(-1 *
                           ((bioassay_mortality) - 0.71607295) *
                           4.00458614))) * 0.78970871)  # custom fitted for SNT BFA 2022
  } else warning('Name for the bioassay- to hut-trial-mortality function not found.')
}

get_hut_BF_from_hut_mortality = function(hut_mortality, fit_version_BF = 'ITN_extraction', fit_location = 'all') {
    #' Given the hut mortality value, get the hut bloodfeeding estimate using one of several possible functions
    #' @param k1 fit parameter corresponding to ITN extraction function
    #' @param k2 fit parameter corresponding to ITN extraction function
    #' @param hut_mortality the hut mortality value (can be a scalar or vector)
    #' @param fit_version_BF string corresponding to the relationship to use to calculate hut bloodfeeding from hut mortality

  if (fit_version_BF == 'Nash_2021') {
    fit_param_Nash <- list()
    fit_param_Nash[['west_huts']] <- c(0.04, 5.13)
    fit_param_Nash[['east_huts']] <- c(0.01, 3.43)
    fit_param_Nash[['all']] <- c(0.04, 4.66)
    a = fit_param_Nash[[fit_location]][1]
    b = fit_param_Nash[[fit_location]][2]
  }

  if (fit_version_BF == 'ITN_extraction') {
    k1_fit = 0.27
    k2_fit = 1.3
    return(k1 * exp(k2 * (0.5 - hut_mortality)))
  } else if (fit_version_BF == 'Nash_2021') {
    return((1 - (exp(a * (1 - exp(b * (1 - hut_mortality))) / b))) / (1 - hut_mortality))  # in ms, they adjusted to get BF and survive by assuming independent mortality. Adjust back here by dividing by (1-P(die)).
  } else warning('Name for the hut-trial-mortality to blood-feeding-fraction function not found.')
}

get_PBO_mort_from_permethrin_mort = function(permethrin_mortality, fit_version = 'Churcher_2016') {
    #' Given a permethrin [bioassay or hut] mortality, get estimate of PBO  [bioassay or hut]  mortality
    #' @param permethrin_mortality the mortality value for permethrin (can be a scalar or vector)

  if (fit_version == 'Churcher_2016') {
    return(1 / (1 + exp(-(3.41 + (5.88 * (permethrin_mortality - 0.5) / (1 + 0.78 * (permethrin_mortality - 0.5)))))))
  } else if (fit_version == 'Sherrad-Smith_2022') {
    return(1 / ((1 + exp(-(-1.43 + (5.60 * permethrin_mortality))))))
  } else if (fit_version == '2022_snt_BFA') {
    return((1 / ((1 + exp(-(-1.77407985 + (3.30887451 * permethrin_mortality)))))) * 0.96017955)
  }else warning('Name for the permethrin-mortality to PBO mortality function not found.')

}

get_dtk_block_kill_from_hut_mort_BF = function(hut_mortality, hut_BF, frac_reassign_feed_survive) {
    #' Given the hut trial mortality and bloodfeeding values, estimate the dtk block and kill rates
    #' @param hut_mortality the hut mortality value
    #' @param hut_BF the hut bloodfeeding value
    #' @param frac_reassign_feed_survive the fraction of mosquitoes that fall in the 'feed and die' category that are reassigned to 'feed and survive'
    #' Additional details: reassign the mosquitoes that eat and then die in the hut trials to either eat and survive or die without feeding for the dtk
    #'                     we assume that hut mortality and hut blood-feeding are independent events

  hut_frac_BF_survive = hut_BF * (1 - hut_mortality)
  hut_frac_BF_die = hut_BF * hut_mortality
  hut_frac_noBF_survive = (1 - hut_BF) * (1 - hut_mortality)
  hut_frac_noBF_die = (1 - hut_BF) * hut_mortality

  dtk_frac_BF_survive = sapply((hut_frac_BF_survive + hut_frac_BF_die * frac_reassign_feed_survive), min, 1)
  dtk_frac_noBF_survive = hut_frac_noBF_survive
  dtk_frac_noBF_die = sapply((hut_frac_noBF_die + hut_frac_BF_die * (1 - frac_reassign_feed_survive)), min, 1)
  # renormalize, if necessary
  dtk_total = dtk_frac_BF_survive +
    dtk_frac_noBF_survive +
    dtk_frac_noBF_die
  dtk_frac_BF_survive = dtk_frac_BF_survive / dtk_total
  dtk_frac_noBF_survive = dtk_frac_noBF_survive / dtk_total
  dtk_frac_noBF_die = dtk_frac_noBF_die / dtk_total

  dtk_blocking_rate = 1 - dtk_frac_BF_survive
  dtk_killing_rate = dtk_frac_noBF_die / (dtk_frac_noBF_die + dtk_frac_noBF_survive)

  return(list(list(dtk_blocking_rate, dtk_killing_rate), list(dtk_frac_BF_survive, dtk_frac_noBF_survive, dtk_frac_noBF_die), list(hut_frac_BF_survive, hut_frac_BF_die, hut_frac_noBF_survive, hut_frac_noBF_die)))
}

get_dtk_block_kill_from_bioassay = function(bioassay_mortality, k1, k2, frac_reassign_feed_survive, fit_version = 'loglogistic_Nash', fit_version_BF = 'ITN_extraction') {
    #' Given a bioassay mortality, get the blocking and killing rates for the dtk
    #' @param bioassay_mortality the bioassay mortality value (can be a scalar or vector)
    #' @param k1 fit parameter corresponding to ITN extraction function
    #' @param k2 fit parameter corresponding to ITN extraction function
    #' @param frac_reassign_feed_survive the fraction of mosquitoes that fall in the 'feed and die' category that are reassigned to 'feed and survive'
    #' @param fit_version string corresponding to the relationship to use to calculate hut mortality from bioassay mortality
    #' @param fit_version_BF string corresponding to the relationship to use to calculate hut bloodfeeding from hut mortality

  hut_mortality = get_hut_mortality_from_bioassay_mortality(bioassay_mortality, fit_version = fit_version)
  hut_BF = get_hut_BF_from_hut_mortality(k1, k2, hut_mortality, fit_version_BF = fit_version_BF)
  dtk_block_kill = get_dtk_block_kill_from_hut_mort_BF(hut_mortality, hut_BF, frac_reassign_feed_survive)[[1]]
  return(dtk_block_kill)
}


## ---------------------------------------------------------------------------------
# wrapper functions for getting dtk parameters from bioassay mortality  for different ITN types
# per default use logistic relationship for defining mortality, and loglogistic relationship for defining blocking
## ---------------------------------------------------------------------------------
f_get_dtk_block_kill <- function(mort_bioassay, mort_fit_version = 'logistic_Nash') {
  ## Use logistic relationship for defining mortality, and loglogistic relationship for defining blocking
  if (mort_fit_version == '2022_snt_BFA') {
    mort_EHT <- get_hut_mortality_from_bioassay_mortality(mort_bioassay, fit_version = '2022_snt_BFA')
  }else {
    mort_EHT <- get_hut_mortality_from_bioassay_mortality(mort_bioassay, fit_version = 'logistic_Nash', fit_location = 'west_huts')
  }

  mort_EHT_forBF <- get_hut_mortality_from_bioassay_mortality(mort_bioassay, fit_version = 'loglogistic_Nash', fit_location = 'all')
  bloodfed_EHT <- get_hut_BF_from_hut_mortality(hut_mortality = mort_EHT_forBF, fit_version_BF = 'Nash_2021')

  dtk_block_kill <- get_dtk_block_kill_from_hut_mort_BF(mort_EHT, bloodfed_EHT, frac_reassign_feed_survive)[[1]]

  return(dtk_block_kill)
}

f_get_dtk_block_kill_PBO <- function(mort_bioassay, mort_fit_version = 'logistic_Nash') {

  mort_EHT <- get_hut_mortality_from_bioassay_mortality(mort_bioassay, fit_version = 'logistic_Nash', fit_location = 'west_huts')
  mort_EHT_PBO <- get_PBO_mort_from_permethrin_mort(mort_EHT, fit_version = 'Sherrad-Smith_2022')

  mort_EHT_forBF <- get_hut_mortality_from_bioassay_mortality(mort_bioassay, fit_version = 'loglogistic_Nash', fit_location = 'all')
  mort_EHT_forBF_PBO <- get_PBO_mort_from_permethrin_mort(mort_EHT_forBF, fit_version = 'Sherrad-Smith_2022')
  bloodfed_EHT_PBO <- get_hut_BF_from_hut_mortality(hut_mortality = mort_EHT_forBF_PBO, fit_version_BF = 'Nash_2021')

  dtk_block_kill <- get_dtk_block_kill_from_hut_mort_BF(mort_EHT_PBO, bloodfed_EHT_PBO, frac_reassign_feed_survive)[[1]]

  if (mort_fit_version == '2022_snt_BFA') {
    ### see parameter estimation in scaling_to_func_parameter.R,  using llin_killrate as input resulted in best fitting estimates
    llin_killrate <- f_get_dtk_block_kill(mort_bioassay, mort_fit_version = '2022_snt_BFA')[[2]]
    dtk_block_kill[[2]] = dtk_block_kill[[2]] * (0.83009 * (llin_killrate / (0.01019 + llin_killrate)))
  }
  return(dtk_block_kill)
}

f_get_dtk_block_kill_IG2 <- function(mort_bioassay, mort_fit_version = 'logistic_Nash') {
  if (mort_fit_version == '2022_snt_BFA') {
    dtk_block_kill <- f_get_dtk_block_kill_PBO(mort_bioassay, mort_fit_version)
  }else {
    dtk_block_kill <- f_get_dtk_block_kill_PBO(mort_bioassay)
  }
  dtk_block_kill[[1]] <- dtk_block_kill[[1]] * 0.885
  dtk_block_kill[[2]] <- 0.75

  return(dtk_block_kill)
}
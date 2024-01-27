####
# This script is used to calculate the ITN usage ratio among age groups
# (0-5, 6-10, 11-20 and 20+) based on DHS datasets. There are two versions of
# this ratio: national level and admin 1 level
####
library(dplyr)
library(haven)
library(forcats)

# Functions
get_pr <- function (rootdir, year) {
  if (year == 2012) {
    dtafile <- file.path(rootdir, "GN_2012_DHS_05212020", "GNPR62DT",
                         "GNPR62FL.DTA")
    return(haven::read_dta(dtafile))
  } else if (year == 2018) {
    dtafile <- file.path(rootdir, "GN_2018_DHS_05212020_1029_148964", "GNPR71DT",
                         "GNPR71FL.DTA")
    return(haven::read_dta(dtafile))
  } else if (year == 2021) {
    dtafile <- file.path(rootdir, "GN_2021_MIS_04272022_1346_148964", "GNPR81DT",
                         "GNPR81FL.DTA")
    return(haven::read_dta(dtafile))
  }
  
  stop("Error: invalid year")
}

subset_rename <- function(df) {
  df1 <- df %>%
    dplyr::select(hv005, hv024, hv104, hv105, hml12) %>%
    mutate(
      sex = case_when(
        hv104 == 1 ~ "Male",
        hv104 == 2 ~ "Female",
        hv104 == 9 ~ NA_character_
      ),
      net_use = case_when(
        hml12 == 0 ~ 0,
        hml12 == 1 ~ 1,
        hml12 == 2 ~ 1,
        T ~ 0),
      ageg = case_when(
        hv105 <= 5 ~ "U05",
        hv105 <= 10 ~ "U10",
        hv105 <= 20 ~ "U20",
        hv105 == 98 ~ NA_character_,
        T ~ "A20"
      )) %>%
    dplyr::select(weight = hv005, region = hv024, sex, ageg, net_use)
  return(df1)
}

collate_years <- function(years) {
  bigdf <- data.frame()
  for (yr in years) {
    df <- get_pr(dhsdir, yr)
    df <- subset_rename(df)
    df$year <- yr
    
    bigdf <- bind_rows(bigdf, df)
  }
  
  return(bigdf)
}

# Collate and process
bigdf <- collate_years(c(2012, 2018, 2021))
bigdf$ageg <- factor(bigdf$ageg, levels = c("U05", "U10", "U20", "A20"))
net_yr_age <- bigdf %>%
  group_by(year, ageg) %>%
  na.omit() %>%
  summarise(net_use = sum(net_use * weight) / sum(weight),
            n = n()) %>%
  group_by(year) %>%
  mutate(r = net_use / net_use[ageg == "U05"])

net_yr_age_region <- bigdf %>%
  group_by(year, ageg, region) %>%
  na.omit() %>%
  summarise(net_use = sum(net_use * weight) / sum(weight),
            n = n()) %>%
  group_by(year, region) %>%
  mutate(r = net_use / net_use[ageg == "U05"])

net_yr_age_region$region <- as_factor(net_yr_age_region$region)

# Output
data.table::fwrite(net_yr_age, "data/intermediate_data/net_use_ratio.csv")
data.table::fwrite(net_yr_age_region, "data/intermediate_data/net_use_ratio_admin1.csv")

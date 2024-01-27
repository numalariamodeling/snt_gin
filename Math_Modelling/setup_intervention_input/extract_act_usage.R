####
# This script is used to extract national and regional level of ACT usage
# from DHS.
# This script relies on DHS datasets which are not included in this repository.
####
library(dplyr)

# Functions
get_kr <- function (rootdir, year) {
  if (year == 2012) {
    dtafile <- file.path(rootdir, "GN_2012_DHS_05212020", "GNKR62DT",
                         "GNKR62FL.DTA")
    return(haven::read_dta(dtafile))
  } else if (year == 2018) {
    dtafile <- file.path(rootdir, "GN_2018_DHS_05212020_1029_148964", "GNKR71DT",
                         "GNKR71FL.DTA")
    return(haven::read_dta(dtafile))
  } else if (year == 2021) {
    dtafile <- file.path(rootdir, "GN_2021_MIS_04272022_1346_148964", 
                         "GNKR81DT", "GNKR81FL.DTA")
    return(haven::read_dta(dtafile))
  }
  
  stop("Error: invalid year")
}

mltaken <- function(df) {
  mlt1 <- df %>%
    dplyr::select(ml13a:ml13h) %>%
    rowSums(na.rm = T)
  mlt2 <- df %>%
    dplyr::select(ml13a:ml13h) %>%
    apply(1, \(x) all(is.na(x) | x == 9))
  mlt1[mlt2] <- NA
  mlt1 <- as.numeric(mlt1 >= 1)
  
  return(mlt1)
}

acttaken <- function(df) {
  actt <- df %>%
    dplyr::select(contains(act)) %>%
    apply(1, \(x) sum(x == 1, na.rm = T))
  
  return(actt)
}

# Loop through DHS years and extract data
non_act <- c("ml13a", "ml13b", "ml13c", "ml13d", "ml13da",
             "ml13g", "ml13h")
act <- c("ml13e", "ml13aa", "ml13ab", "ml13f")

resdf <- data.frame()
for (yr in c(2012, 2018, 2021)) {
  df <- get_kr(dhsdir,yr)
  tmp <- df[df$h22==1 & df$h32z==1,]
  tmp$mltaken <- mltaken(tmp)
  tmp$acttaken <- acttaken(tmp)
  
  res <- tmp %>%
    filter(mltaken == 1) %>%
    summarise(act_perc = sum(v005 * acttaken) / sum(v005))
  res$year <- yr
  resdf <- bind_rows(resdf, res)
}

data.table::fwrite(resdf, 
                   file.path("data/intermediate_data", "act_perc.csv"))


#### Regional
resdf <- data.frame()
for (yr in c(2012, 2018, 2021)) {
  df <- get_kr(dhsdir,yr)
  tmp <- df[df$h22==1 & df$h32z==1,]
  tmp$mltaken <- mltaken(tmp)
  tmp$acttaken <- acttaken(tmp)
  
  res <- tmp %>%
    filter(mltaken == 1) %>%
    group_by(v024) %>%
    summarise(act_perc = sum(v005 * acttaken) / sum(v005)) %>%
    mutate(region = haven::as_factor(v024)) %>%
    select(-v024)
  res$year <- yr
  resdf <- bind_rows(resdf, res)
}

data.table::fwrite(resdf, 
                   file.path("data/intermediate_data", "act_perc_reg.csv"))

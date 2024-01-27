####
# This script is used to calculate the proportion of each age group (0-5, 6-10, 
# 11-20 and 20+) in each district. This is used mainly in the ITN usage 
# calculations
####
library(raster)
library(dplyr)

shpfile <- "data/shp/GIN_adm2.shp"
shp <- shapefile(shpfile) |>
  spTransform(CRS("+init=epsg:4326"))
master_csv <- "data/guinea_DS_pop.csv"
master_df <- data.table::fread(master_csv)

# Functions
subset_rename <- function (df) {
  df1 <- df %>%
    dplyr::select(hv001, hv005, hv024, hv104, hv105, hml12) %>%
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
    dplyr::select(cluster = hv001, weight = hv005, region = hv024, sex, ageg, net_use)
  return(df1)
}

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

collate_years <- function (years = c(2012, 2018, 2021)) {
  bigdf <- data.frame()
  for (yr in years) {
    df <- get_pr(dhsdir, yr)
    df <- subset_rename(df)
    df$year <- yr
    
    ge_sp <- get_ge(dhsdir, yr)
    cond <- ge_sp$LATNUM == 0 & ge_sp$LONGNUM == 0
    ge_sp <- ge_sp[!cond,] |>
      spTransform(crs(shp))
    tmp <- over(ge_sp, shp)[, c("NAME_2", "NAME_1")]
    ge_sp$DS_Name <- tmp$NAME_2
    ge_sp$region <- tmp$NAME_1
    df <- df |>
      select(-region) |>
      left_join(ge_sp@data |> dplyr::select(DHSCLUST, DS_Name, region),
                by = c("cluster" = "DHSCLUST"))
    
    bigdf <- bind_rows(bigdf, df)
  }
  
  return(bigdf)
}

match_names <- function(x, y) {
  mat <- adist(x, y, ignore.case = T)
  z <- y[apply(mat, 1, which.min)]
  if (n_distinct(y) != n_distinct(z)) {
    z_df <- as.data.frame(table(z))
    dup_z <- unique(as.character(z_df[z_df$Freq != median(z_df$Freq), 'z']))
    dup_x <- unique(x[which(z %in% dup_z)])
    dup_y <- unique(y[!(y %in% z)])
    warning(paste0(n_distinct(dup_z), ' duplicate(s) found! Please check: ', paste0(dup_x, collapse = ', '),
                   '. => No match found for: ', paste0(dup_y, collapse = ', ')))
    return(z)
  }else { return(z) }
}

# Collate DHS results and calculate
bigdf <- collate_years()
bigdf$ageg <- factor(bigdf$ageg, levels = c("U05", "U10", "U20", "A20"))

prop_yr_age <- bigdf |>
  filter(!is.na(ageg)) |>
  group_by(year, ageg) |>
  summarise(n = sum(weight/1e6, na.rm=T)) |>
  group_by(year) |>
  mutate(nat_p = n/sum(n))

prop_yr_age_ds <- bigdf |>
  filter(!is.na(ageg), !is.na(DS_Name)) |>
  group_by(DS_Name, region, year, ageg) |>
  summarise(n = sum(weight/1e6, na.rm=T)) |>
  group_by(DS_Name, year) |>
  mutate(p = n/sum(n))

prop_yr_age_ds1 <- prop_yr_age_ds |>
  group_by(year) |>
  tidyr::complete(tidyr::nesting(DS_Name = shp$NAME_2, region = shp$NAME_1),
                  ageg = c("U05", "U10", "U20", "A20")) |>
  left_join(prop_yr_age |> dplyr::select(-n)) |>
  mutate(p = ifelse(is.na(p), nat_p, p))

prop_yr_age_ds1 <- prop_yr_age_ds1 |>
  mutate(DS_Name = ifelse(DS_Name == "Yamou", "Yomou", DS_Name),
         DS_Name = match_names(DS_Name, master_df$DS_Name))

# Output
outdir <- "data/intermediate_data"
data.table::fwrite(prop_yr_age_ds1, 
                   file.path(outdir, "prop_age_ds.csv"))

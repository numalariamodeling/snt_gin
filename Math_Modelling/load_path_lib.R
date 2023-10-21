tryCatch(library(raster),
         error=function(e) cat("Can't load `raster` package, ignore if unimportant\n"))
library(sp)
tryCatch(library(sf),
         error=function(e) cat("Can't load `sf` package, ignore if unimportant\n"))
library(dplyr)
library(stringr)
library(ggplot2)
library(glue)
library(lubridate)
library(forcats)

boxdir <- file.path(Sys.getenv('USERPROFILE'), "NU-malaria-team Dropbox")
projdir <- file.path(boxdir, "projects/hbhi_guinea")
datadir <- file.path(boxdir, "data/guinea")
dhsdir <- file.path(boxdir, "data/guinea_dhs/data_analysis/master/data")
shapedir <- file.path(boxdir, "data/guinea_shapefiles/Guinea_Health_District")
shpfile <- file.path(shapedir, "GIN_adm2.shp")
master_csv <- file.path(projdir, "guinea_DS_pop.csv")



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

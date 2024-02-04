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

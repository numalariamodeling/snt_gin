## --------------------------- 00_write_cluster_DS.R ---------------------------
## Load household clusters from DHS and match them to admin2 boundaries for Guinea
## Input: GNGE71FL.shp, GIN_adm2.shp, guinea_DS_pop.csv
## Output: cluster_DS_DHS2018.csv, or for other years
##------------------------------------------------------------

library(data.table)
library(tidyverse)
library(raster)
library(maptools)  # going to retire 2023

source("input_processor/load_path_lib.R")
source("input_processor/functions.R")
data_dir <- dhsdir

DHSyear <- 2021
if(DHSyear==2005)GE_fname <- "GN_2005_DHS_06012020_126_148964/GNGE52FL/GNGE52FL.shp"
if(DHSyear==2012)GE_fname <- "GN_2012_DHS_05212020/GNGE61FL/GNGE61FL.shp"
if(DHSyear==2018)GE_fname <- "GN_2018_DHS_05212020_1029_148964/GNGE71FL/GNGE71FL.shp"
if(DHSyear==2021)GE_fname <- "GN_2021_MIS_04272022_1346_148964/GNGE81FL/GNGE81FL.shp"


# Load and transform shapefiles
myproj <- "+proj=longlat +datum=WGS84 +no_defs"
shp_dir <- file.path(boxdir, 'data', 'guinea_shapefiles')
shp_admin1 <- shapefile(file.path(shp_dir, 'GIN_adm_shp', 'GIN_adm1.shp'))
shp_admin2 <- shapefile(file.path(shp_dir, 'Guinea_Health_District', 'GIN_adm2.shp'))
spTransform(shp_admin1, myproj)
spTransform(shp_admin2, myproj)

## Load DS pop, admin unit names to use
DSpop <- fread(file.path(projdir, "guinea_DS_pop.csv"))
DSpop <- DSpop |> mutate(NAME_2 = match_names(DS_Name, shp_admin2$NAME_2))  #TODO add source to script with match_names when PRed

# Load household cluster shapefile
clusterssp <- shapefile(file.path(data_dir, GE_fname))
spTransform(clusterssp, myproj)

# Overlay HH cluster coordinates over admin2 shapefile
clustersspDS <- over(clusterssp, shp_admin2)
clusterDS <- spCbind(clusterssp, clustersspDS) |> as.data.frame()  ## TODO use sp alternative

## Check unique length
length(unique(clustersspDS$NAME_2))
length(unique(DSpop$NAME_2))

clusterDS_v0 <- clusterDS
clusterDS <- clusterDS |>
  left_join(DSpop[, c('NAME_2', 'DS_Name', 'seasonality_archetype', 'seasonality_archetype_2')], all = TRUE) |>
  filter(!is.na(DS_Name))

# Check dimensions and merge success
dim(clusterDS_v0)
dim(clusterDS)
length(unique(clusterDS$DS_Name))
table(clusterDS$DHSYEAR, exclude = NULL)
table(clusterDS$DHSYEAR, exclude = NULL)
table(clusterDS$seasonality_archetype_2, exclude = NULL)
table(clusterDS$DS_Name, clusterDS$seasonality_archetype_2, exclude = NULL)

# Encoding might differ depending on local machine and system used
clusterDS$NAME_2 <- iconv(clusterDS$NAME_2, from = 'UTF-8', "ASCII//TRANSLIT")
clusterDS$NAME_1 <- iconv(clusterDS$NAME_1, from = 'UTF-8', "ASCII//TRANSLIT")

# Select variables and save dataframe
clusterDS |>
  mutate(v001 = DHSCLUST) |>
  dplyr::select(NAME_0, DHSYEAR, DHSID, DHSCLUST, v001, NAME_1, NAME_2,
                DS_Name, seasonality_archetype, seasonality_archetype_2,
                DHSREGNA, ADM1DHS, ADM1NAME, SOURCE, URBAN_RURA, LATNUM, LONGNUM, ALT_GPS, DATUM) |>
  fwrite(file.path(projdir, 'DS_DHS_estimates', paste0('cluster_DS_DHS', DHSyear, '.csv')))


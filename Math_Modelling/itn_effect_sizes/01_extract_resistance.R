## --------------------------- 01_extract_resistance.R ---------------------------
## Extract resistance values from raster files for a specified country (here Guinea)
## Read in raster files from Penny Hancock et al paper, Vector Atlas Project.
## [Hancock et al 2020](https://journals.plos.org/plosbiology/article?id=10.1371/journal.pbio.3000633)
## Input: Raster files named IR+rasters+2017.grd
## Output: Dataframe with summary statistics per admin1 or admin2 for multiple years for which raster files available
##------------------------------------------------------------

pckg <- c("dplyr", "tidyr", "data.table", "rgdal", "raster", "exactextractr", "malariaAtlas")
a <- lapply(pckg, require, character.only = TRUE)
rm(a)

box_dir <- file.path(Sys.getenv('USERPROFILE'), '/NU Malaria Modeling Dropbox')
raster_dir <- file.path(box_dir, 'data', 'burkina_rasterfiles', 'insecticide_resistance')  ## raster for all West Africa
shp_dir <- file.path(box_dir, 'data', 'guinea_shapefiles')
out_dir <- file.path(box_dir, 'projects/hbhi_guinea/ento/insecticide_resistance_extract2022')


##------------------------------------------------------------ define custom functions for spatial IR raster
get_rasters <- function(raster_dir) {
  # 1. List all files in the specified directory with the 'grd' file extension
  # 2. Iterate through each raster file in the directory
  # 3. Extract the year from the file name using parse_number from readr package
  # 4. Read the raster file and store it in the raster_files list with the year as the key

  rastlist <- list.files(raster_dir, pattern = 'grd$')
  raster_files <- list()
  for (rast_file in rastlist) {
    year <- as.character(readr::parse_number(rast_file))
    raster_files[[year]] <- stack((file.path(raster_dir, rast_file)))
  }
  return(raster_files)
}

format_raster <- function(raster_files, shp_file) {
  # 1. Crop the raster to match the extent of the provided shapefile
  # 2. Mask the raster to retain values only within the shapefile's boundary
  # 3. Resample the raster to match the resolution of the first raster file

  beginCluster()
  for (i in c(1:length(raster_files))) {
    raster_files[[i]] <- crop(x = raster_files[[i]], y = extent(shp_file))
    raster_files[[i]] <- mask(x = raster_files[[i]], mask = shp_file)
    raster_files[[i]] <- raster::resample(raster_files[[i]], raster_files[[1]], method = "bilinear")
  }
  endCluster()

  return(raster_files)
}

extract_raster <- function(raster_files, shp_file, funcs = c('mean', 'median', 'stdev', 'min', 'max')) {
  # 1. Iterate through each raster file corresponding to different years
  # 2. Extract specified summary statistics (funcs) for the shapefile's boundary
  # 3. Add the 'year' column to the extracted data based on current iteration
  # 4. Check if the shapefile has ISO, NAME_1, and NAME_2 columns, and add them if available

  beginCluster()
  raster_values <- list()
  for (name in names(raster_files)) {
    raster_file = raster_files[[name]]
    raster_values[[name]] <- cbind(exact_extract(raster_file, shp_file, funcs))
    raster_values[[name]]$year <- name
    if ("ISO" %in% colnames(as.data.frame(shp_file)))raster_values[[name]]$ISO <- as.data.frame(shp_file)[, 'ISO']
    if ("NAME_1" %in% colnames(as.data.frame(shp_file)))raster_values[[name]]$NAME_1 <- as.data.frame(shp_file)[, 'NAME_1']
    if ("NAME_2" %in% colnames(as.data.frame(shp_file)))raster_values[[name]]$NAME_2 <- as.data.frame(shp_file)[, 'NAME_2']
  }
  endCluster()
  return(raster_values)
}

##------------------------------------------------------------

# Load shapefiles for Guinea and check names
shp_admin0 <- shapefile(file.path(shp_dir, 'GIN_adm_shp', 'GIN_adm0.shp'))
shp_admin1 <- shapefile(file.path(shp_dir, 'GIN_adm_shp', 'GIN_adm1.shp'))
shp_admin2 <- shapefile(file.path(shp_dir, 'Guinea_Health_District', 'GIN_adm2.shp'))

shp_admin2$NAME_1 <- iconv(shp_admin2$NAME_1, from = 'UTF-8', "ASCII//TRANSLIT")
shp_admin2$NAME_2 <- iconv(shp_admin2$NAME_2, from = 'UTF-8', "ASCII//TRANSLIT")
unique(shp_admin2$NAME_1)
unique(shp_admin2$NAME_2)
length(unique(shp_admin2$NAME_2))

# Load raster files, format and extract values - ADMIN 1
raster_files <- get_rasters(raster_dir)
raster_files <- format_raster(raster_files, shp_file = shp_admin0)

res_dat1 <- extract_raster(raster_files, shp_file = shp_admin1) |>
  bind_rows() |>
  dplyr::select(year, NAME_1, everything())

fwrite(res_dat1, file.path(out_dir, 'insecticide_resistance_extract_admin1.csv'))

# Load raster files, format and extract values - ADMIN 2
res_dat2 <- extract_raster(raster_files, shp_file = shp_admin2) |>
  bind_rows() |>
  dplyr::select(year, NAME_1, NAME_2, everything())

if ('ISO' %in% colnames(res_dat1))res_dat1 <- res_dat1 |> dplyr::select(-ISO)
if ('ISO' %in% colnames(res_dat2))res_dat2 <- res_dat2 |> dplyr::select(-ISO)
res_dat2$NAME_2 <- iconv(res_dat2$NAME_2, from = '', "ASCII//TRANSLIT")
res_dat2$NAME_1 <- iconv(res_dat2$NAME_1, from = '', "ASCII//TRANSLIT")
res_dat2$NAME_2[res_dat2$NAME_2 == 'Yamou'] <- 'Yomou'

fwrite(res_dat2, file.path(out_dir, 'insecticide_resistance_extract_admin2.csv'))

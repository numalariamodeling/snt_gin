source("input_processor/load_path_lib.R")
source("input_processor/functions.R")

intdir <- "intermediate_data/"
outdir <- file.path(boxdir, "projects\\hbhi_guinea\\simulation_inputs\\")
dir.create(file.path(intdir, "coord"), recursive = T)
masterdf <- data.table::fread(master_csv)

shp <- shpfile |> st_read()
# shp <- st_transform(shp, 4326)

xy <- st_centroid(shp) |> st_coordinates() |> as.data.frame()
xy$name <- shp$NAME_2
xy$name[xy$name == "Yamou"] <- "Yomou"
xy$name <- match_names(xy$name, masterdf$DS_Name)
xy$nodes <- 1
xy$X <- round(xy$X, 5)
xy$Y <- round(xy$Y, 5)

for (ds in xy$name) {
  df <- xy |> filter(name == ds) |>
    select(name, lat=Y, lon=X, nodes)
  ds1 <- ds |> str_replace_all(' ', '_')
  data.table::fwrite(df, file.path(intdir, 'coord', glue('{ds1}.csv')))
}
source("input_processor/load_path_lib.R")
source("input_processor/functions.R")

outdir <- file.path(datadir, "intermediate_data")
if (!dir.exists(outdir)) dir.create(outdir)

shp <- shpfile |> shapefile() |>
  spTransform(CRS("+init=epsg:32628"))

for (yr in c(2012, 2018, 2021)) {
  ge_sp <- get_ge(dhsdir, yr)
  cond <- ge_sp$LATNUM == 0 & ge_sp$LONGNUM == 0
  ge_sp <- ge_sp[!cond,]
  
  kr_df <- get_kr(dhsdir, yr)
  kr_agg <- kr_df %>%
    group_by(DHSCLUST = v001) %>%
    filter(h22 == 1) %>%
    summarise(n = n(),
              rec_trt = sum(h32z == 1, na.rm = T),
              month = getMode(v006))
  
  ge_sp@data <- ge_sp@data %>%
    left_join(kr_agg, by = "DHSCLUST")
  ge_sp <- ge_sp[!is.na(ge_sp$month),]
  ge_coord <- ge_sp %>% spTransform(crs(shp)) %>%
    coordinates()
  
  #### Make grids along shp
  gr <- makegrid(shp, cellsize = c(2000, 2000))
  gr_sp <- gr %>% as.matrix %>%
    SpatialPoints(proj4string = crs(shp))
  
  #### Extract
  cov_df <- data.frame(DHSCLUST = ge_sp$DHSCLUST,
                       x = ge_coord[,1], y = ge_coord[,2])
  gr_df <- data.frame(x = gr[,1], y = gr[,2])
  
  
  #### Outputting
  cov_df$n <- ge_sp$n
  cov_df$rec_trt <- ge_sp$rec_trt
  
  yr_outdir <- file.path(outdir, yr)
  if (!dir.exists(yr_outdir)) dir.create(yr_outdir)
  
  data.table::fwrite(cov_df,
                     file.path(yr_outdir, "fitting_data.csv"))
  data.table::fwrite(gr_df,
                     file.path(yr_outdir, "prediction_data.csv"))
  
}

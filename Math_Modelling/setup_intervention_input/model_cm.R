library(INLA)
source("input_processor/load_path_lib.R")
source("input_processor/functions.R")

intdatadir <- file.path(datadir, "intermediate_data")
shp <- shpfile |> shapefile() |>
  spTransform(CRS("+init=epsg:32628"))
master_df <- data.table::fread(master_csv)

read_data <- function (year) {
  fit_dat <- data.table::fread(
    file.path(intdatadir, year, "fitting_data.csv")) %>%
    na.omit
  
  pred_dat <- data.table::fread(
    file.path(intdatadir, year, "prediction_data.csv")) %>%
    na.omit
  
  return(list(fit_dat, pred_dat))
}

model_cm_year <- function (yr) {
  L <- read_data(yr)
  fit_dat <- L[[1]]
  pred_dat <- L[[2]]
  
  ## Mesh matter
  coords_fit <- fit_dat[,c("x", "y")] %>% as.matrix
  coords_pred <- pred_dat[,c("x", "y")] %>% as.matrix
  
  mesh <- inla.mesh.2d(coords_fit, cutoff = 500, max.edge = c(20000, 50000))
  plot(mesh, asp=1)
  plot(shp, add=T)
  
  ## A matrix and stacks
  spde <- inla.spde2.matern(mesh=mesh, alpha=2)
  
  A <- inla.spde.make.A(mesh, loc=coords_fit)
  Apred <- inla.spde.make.A(mesh, loc=coords_pred)
  
  ## Create stacks
  fieldInd <- inla.spde.make.index("field", n.spde=mesh$n)
  
  stk.fit <- inla.stack(data=list(y=fit_dat$rec_trt),
                        A=list(A), tag='fit',
                        effects=list(fieldInd))
  stk.pred <- inla.stack(data=list(y=NA),
                         A=list(Apred), tag='pred',
                         effects=list(fieldInd))
  stk.all <- inla.stack(stk.fit, stk.pred, remove.unused = T)
  
  ## Model
  N <- c(fit_dat$n, rep(NA, nrow(pred_dat)))
  form <- y ~ 1 + f(field, model=spde)
  mod <- inla(form, family = "binomial",
              control.compute=list(cpo=TRUE),
              data=inla.stack.data(stk.all),
              control.predictor=list(
                A=inla.stack.A(stk.all), compute=T, link=1),
              control.inla= list(int.strategy='eb',
                                 fast=TRUE,dz=1,
                                 step.factor=0.5,
                                 stupid.search=FALSE),
              Ntrials = N, verbose = T)
  
  ## Extract predictions
  id.pred <- inla.stack.index(stk.all, 'pred')$data
  pred <- mod$summary.fitted.values$mean[id.pred]
  predl <- mod$summary.fitted.values$`0.025quant`[id.pred]
  predu <- mod$summary.fitted.values$`0.975quant`[id.pred]
  pred_r <- cbind(coords_pred, pred) %>% rasterFromXYZ(crs = crs(shp))
  predl_r <- cbind(coords_pred, predl) %>% rasterFromXYZ(crs = crs(shp))
  predu_r <- cbind(coords_pred, predu) %>% rasterFromXYZ(crs = crs(shp))
  
  plot(pred_r)
  plot(shp, add=T)
  
  ## Population weighted DS values
  yr1 <- ifelse(yr == 2021, 2020, yr)
  f <- list.files(file.path(datadir, "Population", "raster"),
                  pattern = glue("gin_ppp_{yr1}.*.tif"),
                  full.names = T)
  pop <- raster(f)
  pop <- projectRaster(pop, crs=projection(shp))
  
  pred_sp <- SpatialPoints(coords_pred, proj4string = CRS(projection(shp)))
  pred_df <- over(pred_sp, shp) %>%
    dplyr::select(DS_Name = NAME_2)
  pred_df$pop <- extract(pop, pred_sp)
  pred_df$pred <- pred
  pred_df$predl <- predl
  pred_df$predu <- predu
  
  cm_by_ds <- pred_df %>%
    na.omit() %>%
    group_by(DS_Name) %>%
    summarise(cm_cov = sum(pred * pop)/sum(pop),
              cm_cov_lci = sum(predl * pop)/sum(pop),
              cm_cov_uci = sum(predu * pop)/sum(pop)) |>
    mutate(DS_Name = ifelse(DS_Name == "Yamou", "Yomou", DS_Name),
      DS_Name = match_names(DS_Name, master_df$DS_Name))
  
  outname <- paste0(intdatadir, "/cm_by_ds_", yr, ".csv")
  data.table::fwrite(cm_by_ds, outname)
}

model_cm_year(2012)
model_cm_year(2018)
model_cm_year(2021)

library(dplyr)

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

get_ge <- function (rootdir, year) {
  if (year == 2012) {
    ge_fname <- file.path(rootdir, "GN_2012_DHS_05212020", 
                          "GNGE61FL", "GNGE61FL.shp")
  } else if (year == 2018) {
    ge_fname <- file.path(rootdir, "GN_2018_DHS_05212020_1029_148964", 
                          "GNGE71FL", "GNGE71FL.shp")
  } else if (year == 2021) {
    ge_fname <- file.path(rootdir, "GN_2021_MIS_04272022_1346_148964", 
                          "GNGE81FL", "GNGE81FL.shp")
  } else {
    stop("Wrong year.")
  }
  
  return(raster::shapefile(ge_fname))
}

getMode <- function(v) {
  tab <- table(v)
  ind <- which.max(tab)[1]
  return(names(tab)[ind] |> as.numeric)
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


names_match <- function(x, y) {
  x <- unique(sort(x))
  y <- unique(sort(y))

  XnotinY <- which(!(x %in% y))
  YnotinX <- which(!(y %in% x))

  if (length(XnotinY) > 0 | length(YnotinX) > 0) {
    message(paste0("X not in Y n= ", length(XnotinY), ': ', paste0(x[XnotinY], collapse = '", "')))
    message(paste0("Y not in X n= ", length(YnotinX), ': ', paste0(y[YnotinX], collapse = '", "')))
    return(FALSE)
  }else {
    return(TRUE)
  }
}

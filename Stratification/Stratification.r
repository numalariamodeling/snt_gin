
###1. Estimates incidence following WHO framework

annual_routine_data_adjusted_update = annual_routine_data_adjusted %>%
  mutate(
    total_cases_report_public_sector = conf,
    cases_adjusted_presumed = conf + (pres*TPR),
    cases_adjusted_presumed_RR = cases_adjusted_presumed/rep_rate,
    cases_adjusted_presumed_RR_TSR = cases_adjusted_presumed_RR + F+T,
    crude_incidence = (total_cases_report_public_sector/Population)*1000,
    incidence_adj_presumed_cases = (cases_adjusted_presumed/Population)*1000,
    incidence_adj_presumed_cases_RR = (cases_adjusted_presumed_RR/Population)*1000,
    incidence_adj_presumed_cases_RR_TSR = (cases_adjusted_presumed_RR_TSR/Population)*1000)

  
### Plots all incidences
### Crude incidence
Fig3.A = HD_sff %>%
  filter(year == 2022) %>%
  tm_shape() +
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  tm_polygons("crude_incidence", title = "Incidence pour 1000", style = "fixed",
              breaks = c(0, 100, 250, 450, 1000),
              palette = c( "#2166AC" , "#FDDBC7", "#F4A582", "#E41A1C","#B2182B")) +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6,frame = FALSE)



### 

g2 = HD_sff %>%
  filter(year == 2021) %>%
  tm_shape() +
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  tm_polygons("crude_incidence", title = "Incidence pour 1000", style = "fixed",
              breaks = c(0, 5, 50, 100, 200, 300, 500, 1000),
              palette = c("#92C5DE", "#4393C3", "#2166AC" , "#FDDBC7", "#F4A582", "#E41A1C","#B2182B")) +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6,frame = FALSE)


g3 = HD_sff %>%
  filter(year == 2020) %>%
  tm_shape() +
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  tm_polygons("crude_incidence", title = "Incidence pour 1000", style = "fixed",
              breaks = c(0, 5, 50, 100, 200, 300, 500, 1000),
              palette = c("#92C5DE", "#4393C3", "#2166AC" , "#FDDBC7", "#F4A582", "#E41A1C","#B2182B")) +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6,frame = FALSE)



g4 = HD_sff %>%
  filter(year == 2019) %>%
  tm_shape() +
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  tm_polygons("crude_incidence", title = "Incidence pour 1000", style = "fixed",
              breaks = c(0, 5, 50, 100, 200, 300, 500, 1000),
              palette = c("#92C5DE", "#4393C3", "#2166AC" , "#FDDBC7", "#F4A582", "#E41A1C","#B2182B")) +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6,frame = FALSE)



g5 = HD_sff %>%
  filter(year == 2018) %>%
  tm_shape() +
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  tm_polygons("crude_incidence", title = "Incidence pour 1000", style = "fixed",
              breaks = c(0, 5, 50, 100, 200, 300, 500, 1000),
              palette = c("#92C5DE", "#4393C3", "#2166AC" , "#FDDBC7", "#F4A582", "#E41A1C","#B2182B")) +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6,frame = FALSE)


tmap_arrange(g1, g2, g3,g4,g5,nrow=2)

### adjinc 1
all_incidences_adjinc1 = HD_sff %>%
  tm_shape() +
  tm_polygons("incidence_adj_presumed_cases", title = "Incidence pour 1000", style = "fixed",
              breaks = c(0, 5, 50, 100, 200, 300, 500, 1000),
              palette = c("#92C5DE", "#4393C3", "#2166AC" , "#FDDBC7", "#F4A582", "#E41A1C","#B2182B")) +
  tm_facets('year', nrow = 2) +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6,frame = FALSE)



### adjinc 2
all_incidences_adjinc2 = HD_sff %>%
  tm_shape() +
  tm_polygons("incidence_adj_presumed_cases_RR", title = "Incidence pour 1000", style = "fixed",
              breaks = c(0, 5, 50, 100, 200, 300, 500, 1000),
              palette = c("#92C5DE", "#4393C3", "#2166AC" , "#FDDBC7", "#F4A582", "#E41A1C","#B2182B")) +
  tm_facets('year', nrow = 2) +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6,frame = FALSE)

### adjinc 3
all_incidences_adjinc3 = HD_sff %>%
  tm_shape() +
  tm_polygons("incidence_adj_presumed_cases_RR_TSR", title = "Incidence pour 1000", style = "fixed",
              breaks = c(0, 5, 50, 100, 200, 300, 500, 1000),
              palette = c("#92C5DE", "#4393C3", "#2166AC" , "#FDDBC7", "#F4A582", "#E41A1C","#B2182B")) +
  tm_facets('year', nrow = 2) +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6,frame = FALSE)


###2. Prevalence from Malaria atlas Project

GN_2021 = GIN_MAP_output_WHOpop_20230206_3_ %>%
  filter(year == 2021 & Region !="Conakry") %>%
  group_by(District) %>%
  summarise(PFPR_u5 = mean(pfpr_u5, na.rm = TRUE)) %>%
  mutate(PFPR_u5 = PFPR_u5*100)


prev = HD_prev %>%
  tm_shape() +
  tm_polygons("PFPR_u5", title = "", style = "fixed",
              palette = "-RdYlBu") +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)


###3. All causes mortality from IHME

GIN_HDs_aggregated_mortality_estimates = GIN_HDs_aggregated_mortality_estimates %>%
  mutate(u5_mortality = round(u5_q_mean*100,2), adm2 = District) %>%
  filter(year == 2017)


u5_mortality = HD_mortality %>%
  tm_shape() +
  tm_polygons("u5_mortality", title = "", style = "fixed",
              breaks = c(0, 6.5, 7.5, 9.5, 12.5, 15, 20),
              labels = c("<6.5","6.5-<7.5",'7.5<9.5', "9.5-<12.5", "12.5-<15", ">=15"),
              palette = "-RdYlBu") +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)


###3. Incidence + Prevalence (Morbidity)

annual_routine_data_mediane = annual_routine_data_mediane %>%
  mutate(score_inc = case_when(
    incidence_RR_mediane < 100 ~ 1,
    incidence_RR_mediane >= 100 & incidence_RR_mediane <250 ~ 2,
    incidence_RR_mediane >= 250 & incidence_RR_mediane <450 ~3,
    incidence_RR_mediane >=450 ~ 4,
    TRUE ~ incidence_RR_mediane
  ),
  score_prev = case_when(
    pfpr_u5 < 10 ~ 1,
    pfpr_u5 >=10 & pfpr_u5 <20 ~2,
    pfpr_u5 >= 20 & pfpr_u5 <40 ~ 3,
    pfpr_u5 >=40 ~4,
    TRUE ~ pfpr_u5
  )) %>%
  rowwise() %>%
  mutate(combo = sum(score_inc, score_prev))


combo = HD_composite %>%
  tm_shape() +
  tm_polygons("combo", title = "", style = "fixed",
              palette = c("#2166AC", "#92C5DE","#F4A582", "#B2182B")) +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)

###4. Morbidity+Mortality
annual_routine_data_mediane = annual_routine_data_mediane %>%
  mutate(score_mort = case_when(
    u5_mortality >= 7.5 & u5_mortality < 9.5 ~1,
    u5_mortality >=9.5 & u5_mortality < 12.5 ~2,
    u5_mortality >= 12.5 & u5_mortality <=15 ~3
  )) %>%
  rowwise()%>%
  mutate(combo_morbi_mort = sum(combo, score_mort))

maps_mortality = HD_composite_finale %>%
  tm_shape() +
  tm_polygons("combo_morbi_mort", title = "", style = "fixed",
              palette = c("#2166AC", "#92C5DE","#F4A582", "#B2182B")) +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)
            

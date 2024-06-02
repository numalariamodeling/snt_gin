##### IRS strategic map

HD_composite_finale = HD_composite_finale %>%
  mutate(PBO_MILDA = ifelse(combo_morbi_mort %in% c(8,9), 1, 0),
         PBO_MILDA = ifelse(adm2 == "Nzerekore", 1, PBO_MILDA))

HD_composite_finale$PBO_MILDA = as.factor(HD_composite_finale$PBO_MILDA)

HD_composite_finale = HD_composite_finale %>%
  mutate(IRS_strategic = ifelse(combo_morbi_mort == 9, 1, 0))

HD_composite_finale$IRS_strategic = as.factor(HD_composite_finale$IRS_strategic)


IRS_stra_finale = HD_composite_finale %>%
  #filter(year == 2021) %>%
  tm_shape() +
  tm_polygons('PBO_MILDA',
              palette = c("1"="#238B45", "0"="#C7E9C0"))+
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  # tm_polygons("campaign", title = "", style = "fixed",
  #             #breaks = c(0, 30, 50, 70, 100),
  #             #labels = c('0<30', "30-<50", "50-<70", "70-<100"),
  #             palette = "#92C5DE", "#762A83", "#C51B7D") +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)



pdf('irs_strate_finale.pdf')
print(IRS_stra_finale)
dev.off()


#### MILDA PBO/IG2 PID mise en oeuvre

PBO_stra = HD_composite_finale %>%
  #filter(year == 2021) %>%
  tm_shape() +
  tm_polygons('IRS_strategic',
              palette = c("1"="#969696", "0"="#238B45"))+
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  # tm_polygons("campaign", title = "", style = "fixed",
  #             #breaks = c(0, 30, 50, 70, 100),
  #             #labels = c('0<30', "30-<50", "50-<70", "70-<100"),
  #             palette = "#92C5DE", "#762A83", "#C51B7D") +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)



pdf('PBO_strategique.pdf')
print(PBO_stra)
dev.off()


## PBO/IG2 prioritization, PID mise en oeuvre

HD_composite_finale = HD_composite_finale %>%
  mutate(PBO_prior = ifelse(IRS_strategic ==0 & combo_morbi_mort %in% c(8,9), 1, ifelse(IRS_strategic == 1, 2, 3)))

HD_composite_finale$PBO_prior = as.factor(HD_composite_finale$PBO_prior)

PBO_prior_slide_87 = HD_composite_finale %>%
  #filter(year == 2021) %>%  
  tm_shape() +
  tm_polygons('PBO_prior',
              palette = c("1"="#238B45", "2"="#969696", "3" = "#C7E9C0"))+
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  # tm_polygons("campaign", title = "", style = "fixed",
  #             #breaks = c(0, 30, 50, 70, 100),
  #             #labels = c('0<30', "30-<50", "50-<70", "70-<100"),
  #             palette = "#92C5DE", "#762A83", "#C51B7D") +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)



pdf('PBO_prior_slide_83_fin.pdf')
print(PBO_prior_slide_87)
dev.off()



############## IRS, PID pas mise en oeuvre

HD_composite_finale = HD_composite_finale %>%
  mutate(PBO_prior_without_IRS = ifelse(combo %in% c(6,7), 1, 0),
         PBO_prior_without_IRS = ifelse(adm2 %in% c("Nzerekore", "Forecariah"), 1, PBO_prior_without_IRS))

HD_composite_finale$PBO_prior_without_IRS = as.factor(HD_composite_finale$PBO_prior_without_IRS)

PBO_prior_without_IRS_slide_84 = HD_composite_finale %>%
  #filter(year == 2021) %>%
  tm_shape() +
  tm_polygons('PBO_prior_without_IRS',
              palette = c("1"="#238B45", "0"="#C7E9C0"))+
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  # tm_polygons("campaign", title = "", style = "fixed",
  #             #breaks = c(0, 30, 50, 70, 100),
  #             #labels = c('0<30', "30-<50", "50-<70", "70-<100"),
  #             palette = "#92C5DE", "#762A83", "#C51B7D") +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)



pdf('PBO_prior_without_IRS_update_fianle.pdf')
print(PBO_prior_without_IRS_slide_84)
dev.off()


### ciblage du vaccin

##1. Incidence and mortality

HD_composite_finale1 = HD_composite_finale %>%
  #dplyr::left_join(mortality, by=c("REGION", "PREF")) %>%
  dplyr::mutate(adjinc3_cat = cut(incidence_RR_mediane, c(0, 250, 350, 450, 2000), labels = c("0<250", "250<350", "350<450", ">=450")),
                au5mr_cat = u5_mortality,
                priority = case_when(
                  adjinc3_cat == '>=450' & au5mr_cat >9.5 ~1,
                  adjinc3_cat == '>=450' & au5mr_cat >= 7.5 & au5mr_cat < 9.5 ~1,
                  adjinc3_cat == '350<450' & au5mr_cat > 9.5 ~1,
                  adjinc3_cat == '250<350' & au5mr_cat >=9.5 ~2,
                  adjinc3_cat == '350<450' & au5mr_cat >= 7.5 & au5mr_cat <9.5 ~2,
                  adjinc3_cat == '>=450' & au5mr_cat >= 6.5 & au5mr_cat <7.5 ~2,
                  adjinc3_cat == '250<350' & au5mr_cat >= 7.5 & au5mr_cat < 9.5 ~3,
                  adjinc3_cat == '350<450' & au5mr_cat >= 6.5 & au5mr_cat <7.5 ~3,
                  adjinc3_cat == '>=450' & au5mr_cat  >=6.5 ~3,
                  adjinc3_cat == '250<350' & au5mr_cat >= 6.5 & au5mr_cat <7.5 ~4,
                  adjinc3_cat == '350<450' & au5mr_cat <=6.5 ~4,
                  adjinc3_cat == '250<350' & au5mr_cat <=6.5 ~5
                ))


HD_composite_finale = HD_composite_finale %>%
  #dplyr::left_join(HD,., by = c("REGION",'PREF')) %>%
  dplyr::mutate(cat = as.factor(priority))


incide_mortal = incide_2021 %>%
  dplyr::left_join(mortality, by=c("REGION", "PREF")) %>%
  dplyr::mutate(adjinc3_cat = cut(adjinc3, c(0, 250, 350, 450, 2000), labels = c("0<250", "250<350", "350<450", ">=450")),
                priority = case_when(
                  adjinc3_cat == '>=450' & au5mr_cat == '>=9.5%' ~1,
                  adjinc3_cat == '>=450' & au5mr_cat == '7.5<9.5%' ~1,
                  adjinc3_cat == '350<450' & au5mr_cat == '>=9.5%' ~1,
                  adjinc3_cat == '250<350' & au5mr_cat == '>=9.5%' ~2,
                  adjinc3_cat == '350<450' & au5mr_cat == '7.5<9.5%' ~2,
                  adjinc3_cat == '>=450' & au5mr_cat == '6.5<7.5%' ~2,
                  adjinc3_cat == '250<350' & au5mr_cat == '7.5<9.5%' ~3,
                  adjinc3_cat == '350<450' & au5mr_cat == '6.5<7.5%' ~3,
                  adjinc3_cat == '>=450' & au5mr_cat == '<=6.5%' ~3,
                  adjinc3_cat == '250<350' & au5mr_cat == '6.5<7.5%' ~4,
                  adjinc3_cat == '350<450' & au5mr_cat == '<=6.5%' ~4,
                  adjinc3_cat == '250<350' & au5mr_cat == '<=6.5%' ~5,
                  adjinc3_cat == '0<250' ~ 0
                ))


HD_composite_finale = HD_composite_finale %>%
  dplyr::mutate(name = forcats::fct_relevel(cat, '2', '3', '<250 cas pour 1000'))


vaccine_inc_mort = HD_composite_finale1 %>%
  #filter(year == 2021) %>%
  tm_shape() +
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  tm_polygons("name", title = "Catégories", style = "fixed",
              #breaks = c(0, 250, 350, 450, 2000),
              #labels = c('0<250', "250<350", "350<450", "450<2000"),
              palette = c("#762A83", "#C51B7D", "#DE77AE",  "< 250 cas/1000"= "#FFFFFF")) +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6,frame = FALSE)


pdf('vaccine_adjinc2_mortality_fina.pdf')
print(vaccine_inc_mort)
dev.off()


vaccine_adjinc2_morta_update = HD_composite_finale1 %>%
  #filter(year == 2021) %>%
  tm_shape() +
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  tm_polygons("name", title = "Catégories", style = "fixed",
              #breaks = c(0, 250, 350, 450, 2000),
              #labels = c('0<250', "250<350", "350<450", "450<2000"),
              palette = c("2" = "#762A83", "3" = "#C51B7D", "< 250 cas/1000"= "#FFFFFF")) +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6,frame = FALSE)



pdf('vaccine_adjinc2_mortality_update.pdf')
print(vaccine_adjinc2_morta_update)
dev.off()

## Prevalence and mortality

HD_composite_finale1 = HD_composite_finale1 %>%
  mutate(cat_prev = case_when(
    pfpr_u5>=20 & pfpr_u5<40 & u5_mortality >=9.5 ~ 1,
    pfpr_u5 >=40 & u5_mortality >=9.5 ~1,
    pfpr_u5 >= 40 & u5_mortality >= 7.5 & u5_mortality <9.5 ~ 1,
    pfpr_u5>=10 & pfpr_u5 <20 & u5_mortality >=9.5 ~2,
    pfpr_u5>=20 & pfpr_u5<40 & u5_mortality >=7.5 & u5_mortality<9.5 ~2,
    pfpr_u5 >=40 & u5_mortality<=7.5 ~ 2,
    pfpr_u5 >= 10 & pfpr_u5<20 & u5_mortality >=7.5 & u5_mortality<9.5 ~3,
    pfpr_u5>=20 & pfpr_u5<40 & u5_mortality<=7.5 ~ 3,
    pfpr_u5>=40 & u5_mortality<=6.5 ~ 3,
    pfpr_u5 >= 10 & pfpr_u5 < 20 & u5_mortality<=7.5 ~4,
    pfpr_u5>=20 & pfpr_u5<40 & u5_mortality <=6.5 ~4,
    pfpr_u5 >= 10 & pfpr_u5 < 20 & u5_mortality<=6.5 ~5,
    pfpr_u5<10~0
    
  ))


HD_composite_finale = HD_composite_finale %>%
  dplyr::mutate(name_prev = as.factor(cat_prev))


vaccine_prev_mort = HD_composite_finale %>%
  #filter(year == 2021) %>%
  tm_shape() +
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  tm_polygons("name_prev", title = "Catégories", style = "fixed",
              #breaks = c(0, 250, 350, 450, 2000),
              #labels = c('0<250', "250<350", "350<450", "450<2000"),
              palette = c("#762A83", "#C51B7D", "#DE77AE", "#FFFFFF")) +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6,frame = FALSE)


pdf('vaccine_prev_mortality.pdf')
print(vaccine_prev_mort)
dev.off()


### Re-categoriser la categorie 1 (taux d'abandon <= 5)

HD_composite_finale = HD_composite_finale %>%
  mutate(recat1 = ifelse(adm2 %in% vec, 1, 0))


HD_composite_finale$recat1 = as.factor(HD_composite_finale$recat1)

recat1 = HD_composite_finale %>%
  #filter(year == 2021) %>%
  tm_shape() +
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  tm_polygons("cate1_f", title = "Catégories", style = "fixed",
              #breaks = c(0, 250, 350, 450, 2000),
              #labels = c('0<250', "250<350", "350<450", "450<2000"),
              palette = c("#762A83", "#C51B7D", "#DE77AE", "#FFFFFF")) +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6,frame = FALSE)

pdf('recat1_finale.pdf')
print(recat1)
dev.off()
### population des moins de 1 an

HD_composite_finale = HD_composite_finale %>%
  left_join(population_u1, by='adm2')


pop_moins_1 = HD_composite_finale %>%
  #filter(name_prev == 1) %>%
  tm_shape() +
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  #tm_polygons("population_u1", title = "Population",palette = "Dark2") +
  tm_polygons("name_prev",title = "Catégorie", palette = c("2"="#C51B7D", "1"="#762A83")) +
  tm_bubbles(size = "population_u1", col = "navy",
             title.size = "Population de moins de 1 ans") +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6,frame = FALSE)



pdf('population_u1.pdf')
print(pop_moins_1)
dev.off()



##### Zones eligibles CPS

prev_cps = HD_composite_finale %>%
  #filter(year == 2020) %>%
  tm_shape() +
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  tm_polygons("pfpr_u5", title = "", style = "fixed",
              breaks = c(0, 5, 10, 
                         20, 40, 60),
              labels = c('0-5', "5<10", "10<20", "20<40", ">40"),
              palette = "-RdYlBu") +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)

pdf("Preva_CPS.pdf")
print(prev_cps)
dev.off()

####

HD_composite_finale = HD_composite_finale %>%
  mutate(cps = ifelse(pfpr_u5 > 5, 1, 0),
         cps_without_kindia = ifelse(adm2 %in% c("kindia", "Telimele", "Dubreka", "Coyah", "Forecariah", "Boke",
                                                 "Macenta", "Nzerekore", "Yomou", "Lola"), 0, 1))


HD_composite_finale$cps=as.factor(HD_composite_finale$cps)

HD_composite_finale$cps_without_kindia=as.factor(HD_composite_finale$cps_without_kindia)



cps = HD_composite_finale %>%
  #filter(year == 2021) %>%
  tm_shape() +
  tm_polygons('cps',
              palette = c("0"="#FFFFFF", "1"="#D94801"))+
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  # tm_polygons("campaign", title = "", style = "fixed",
  #             #breaks = c(0, 30, 50, 70, 100),
  #             #labels = c('0<30', "30-<50", "50-<70", "70-<100"),
  #             palette = "#92C5DE", "#762A83", "#C51B7D") +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)



pdf('CPS_all_DS.pdf')
print(cps)
dev.off()



cps_without_kindia = HD_composite_finale %>%
  #filter(year == 2021) %>%
  tm_shape() +
  tm_polygons('cps_without_kindia',
              palette = c("0"="#FFFFFF", "1"="#D94801"))+
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  # tm_polygons("campaign", title = "", style = "fixed",
  #             #breaks = c(0, 30, 50, 70, 100),
  #             #labels = c('0<30', "30-<50", "50-<70", "70-<100"),
  #             palette = "#92C5DE", "#762A83", "#C51B7D") +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)



pdf('CPS_without_kindia_boke_nzere.pdf')
print(cps_without_kindia)
dev.off()

### CPS according to rainfall
HD_composite_finale = HD_composite_finale %>%
  mutate(CPS_past = ifelse(adm2 %in% c('Labe', 'Mali', 'Lelouma', 'Tougue','Koubia', 'Gaoual', 'Koundara', 'Dalaba', 'Pita', 'Mamou',
                                       'Dinguiraye','Dabola', 'Faranah', 'Kouroussa', 'Mandiana', 'Siguiri', 'Kankan'), 1,0),
         CPS_rainfall = ifelse(adm2 %in% c("Boke", "Lola", "Nzerekore", "Yomou", "Macenta"), 0, 1),
         CPS_rainfall_cases = ifelse(adm2 %in% c("Kerouane", "Kissidougou", "Pita", "Dalaba", "Mamou", "Telimele", "Coyah", "Dubreka", "Forecariah"), 1, 0),
         class_CPS = ifelse(CPS_past == 1, 1, ifelse(CPS_past == 0 & CPS_rainfall == 1 & CPS_rainfall_cases == 1, 2, 3)))

HD_composite_finale$class_CPS=as.factor(HD_composite_finale$class_CPS)


### CPS according to rainfall
HD_composite_finale = HD_composite_finale %>%
  mutate(CPS_past = ifelse(adm2 %in% c('Labe', 'Mali', 'Lelouma', 'Tougue','Koubia', 'Gaoual', 'Koundara', 'Dalaba', 'Pita', 'Mamou',
                                       'Dinguiraye','Dabola', 'Faranah', 'Kouroussa', 'Mandiana', 'Siguiri', 'Kankan'), 1,0),
         #CPS_rainfall = ifelse(adm2 %in% c("Boke", "Lola", "Nzerekore", "Yomou", "Macenta"), 0, 1),
         CPS_rainfall_cases = ifelse(adm2 %in% c("Kerouane", "Kissidougou", "Telimele"), 1, 0),
         class_CPS = ifelse(CPS_past == 1, 1, ifelse(CPS_past == 0 & CPS_rainfall_cases == 1, 2, 3)))

HD_composite_finale$class_CPS=as.factor(HD_composite_finale$class_CPS)

CPS_EXPANSION = HD_composite_finale %>%
  #filter(year == 2021) %>%  
  tm_shape() +
  tm_polygons('class_CPS',
              palette = c("1"="#D94801", "3"="#FFFFFF", "2" = "#B2182B"))+
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  # tm_polygons("campaign", title = "", style = "fixed",
  #             #breaks = c(0, 30, 50, 70, 100),
  #             #labels = c('0<30', "30-<50", "50-<70", "70-<100"),
  #             palette = "#92C5DE", "#762A83", "#C51B7D") +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)



pdf('CPS_EXPANSION_finale.pdf')
print(CPS_EXPANSION)
dev.off()


### CPP

HD_composite_finale = HD_composite_finale %>%
  mutate(#CPS = ifelse(adm2 %in% c('Labe', 'Mali', 'Lelouma', 'Tougue','Koubia', 'Gaoual', 'Koundara', 'Dalaba', 'Pita', 'Mamou',
    #  'Dinguiraye','Dabola', 'Faranah', 'Kouroussa', 'Mandiana', 'Siguiri', 'Kankan'), 1,0),
    CPP = ifelse(class_CPS == 3 & pfpr_u5 > 10, 1, 0))




HD_composite_finale$CPP=as.factor(HD_composite_finale$CPP)



CPP = HD_composite_finale %>%
  #filter(year == 2021) %>%
  tm_shape() +
  tm_polygons('CPP',
              palette = c("0"="#FFFFFF", "1"="#FFFFCC"))+
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  # tm_polygons("campaign", title = "", style = "fixed",
  #             #breaks = c(0, 30, 50, 70, 100),
  #             #labels = c('0<30', "30-<50", "50-<70", "70-<100"),
  #             palette = "#92C5DE", "#762A83", "#C51B7D") +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)



pdf('CPP_update_finale_finale.pdf')
print(CPP)
dev.off()


### CPP pilote

HD_composite_finale = HD_composite_finale %>%
  mutate(CPP_pilote = ifelse(CPP ==1 & adm2 %in% c("Nzerekore", "Lola", "Yomou", "Beyla", "Gueckedou", "Macenta"), 1, 0))


HD_composite_finale$CPP_pilote=as.factor(HD_composite_finale$CPP_pilote)



CPP_pilote = HD_composite_finale %>%
  #filter(year == 2021) %>%
  tm_shape() +
  tm_polygons('CPP_pilote',
              palette = c("0"="#FFFFFF", "1"="#FFFFCC"))+
  #tm_polygons(col = "net_use", breaks = c(0, 35,45, 55, 65, 75, 90), palette = "viridis") +
  # tm_polygons("campaign", title = "", style = "fixed",
  #             #breaks = c(0, 30, 50, 70, 100),
  #             #labels = c('0<30', "30-<50", "50-<70", "70-<100"),
  #             palette = "#92C5DE", "#762A83", "#C51B7D") +
  #tm_facets("year", ncol = 2) +
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)



pdf('CPP_pilote_update_finale_finale.pdf')
print(CPP_pilote)
dev.off()
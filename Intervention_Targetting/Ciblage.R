### Interventions targeting

#1. Targeting of IRS 

HD_composite_finale = HD_composite_finale %>%
  mutate(IRS_strategic = ifelse(combo_morbi_mort == 9, 1, 0))

Fig4 = HD_composite_finale %>%
  tm_shape() +
  tm_polygons('IRS_strategic',
              palette = c("1"="#969696", "0"="#238B45"))+
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)


###2. Targeting of IG2 bednets 

Fig5.A = HD_composite_finale %>%
  tm_shape() +
  tm_polygons('PBO_MILDA',
              palette = c("1"="#238B45", "0"="#C7E9C0"))+
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)


####3. Targeting of SMC

# Areas eligibles for SMC

HD_composite_finale = HD_composite_finale %>%
  mutate(cps = ifelse(pfpr_u5 > 5, 1, 0),
         cps_without_kindia = ifelse(adm2 %in% c("kindia", "Telimele", "Dubreka", "Coyah", "Forecariah", "Boke",
                                                 "Macenta", "Nzerekore", "Yomou", "Lola"), 0, 1))

cps = HD_composite_finale %>%
  tm_shape() +
  tm_polygons('cps',
              palette = c("0"="#FFFFFF", "1"="#D94801"))+
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)


# SMC according to rainfall
HD_composite_finale = HD_composite_finale %>%
  mutate(CPS_past = ifelse(adm2 %in% c('Labe', 'Mali', 'Lelouma', 'Tougue','Koubia', 'Gaoual', 'Koundara', 'Dalaba', 'Pita', 'Mamou',
                                       'Dinguiraye','Dabola', 'Faranah', 'Kouroussa', 'Mandiana', 'Siguiri', 'Kankan'), 1,0),
         CPS_rainfall = ifelse(adm2 %in% c("Boke", "Lola", "Nzerekore", "Yomou", "Macenta"), 0, 1),
         CPS_rainfall_cases = ifelse(adm2 %in% c("Kerouane", "Kissidougou", "Pita", "Dalaba", "Mamou", "Telimele", "Coyah", "Dubreka", "Forecariah"), 1, 0),
         class_CPS = ifelse(CPS_past == 1, 1, ifelse(CPS_past == 0 & CPS_rainfall == 1 & CPS_rainfall_cases == 1, 2, 3)))


### SMC according to rainfall
HD_composite_finale = HD_composite_finale %>%
  mutate(CPS_past = ifelse(adm2 %in% c('Labe', 'Mali', 'Lelouma', 'Tougue','Koubia', 'Gaoual', 'Koundara', 'Dalaba', 'Pita', 'Mamou',
                                       'Dinguiraye','Dabola', 'Faranah', 'Kouroussa', 'Mandiana', 'Siguiri', 'Kankan'), 1,0),
         #CPS_rainfall = ifelse(adm2 %in% c("Boke", "Lola", "Nzerekore", "Yomou", "Macenta"), 0, 1),
         CPS_rainfall_cases = ifelse(adm2 %in% c("Kerouane", "Kissidougou", "Telimele"), 1, 0),
         class_CPS = ifelse(CPS_past == 1, 1, ifelse(CPS_past == 0 & CPS_rainfall_cases == 1, 2, 3)))


Fig6.D = HD_composite_finale %>%
  tm_shape() +
  tm_polygons('class_CPS',
              palette = c("1"="#D94801", "3"="#FFFFFF", "2" = "#B2182B"))+
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)

###4. Targeting of the malaria vaccine

# Prevalence and mortality

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



g = HD_composite_finale %>%
  tm_shape() +
  tm_polygons("name_prev", title = "Catégories", style = "fixed"),
              palette = c("#762A83", "#C51B7D", "#DE77AE", "#FFFFFF")) +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6,frame = FALSE)


# Re-priotize category 1 (Dropout rate <= 5)

g1 = HD_composite_finale %>%
  tm_shape() +
  tm_polygons("cate1_f", title = "Catégories", style = "fixed"),
              palette = c("#762A83", "#C51B7D", "#DE77AE", "#FFFFFF")) +
  tm_layout(legend.outside = TRUE,
            legend.title.size = 0.6,
            legend.text.size = 0.6,frame = FALSE)




###5 Targeting of PMC 

HD_composite_finale = HD_composite_finale %>%
  mutate(CPP = ifelse(class_CPS == 3 & pfpr_u5 > 10, 1, 0))

g3 = HD_composite_finale %>%
  tm_shape() +
  tm_polygons('CPP',
              palette = c("0"="#FFFFFF", "1"="#FFFFCC"))+
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)


# PMC pilote areas

HD_composite_finale = HD_composite_finale %>%
  mutate(CPP_pilote = ifelse(CPP ==1 & adm2 %in% c("Nzerekore", "Lola", "Yomou", "Beyla", "Gueckedou", "Macenta"), 1, 0))


g4 = HD_composite_finale %>%
  tm_shape() +
  tm_polygons('CPP_pilote',
              palette = c("0"="#FFFFFF", "1"="#FFFFCC"))+
  tm_layout(legend.outside = FALSE,
            legend.title.size = 0.6,
            legend.text.size = 0.6, frame = FALSE)

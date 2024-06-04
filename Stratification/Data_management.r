###1 Missing values 

data_routine[, col][data_routine[, col] == 0] <- NA


missing_data = data_routine %>%
    dplyr::select(adm1, adm2, hf, date, Annee, Mois, susp,test, testrdt, testmic, conf,confmic, confrdt, pres, pressev, maladm,
          maltreat, maldth) %>%
    dplyr::group_by(adm1, adm2, date, Annee, Mois)%>%
   dplyr::summarise(across(susp:maldth, ~sum(is.na(.x))))%>%
   rename_with(~str_c("na_", .), .cols = all_of(col)) %>%
   ungroup() %>%
  left_join(liste_FS, by=c('adm1','adm2', 'date')) %>%
  tidyr::pivot_longer(cols = na_susp:na_maldth, names_to = 'Variables', values_to = 'Numerateur') %>%
  separate(Variables, into = c('Proportion',"Indicateurs", "Categories")) %>%
  select(Region = adm1, District = adm2, date, Annee, Mois,Indicateurs, Categories, Numerateur, Denominateur) %>%
  mutate(Categories = replace_na(Categories, 'Tous les ages'),
         type = recode(Indicateurs,  'susp' = "Cas suspects de Paludisme enfant tous les ages" , 'test'='Tests realises (TDR+GE) tous les ages',
                       'testrdt' = 'TDR realises tous les ages', 'testmic' = 'GE realises tous les ages', 'confmic'= 'GE positif tous les ages', 
                       'confrdt' = 'TDR positif tous les ages', 'conf' = 'TDR+GE positif tous les ages',
                       'maladm' = 'Cas confirmes de paludisme grave tous les ages', 
                       'pres' = 'Cas presume de paludisme simple tous les ages', 
                       'pressev' = 'Cas presume de Paludisme grave tous les ages', 
                       'maltreat' = 'Cas de paludisme simple confirmes traites aux ACT tous les ages',
                       'maldth' = 'Deces dus au paludisme grave tous les ages'),
         Proportion = round(Numerateur/Denominateur*100,2)) %>%
  select(Region, District, date, Annee, Mois, type, Numerateur, Denominateur, Proportion)


 Figure S1.2: = ggplot(test, aes(x = as.factor(date), y = type, fill = Proportion)) +
  geom_tile() +
  scale_fill_viridis (option = 'D') +
  xlab("Mois-Annee") + 
  ylab("Indicateurs") +
  theme_classic()

###2. Outliers detection

data = data_allout %>% gather(allout, allout_u5, allout_ov5, allout_preg, key='indicators', value="valeur")


p = ggplot(data = data, aes(x = valeur, y = name, color = as.factor(year)))+
  geom_point() +
  theme_classic() +
  theme(legend.position="bottom") +
  xlab('') +
  ylab('') 

p = p+ labs (color = 'year')
  
###3. Review of data coherence 

coherence_data = data_routine %>%
  select(adm1, adm2, hf, month, year,  test, susp, conf, maltreat, maladm, maldth) %>%
   mutate(test_suspects = ifelse(susp < test, 'Pas normal', 'Normal'),
         test_cas = ifelse(test < conf, 'Pas normal', 'Normal'),
         conf_traite = ifelse(conf < maltreat, 'Pas normal', 'Normal'))%>%
  pivot_longer(cols = test_suspects:conf_traite, names_to = 'type', values_to = 'Value')




### 4.  Reporting rate using only confirmed cases

data_hf_actifs[, cols][data_hf_actifs[, cols] == 0] <- NA

data_hf_actifs = data_hf_actifs %>%
  dplyr::mutate(nomiss = apply(bfa_hf_actifs[,c(7:9)], 1, function(y) sum(!is.na(y))),
                varmis =ifelse(nomiss == 0, 0, 1),
                actif = ifelse(varmis == 0, 'Inactif', 'actif'))

data_hf_active = data_hf_actifs %>%
  dplyr::arrange(adm1, adm2, hf,UID, Date) %>%
  dplyr::group_by(adm1, adm2, hf, UID) %>%
  dplyr::mutate(cummiss = sum(nomiss),
         hfinactivity = nomiss/3*100,
         start_date = min(Date[hfinactivity != 100]))

data_hf_active2 = data_hf_active %>% dplyr::group_by(adm2, month, year, Date) %>%
  dplyr::summarize(total_hf =length(UID),
                   total_hf_active = length(which(actif == 'actif'))) %>%
  dplyr::mutate(Reporting_rate = round(total_hf_active/total_hf*100,2))

  p = ggplot(data_hf_active2, aes(x = Date, y = adm2, fill = Reporting_rate)) +
  geom_tile() +
  scale_fill_viridis (option = 'D') +
  xlab("Year") + 
  ylab("Health districts") +
  theme_classic()

p= p + theme(legend.position="none")
p = p + theme(axis.text.x = element_text(face="bold", size = 5, angle = 45))


p = p + theme(
  panel.border = element_blank(),
  panel.grid.major = element_blank(),
  panel.grid.minor = element_blank()
)

Figure S1.1 = p + labs(fill = 'Reportin rate (Conf, test, susp)')

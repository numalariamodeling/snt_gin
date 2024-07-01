## SMC efficacy calibration ('vaccSMC)'
### _EMOD-dtk_


Scripts to calibrating SMC efficacy to Milligan/Zongo et al SMC trial in Burkina Faso using EMOD's vaccine campaign event as approximation (without  parasite clearing drug).
([malaria_vaccdrug_campaigns.py](https://github.com/InstituteforDiseaseModeling/dtk-tools-malaria/blob/master/malaria/interventions/malaria_vaccdrug_campaigns.py))

Note: in these fitting scripts the vaccine decay duration is per default scaled using
`'Decay_Time_Constant': vacc_decay_duration / math.log(2)`, with math.log(2)~0.6931471805599453.

### Running scripts
Working directory needs to be set at the repository root (**snt_gin**).  
For running calibration: 
1) run the `make_SMC_params.R` script with rnd set to 1, to create an initial csv for the sample parameters to run  
2) run simulation scripts with rnd set to 1,  `calibrate_milligan.py`  
3) set rnd in `make_SMC_params.R` to the next number i.e. 2 and run script  
4) repeat step 2 and 3 as needed  
_Note: the calibration settings in `make_SMC_params.R`  might need additional tweaking of initial parameter limits, or the  selection criteria (only those above median )_

Submission examples:
Example 1
``` 
  cd snt_gin/Math_Modelling/smc_efficacy
  Rscript make_SMC_params.R
  python calibrate_milligan.py
  python analyze_SMC_milligan.py -name vaccSMC_milligan_30_fit_rnd1 -id 2023_01_03_13_02_16_699134
  ## edit make_SMC_params.R, then run
  Rscript make_SMC_params.R
```

### Explore selected sample sets
The scripts `effect_size_comparison_single_dose_IIV.R` and  `effect_size_comparison_single_dose.R` generate plots to describe single SMC dose
by sample id and by EIR and requrie custom editing as needed.


### References

- Chandramohan D, et al 2021. 
**Seasonal Malaria Vaccination with or without Seasonal Malaria Chemoprevention.** 
N Engl J Med. 2021 Sep 9;385(11):1005-1017. Epub 2021 Aug 25. PMID: 34432975.
https://pubmed.ncbi.nlm.nih.gov/34432975/


- Zongo I, Milligan P, et al. 2015.
**Randomized Noninferiority Trial of Dihydroartemisinin-Piperaquine Compared with Sulfadoxine-Pyrimethamine plus Amodiaquine 
for Seasonal Malaria Chemoprevention in Burkina Faso**. 
Antimicrob Agents Chemother. 2015 Aug;59(8):4387-96. Epub 2015 Apr 27. https://pubmed.ncbi.nlm.nih.gov/25918149/




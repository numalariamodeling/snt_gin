## ITN efficacy Guinea 2010-2022


**Scripts:** 
- `r_helper.R`: helper functions for generating plots in R
- `itn_dtk_block_kill_functions.R` adapted from Ozodiegwu et al 2023 methodology, using more recent relationship by [Nash et al 2021](https://pubmed.ncbi.nlm.nih.gov/35284856/)
- `01_extract_resistance.R`: Extract resistance values from raster files for a specified country (here Guinea, obtained from [Hancock et al 2020](https://journals.plos.org/plosbiology/article?id=10.1371/journal.pbio.3000633))
- `02_itn_resistance_trend_adjustments.R`: Options for resistance trend smoothing presented to PNLP
- `03_country_resistance_scaling.R`: Generate ITN efficacy estimates per district in Guinea, accounting for resistance
- `04_SI_figure.R`: Figures for Supplement

**/parameterization:**  
- `00_itn_trial_param.R`:  Reproduced figures showing the relationships from Nash et al 2021, for EMOD
- `00_itn_waning_curves.py`: ITN retention curves plotted
- `01_expand_samples.py`: Script to generate sample csv for Banfora ITN fitting simulation
- `02_run_banfora_itncalib_20132014.py`: Run 2005-2019 for Banfora for ITN killing parameter fitting. Adapted from older hbhi workflow fit_2005-2019.py, still in dtk, not in emodpy, for reference only
- `03_analyze_itn_sim.py`: Corresponding analyzer script to 02_run_banfora_itncalib_20132014.py, using dtk, for reference only
- `04_fit_itn_kill_rate.R`: Loading simulation_outputs to get scaling factor for kill rate

**Other:**
- `itn_waning_curves.py`:
- `itn_trials_efficacy_parameters.xlsx`:

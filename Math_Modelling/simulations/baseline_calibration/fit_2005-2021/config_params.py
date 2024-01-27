import os
from pathlib import Path

import pandas as pd
import manifest
from emodpy_malaria.vector_config import set_species_param
from snt.hbhi.set_up_general import initialize_config
from snt.hbhi.set_up_interventions import InterventionSuite

# Files
larval_hab_csv = 'simulation_inputs/larval_habitats/monthly_habitats5.csv'
master_csv = 'guinea_DS_pop.csv'
rel_abund_csv = 'simulation_inputs/DS_vector_rel_abundance.csv'
samp_csv = 'simulation_priors/lhs_samples_v1.csv'

# Suite and experiment name
homepath = os.path.expanduser('~')
user = Path(homepath).name
expname = f'{user}_fit_gin_DS'
suitename = f'{user}_fit_gin_2005-2021'

# Simulations settings
num_seeds = 2
ser_num_seeds = 1
years = 17
ser_date = 45 * 365
serialize = False
pull_from_serialization = True
use_arch_burnin = True

filtered_report = 0
yr_plusone = True
event_reporter = False
add_event_report = False

burnin_id = "kbt4040_gin_1960-2004_2023_08_17_17_09"

# DS Settings
demographic_suffix = '_wSMC_risk_wIP'
climate_suffix = ''
climate_prefix = False
use_arch_input = False

# load dfs
master_df = pd.read_csv(os.path.join(manifest.IO_DIR, master_csv))
master_df = master_df.set_index('DS_Name')
samp_df = pd.read_csv(os.path.join(manifest.IO_DIR, samp_csv))
ds_list = samp_df.DS_Name.unique()

# INTERVENTIONS
## Intervention Suite
int_suite =  InterventionSuite()
# hs unchanged
int_suite.hs_ds_col = 'DS_Name'
int_suite.hs_duration = 365 # Set to none when want to follow df's duration to the dot
# itn
int_suite.itn_ds_col = 'DS_Name'
int_suite.itn_discard_distribution = 'weibull'
#int_suite.itn_discard_lambda = 2.39
int_suite.itn_cov_cols = ['U05', 'U10', 'U20', 'A20']
int_suite.itn_cov_age_bin = [0, 5, 10, 20]
int_suite.itn_retention_in_yr = 1.69
int_suite.itn_seasonal_months = [0, 91, 182, 274]
int_suite.itn_seasonal_values = [0.739, 0.501, 0.682, 1]
# smc
int_suite.smc_adherence = True
int_suite.smc_coverage_col = ['coverage_high_access_u5', 'coverage_low_access_u5',
                              'coverage_high_access_o5', 'coverage_low_access_o5']
int_suite.smc_access = ['High', 'Low', 'High', 'Low']
int_suite.smc_agemins = [0.25, 0.25, 5, 5]
int_suite.smc_agemax_type = ['fixed', 'fixed', 'fixed', 'fixed']
int_suite.smc_agemaxs = [5, 5, 10, 10]
int_suite.smc_leakage = False

# Config prefix
def set_config(config):
    initialize_config(config, manifest, years, serialize)

    config.parameters.x_Temporary_Larval_Habitat = 0.2  # Package default is 0.2
    config.parameters.x_Base_Population = 1
    config.parameters.x_Birth = 1

    config.parameters.Report_Event_Recorder = 1
    config.parameters.Report_Event_Recorder_Individual_Properties = []
    config.parameters.Report_Event_Recorder_Events = ['Received_NMF_Treatment', 
                                                      'Received_Severe_Treatment',
                                                      'Received_Treatment']
    config.parameters.Report_Event_Recorder_Ignore_Events_In_List = 0

    set_species_param(config, 'arabiensis', 'Anthropophily', 0.88, overwrite=True)
    set_species_param(config, 'arabiensis', 'Indoor_Feeding_Fraction', 0.5, 
                      overwrite=True)
    set_species_param(config, 'funestus', 'Anthropophily', 0.5, overwrite=True)
    set_species_param(config, 'funestus', 'Indoor_Feeding_Fraction', 0.86, 
                      overwrite=True)
    set_species_param(config, 'gambiae', 'Anthropophily', 0.74, overwrite=True)
    set_species_param(config, 'gambiae', 'Indoor_Feeding_Fraction', 0.9, overwrite=True)

    return config
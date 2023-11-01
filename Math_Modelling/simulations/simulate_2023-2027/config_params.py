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
samp_csv = 'simulation_priors/selected_particles_v1.csv'
scenariopath = os.path.join(manifest.IO_DIR, 'simulation_inputs/_scenarios_2023')
scenario_csv = 'scenarios_2023-2029.csv'

# Suite and experiment name
homepath = os.path.expanduser('~')
user = Path(homepath).name
expname = f'{user}_gin_2023-2029_3x'
suitename = f'{user}_gin_2023-2029_3x'

# Simulations settings
num_seeds = 15
ser_num_seeds = 15
years = 7
ser_date = 18 * 365
serialize = False
pull_from_serialization = True
use_arch_burnin = False

filtered_report = years
yr_plusone = True
event_reporter = False
add_event_report = True

burnin_id = "kbt4040_gin_2005-2022_3x_2023_09_27_09_56"

# DS Settings
demographic_suffix = '_wSMC_risk_wIP'
climate_suffix = ''
climate_prefix = False
use_arch_input = False

# load dfs
scen_df = pd.read_csv(os.path.join(scenariopath, scenario_csv)).set_index('scen')
master_df = pd.read_csv(os.path.join(manifest.IO_DIR, master_csv))
master_df = master_df.set_index('DS_Name')
samp_df = pd.read_csv(os.path.join(manifest.IO_DIR, samp_csv))
ds_list = samp_df.DS_Name.unique()
#ds_list = ['Kerouane', 'Kissidougou']

# INTERVENTIONS
## Intervention Suite
int_suite =  InterventionSuite()
# hs unchanged
int_suite.hs_ds_col = 'DS_Name'
int_suite.hs_duration = 365 # Set to none when want to follow df's duration to the dot
int_suite.hs_coverage_age = {
    'u5_coverage': [0, 5],
    'adult_coverage': [5, 100]
}
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
# pmc
int_suite.pmc_touchpoint_col = 'pmc_age_days'
int_suite.pmc_start_col = 'simday'
int_suite.pmc_coverage_col = 'pmc_coverage'
# rtss
int_suite.rtss_auto_changeips = True

# Config prefix
def set_config(config):
    initialize_config(config, manifest, years, serialize)

    config.parameters.x_Temporary_Larval_Habitat = 3  # Package default is 0.2
    config.parameters.x_Base_Population = 3
    config.parameters.x_Birth = 3

    config.parameters.Report_Event_Recorder = 1
    config.parameters.Report_Event_Recorder_Individual_Properties = []
    config.parameters.Report_Event_Recorder_Events = ['Received_NMF_Treatment', 
                                                      'Received_Severe_Treatment',
                                                      'Received_Treatment',
                                                      'NewClinicalCase']
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

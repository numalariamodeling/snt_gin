import os
from pathlib import Path

import pandas as pd
import manifest
from emodpy_malaria.vector_config import set_species_param
from snt.hbhi.set_up_general import initialize_config
from snt.hbhi.set_up_general import setup_ds

# Files
larval_hab_csv = 'simulation_inputs/larval_habitats/monthly_habitats5.csv'
rel_abund_csv = 'simulation_inputs/DS_vector_rel_abundance.csv'
master_csv = 'guinea_DS_pop.csv'

# Suite and experiment name
homepath = os.path.expanduser('~')
user = Path(homepath).name
expname = f'{user}_DS_seasonal_calib'
suitename = f'{user}_seasonal_calib'

# Simulations settings
num_seeds = 10
years = 30
serialize = False
pull_from_serialization = False

filtered_report = 1
yr_plusone = True
event_reporter = False

# DS Settings
demographic_suffix = '_wSMC_risk_wIP'
climate_suffix = ''
climate_prefix = False
use_arch_burnin = True
use_arch_input = True

# load dfs
master_df = pd.read_csv(os.path.join(manifest.IO_DIR, master_csv))
master_df = master_df.set_index('DS_Name')
lhdf = pd.read_csv(os.path.join(manifest.IO_DIR, larval_hab_csv))
rel_abund_df = pd.read_csv(os.path.join(manifest.IO_DIR, rel_abund_csv))
rel_abund_df = rel_abund_df.set_index('DS_Name')

# analyze matter
output_expt_name = 'DS_seasonal_calib_30yr'
sweep_variables = ['DS_Name', 'archetype', 'Run_Number']

# Config prefix
def set_config(config, platform, ds):
    initialize_config(config, manifest, years, serialize)

    config.parameters.x_Temporary_Larval_Habitat = 1  # Package default is 0.2
    config.parameters.x_Base_Population = 1
    config.parameters.x_Birth = 1

    set_species_param(config, 'arabiensis', 'Anthropophily', 0.88, overwrite=True)
    set_species_param(config, 'arabiensis', 'Indoor_Feeding_Fraction', 0.5, overwrite=True)
    set_species_param(config, 'funestus', 'Anthropophily', 0.5, overwrite=True)
    set_species_param(config, 'funestus', 'Indoor_Feeding_Fraction', 0.86, overwrite=True)
    set_species_param(config, 'gambiae', 'Anthropophily', 0.74, overwrite=True)
    set_species_param(config, 'gambiae', 'Indoor_Feeding_Fraction', 0.9, overwrite=True)

    setup_ds(config,
             manifest=manifest,
             platform=platform,
             my_ds=ds,
             archetype_ds=master_df.at[ds, 'seasonality_archetype_2'],
             pull_from_serialization=pull_from_serialization,
             rel_abund_df=rel_abund_df,
             lhdf=lhdf,
             demographic_suffix=demographic_suffix,
             climate_prefix=climate_prefix,
             climate_suffix=climate_suffix,
             use_arch_burnin=use_arch_burnin,
             use_arch_input=use_arch_input)

    return config
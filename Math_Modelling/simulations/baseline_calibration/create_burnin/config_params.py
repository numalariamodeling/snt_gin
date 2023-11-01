import os
from pathlib import Path

import pandas as pd
import manifest
from emodpy_malaria.vector_config import set_species_param
from snt.hbhi.set_up_general import initialize_config

# Files
larval_hab_csv = 'simulation_inputs/larval_habitats/monthly_habitats5.csv'
master_csv = 'guinea_DS_pop.csv'
rel_abund_csv = 'simulation_inputs/DS_vector_rel_abundance.csv'
samp_csv = 'simulation_priors/lhs_samples_v1.csv'
#samp_csv = 'simulation_priors/selected_particles_v1.csv'

# Suite and experiment name
homepath = os.path.expanduser('~')
user = Path(homepath).name
expname = f'{user}_gin_1960-2004_3x'

suitename = f'{user}_gin_1960-2004_3x'

# Simulations settings
num_seeds = 1
years = 45
serialize = True
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
samp_df = pd.read_csv(os.path.join(manifest.IO_DIR, samp_csv))
ds_list = samp_df.archetype.unique()


# Config prefix
def set_config(config):
    initialize_config(config, manifest, years, serialize)

    config.parameters.x_Temporary_Larval_Habitat = 3  # Package default is 0.2
    config.parameters.x_Base_Population = 3
    config.parameters.x_Birth = 3

    set_species_param(config, 'arabiensis', 'Anthropophily', 0.88, overwrite=True)
    set_species_param(config, 'arabiensis', 'Indoor_Feeding_Fraction', 0.5, overwrite=True)
    set_species_param(config, 'funestus', 'Anthropophily', 0.5, overwrite=True)
    set_species_param(config, 'funestus', 'Indoor_Feeding_Fraction', 0.86, overwrite=True)
    set_species_param(config, 'gambiae', 'Anthropophily', 0.74, overwrite=True)
    set_species_param(config, 'gambiae', 'Indoor_Feeding_Fraction', 0.9, overwrite=True)

    return config

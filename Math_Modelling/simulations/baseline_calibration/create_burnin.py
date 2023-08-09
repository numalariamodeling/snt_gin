import numpy as np
import os
import pandas as pd
import time
from dtk.utils.core.DTKConfigBuilder import DTKConfigBuilder
from dtk.vector.species import update_species_param
from malaria.reports.MalariaReport import add_event_counter_report
from simtools.ExperimentManager.ExperimentManagerFactory import ExperimentManagerFactory
from simtools.ModBuilder import ModBuilder, ModFn
from simtools.SetupParser import SetupParser
from load_paths import load_box_paths
from hbhi.set_up_interventions import InterventionSuite, add_all_interventions
from hbhi.set_up_general import initialize_cb, setup_ds
from hbhi.utils import add_nmf_trt, tryread_df, read_main_dfs, add_monthly_parasitemia_rep_by_year
from tqdm import tqdm

SetupParser.default_block = 'NUCLUSTER'
datapath, projectpath = load_box_paths(parser_default=SetupParser.default_block)
larval_hab_csv = 'simulation_inputs/larval_habitats/monthly_habitats5.csv'
samp_df = pd.read_csv(os.path.join(projectpath, 'simulation_priors/lhs_samples_v1.csv'))

homepath = os.path.expanduser('~')
user = homepath.split('/')[2]
expname = f'{user}_gin_1960-2004'

num_seeds = 1
years = 45
serialize = True
pull_from_serialization = False


def input_override(cb, ds):
    cb.update_params({
        "Air_Temperature_Filename": os.path.join(ds, '5yr_consttemp', 'air_temperature_daily.bin'),
        "Land_Temperature_Filename": os.path.join(ds, '5yr_consttemp', 'air_temperature_daily.bin'),
        "Rainfall_Filename": os.path.join(ds, '5yr_consttemp', 'rainfall_daily.bin'),
        "Relative_Humidity_Filename": os.path.join(ds, '5yr_consttemp', 'relative_humidity_daily.bin')
    })

    return {"Input_Override": 1}


# BASIC SETUP
# Filtered report for the last year
cb = initialize_cb(years, serialize, filtered_report=1)
cb.update_params( {
    'x_Temporary_Larval_Habitat': 1, # Package default is 0.2
    'x_Base_Population': 1,
    'x_Birth': 1
})

update_species_param(cb, 'arabiensis', 'Anthropophily', 0.88, overwrite=True)
update_species_param(cb, 'arabiensis', 'Indoor_Feeding_Fraction', 0.5, overwrite=True)
update_species_param(cb, 'funestus', 'Anthropophily', 0.5, overwrite=True)
update_species_param(cb, 'funestus', 'Indoor_Feeding_Fraction', 0.86, overwrite=True)
update_species_param(cb, 'gambiae', 'Anthropophily', 0.74, overwrite=True)
update_species_param(cb, 'gambiae', 'Indoor_Feeding_Fraction', 0.9, overwrite=True)

# Important DFs
df, rel_abund_df, lhdf = read_main_dfs(projectpath, country='guinea', larval_hab_csv=larval_hab_csv)
ds_list = samp_df.archetype.unique()


# BUILDER
list_of_sims = []
for my_ds in tqdm(ds_list):
    samp_ds = samp_df[samp_df.DS_Name == my_ds]
    samp_ds1 = samp_ds[['Habitat_Multiplier', 'reduce_id', 'seed1']].drop_duplicates()
    L = []
    for r, row in samp_ds1.iterrows():
        L = L + [[ModFn(setup_ds,
                        my_ds=my_ds,
                        archetype_ds=df.at[my_ds, 'seasonality_archetype_2'],
                        pull_from_serialization=pull_from_serialization,
                        burnin_id='',
                        ser_date=0,
                        rel_abund_df=rel_abund_df,
                        lhdf=lhdf,
                        demographic_suffix='_wSMC_risk_wIP',
                        climate_prefix=False,
                        use_arch_burnin=False,
                        use_arch_input=True,
                        hab_multiplier=row['Habitat_Multiplier'],
                        parser_default=SetupParser.default_block),
                  ModFn(input_override, my_ds),
                  ModFn(DTKConfigBuilder.set_param, 'Habitat_Multiplier', row['Habitat_Multiplier']),
                  ModFn(DTKConfigBuilder.set_param, 'Run_Number', row['seed1']),
                  ModFn(DTKConfigBuilder.set_param, 'Sample_ID', row['reduce_id'])]]
    list_of_sims = list_of_sims + L

builder = ModBuilder.from_list(list_of_sims)

run_sim_args = {
    'exp_name': expname,
    'config_builder': cb,
    'exp_builder': builder
}


if __name__ == "__main__":
    SetupParser.init()
    exp_manager = ExperimentManagerFactory.init()
    exp_manager.run_simulations(**run_sim_args)

    time.sleep(20)
    exp_manager.wait_for_finished(verbose=True)
    assert (exp_manager.succeeded())

import os
from functools import partial
from pathlib import Path
from typing import List

import config_params as par
import pandas as pd
from emodpy import emod_task
from emodpy_malaria.interventions.outbreak import add_outbreak_individual
from emodpy_malaria.reporters.builtin import add_report_event_counter
from idmtools.builders import SimulationBuilder
from idmtools.entities.simulation import Simulation
from snt.hbhi.set_up_general import setup_ds
from snt.utility.sweeping import CfgFn, ItvFn, set_param
from tqdm import tqdm

import manifest

platform = None

#####################################
# Utility functions
#####################################

def _config_reports(task):
    """
    Add reports.

    Args:
        task: EMODTask

    Returns: None

    """
    from snt.hbhi.set_up_general import initialize_reports
    initialize_reports(task, manifest,
                       par.event_reporter,
                       par.filtered_report,
                       par.years,
                       par.yr_plusone)


# Override the one in snt package
def add_input_files(task, inputpath, my_ds, demographic_suffix='',
                    clim_subfolder = '5yr_consttemp'):
    """
    Add assets corresponding to the filename parameters set in set_input_files.
    Args:
        task:
        iopath:
        my_ds:
        archetype_ds:
        demographic_suffix:
        climate_suffix:
        climate_prefix:
        use_archetype:

    Returns:
        None
    """
    if demographic_suffix is not None:
        if not demographic_suffix.startswith('_') and not demographic_suffix == '':
            demographic_suffix = '_' + demographic_suffix

    if demographic_suffix is not None:
        demog_path = os.path.join(my_ds, f'{my_ds}_demographics{demographic_suffix}.json')
        task.common_assets.add_asset(os.path.join(inputpath, demog_path),
                                     relative_path=str(Path(demog_path).parent), fail_on_duplicate=False)
    
    # Climate
    if clim_subfolder is not None:
        file_path = os.path.join(my_ds, clim_subfolder, 
                                 'air_temperature_daily.bin')
        task.common_assets.add_asset(os.path.join(inputpath, file_path),
                                     relative_path=str(Path(file_path).parent.parent), 
                                     fail_on_duplicate=False)
        file_path = os.path.join(my_ds, clim_subfolder, 
                                 'air_temperature_daily.bin.json')
        task.common_assets.add_asset(os.path.join(inputpath, file_path),
                                     relative_path=str(Path(file_path).parent.parent), 
                                     fail_on_duplicate=False)

        file_path = os.path.join(my_ds, clim_subfolder, 
                                 'rainfall_daily.bin')
        task.common_assets.add_asset(os.path.join(inputpath, file_path),
                                     relative_path=str(Path(file_path).parent.parent), 
                                     fail_on_duplicate=False)
        file_path = os.path.join(my_ds, clim_subfolder, 
                                 'rainfall_daily.bin.json')
        task.common_assets.add_asset(os.path.join(inputpath, file_path),
                                     relative_path=str(Path(file_path).parent.parent), 
                                     fail_on_duplicate=False)

        file_path = os.path.join(my_ds, clim_subfolder, 
                                 'relative_humidity_daily.bin')
        task.common_assets.add_asset(os.path.join(inputpath, file_path),
                                     relative_path=str(Path(file_path).parent.parent), 
                                     fail_on_duplicate=False)
        file_path = os.path.join(my_ds, clim_subfolder, 
                                 'relative_humidity_daily.bin.json')
        task.common_assets.add_asset(os.path.join(inputpath, file_path),
                                     relative_path=str(Path(file_path).parent.parent), 
                                     fail_on_duplicate=False)

#####################################
# Create EMODTask
#####################################

def build_campaign():
    """
    Adding required interventions common to all

    Returns:
        campaign object
    """

    import emod_api.campaign as campaign

    # passing in schema file to verify that everything is correct.
    campaign.schema_path = manifest.schema_file

    add_outbreak_individual(campaign, start_day=182, 
                            demographic_coverage=0.01, 
                            repetitions=-1,
                            timesteps_between_repetitions=365)

    return campaign


def set_param_fn(config):
    """
    This function is a callback that is passed to emod-api.config to set parameters The Right Way.

    Args:
        config:

    Returns:
        configuration settings
    """

    # You have to set simulation type explicitly before you set other parameters for the simulation
    # sets "default" malaria parameters as determined by the malaria team
    import emodpy_malaria.malaria_config as malaria_config
    config = malaria_config.set_team_defaults(config, manifest)

    par.set_config(config)

    return config


def get_task(**kwargs):
    """
    This function is designed to create and config a Task.

    Args:
        kwargs: optional parameters

    Returns:
        task

    """
    global platform
    platform = kwargs.get('platform', None)

    # Create EMODTask
    print("Creating EMODTask...")
    task = emod_task.EMODTask.from_default2(
        config_path=None,
        eradication_path=manifest.eradication_path,
        schema_path=manifest.schema_file,
        campaign_builder=build_campaign,
        param_custom_cb=set_param_fn,
        ep4_custom_cb=None,
    )

    # Add assets corresponding to the filename parameters set in set_input_files.
    ds_list = par.ds_list

    for my_ds in ds_list:
        add_input_files(task,
                        inputpath=os.path.join(manifest.IO_DIR, 'simulation_inputs',
                                               'DS_inputs_files'),
                        my_ds=my_ds,
                        demographic_suffix=par.demographic_suffix
                        )

    # More stuff to add task, like reports...
    _config_reports(task)

    return task

def sweep_interventions(simulation: Simulation, func_list: List):
    # Specially handel add_all_interventions to add report!
    tags_updated = {}
    for func in func_list:
        tags = func(simulation)
        if tags:
            if isinstance(func, ItvFn):
                fname = func.func.__name__
                if fname == 'add_all_interventions':
                    add_report_event_counter(simulation.task, manifest, event_trigger_list=tags["events"])
            else:
                tags_updated.update(tags)
    return tags_updated


def get_sweep_builders(**kwargs):
    global platform
    platform = kwargs.get('platform', None)

    builder = SimulationBuilder()

    # Important DFs
    master_df = par.master_df
    lhdf = pd.read_csv(os.path.join(manifest.IO_DIR, par.larval_hab_csv))
    rel_abund_df = pd.read_csv(os.path.join(manifest.IO_DIR, par.rel_abund_csv))
    rel_abund_df = rel_abund_df.set_index('DS_Name')

    samp_df = par.samp_df
    ds_list = par.ds_list

    # BUILDER
    int_sweeps = []
    for my_ds in tqdm(ds_list):
        samp_ds = samp_df[samp_df.archetype == my_ds]
        # For each archetype, each Habitat_Multiplier has same reduce_id and seed1 by design of preprocessing
        samp_ds1 = samp_ds[['Habitat_Multiplier', 'reduce_id', 'seed1']].drop_duplicates()
        for r, row in samp_ds1.iterrows():
            int_funcs = []
            cnf = CfgFn(setup_ds,
                        manifest=manifest,
                        platform=platform,
                        my_ds=my_ds,
                        archetype_ds=master_df.at[my_ds, 'seasonality_archetype_2'],
                        pull_from_serialization=par.pull_from_serialization,
                        burnin_id='',
                        ser_date=0,
                        rel_abund_df=rel_abund_df,
                        lhdf=lhdf,
                        demographic_suffix=par.demographic_suffix,
                        climate_prefix=par.climate_prefix,
                        climate_suffix=par.climate_suffix,
                        use_arch_burnin=par.use_arch_burnin,
                        use_arch_input=par.use_arch_input,
                        hab_multiplier=row['Habitat_Multiplier'])
            int_funcs.append(cnf)
            int_funcs.append(partial(set_param, param='Habitat_Multiplier',
                                     value=row['Habitat_Multiplier']))
            int_funcs.append(partial(set_param, param='Run_Number', value=row['seed1']))
            int_funcs.append(
                partial(set_param, param='Sample_ID', value=row['reduce_id']))

            int_sweeps.append(int_funcs)

    builder.add_sweep_definition(sweep_interventions, int_sweeps)
    print(builder.count)

    return [builder]

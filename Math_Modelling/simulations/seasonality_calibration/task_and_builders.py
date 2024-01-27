import os
from functools import partial
from pathlib import Path

import config_params as par
from emodpy import emod_task
from emodpy_malaria.interventions.outbreak import add_outbreak_individual
from emodpy_malaria.interventions.treatment_seeking import add_treatment_seeking
from emodpy_malaria.reporters.builtin import (
    add_event_recorder,
)
from idmtools.builders import SimulationBuilder
from snt.hbhi.utils import add_monthly_parasitemia_rep_by_year
from snt.utility.sweeping import set_param

import manifest

platform = None

#####################################
# Utility functions
#####################################


def _config_reports(task, sim_years):
    """
    Add reports.

    Args:
        task: EMODTask

    Returns: None

    """
    from snt.hbhi.set_up_general import initialize_reports

    initialize_reports(
        task,
        manifest,
        par.event_reporter,
        par.filtered_report,
        par.years,
        par.yr_plusone,
    )
    add_event_recorder(
        task,
        event_list=["Received_Treatment"],
        start_day=(sim_years - 4) * 365,
        end_day=sim_years * 365,
        min_age_years=0,
        max_age_years=10,
    )
    add_monthly_parasitemia_rep_by_year(
        task, manifest, num_year=4,
        tot_year=par.years, sim_start_year=1992,
        yr_plusone=par.yr_plusone, prefix='Monthly'
    )


# Override the one in snt package
def add_input_files(
    task, inputpath, my_ds, demographic_suffix="", clim_subfolder="5yr_consttemp"
):
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
        if not demographic_suffix.startswith("_") and not demographic_suffix == "":
            demographic_suffix = "_" + demographic_suffix

    if demographic_suffix is not None:
        demog_path = os.path.join(
            my_ds, f"{my_ds}_demographics{demographic_suffix}.json"
        )
        task.common_assets.add_asset(
            os.path.join(inputpath, demog_path),
            relative_path=str(Path(demog_path).parent),
            fail_on_duplicate=False,
        )

    # Climate
    if clim_subfolder is not None:
        file_path = os.path.join(my_ds, clim_subfolder, "air_temperature_daily.bin")
        task.common_assets.add_asset(
            os.path.join(inputpath, file_path),
            relative_path=str(Path(file_path).parent.parent),
            fail_on_duplicate=False,
        )
        file_path = os.path.join(
            my_ds, clim_subfolder, "air_temperature_daily.bin.json"
        )
        task.common_assets.add_asset(
            os.path.join(inputpath, file_path),
            relative_path=str(Path(file_path).parent.parent),
            fail_on_duplicate=False,
        )

        file_path = os.path.join(my_ds, clim_subfolder, "rainfall_daily.bin")
        task.common_assets.add_asset(
            os.path.join(inputpath, file_path),
            relative_path=str(Path(file_path).parent.parent),
            fail_on_duplicate=False,
        )
        file_path = os.path.join(my_ds, clim_subfolder, "rainfall_daily.bin.json")
        task.common_assets.add_asset(
            os.path.join(inputpath, file_path),
            relative_path=str(Path(file_path).parent.parent),
            fail_on_duplicate=False,
        )

        file_path = os.path.join(my_ds, clim_subfolder, "relative_humidity_daily.bin")
        task.common_assets.add_asset(
            os.path.join(inputpath, file_path),
            relative_path=str(Path(file_path).parent.parent),
            fail_on_duplicate=False,
        )
        file_path = os.path.join(
            my_ds, clim_subfolder, "relative_humidity_daily.bin.json"
        )
        task.common_assets.add_asset(
            os.path.join(inputpath, file_path),
            relative_path=str(Path(file_path).parent.parent),
            fail_on_duplicate=False,
        )


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

    add_outbreak_individual(
        campaign,
        start_day=182,
        demographic_coverage=0.01,
        repetitions=-1,
        timesteps_between_repetitions=365,
    )
    add_treatment_seeking(
        campaign,
        start_day=5 * 365,
        targets=[
            {
                "agemin": 0,
                "agemax": 100,
                "coverage": 0.4,
                "rate": 0.3,
                "trigger": "NewClinicalCase",
            }
        ],
        drug=["Artemether", "Lumefantrine"],
        broadcast_event_name="Received_Treatment"
    )

    return campaign


def set_param_fn(config, platform, ds):
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

    par.set_config(config, platform, ds)

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
    platform = kwargs.get("platform", None)
    ds = kwargs.get("ds")

    def set_param_fn_plus(config):
        return set_param_fn(config, platform, ds)

    # Create EMODTask
    print("Creating EMODTask...")
    task = emod_task.EMODTask.from_default2(
        config_path=None,
        eradication_path=manifest.eradication_path,
        schema_path=manifest.schema_file,
        campaign_builder=build_campaign,
        param_custom_cb=set_param_fn_plus,
        ep4_custom_cb=None,
    )

    # Add assets corresponding to the filename parameters set in set_input_files.
    ds = kwargs.get("ds")
    ds_list = [ds]

    for my_ds in ds_list:
        add_input_files(
            task,
            inputpath=os.path.join(
                manifest.IO_DIR, "simulation_inputs", "DS_inputs_files"
            ),
            my_ds=my_ds,
            demographic_suffix=par.demographic_suffix,
        )

    # More stuff to add task, like reports...
    _config_reports(task, par.years)

    return task


def get_sweep_builders(**kwargs):
    global platform
    platform = kwargs.get("platform", None)
    builder = SimulationBuilder()

    # BUILDER
    builder.add_sweep_definition(
        partial(set_param, param="Run_Number"), range(4326, 4326 + par.num_seeds)
    )
    print(builder.count)

    return [builder]

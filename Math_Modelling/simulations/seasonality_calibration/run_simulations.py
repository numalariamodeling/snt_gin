import argparse
import os
from datetime import datetime as dt

import config_params as par
from analyze import analyze_experiment
from idmtools.core.platform_factory import Platform
from idmtools.entities import Suite
from idmtools.entities.experiment import Experiment
from idmtools.entities.templated_simulation import TemplatedSimulations
from task_and_builders import get_sweep_builders, get_task
import emod_api.schema_to_class as s2c

import manifest

s2c.show_warnings = False

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-ds', dest='ds', type=str, required=True)

    return parser.parse_args()


def _print_params():
    """
    Just a useful convenient function for the user.
    """
    print("test_run: ", par.test_run)
    print("iopath: ", par.iopath)
    print("expname: ", par.expname)
    print("homepath: ", par.homepath)
    print("user: ", par.user)
    print("serialize: ", par.serialize)
    print("num_seeds: ", par.num_seeds)
    print("years: ", par.years)
    print("pull_from_serialization: ", par.pull_from_serialization)


def _post_run(experiment: Experiment, **kwargs):
    """
    Add extra work after run experiment.
    Args:
        experiment: idmtools Experiment
        kwargs: additional parameters
    Return:
    """
    outdir = par.output_expt_name.replace('DS', kwargs.get('ds'))
    analyze_experiment(platform, 
                       experiment.id,
                       os.path.join(manifest.output_dir, outdir))
    pass


def _config_experiment(**kwargs):
    """
    Build experiment from task and builder. task is EMODTask. builder is 
    SimulationBuilder used for config parameter sweeping.
    Return:
        experiment
    """

    builders = get_sweep_builders(**kwargs)
    task = get_task(**kwargs)

    if manifest.SIF_PATH:
        task.sif_path = manifest.SIF_PATH

    ts = TemplatedSimulations(base_task=task, builders=builders)
    experiment = Experiment.from_template(ts, name=par.expname)

    suite = Suite(name = par.suitename)
    suite.uid = par.suitename

    now = dt.now()
    now_str = now.strftime("%Y_%m_%d_%H_%M")
    expname = par.expname.replace('DS', kwargs.get('ds'))
    expid = f'{expname}_{now_str}'
    experiment.uid = expid
    suite.add_experiment(experiment)

    return experiment


def run_experiment(**kwargs):
    """
    Get configured calibration and run
    Args:
        kwargs: user inputs

    Returns: None

    """
    # make sure pass platform through
    kwargs['platform'] = platform

    experiment = _config_experiment(**kwargs)
    experiment.run(wait_until_done=True)

    if not experiment.succeeded:
        print(f"Experiment {experiment.uid} failed.\n")
        exit()

    print(f"Experiment {experiment.uid} succeeded.")

    _post_run(experiment, **kwargs)


if __name__ == "__main__":
    args = parse_args()

    # To use Slurm Platform: Specify job directory
    platform = Platform('SLURM_LOCAL', job_directory=manifest.job_dir,
                        partition='b1139', time='2:00:00',
                        account='b1139', modules=['singularity'],
                        mem_per_cpu='2G',
                        max_running_jobs=100)

    # If you don't have Eradication, un-comment out the following to download Eradication
    # import emod_malaria.bootstrap as dtk
    #
    # dtk.setup(pathlib.Path(manifest.eradication_path).parent)
    # os.chdir(os.path.dirname(__file__))
    # print("...done.")
    run_experiment(ds=args.ds)

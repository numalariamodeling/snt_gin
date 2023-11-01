import argparse
import os

import config_params as par
from idmtools.analysis.analyze_manager import AnalyzeManager
from idmtools.core import ItemType

from simulation_emodpy.analyzer.analyzer_collection import (
    EventReporterAnalyzer,
    MonthlyAgebinPfPRAnalyzer,
)


def parse_args():
    parser = argparse.ArgumentParser()
    #parser.add_argument(
    #    "-prefix", dest="prefix", type=str, required=False, default=None
    #)
    #parser.add_argument("-name", dest="expt_name", type=str, required=False)
    parser.add_argument("-id", dest="expt_id", type=str, required=True)
    parser.add_argument("-ds", dest="ds", type=str, required=True)

    return parser.parse_args()


def analyze_experiment(platform, expt_id, wdir):
    if not os.path.exists(wdir):
        os.makedirs(wdir)

    analyzers = []
    analyzers.append(MonthlyAgebinPfPRAnalyzer(sweep_variables=par.sweep_variables,
                                               working_dir=wdir,
                                               start_year=2018,
                                               end_year=2022))
    analyzers.append(EventReporterAnalyzer(sweep_variables=par.sweep_variables,
                                           working_dir=wdir))
    
    manager = AnalyzeManager(platform=platform,
                             configuration={},
                             ids=[(expt_id, ItemType.EXPERIMENT)],
                             analyzers=analyzers,
                             partial_analyze_ok=True,
                             max_workers=16)
    manager.analyze()


if __name__ == "__main__":
    
    from idmtools.core.platform_factory import Platform
    import manifest

    args = parse_args()
    platform = Platform('SLURM_LOCAL', job_directory=manifest.job_dir)
    outdir = par.output_expt_name.replace('DS', args.ds)
    analyze_experiment(platform, 
                       args.expt_id,
                       os.path.join(manifest.output_dir, outdir))

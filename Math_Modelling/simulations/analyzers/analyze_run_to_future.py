import argparse
import os
import manifest
from idmtools.analysis.analyze_manager import AnalyzeManager
from idmtools.core import ItemType
from idmtools.core.platform_factory import Platform

from simulation_emodpy.analyzer.analyzer_collection import (
    AnnualAgebinPfPRAnalyzer,
    MonthlyAgebinPfPRAnalyzer,
    annualSevereTreatedByAgeAnalyzer,
)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-mode", dest="mode", type=int, default=2)
    parser.add_argument("-name", dest="expt_name", type=str, required=False)
    parser.add_argument("-id", dest="expt_id", type=str, required=True)

    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    wdir = manifest.output_dir
    wdir = os.path.join(wdir, args.expt_name)

    if not os.path.exists(wdir):
        os.makedirs(wdir)

    if args.mode == 1:
        start_year = 2005
        end_year = 2023
    else:
        start_year = 2023
        end_year = 2030

    sweep_variables = ["Sample_ID", "DS_Name", "archetype", "Run_Number"]

    platform = Platform('SLURM_LOCAL', job_directory=manifest.job_dir)

    with platform:
        analyzers = []
        analyzers.append(
            MonthlyAgebinPfPRAnalyzer(
                sweep_variables=sweep_variables,
                working_dir=wdir,
                start_year=start_year,
                end_year=end_year
            )
        )
        analyzers.append(
            AnnualAgebinPfPRAnalyzer(
                sweep_variables=sweep_variables,
                working_dir=wdir,
                start_year=start_year,
                end_year=end_year-1
            )
        )
        analyzers.append(
            annualSevereTreatedByAgeAnalyzer(
                sweep_variables=sweep_variables,
                working_dir=wdir,
                start_year=start_year
            )
        )

        manager = AnalyzeManager(
            configuration={},
            ids=[(args.expt_id, ItemType.EXPERIMENT)],
            analyzers=analyzers,
            partial_analyze_ok=True,
            max_workers=8,
            analyze_failed_items=True,
            executor_type='process'
        )

        manager.analyze()

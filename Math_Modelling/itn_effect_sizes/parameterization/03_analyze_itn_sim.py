import os
import sys
import numpy as np
import pandas as pd
from simtools.Analysis.BaseAnalyzers import BaseAnalyzer
import datetime
from simtools.Analysis.AnalyzeManager import AnalyzeManager
from simtools.SetupParser import SetupParser

sys.path.append('../')
from load_paths import load_box_paths
from analyzer_collection import *

if __name__ == "__main__":

    if os.name == "posix":
        SetupParser.default_block = 'NUCLUSTER'
        filter_exists = True
        project_path = '/projects/b1139/emod_itn_exploration/'
    else:
        SetupParser.default_block = 'HPC'
        filter_exists = False
        data_path, project_path = load_box_paths()

    SetupParser.init()

    """Simulation arguments"""
    DS_Name = "DS_Name"
    expdirsub = 'BFA_ITN_sim'

    expt_ids = {
        #'mrm9534_banfora_itncalib_2014_v8_newNets_counterfactual': '2022_11_18_11_32_07_455327',
        #'mrm9534_banfora_itncalib_2014_v8_newNets': '2022_11_18_11_24_00_877975',
        'mrm9534_NNP_newnets_test_v0':'2022_12_16_10_46_47_646116'}

    # Set years explicitly, as defaults in parse_args might be different
    start_year = 2010
    end_year = 2023

    working_dir = os.path.join(project_path, 'simulation_outputs', expdirsub)
    if not os.path.exists(working_dir):
        os.mkdir(working_dir)

    for exp_name, exp_id in expt_ids.items():
        exp_sweeps = [DS_Name, 'Sample_ID']
        sweep_variables = list(set(["Run_Number"] + exp_sweeps))
        print(sweep_variables)

        analyzers = [
            #MonthlyPfPRAnalyzer(expt_name=exp_name,
            #                    sweep_variables=sweep_variables,
            #                    working_dir=working_dir,
           #                     start_year=start_year,
            #                    end_year=end_year,
            #                    filter_exists=filter_exists),
            #MonthlyTreatedCasesAnalyzer(expt_name=exp_name,
            #                            sweep_variables=sweep_variables,
            #                            working_dir=working_dir,
            #                            start_year=start_year,
            #                            end_year=end_year,
            #                            filter_exists=filter_exists),
            monthlyTreatedByAgeAnalyzer(expt_name=exp_name,
                                        sweep_variables=sweep_variables,
                                        working_dir=working_dir,
                                        agebins=[5],
                                        start_year=2005,
                                        end_year=end_year),
            # BednetUsageAnalyzer(expt_name=exp_name,
            #                    sweep_variables=sweep_variables,
            #                    working_dir=working_dir,
            #                    start_year=start_year,
            #                    filter_exists=filter_exists),
        ]
        am = AnalyzeManager(exp_id, analyzers=analyzers)
        am.analyze()

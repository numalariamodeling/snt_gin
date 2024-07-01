import logging
import numpy as np
import pandas as pd
import os
import sys
import math
import time
from dtk.utils.core.DTKConfigBuilder import DTKConfigBuilder
from simtools.SetupParser import SetupParser
from simtools.ExperimentManager.ExperimentManagerFactory import ExperimentManagerFactory
from simtools.ModBuilder import ModBuilder, ModFn
from malaria.interventions.malaria_vaccine import add_vaccine
from load_paths import load_box_paths

from vaccSMC_milligan_helper import set_EIR, setup_simulation, add_case_management, diagnostic_survey
wdir = os.path.join(os.getcwd(), "Math_Modelling/smc_efficacy")


logger = logging.getLogger(__name__)
if os.name == "posix":
    SetupParser.default_block = 'NUCLUSTER'
else:
    SetupParser.default_block = 'HPC'

rnd = 1
eir_scl_factors = [1.25]  ## 0.25  ##  initial EIR = 24
if len(eir_scl_factors) >1:
    exp_name = f'vaccSMC_milligan_eirsweep_fit_rnd{rnd}'
if len(eir_scl_factors) == 1:
    exp_name = f'vaccSMC_milligan_eir{int(eir_scl_factors[0]*24)}_fit_rnd{rnd}'
cb = DTKConfigBuilder.from_defaults('MALARIA_SIM')


def add_vaccSMC(cb, start_days, coverages, initial_effect = 0.8, box_duration = 32,
                decay_duration = 10):
    decay_params = {'Waning_Config': {'Initial_Effect': initial_effect,
                                      'Box_Duration': box_duration,
                                      'Decay_Time_Constant': decay_duration / math.log(2),
                                      'class': 'WaningEffectBoxExponential'}}
    for (d, cov) in zip (start_days, coverages):
        add_vaccine(cb,
                   vaccine_type='RTSS',
                   vaccine_params=decay_params,
                   start_days=[d],
                   coverage=cov,
                   repetitions=1,
                   target_group={'agemin': 0.25, 'agemax': 5},
                   receiving_vaccine_event_name='Received_SMCvacc',
                   birthtriggered=False)

    return {'SMCcov' : coverages[0],
            'vacc_initial_effect' : initial_effect,
            'vacc_box_duration' : box_duration,
            'vacc_decay_duration' : decay_duration}

# define global variables: sim duration, start of SMC, data collect starts by type, reporter start,
# number of replication seeds, serialization option, random seed, project paths
sim_years = 11
smc_2015 = 213 # date of SMC start in 2015
hrp2_data_collection_start = 239 #239 # started 228 and lasted 3 weeks, so taking the midpoint
inc_data_collection_start = 213
report_start = (sim_years - 2) * 365 + inc_data_collection_start
hrp2_report_start = (sim_years - 2) * 365 + hrp2_data_collection_start
numseeds = 6
np.random.seed(4326)
datapath, project_path = load_box_paths()
samp_df = pd.read_csv(os.path.join(wdir, 'par_out', f'rnd{rnd}.csv'))

# must run every time i.e. not in builder
setup_simulation(cb, sim_years, 7,report_start)
diagnostic_survey(cb, hrp2_report_start)
add_case_management(cb, 0.5)

builder = ModBuilder.from_list([[ModFn(add_vaccSMC,
                                 start_days=[smc_2015 + (sim_years - 2) * 365],
                                 initial_effect=row['vacc_initial_effect'],
                                 box_duration=row['vacc_box_duration'],
                                 decay_duration=row['vacc_decay_duration'],
                                 coverages=[1 if row['vacc_initial_effect'] else 0]),
                                 ModFn(set_EIR, EIRscale_factor=eir_scl),
                                 ModFn(DTKConfigBuilder.set_param, 'Run_Number', x),
                                 ModFn(DTKConfigBuilder.set_param, 'Sample_id', row['samp_id'])
                                 ]
                                for x in range(numseeds)
                                for eir_scl in eir_scl_factors
                                for rid, row in samp_df.iterrows()
                                ])

run_sim_args = {
    'exp_name': exp_name,
    'config_builder': cb,
    'exp_builder' : builder
}

if __name__ == "__main__":
    SetupParser.init()
    exp_manager = ExperimentManagerFactory.init()
    exp_manager.run_simulations(**run_sim_args)

    time.sleep(20)
    exp_manager.wait_for_finished(verbose=True)
    assert (exp_manager.succeeded())
    expt_id = exp_manager.experiment.exp_id
    with open('analyses.sh', 'a') as f:
        f.write('#!/bin/sh\n')
        f.write(f'python analyze_SMC_milligan.py -name {exp_name} -id {expt_id}\n')

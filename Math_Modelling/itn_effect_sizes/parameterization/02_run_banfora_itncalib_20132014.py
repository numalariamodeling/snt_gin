###----------------------------------------------------------------------------------------------------------------
### Script copied and modified from hbhi workflow
### https://github.com/numalariamodeling/hbhi/blob/main/country_template/simulation/calibration/fit_2005-2019.py#L22
### Not updated to run via emodpy, still using dtk, for reference only
###------------------------------------------------------------------------------------------------------------
import os
import pandas as pd
import time
import math
import numpy as np
from scipy import interpolate
from dtk.utils.core.DTKConfigBuilder import DTKConfigBuilder
from simtools.ExperimentManager.ExperimentManagerFactory import ExperimentManagerFactory
from simtools.ModBuilder import ModBuilder, ModFn
from simtools.SetupParser import SetupParser
# from simulation.load_paths import load_box_paths
# from simulation.recorder import record_experiment
from malaria.interventions.malaria_vaccine import add_vaccine
from malaria.interventions.malaria_drugs import set_drug_param
from malaria.interventions.malaria_drug_campaigns import add_drug_campaign
from hbhi.set_up_general import initialize_cb, setup_ds, set_spaq_params
from hbhi.set_up_interventions import InterventionSuite, add_all_interventions, update_smc_access_ips
from hbhi.utils import add_monthly_parasitemia_rep_by_year, add_nmf_trt, tryread_df, read_main_dfs
from tqdm import tqdm
import sys

sys.path.append('../')

SetupParser.default_block = 'NUCLUSTER'
projectpath = '/projects/b1139/malaria-bf-hbhi/IO/'
scenario_csv = os.path.join(projectpath, 'simulation_inputs/_scenarios_ms/Intervention_scenarios_2010_2019.csv')
larval_hab_csv = 'simulation_inputs/monthly_habitats_v4.csv'
samp_csv = '/projects/b1139/malaria-bf-hbhi/IO/simulation_priors/selected_particles.csv'
samp_csv = '/home/mrm9534/gitrepos/emod_itn_exploration/itn_calibration_BFA/selected_particles_ITNextended.csv'
num_seeds = 12
start_year = 2005
years = 15  # 2005 to 2019 year
ser_num_seeds = 1
ser_date = 45 * 365
serialize = False
pull_from_serialization = True

burnin_id = '2022_11_10_14_52_29_250823'
use_arch_burnin = True
itn_calib = True

user = os.getlogin()
expname = f'{user}_banfora_itncalib_20132014_v1'

if __name__ == "__main__":

    # BASIC SETUP
    cb = initialize_cb(years, serialize=serialize, filtered_report=years,
                       event_reporter=False)
    cb.update_params({
        'x_temporary_Larval_Habitat': 1,  # Package default is 0.2
        'x_Base_Population': 0.5,
        'x_Birth': 0.5
    })
    cb.update_params({
        "Report_Event_Recorder": 1,
        "Report_Event_Recorder_Individual_Properties": [],
        "Report_Event_Recorder_Events": ['Received_NMF_Treatment', 'Received_Severe_Treatment',
                                         'Received_Treatment'],
        "Report_Event_Recorder_Ignore_Events_In_List": 0
    })

    # INTERVENTIONS
    ## Intervention Suite
    int_suite = InterventionSuite()
    # hs unchanged
    int_suite.hs_duration = None  # Set to none when want to follow df's duration to the dot
    # itn
    int_suite.itn_ds_col = 'District'
    int_suite.itn_discard_distribution = 'weibull'
    int_suite.itn_cov_cols = ['ITN_U05', 'ITN_U10', 'ITN_U20', 'ITN_A20']
    int_suite.itn_cov_age_bin = [0, 5, 10, 20]
    int_suite.itn_retention_in_yr = 1.58
    int_suite.itn_seasonal_months = [0, 90, 120, 152, 182]
    int_suite.itn_seasonal_values = [0.906, 0.75, 0.791, 0.91, 1]
    # smc
    int_suite.smc_adherence = True
    int_suite.smc_coverage_col = ['coverage_high_access_U5', 'coverage_low_access_U5',
                                  'coverage_high_access_5_10', 'coverage_low_access_5_10']
    int_suite.smc_access = ['High', 'Low', 'High', 'Low']
    int_suite.smc_agemins = [0.25, 0.25, 5, 5]
    int_suite.smc_agemax_type = ['fixed', 'fixed', 'fixed', 'fixed']
    int_suite.smc_agemaxs = [5, 5, 10, 10]
    int_suite.smc_leakage = False
    # irs unchanged

    # Treatment-seeking and malaria testing prompted by NMF
    add_nmf_trt(cb, years, 0)

    # Treatment-seeking
    hs_df = tryread_df(os.path.join(projectpath, 'simulation_inputs',
                                    '_scenarios_2022', 'cm_2005_2019.csv'))
    # ITNs
    itn_df = tryread_df(os.path.join(projectpath, 'simulation_inputs',
                                     '_scenarios_2022', 'itn_2005_2019.csv'))
    # ITN ANC
    itn_anc_df = tryread_df(os.path.join(projectpath, 'simulation_inputs',
                                         '_scenarios_2022', 'anc_2005_2019.csv'))
    # IRS
    irs_df = tryread_df(os.path.join(projectpath, 'simulation_inputs',
                                     '_scenarios_2022', 'irs_2005_2019.csv'))
    # SMC
    smc_df = tryread_df(os.path.join(projectpath, 'simulation_inputs',
                                     '_scenarios_2022', 'smc_2005_2019.csv'))


    # vaccSMC
    def add_vaccdrugSMC_df(cb, my_ds, smc_df):
        smc_df1 = smc_df[smc_df.DS_Name == my_ds].copy()
        smc_df1['vaccSMC_coverage'] = smc_df1.loc[:, 'high_access_U5'] * smc_df1.loc[:, 'coverage_high_access_U5'] + \
                                      (1 - smc_df1.loc[:, 'high_access_U5']) * smc_df1.loc[:, 'coverage_low_access_U5']

        start_days = smc_df1.simday.tolist()
        coverages = smc_df1.vaccSMC_coverage.tolist()

        add_vaccdrugSMC(cb, start_days, coverages)

        return {}


    # ITN addtional (right now it really is just ITN ANC)
    itn_anc_df['type'] = 'antenatal'
    itn_anc_df[int_suite.itn_ds_col] = itn_anc_df['DS_Name']
    itn_addtnl_df = itn_anc_df

    # CUSTOM REPORTS
    add_monthly_parasitemia_rep_by_year(cb, num_year=years, tot_year=years,
                                        sim_start_year=2005,
                                        yr_plusone=True, prefix='Monthly_')
    # add_annual_parasitemia_rep(cb, num_year=years, tot_year=years,
    #                           sim_start_year=2005,
    #                           age_bins=[2, 10, 125])

    # FOR CONFIGURING LARVAL HABTIATS
    df, rel_abund_df, lhdf = read_main_dfs(projectpath, country='burkina',
                                           larval_hab_csv=larval_hab_csv)
    samp_df = pd.read_csv(samp_csv)
    ds_list = samp_df.DS_Name.unique()
    ds_list = ['Banfora']


    # BUILDER

    ## Function by Ben Toh, Northwestern University  see hbhi repository
    def lin_interpolate(years, vals):
        val_interp = interpolate.interp1d(years, vals)

        full_vals = val_interp(range(years[0], years[-1] + 1))
        return (full_vals)


    list_of_sims = []
    for my_ds in ds_list:
        samp_ds = samp_df[samp_df.DS_Name == my_ds].copy()
        samp_ds = samp_ds[samp_ds['rank'] == 1]
        # samp_ds = samp_ds[samp_ds['id'] <= 4]
        L = []
        for r, row in tqdm(samp_ds.iterrows()):
            hs_ds = hs_df.copy()[hs_df[int_suite.hs_ds_col] == my_ds]
            full_covs = lin_interpolate([2005, 2010, 2014, 2017, 2019],
                                        [0, row['CM_cov_2010'], row['CM_cov_2014'], row['CM_cov_2017'],
                                         row['CM_cov_2017']])
            hs_ds['U5_coverage'] = full_covs * hs_ds['U5_coverage']
            hs_ds['adult_coverage'] = full_covs * hs_ds['adult_coverage']

            if not itn_calib:
                itn_ds = itn_df.copy()[itn_df[int_suite.itn_ds_col] == my_ds.upper()]
                itn_ds = itn_ds.reset_index()
                # TODO: Make code below more defensive
                itn_ds.loc[0, int_suite.itn_cov_cols] = itn_ds.loc[0, int_suite.itn_cov_cols] * row['ITN_2010']
                itn_ds.loc[1, int_suite.itn_cov_cols] = itn_ds.loc[1, int_suite.itn_cov_cols] * row['ITN_2013']
                itn_ds.loc[2, int_suite.itn_cov_cols] = itn_ds.loc[2, int_suite.itn_cov_cols] * row['ITN_2016']
                itn_ds.loc[3, int_suite.itn_cov_cols] = itn_ds.loc[3, int_suite.itn_cov_cols] * row['ITN_2019']
            else:
                itn_ds = itn_df.copy()[itn_df[int_suite.itn_ds_col] == my_ds.upper()]
                if 'counterfactual' in expname:
                    itn_ds = itn_ds.loc[itn_ds['year'] < 2015]
                else:
                    itn_ds = itn_ds.loc[itn_ds['year'] < 2017]
                itn_ds = itn_ds.reset_index()

                itn_ds.loc[0, int_suite.itn_cov_cols] = itn_ds.loc[0, int_suite.itn_cov_cols] * row['ITN_2010']
                itn_ds.loc[1, int_suite.itn_cov_cols] = itn_ds.loc[1, int_suite.itn_cov_cols] * row['ITN_2013']
                itn_ds.loc[1, 'blocking_rate'] = row['blocking_rate']
                itn_ds.loc[1, 'kill_rate'] = row['kill_rate']
                if 'counterfactual' not in expname:
                    itn_ds.loc[2, int_suite.itn_cov_cols] = itn_ds.loc[2, int_suite.itn_cov_cols] * row['ITN_2014']
                    itn_ds.loc[2, 'blocking_rate'] = row['blocking_rate']
                    itn_ds.loc[2, 'kill_rate'] = row['kill_rate']
                    itn_ds.loc[2, 'simday'] = row['ITN_2014_day']
                    itn_ds.loc[2, 'year'] = row['ITN_2014_year']

            L = L + [[ModFn(setup_ds,
                            my_ds=my_ds,
                            archetype_ds=df.at[my_ds, 'seasonality_archetype_2'],
                            pull_from_serialization=pull_from_serialization,
                            burnin_id=burnin_id,
                            ser_date=ser_date,
                            rel_abund_df=rel_abund_df,
                            lhdf=lhdf,
                            demographic_suffix='_IPs_risk',
                            use_arch_burnin=True,
                            use_arch_input=False,
                            hab_multiplier=row['Habitat_Multiplier'],
                            parser_default=SetupParser.default_block,
                            serialize_match_tag=['Habitat_Multiplier'],
                            serialize_match_val=[float(row['Habitat_Multiplier'])]),
                      ModFn(add_all_interventions,
                            int_suite=int_suite,
                            my_ds=my_ds,
                            hs_df=hs_ds,
                            itn_df=itn_ds,
                            itn_addtnl_df=itn_addtnl_df,
                            smc_df=smc_df,
                            irs_df=irs_df,
                            rep_start=0,
                            rep_duration=years * 365),
                      ModFn(DTKConfigBuilder.set_param, 'DS_Name', my_ds),
                      ModFn(DTKConfigBuilder.set_param, 'Sample_ID', row['id']),
                      ModFn(DTKConfigBuilder.set_param, 'Run_Number', row['seed2'] + x)]
                     for x in range(num_seeds)
                     ]
        list_of_sims = list_of_sims + L

    builder = ModBuilder.from_list(list_of_sims)

    run_sim_args = {
        'exp_name': expname,
        'config_builder': cb,
        'exp_builder': builder
    }

    SetupParser.init()
    exp_manager = ExperimentManagerFactory.init()
    exp_manager.run_simulations(**run_sim_args)

    time.sleep(20)
    exp_manager.wait_for_finished(verbose=True)
    assert (exp_manager.succeeded())

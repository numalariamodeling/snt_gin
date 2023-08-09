import argparse
import os
import pandas as pd
import time
from scipy import interpolate
from dtk.utils.core.DTKConfigBuilder import DTKConfigBuilder
from dtk.vector.species import update_species_param
from simtools.ExperimentManager.ExperimentManagerFactory import ExperimentManagerFactory
from simtools.ModBuilder import ModBuilder, ModFn
from simtools.SetupParser import SetupParser
from load_paths import load_box_paths
from hbhi.set_up_general import initialize_cb, setup_ds
from hbhi.set_up_interventions import InterventionSuite, add_all_interventions, update_smc_access_ips
from hbhi.utils import (add_monthly_parasitemia_rep_by_year, add_nmf_trt, tryread_df, read_main_dfs,
                        add_annual_parasitemia_rep)
from tqdm import tqdm


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-sc', dest='scen', type=str, required=True)

    return parser.parse_args()


def input_override(cb, ds):
    cb.update_params({
        "Air_Temperature_Filename": os.path.join(ds, '5yr_consttemp', 'air_temperature_daily.bin'),
        "Land_Temperature_Filename": os.path.join(ds, '5yr_consttemp', 'air_temperature_daily.bin'),
        "Rainfall_Filename": os.path.join(ds, '5yr_consttemp', 'rainfall_daily.bin'),
        "Relative_Humidity_Filename": os.path.join(ds, '5yr_consttemp', 'relative_humidity_daily.bin')
    })

    return {"Input_Override": 1}

SetupParser.default_block = 'NUCLUSTER'
datapath, projectpath = load_box_paths(parser_default=SetupParser.default_block)
scenariopath = os.path.join(projectpath, 'simulation_inputs/_scenarios_2023/')
scenarios_csv = os.path.join(scenariopath, 'scenarios_2023-2029.csv')
larval_hab_csv = 'simulation_inputs/larval_habitats/monthly_habitats5.csv'
samp_csv = os.path.join(projectpath, 'simulation_priors/selected_particles_v1.csv')

num_seeds = 3
years = 7  # 2023 to 2029 year
ser_num_seeds = 3
ser_date = 18*365
serialize = False
pull_from_serialization = True

burnin_id = "2023_05_06_09_53_57_200038"
use_arch_burnin = False

homepath = os.path.expanduser('~')
user = homepath.split('/')[2]


if __name__ == "__main__":

    args = parse_args()
    scen_df = pd.read_csv(scenarios_csv)
    scen_df.set_index('scen', inplace=True)
    scen_row = scen_df.loc[args.scen, :]
    expname = f'{user}_run_gin_2023-2029_{args.scen}'

    # BASIC SETUP
    cb = initialize_cb(years, serialize=serialize, filtered_report=years,
                       event_reporter=False)
    cb.update_params({
        'x_temporary_Larval_Habitat': 1, # Package default is 0.2
        'x_Base_Population': 1,
        'x_Birth': 1
    })
    cb.update_params({
        "Report_Event_Recorder": 1,
        "Report_Event_Recorder_Individual_Properties": [],
        "Report_Event_Recorder_Events" : ['Received_NMF_Treatment', 'Received_Severe_Treatment',
                                          'Received_Treatment'],
        "Report_Event_Recorder_Ignore_Events_In_List": 0
    })
    update_species_param(cb, 'arabiensis', 'Anthropophily', 0.88, overwrite=True)
    update_species_param(cb, 'arabiensis', 'Indoor_Feeding_Fraction', 0.5, overwrite=True)
    update_species_param(cb, 'funestus', 'Anthropophily', 0.5, overwrite=True)
    update_species_param(cb, 'funestus', 'Indoor_Feeding_Fraction', 0.86, overwrite=True)
    update_species_param(cb, 'gambiae', 'Anthropophily', 0.74, overwrite=True)
    update_species_param(cb, 'gambiae', 'Indoor_Feeding_Fraction', 0.9, overwrite=True)


    # INTERVENTIONS
    ## Intervention Suite
    int_suite =  InterventionSuite()
    # hs
    int_suite.hs_ds_col = 'DS_Name'
    int_suite.hs_duration = 365 # Set to none when want to follow df's duration to the dot
    int_suite.hs_coverage_age = { # column: [agemin, agemax]
        'u5_coverage': [0, 5],
        'adult_coverage': [5, 100]
    }
    # itn
    int_suite.itn_ds_col = 'DS_Name'
    int_suite.itn_discard_distribution = 'weibull'
    int_suite.itn_cov_cols = ['U05', 'U10', 'U20', 'A20']
    int_suite.itn_cov_age_bin = [0, 5, 10, 20]
    int_suite.itn_retention_in_yr = 1.69
    int_suite.itn_seasonal_months = [0, 91, 182, 274]
    int_suite.itn_seasonal_values = [0.739, 0.501, 0.682, 1]
    # smc
    int_suite.smc_adherence = True
    int_suite.smc_coverage_col = ['coverage_high_access_u5', 'coverage_low_access_u5',
                                  'coverage_high_access_o5', 'coverage_low_access_o5']
    int_suite.smc_access = ['High', 'Low', 'High', 'Low']
    int_suite.smc_agemins = [0.25, 0.25, 5, 5]
    int_suite.smc_agemax_type = ['fixed', 'fixed', 'fixed', 'fixed']
    int_suite.smc_agemaxs = [5, 5, 10, 10]
    int_suite.smc_leakage = False
    # pmc
    int_suite.pmc_touchpoint_col = 'pmc_age_days'
    int_suite.pmc_start_col = 'simday'
    int_suite.pmc_coverage_col = 'pmc_coverage'
    # rtss
    int_suite.rtss_auto_changeips = True

    # Treatment-seeking and malaria testing prompted by NMF
    add_nmf_trt(cb, years, 0)

    # Treatment-seeking
    hs_df = tryread_df(os.path.join(scenariopath, 'cm', f"{scen_row['CM']}.csv"))

    # ITNs
    itn_df = tryread_df(os.path.join(scenariopath, 'itn', f"{scen_row['ITN']}.csv"))

    # ITN ANC
    #itn_anc_df = tryread_df(os.path.join(scenariopath, 'itn', f"{scen_row['ANC']}.csv"))
    #itn_anc_df['type'] = 'antenatal'
    #itn_anc_df[int_suite.itn_ds_col] = itn_anc_df['DS_Name']

    # SMC
    smc_df = tryread_df(os.path.join(scenariopath, 'smc', f"{scen_row['SMC']}.csv"))
    smc_df['round'] = smc_df['cycle']
    smc_df['high_access_U5'] = smc_df['high_access_u5']
    smc_df['high_access_5_10'] = smc_df['high_access_o5']
    smc_df['coverage_low_access_u5'] = 0
    smc_df['coverage_low_access_o5'] = 0

    # PMC
    pmc_df = tryread_df(os.path.join(scenariopath, 'pmc', f"{scen_row['PMC']}.csv"))
    if len(pmc_df) > 0:
        pmc_df['distribution_mean'] = 0

    # RTSS
    rtss_df = tryread_df(os.path.join(scenariopath, 'rtss', f"{scen_row['RTSS']}.csv"))

    # CUSTOM REPORTS
    add_monthly_parasitemia_rep_by_year(cb, num_year=years, tot_year=years,
                                        sim_start_year=2023,
                                        yr_plusone=True, prefix='Monthly_')
    #add_monthly_parasitemia_rep_by_year(cb, num_year=years, tot_year=years,
    #                                    sim_start_year=2005,
    #                                    yr_plusone=True,
    #                                    age_bins=[1, 5, 10],
    #                                    prefix='Monthly_U1U5_')
    add_annual_parasitemia_rep(cb, num_year=years, tot_year=years,
                               sim_start_year=2023,
                               age_bins = [0.25, 1, 2, 5, 10, 15, 30, 50, 125])

    # FOR CONFIGURING LARVAL HABTIATS
    df, rel_abund_df, lhdf = read_main_dfs(projectpath, country='guinea',
                                           larval_hab_csv=larval_hab_csv)
    samp_df = pd.read_csv(samp_csv)
    samp_df = samp_df[~(samp_df.DS_Name=='Conakry')]

    # Subsetting DSes (Not subsetting yet...)
    ds_list = samp_df.DS_Name.unique()
    if not pd.isna(scen_row['smcsubset']):
        ds_list = df[df['CPS'] == scen_row['smcsubset']].index
    elif scen_row['pmcsubset'] == 'yes':
        ds_list = df[df['CPP'] == 'CPP'].index
    elif scen_row['pmcsubset'] == 'Yomou':
        ds_list = ['Yomou']

    #elif scen_row['irssubset'] == 'yes':
    #    if len(irs_df) == 0:
    #        ds_list = ["Diebougou", "Batie", "Mangodara", "Ouargaye", "Pama", "Gayeri", 
    #                   "Gorom-Gorom", "Gaoua", "Kampti", "Dano"]
    #    else:
    #        ds_list = irs_df.DS_Name.unique()

    # BUILDER
    def lin_interpolate(years, vals):
        val_interp = interpolate.interp1d(years, vals)
        full_vals = val_interp(range(years[0], years[-1]+1))
        return (full_vals)

    list_of_sims = []
    for my_ds in tqdm(ds_list):
        samp_ds = samp_df[samp_df.DS_Name == my_ds].copy()
        L = []
        for r, row in samp_ds.iterrows():
            L = L + [[ModFn(setup_ds,
                            my_ds=my_ds,
                            archetype_ds=df.at[my_ds, 'seasonality_archetype_2'],
                            pull_from_serialization=pull_from_serialization,
                            burnin_id=burnin_id,
                            ser_date=ser_date,
                            rel_abund_df=rel_abund_df,
                            lhdf=lhdf,
                            demographic_suffix='_wSMC_risk_wIP',
                            climate_prefix=True,
                            use_arch_burnin=use_arch_burnin,
                            use_arch_input=use_arch_burnin,
                            hab_multiplier=row['Habitat_Multiplier'],
                            parser_default=SetupParser.default_block,
                            serialize_match_tag=['Sample_ID', 'Run_Number'],
                            serialize_match_val=[row['id'], row['seed2'] + x % ser_num_seeds]),
                       ModFn(add_all_interventions,
                             int_suite=int_suite,
                             my_ds=my_ds,
                             hs_df=hs_df,
                             itn_df=itn_df,
                             smc_df=smc_df,
                             pmc_df=pmc_df,
                             rtss_df=rtss_df,
                             addtl_smc_func=update_smc_access_ips,
                             rep_start=0,
                             rep_duration=years*365),
                      ModFn(input_override, ds=my_ds),
                      ModFn(DTKConfigBuilder.set_param, 'DS_Name', my_ds),
                      ModFn(DTKConfigBuilder.set_param, 'Sample_ID', row['id']),
                      ModFn(DTKConfigBuilder.set_param, 'Run_Number', row['seed2']+x)]
                      for x in range(num_seeds)]
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

    time.sleep(40)
    exp_manager.wait_for_finished(verbose=True)
    assert (exp_manager.succeeded())
    expt_id = exp_manager.experiment.exp_id

    print(f"python simulation/analyzer/analyze_2023-2029.py -name 2023-2029_{args.scen}_v1 -id {expt_id}")
    os.system(f"python simulation/analyzer/analyze_2023-2029.py -name 2023-2029_{args.scen}_v1 -id {expt_id}")

    print(f"Rscript output_processor/iptp_postprocessing.R {args.scen}")
    os.system(f"Rscript output_processor/iptp_postprocessing.R {args.scen}")

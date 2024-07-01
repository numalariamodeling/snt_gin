import logging
import numpy as np
import pandas as pd
import os
import copy
import math
import time
import scipy.stats as stats
from malaria.interventions.health_seeking import add_health_seeking
from malaria.reports.MalariaReport import add_summary_report
from dtk.interventions.input_EIR import add_InputEIR, monthly_to_daily_EIR
from malaria.interventions.malaria_drug_campaigns import add_drug_campaign, add_diagnostic_survey
from malaria.interventions.adherent_drug import configure_adherent_drug
from malaria.site.input_EIR_by_site import mAb_vs_EIR
from malaria.interventions.malaria_drugs import set_drug_param, get_drug_param
from malaria.interventions.malaria_vaccine import add_vaccine
from malaria.reports.MalariaReport import add_event_counter_report



def set_EIR(cb, EIRscale_factor):
    '''
    sets forced daily EIR and applies EIR scale factor
    :param cb: model builder
    :type cb: builder
    :param EIRscale_factor: scale factor on EIR; applied to annual EIR
    :type EIRscale_factor: float
    :return: EIR scale factor (EIR scale factor)
    :rtype: float
    '''

    site_EIR_annualized = [2.123434646246,1.185709626614,1.461941812138,2.055990357376,3.394446468911,
                           14.09612136473,38.35029882503,110.9376291313,88.10438545742,20.11124002161,
                           4.10895200141,1.468215537103, (2.123434646246 + 1.468215537103)/2]

    monthly_EIR = [x/12 for x in site_EIR_annualized]
    daily_EIR = monthly_to_daily_EIR(monthly_EIR)

    add_InputEIR(cb, start_day=0, EIR_type='DAILY', dailyEIRs=daily_EIR, scaling_factor=EIRscale_factor)

    annual_eir = sum([x*EIRscale_factor for x in daily_EIR])
    Maternal_Antibody_Protection = 0.1327
    mAb = Maternal_Antibody_Protection * mAb_vs_EIR(annual_eir)
    cb.update_params({'Maternal_Antibody_Protection': mAb})

    return {'EIR scale factor': EIRscale_factor,
            'annual EIR': annual_eir}


def setup_simulation(cb, sim_years, interval=7, report_start=None):
    '''
    sets required simulation parameters, defines configuration and serialization variables
    :param cb: model builder
    :type cb: builder
    :param interval: interval to run summary reports
    :type interval: integer
    '''
    # basic config updates
    cb.update_params({'Demographics_Filenames': ['under_5_demographics_with_SMC_access_IIV.json'],
                      'x_Base_Population': 10, ### initial population in json: 100
                      'x_Birth': 1,
                      'Vector_Species_Names': [],
                      'Enable_Vital_Dynamics': 1,
                      'Enable_Births': 1,
                      'Disable_IP_Whitelist': 1,
                      'Simulation_Duration': sim_years*365,
                      'Maternal_Antibodies_Type': 'CONSTANT_INITIAL_IMMUNITY',
                      'Birth_Rate_Dependence': 'FIXED_BIRTH_RATE',
                      'Climate_Model': 'CLIMATE_CONSTANT',
                      "Parasite_Smear_Sensitivity": 0.02,
                      'logLevel_JsonConfigurable': 'ERROR'
                      })
    # serializations
    cb.update_params({
        'Serialized_Population_Reading_Type': 'NONE',
        'Serialized_Population_Writing_Type': 'NONE',
        'Serialization_Mask_Node_Read': 0,
        'Enable_Random_Generator_From_Serialized_Population': 0
    })

    # reporter for whole population
    if report_start:
        add_summary_report(cb, start=report_start, interval=interval,
                           age_bins=[0.25, 5,100], description='Monthly_from_%d' % report_start) # called monthly regardless of interval

        # reporters by access group
        add_summary_report(cb, start=report_start, interval = interval,
                           age_bins=[0.25,5,100], ipfilter='SMCAccess:High',
                           description='Monthly_HAG_from_%d' % report_start)

        add_summary_report(cb, start=report_start, interval=interval,
                           age_bins=[0.25, 5,100], ipfilter='SMCAccess:Low',
                           description='Monthly_LAG_from_%d' % report_start)

        # HRP2 prevalence survey
        add_event_counter_report(cb, event_trigger_list=["Received_Test_Age_0_to_1", "Tested_Pos_Age_0_to_1",
                                                         "Received_Test_Age_1_to_2", 'Tested_Pos_Age_1_to_2',
                                                         "Received_Test_Age_2_to_3", "Tested_Pos_Age_2_to_3",
                                                         "Received_Test_Age_3_to_4", "Tested_Pos_Age_3_to_4",
                                                         "Received_Test_Age_4_to_5", "Tested_Pos_Age_4_to_5",
                                                         #"Received_SMC",
                                                         "Received_Treatment"])
    else:
        print('No reports added, please define report_start to add them as needed')


def add_case_management(cb, coverage) :
    '''
    adds case management to simulation using add_health_seeking()
    :param cb: model builder
    :type cb: builder
    :param coverage: proportion of individuals covered by CM
    :type coverage: float
    :return: coverage level
    :rtype: float
    '''

    add_health_seeking(cb, start_day=0, drug=['Artemether', 'Lumefantrine'],
                       targets=[{'trigger': 'NewClinicalCase', 'coverage': coverage, 'agemin': 0.25, 'agemax': 5,
                                 'seek': 1,'rate': 0.3},
                                ]
                       )
    return { 'CM_coverage' : coverage}


def make_vehicle_drug(cb, decay_time, Cmax, C50, maxeff, hep=0):
    #set_drug_param(cb, "Vehicle", "PKPD_Model", "FIXED_DURATION_CONSTANT_EFFECT")

    if not (decay_time == 0):
        set_drug_param(cb, "Vehicle", "Drug_Decay_T1", decay_time)
        set_drug_param(cb, "Vehicle", "Drug_Decay_T2", decay_time)

    if not (Cmax == 0):
        set_drug_param(cb, "Vehicle", "Drug_Cmax", Cmax)

    if not (C50 == 0):
        set_drug_param(cb, "Vehicle", "Drug_PKPD_C50", C50)

    if not (maxeff == 0):
        set_drug_param(cb, "Vehicle", "Max_Drug_IRBC_Kill", maxeff)

    if not (hep==0):
        set_drug_param(cb, "Vehicle", "Drug_Hepatocyte_Killrate", hep)

    return {'drug_decay_time': decay_time,
            'drug_cmax': Cmax,
            'drug_c50': C50,
            'drug_irbc_killing': maxeff,
            'drug_hep_killing': hep}


def make_vehicle_drug2(cb, time, maxeff):
    set_drug_param(cb, "Vehicle", "PKPD_Model", "FIXED_DURATION_CONSTANT_EFFECT")
    set_drug_param(cb, "Vehicle", "Drug_Decay_T1", time)
    set_drug_param(cb, "Vehicle", "Drug_Decay_T2", time)
    set_drug_param(cb, "Vehicle", "Max_Drug_IRBC_Kill", maxeff)

    set_drug_param(cb, "Vehicle", "Drug_Gametocyte02_Killrate", maxeff)
    set_drug_param(cb, "Vehicle", "Drug_Gametocyte34_Killrate", maxeff)
    set_drug_param(cb, "Vehicle", "Drug_GametocyteM_Killrate", maxeff)

    return {}


def add_vaccdrugSMC(cb, start_days, coverages, vacc_initial_effect=0.83,
                    vacc_box_duration=17.3, vacc_decay_duration=5.31,
                    drug_decay_time=2, drug_irbc_killing=18.6, drug_hep_killing=1.5,
                    drug_Cmax=1000, drug_C50=100):
    for (d, cov) in zip(start_days, coverages):
        add_drug_campaign(cb, campaign_type='SMC',
                          drug_code='Vehicle',
                          start_days=[d], coverage=cov,
                          repetitions=1,
                          target_group={'agemin': 0.25, 'agemax': 5})

    # Modify vehicle drug only after adding drug campaign... because reasons *shrug*
    make_vehicle_drug(cb, drug_decay_time, drug_Cmax, drug_C50, drug_irbc_killing, drug_hep_killing)

    vacc_decay_params = {'Waning_Config': {'Initial_Effect': vacc_initial_effect,
                                           'Box_Duration': vacc_box_duration,
                                           'Decay_Time_Constant': vacc_decay_duration / math.log(2),
                                           'class': 'WaningEffectBoxExponential'},
                         'Efficacy_Is_Multiplicative': 1}

    add_vaccine(cb,
                vaccine_type='RTSS',
                vaccine_params=vacc_decay_params,
                start_days=[start_days[0]],
                coverage=1,
                target_group={'agemin': 0.25, 'agemax': 5},
                trigger_condition_list=['Received_Vehicle'],
                trigger_coverage=1,
                receiving_vaccine_event_name='Received_SMCvacc',
                birthtriggered=False)

    return {'SMCcov': sum(coverages)/len(coverages)}
    

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

    return {'vacc_initial_effect' : initial_effect,
            'vacc_box_duration' : box_duration,
            'vacc_decay_duration' : decay_duration}


def add_drugSMC(cb, start_days, coverages, drug_code='Vehicle'):
    for (d, cov) in zip (start_days, coverages):
        add_drug_campaign(cb, campaign_type='SMC',
                          drug_code=drug_code,
                          start_days=[d], coverage=cov,
                          repetitions=1,
                          target_group={'agemin': 0.25, 'agemax': 5},
                          receiving_drugs_event_name='Received_SMCdrug')

    return {'SMCcov' : coverages[0]}


def diagnostic_survey(cb, hrp2_report_start):
    '''
    implement HRP2 diagnostic by age using diagnostic_survey
    :param cb: model builder
    :type cb: builder
    '''

    # create master dictionary of agebins
    agebins = { '%d_to_%d' % (x, x+1) : [x, x+1] for x in range(1, 5)}
    agebins['0_to_1'] = [0.25, 1]

    # iterate through agebins
    for key, val in agebins.items() :
        add_diagnostic_survey(cb, start_day=hrp2_report_start,
                              repetitions=2, #2, 73
                              tsteps_btwn_repetitions=365, #365, 7
                              target={'agemin': val[0], 'agemax': val[1]},
                              diagnostic_type='PF_HRP2',
                              diagnostic_threshold=5,
                              positive_diagnosis_configs=[{'class': 'BroadcastEvent',
                                                           'Broadcast_Event': 'Tested_Pos_Age_%s' % key}],
                              received_test_event='Received_Test_Age_%s' % key
                              )


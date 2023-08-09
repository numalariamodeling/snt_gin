import os
import pandas as pd
import json
from dtk.tools.demographics.DemographicsGeneratorConcern import (WorldBankBirthRateConcern,
                                                                 EquilibriumAgeDistributionConcern,
                                                                 DefaultIndividualAttributesConcern)
from dtk.tools.demographics.DemographicsGenerator import DemographicsGenerator
from input_file_generation.add_properties_to_demographics import generate_demographics_properties
from load_paths import load_box_paths

projectpath = ''
datapath, projectpath = load_box_paths(parser_default='NUCLUSTER')
input_path = os.path.join(projectpath, 'simulation_inputs/DS_inputs_files/')


def generate_demographics(demo_df, ds, demo_fname, ipflag=False):
    demo_df = demo_df[demo_df['DS_Name'] == ds]
    demo_df['standard_pop'] = 1000
    demo_df['nodeid'] = 1

    br_concern = WorldBankBirthRateConcern(country="Guinea", birthrate_year=2016)

    chain = [
        DefaultIndividualAttributesConcern(),
        br_concern,
        EquilibriumAgeDistributionConcern(default_birth_rate=br_concern.default_birth_rate),
    ]

    current = DemographicsGenerator.from_dataframe(demo_df,
                                                   population_column_name='standard_pop',
                                                   nodeid_column_name='nodeid',
                                                   latitude_column_name='lat',
                                                   longitude_column_name='lon',
                                                   node_id_from_lat_long=False,
                                                   concerns=chain,
                                                   load_other_columns_as_attributes=True,
                                                   include_columns=['DS_Name']
                                                   )

    if ipflag:
        current = inject_smc_risk(current)

    with open(demo_fname, 'w') as fout:
        json.dump(current, fout, sort_keys=True, indent=4, separators=(',', ': '))


def inject_smc_risk(jsobj):
    ip_dict = {
        'Initial_Distribution': [0.5, 0.5],
        'Property': 'SMCAccess',
        'Transitions': [],
        'Values': ['Low', 'High']
    }
    jsobj['Defaults']['IndividualProperties'] = []
    jsobj['Defaults']['IndividualProperties'].append(ip_dict)
    jsobj['Defaults']['IndividualAttributes']['RiskDistributionFlag'] = 3

    return jsobj


def add_custom_IPs(demo_fname, IP_demo_fname=None, overwrite=False):
    ## also see https://github.com/numalariamodeling/rtss-scenarios/blob/main/simulation/inputs/add_IPs.py
    ## Add IPs without regenerating input demographics
    IPs = [{'Property': 'DrugStatus',
            'Values': ['None', 'RecentDrug'],
            'Initial_Distribution': [1, 0],
            'Transitions': []},
           {'Property': 'SMCAccess',
            'Values': ['Low', 'High'],
            'Initial_Distribution': [0.5, 0.5],
            'Transitions': []},
           {'Property': 'Pregnant',
            'Values': ['IsPregnant', 'NotPregnant'],
            'Initial_Distribution': [0, 1],
            'Transitions': []},
           {'Property': 'AgeGroup',
            'Values': ['Under15', '15to30', '30to50', '50plus'],
            'Initial_Distribution': [1, 0, 0, 0],
            'Transitions': []},
           {'Property': 'VaccineStatus',
            'Values': ['None', 'GotVaccine', 'GotBooster1', 'GotBooster2', 'GotBooster3'],
            'Initial_Distribution': [1, 0, 0, 0, 0],
            'Transitions': []}
           ]

    ddf1 = pd.DataFrame({'Property': ['DrugStatus'] * 2,
                         'Property_Value': ['None', 'RecentDrug'],
                         'Initial_Distribution': [1, 0]})

    ddf2 = pd.DataFrame({'Property': ['SMCAccess'] * 2,
                         'Property_Value': ['Low', 'High'],
                         'Initial_Distribution': [0.5, 0.5]})

    ddf3 = pd.DataFrame({'Property': ['Pregnant'] * 2,
                         'Property_Value': ['IsPregnant', 'NotPregnant'],
                         'Initial_Distribution': [0, 1]})

    ddf4 = pd.DataFrame({'Property': ['AgeGroup'] * 4,
                         'Property_Value': ['Under15', '15to30', '30to50', '50plus'],
                         'Initial_Distribution': [1, 0, 0, 0]})

    ddf5 = pd.DataFrame({'Property': ['VaccineStatus'] * 5,
                         'Property_Value': ['None', 'GotVaccine', 'GotBooster1', 'GotBooster2', 'GotBooster3'],
                         'Initial_Distribution': [1, 0, 0, 0, 0]})

    adf = pd.concat([ddf1, ddf2, ddf3, ddf4, ddf5])

    adf['Property_Type'] = 'IP'
    adf['node'] = 1

    if overwrite:
        IP_demo_fname = demo_fname
    else:
        if not IP_demo_fname:
            IP_demo_fname = demo_fname.replace('.json', '_wIP.json')

    generate_demographics_properties(refdemo_fname=demo_fname,
                                     output_filename=IP_demo_fname,
                                     as_overlay=False,
                                     IPs=IPs,
                                     df=adf)


if __name__ == '__main__':

    master_csv = os.path.join(projectpath, 'guinea_DS_pop.csv')
    df = pd.read_csv(master_csv, encoding='latin')
    df.rename(columns={'long': 'lon'}, inplace=True)

    for ds in df['DS_Name'].unique():
        print(ds)
        if not os.path.exists(os.path.join(input_path, ds)):
            os.makedirs(os.path.join(input_path, ds))
        demo_fname = os.path.join(input_path, ds, '%s_demographics_wSMC_risk_wIP.json' % ds)
        generate_demographics(df, ds, demo_fname, ipflag=False)
        add_custom_IPs(demo_fname, overwrite=True)

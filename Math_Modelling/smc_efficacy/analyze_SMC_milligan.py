import pandas as pd
import numpy as np
import os
import argparse
from simtools.Analysis.BaseAnalyzers import BaseAnalyzer
import sys


class CasesAvertedAnalyzer(BaseAnalyzer):
    '''
    this class defines the cases averted/efficacy analyzer
    '''

    def __init__(self, exp_name, sweep_variables=None, working_dir='./'):
        '''
        initializates class
        :param exp_name: experiment name
        :type exp_name: string
        :param sweep_variables: variables to sweep over when grabbing data
        :type sweep_variables: list
        :param working_dir: workign directory
        :type working_dir: string
        '''

        super(CasesAvertedAnalyzer, self).__init__(working_dir=working_dir,
                                                   # filenames=["output/MalariaSummaryReport_Interval_7_from_3863.json"]) #AQ PD sweep
                                                   # filenames = ["output/MalariaSummaryReport_Weekly_2020_2021.json"]) #Guinea
                                                   filenames=[
                                                       "output/MalariaSummaryReport_Monthly_from_3498.json"])  # BF
        # filenames=["output/MalariaSummaryReport_5th_year_August.json"]) #kita
        self.sweep_variables = sweep_variables or ["SMC_Coverage"]
        self.exp_name = exp_name
        self.data_channel_type = 'DataByTimeAndAgeBins'
        self.channel_name = 'Clinical Incidence'
        self.ages = [0.25, 5, 100]  # [0.25,5,15,30,50,125]
        self.data_channels = 'Annual Clinical Incidence by Age Bin'

    def select_simulation_data(self, data, simulation):
        '''
        selects and organizes data to be saved
        :param data: data grabbed from simulation output
        :type data: data frame
        :param simulation: simulation replicate
        :type simulation: simulation
        :return: dataframe from all simulations (simdata)
        :rtype: dataframe
        '''
        # print(data[self.filenames[0]])
        # Load last 2 years of data from simulation
        # output_data_df = pd.DataFrame(data[self.filenames[0]][self.data_channel_type][self.data_channels][:-1]) #grab from Aug 2015 -- start of SMC
        output_data_df = pd.DataFrame(
            data[self.filenames[0]][self.data_channel_type][self.data_channels])  # grab from Aug 2015 -- start of SMC
        output_data_df.columns = ['Clinical_inc_0.25', 'Clinical_inc_5', 'Clinical_inc_100']
        # output_data_df.columns = ['Clinical_inc_0.25', 'Clinical_inc_5', 'Clinical_inc_15', 'Clinical_inc_30','Clinical_inc_50','Clinical_inc_125']
        output_data_df['Interval'] = output_data_df.index

        # reorient dataframe to long format
        simdata = pd.DataFrame()
        cols = [x for x in output_data_df.columns.values if 'inc' in x]
        for col in cols:
            sdf = output_data_df[['Interval', col]]
            sdf = sdf.rename(columns={col: self.channel_name})
            sdf['Age'] = col.split('_')[-1]
            simdata = pd.concat([simdata, sdf])

        # add tags
        for sweep_var in self.sweep_variables:
            simdata[sweep_var] = simulation.tags[sweep_var]

        return simdata

    def finalize(self, all_data):
        '''
        finalize data frame for saving
        :param all_data: all dataframes from simulations
        :type all_data: tuple
        :return: CSV of final data frame to output directory
        :rtype: CSV
        '''

        # concatenate all simulation data into one dataframe
        selected = [data for sim, data in all_data.items()]  # grab data in tuple form
        if len(selected) == 0:  # error out if no data selected
            print("\nNo data have been returned... Exiting...")
            return
        df = pd.concat(selected, sort=False).reset_index(drop=True)  # concat into dataframe

        # take mean over all random seeds
        grouping_list = self.sweep_variables
        grouping_list.append('Age')
        grouping_list.insert(0, 'Interval')
        df = df.groupby(grouping_list)['Clinical Incidence'].agg([np.min, np.mean, np.max]).reset_index()
        # df = df.groupby(['start_days','Interval', 'Sample_Number','EIR scale factor','kmax','krate_scale_factor_s','krate_scale_factor_p','Age'])['Clinical Incidence'].agg([np.min, np.mean, np.max]).reset_index()
        df = df.rename(columns={'amin': 'Case_min', 'mean': 'Case', 'amax': 'Case_max'})
        df = df.sort_values(by=grouping_list)
        fn = os.path.join(self.working_dir, self.exp_name)
        if not os.path.exists(fn):
            os.makedirs(fn)
        print('\nSaving data to: %s' % fn)
        df.to_csv(os.path.join(fn, 'cases.csv'))


class HRP2PrevalenceAnalyzer(BaseAnalyzer):
    '''
    defines HRP2 prevalence analzyer class
    '''

    def __init__(self, exp_name, sweep_variables=None, working_dir='./'):  # sweep_variables=None,

        super(HRP2PrevalenceAnalyzer, self).__init__(working_dir=working_dir,
                                                     filenames=["output/ReportEventCounter.json"])
        self.sweep_variables = sweep_variables or ["SMC_Coverage"]
        self.exp_name = exp_name
        self.data_channel_type = 'Channels'
        self.channel_name = 'HRP2'
        self.ages = range(5)
        self.age_range = ['%d_to_%d' % (x, x + 1) for x in self.ages]
        self.data_channels = ['Received_Test_Age_%s' % x for x in self.age_range] + \
                             ['Tested_Pos_Age_%s' % x for x in self.age_range]

        self.reference_dict = {
            'post': {
                'Ref_HRP2_0_to_1': 0.09,
                'Ref_HRP2_1_to_2': 0.11,
                'Ref_HRP2_2_to_3': 0.18,
                'Ref_HRP2_3_to_4': 0.20,
                'Ref_HRP2_4_to_5': 0.21
            },
            'pre': {
                'Ref_HRP2_0_to_1': 0.19,
                'Ref_HRP2_1_to_2': 0.29,
                'Ref_HRP2_2_to_3': 0.41,
                'Ref_HRP2_3_to_4': 0.53,
                'Ref_HRP2_4_to_5': 0.58
            }
        }

    def select_simulation_data(self, data, simulation):

        # Load last 2 years of data from simulation
        output_data_df = pd.DataFrame(
            {channel: data[self.filenames[0]]['Channels'][channel]['Data'][-730:] for channel in self.data_channels})
        # remove dates when there were no prevalence surveys
        output_data_df['day'] = output_data_df.index
        output_data_df = output_data_df[output_data_df[self.data_channels[0]] > 0]
        # calculate prevalence
        for agebin in self.age_range:
            output_data_df['Prevalence_Age_%s' % agebin] = output_data_df['Tested_Pos_Age_%s' % agebin] / \
                                                           output_data_df['Received_Test_Age_%s' % agebin]

        # reorient dataframe to long format
        simdata = pd.DataFrame()
        cols = [x for x in output_data_df.columns.values if 'Prevalence' in x]
        for col in cols:
            sdf = output_data_df[['day', col]]
            sdf = sdf.rename(columns={col: self.channel_name})
            sdf['Age'] = int(col.split('_')[-1]) - 1
            simdata = pd.concat([simdata, sdf])

        # add tags
        for sweep_var in self.sweep_variables:
            simdata[sweep_var] = simulation.tags[sweep_var]

        return simdata

    def finalize(self, all_data):

        # concatenate all simulation data into one dataframe
        selected = [data for sim, data in all_data.items()]  # grab data in tuple form
        if len(selected) == 0:  # error out if no data selected
            print("\nNo data have been returned... Exiting...")
            return
        df = pd.concat(selected, sort=False).reset_index(drop=True)  # concat into dataframe
        grouping_list = self.sweep_variables
        grouping_list.append('Age')
        grouping_list.insert(0, 'day')

        df = df.groupby(grouping_list)['HRP2'].agg([np.min, np.mean, np.max]).reset_index()
        df = df.rename(columns={'amin': 'HRP2_min', 'mean': 'HRP2', 'amax': 'HRP2_max'})
        df = df.sort_values(by=grouping_list)
        df['Ref_HRP2'] = 0
        df['Distance'] = 0

        ages = df['Age'].unique()
        for ai in ages:
            ref_pre = self.reference_dict['pre']['Ref_HRP2_%s_to_%s' % (ai, ai + 1)]
            ref_post = self.reference_dict['post']['Ref_HRP2_%s_to_%s' % (ai, ai + 1)]
            df.loc[((df['day'] == 239) & (df['Age'] == ai)), 'Ref_HRP2'] = ref_pre
            df.loc[((df['day'] == 604) & (df['Age'] == ai)), 'Ref_HRP2'] = ref_post
            df.loc[((df['day'] == 239) & (df['Age'] == ai)), 'Distance'] = np.sqrt(
                (df.loc[((df['day'] == 239) & (df['Age'] == ai)), 'HRP2'] - ref_pre) ** 2)
            df.loc[((df['day'] == 604) & (df['Age'] == ai)), 'Distance'] = np.sqrt(
                (df.loc[((df['day'] == 604) & (df['Age'] == ai)), 'HRP2'] - ref_post) ** 2)

        df['Total_distance'] = 0
        samples = df['Sample_Number'].unique()
        for si in samples:
            df.loc[((df['Sample_Number'] == si) & (df['day'] == 239)), 'Total_distance'] = df.loc[
                ((df['Sample_Number'] == si) & (df['day'] == 239)), 'Distance'].sum()
            df.loc[((df['Sample_Number'] == si) & (df['day'] == 604)), 'Total_distance'] = df.loc[
                ((df['Sample_Number'] == si) & (df['day'] == 604)), 'Distance'].sum()

        # write to csv
        fn = os.path.join(self.working_dir, self.exp_name)
        if not os.path.exists(fn):
            os.makedirs(fn)
        print('\nSaving data to: %s' % fn)
        df.to_csv(os.path.join(fn, 'hrp2_prevalence_%s.csv' % self.exp_name))


class PfPRAnalyzer(BaseAnalyzer):
    '''
    defines PfPR prevalence analyzer class
    '''

    def __init__(self, exp_name, sweep_variables=None, working_dir='./'):  # sweep_variables=None,

        super(PfPRAnalyzer, self).__init__(working_dir=working_dir,
                                           filenames=[
                                               "output/MalariaSummaryReport_Monthly_from_3498.json"])  # 3498 #3651
        self.sweep_variables = sweep_variables or ["SMC_Coverage"]
        self.exp_name = exp_name
        self.data_channel_type = 'DataByTimeAndAgeBins'  # 'DataByTimeAndPfPRBinsAndAgeBins'
        self.data_channels = 'PfPR by Age Bin'
        self.channel_name = 'PfPR'

    def select_simulation_data(self, data, simulation):

        # Load last 2 years of data from simulation
        output_data_df = pd.DataFrame(data[self.filenames[0]][self.data_channel_type][self.data_channels][:-1])

        # output_data_df = output_data_df[output_data_df[self.data_channels[0]] > 0]
        output_data_df.columns = ['PfPR_0.25', 'PfPR_5', 'PfPR_100']
        output_data_df['Interval'] = output_data_df.index

        # reorient dataframe to long format
        simdata = pd.DataFrame()
        cols = [x for x in output_data_df.columns.values if 'PfPR' in x]
        for col in cols:
            sdf = output_data_df[['Interval', col]]
            sdf = sdf.rename(columns={col: self.channel_name})
            sdf['Age'] = col.split('_')[-1]
            simdata = pd.concat([simdata, sdf])

        # add tags
        for sweep_var in self.sweep_variables:
            simdata[sweep_var] = simulation.tags[sweep_var]

        return simdata

    def finalize(self, all_data):

        # concatenate all simulation data into one dataframe
        selected = [data for sim, data in all_data.items()]  # grab data in tuple form
        if len(selected) == 0:  # error out if no data selected
            print("\nNo data have been returned... Exiting...")
            return
        df = pd.concat(selected, sort=False).reset_index(drop=True)  # concat into dataframe

        grouping_list = self.sweep_variables
        grouping_list.append('Age')
        grouping_list.insert(0, 'Interval')
        df = df.groupby(grouping_list)['PfPR'].agg([np.min, np.mean, np.max]).reset_index()
        df = df.rename(columns={'amin': 'PfPR_min', 'mean': 'PfPR', 'amax': 'PfPR_max'})
        df = df.sort_values(by=grouping_list)

        # keep only age 5
        df = df.loc[df['Age'] == '5']

        # write to csv
        fn = os.path.join(self.working_dir, self.exp_name)
        if not os.path.exists(fn):
            os.makedirs(fn)
        print('\nSaving data to: %s' % fn)
        df.to_csv(os.path.join(fn, 'pfpr_prevalence_%s.csv' % self.exp_name))


class EventReporterAnalyzer(BaseAnalyzer):
    '''
    defines PfPR prevalence analyzer class
    '''

    def __init__(self, exp_name, sweep_variables=None, working_dir='./'):  # sweep_variables=None,

        super(EventReporterAnalyzer, self).__init__(working_dir=working_dir,
                                                    filenames=["output/ReportEventRecorder.csv"])
        self.sweep_variables = sweep_variables
        self.exp_name = exp_name

    def select_simulation_data(self, data, simulation):

        df = data[self.filenames[0]]
        df = df[df['Time'] > 3000]

        # add tags
        for sweep_var in self.sweep_variables:
            df[sweep_var] = simulation.tags[sweep_var]

        return df

    def finalize(self, all_data):

        # concatenate all simulation data into one dataframe
        selected = [data for sim, data in all_data.items()]  # grab data in tuple form
        if len(selected) == 0:  # error out if no data selected
            print("\nNo data have been returned... Exiting...")
            return
        df = pd.concat(selected, sort=False).reset_index(drop=True)  # concat into dataframe

        fn = os.path.join(self.working_dir, self.exp_name)
        if not os.path.exists(fn):
            os.makedirs(fn)
        print('\nSaving data to: %s' % fn)
        df.to_csv(os.path.join(fn, 'events.csv'), index=False, index_label=False)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-name', dest='exp_name', type=str, required=False)
    parser.add_argument('-id', dest='exp_id', type=str, required=True)

    return parser.parse_args()


if __name__ == "__main__":

    args = parse_args()
    from simtools.Analysis.AnalyzeManager import AnalyzeManager
    from simtools.SetupParser import SetupParser

    if os.name == "posix":
        SetupParser.default_block = 'NUCLUSTER'
    else:
        SetupParser.default_block = 'HPC'
    SetupParser.init()

    sys.path.append('../')
    from helper_scripts.load_paths import load_box_paths

    datapath, projectpath = load_box_paths()

    exp_name = args.exp_name

    expts = {exp_name: args.exp_id}
    wdir = os.path.join(projectpath,'vaccSMC_calibration', 'simulation_output')
    variables_vacc = ['vacc_initial_effect', "vacc_box_duration", "vacc_decay_duration"]
    variables_drug = ['drug_decay_time', 'drug_irbc_killing', 'drug_hep_killing']
    sweep_variables = ['SMCcov', 'Sample_id', 'annual EIR'] + variables_vacc + variables_drug

    # run CasesAvertedAnalyzer for efficacy fitting, experimental outputs
    # run HRP2PrevalenceAnalyzer for HRP2 fitting/comparison to prevalence w/o SMC
    # run PfPRAnalyzer for PfPR, experiment validation

    for expname, expid in expts.items():
        ## uncomment and run this block to run locally
        analyzers = [CasesAvertedAnalyzer(exp_name=expname,
                                          sweep_variables=sweep_variables,
                                          working_dir=wdir),
                     # EventReporterAnalyzer(exp_name=expname,
                     #                      sweep_variables=sweep_variables + ['Run_Number'],
                     #                      working_dir=wdir)
                     ]

        am = AnalyzeManager(expid, analyzers=analyzers)
        am.analyze()


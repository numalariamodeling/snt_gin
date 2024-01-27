import os
import numpy as np
import itertools
import pandas as pd

"""
Script to generate sample csv for Banfora ITN fitting simulation
working dir at location of this script
('~emod_itn_exploration/itn_calibration_BFA')
"""


def generate_combo_df(df1, df2):
    dfs_list = [''] * (2)
    dfs_list[0] = df1.copy()
    dfs_list[1] = df2.copy()

    cool_list = np.array(list(itertools.product(dfs_list[0].to_numpy(), dfs_list[1].to_numpy())))
    cool_list = np.array(list(np.concatenate(x) for x in cool_list))

    # Creating a list of columns for use in the final DataFrame...
    master_columns = []
    for df in dfs_list:
        master_columns.extend(np.array(df.columns))

    # Isolating index columns...
    index_columns = []
    for col in master_columns:
        if 'index' in col:
            index_columns.append(col)

    # Writing all data to master DataFrame...
    master_df = pd.DataFrame(data=cool_list, columns=master_columns)
    # Restructuring master DataFrame to bring index columns to front...
    master_df = master_df[
        [c for c in master_df if c in index_columns] + [c for c in master_df if c not in index_columns]]

    return master_df


def add_ITNparamsweep_to_samples(initial_k, initial_b, kmax, nsamples, date_suffix):
    samp_df = pd.read_csv(os.path.join('selected_particles.csv'))
    samp_df = samp_df[samp_df['rank'] == 1]
    start_year = 2005
    initial_killing = initial_k + list(np.linspace(0, kmax, nsamples))
    initial_blocking = initial_b
    combo = list(itertools.product(initial_killing, initial_blocking))
    samp_df_itnparam = pd.DataFrame(combo)
    samp_df_itnparam.columns = ['kill_rate', 'blocking_rate']
    samp_df = generate_combo_df(samp_df, samp_df_itnparam)
    samp_df['ITN_2014_day'] = (365 * (2014 - start_year)) + 152  # June 2014 (standard net deployment)
    samp_df['ITN_2014_year'] = 2014
    samp_df['ITN_2014'] = 0.95

    samp_df['sample_id'] = samp_df['id']
    samp_df['id'] = samp_df.index

    samp_df.to_csv(os.path.join('selected_particles_ITNextended.csv'))
    samp_df.to_csv(os.path.join(f'selected_particles_ITNextended_{date_suffix}.csv'))


if __name__ == "__main__":
    # used in v6 simulation latest version ran to obtain ITN parameters
    initial_k = [0.101]
    initial_b = [0.524, 0.53, 0.550, 0.564, 0.593, 0.726]
    kmax = 0.6
    nsamples = 32
    add_ITNparamsweep_to_samples(initial_k, initial_b, kmax, nsamples, date_suffix='20221115')

import os
import pandas as pd
from hbhi.params_sample import gen_samples_from_df, reduce_dim
from tqdm import tqdm

priordir = '/projects/b1139/malaria-gn-hbhi/IO/simulation_priors/'
input_df = pd.read_csv(os.path.join(priordir, 'all_priors.csv'))
ds_arch = input_df[['DS_Name', 'archetype']].drop_duplicates()
dses = input_df.DS_Name.unique()

output_list = []
for ds in tqdm(dses):
    output_df = gen_samples_from_df(input_df, ds, nsamples=1000)
    output_df = reduce_dim(output_df, 'Habitat_Multiplier', scale=10)
    output_list.append(output_df)

output_df = pd.concat(output_list)
output_df = pd.merge(output_df, ds_arch, how='left', on=['DS_Name'])

# Harmonise Habitat_Multiplier among DSes of same archetype
archetype_df = output_df.copy()
archetype_df = archetype_df[archetype_df.DS_Name == archetype_df.archetype]
archetype_df = archetype_df[['archetype', 'id', 'Habitat_Multiplier']]
archetype_df.rename(columns={'Habitat_Multiplier': 'HM_New'}, inplace=True)

output_df1 = pd.merge(output_df, archetype_df, how='left', on=['archetype', 'id'])
output_df1['Habitat_Multiplier'] = output_df1['HM_New']
output_df1.drop('HM_New', axis=1, inplace=True)

output_df1.to_csv(os.path.join(priordir, "lhs_samples.csv"), index=False, index_label=False)

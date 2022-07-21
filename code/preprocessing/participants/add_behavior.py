# Import packages
import sys
import os
import json
import stat
import pandas as pd
import numpy as np
from copy import deepcopy


# Check if on cluster or on own machine (mounted server)
# Own machine
if 'darwin' in sys.platform:
    # Base path
    base_dir = os.path.join(os.sep, 'Volumes', 'MPRG-Neurocode', 'Users',
                            'christoph', 'damson')
    base_dir = os.path.join(os.sep, 'Users', 'koch', 'Tardis', 'damson')
# Cluster
elif 'linux' in sys.platform:
    # Base path
    base_dir = os.path.join(os.sep, 'home', 'mpib', 'koch', 'damson')


# Load participants.tsv as data frame
participants_dir = os.path.join(base_dir, 'bids', 'participants.tsv')
participants = pd.read_csv(participants_dir, sep='\t', header=0,
                           index_col=False)

# Load additional participant data
add_dir = os.path.join(base_dir, 'sourcedata', 'NAV_FeedbackPhase_Distance2Location.xlsx')
add = pd.read_excel(add_dir)


cols_1 = np.array('old_id')
cols_1 = np.append(cols_1,
                 np.array(['dist_err_fb_' + str(x+1) + '_ses-1' for x in np.arange(30)]))
cols_1 = np.append(cols_1,
                 np.array(['avg_dist_err_fb_trial_' + str(x+1) + '_ses-1' for x in np.arange(6)]))

cols_2 = np.array(['dist_err_fb_' + str(x+1) + '_ses-2' for x in np.arange(30)])
cols_2 = np.append(cols_2,
                 np.array(['avg_dist_err_fb_trial_' + str(x+1) + '_ses-2' for x in np.arange(6)]))
ids = add.loc[:,'ID']
ses = [x[-1] for x in ids]
idx = [True if x == '2' else False for x in ses]
ids = ids[idx]
ids = [x[0:-2] for x in ids]

# Add empty columns to final data frame
full = pd.DataFrame(columns=np.append(cols_1, cols_2))

for i_id in ids :
    # Save behavior of first session into one pandas array (+ name index)
    ses_1 = deepcopy(add.loc[add.loc[:,'ID'] == i_id + '_2', :])
    ses_1.iloc[0,0] = i_id
    ses_1.columns = cols_1
    ses_1 = ses_1.reset_index(drop=True)
    # Convert ID to numeric for later joining with main data frame
    ses_1.loc[:,'old_id'] = pd.to_numeric(ses_1.loc[:,'old_id'])
    # Save behavior of second session into other pandas
    ses_2 = deepcopy(add.loc[add.loc[:,'ID'] == i_id + '_3', :])
    ses_2 = ses_2.drop(columns='ID')
    ses_2.columns = cols_2
    ses_2 = ses_2.reset_index(drop=True)
    # Concat both sessions to put data into wide format
    temp = pd.concat([ses_1, ses_2], axis = 1)
    # Concat each participant to new data frame
    full = pd.concat([full, temp])

# Add each participants concatenated data to the final data frame
participants = pd.merge(left = participants, right = full, how='left')

# Overwrite old participants.tsv
participants.to_csv(participants_dir, sep = '\t', index=False)


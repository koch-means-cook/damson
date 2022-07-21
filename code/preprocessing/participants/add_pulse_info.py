# Import packages
import sys
import os
import json
import stat
import pandas as pd
import numpy as np


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
add_dir = os.path.join(base_dir, 'sourcedata', 'NAV_pulse_selection.xlsx')
add = pd.read_excel(add_dir)

# Get first pulse of flactuating participants
i_ses_1 = add.loc[:,'ses_id'] == 'ses-1'
i_ses_2 = add.loc[:,'ses_id'] == 'ses-2'
sub_ses_1 = add.loc[i_ses_1, 'sub_id'].reset_index(drop = True)
sub_ses_2 = add.loc[i_ses_2, 'sub_id'].reset_index(drop = True)
first_pulse_ses_1 = add.loc[i_ses_1, 'first_real_pulse'].reset_index(drop = True)
first_pulse_ses_2 = add.loc[i_ses_2, 'first_real_pulse'].reset_index(drop = True)
pulse_comment_ses_1 = add.loc[i_ses_1, 'exclusion_criterion'].reset_index(drop = True)
pulse_comment_ses_2 = add.loc[i_ses_2, 'exclusion_criterion'].reset_index(drop = True)

# Add general first pulse and comment column
participants.loc[:, 'first_pulse_ses-1'] = 1
participants.loc[:, 'first_pulse_ses-2'] = 1
participants.loc[:, 'pulse_comment_ses-1'] = ''
participants.loc[:, 'pulse_comment_ses-2'] = ''

# Fill in participants with pulse fluctuation and add comment
for sub_count, sub in enumerate(sub_ses_1) :
    participants.loc[participants.participant_id == sub, 'first_pulse_ses-1'] = first_pulse_ses_1[sub_count]
    participants.loc[participants.participant_id == sub, 'pulse_comment_ses-1'] = pulse_comment_ses_1[sub_count]
for sub_count, sub in enumerate(sub_ses_2) :
    participants.loc[participants.participant_id == sub, 'first_pulse_ses-2'] = first_pulse_ses_2[sub_count]
    participants.loc[participants.participant_id == sub, 'pulse_comment_ses-2'] = pulse_comment_ses_2[sub_count]
    
# Delete nan values in comments
participants.loc[participants['pulse_comment_ses-1'].isnull(), 'pulse_comment_ses-1'] = ''
participants.loc[participants['pulse_comment_ses-2'].isnull(), 'pulse_comment_ses-2'] = ''

# Overwrite old participants.tsv
participants.to_csv(participants_dir, sep = '\t', index=False, na_rep = 'n/a')

# Change .json information
# open the .json file of participants.tsv:
json_dir = os.path.join(base_dir, 'bids', 'participants.json')
with open(json_dir,'r') as in_file:
    json_info = json.load(in_file)
in_file.close()

# First pulse
description = ('Which of the logged scanner pulses is the time stamp of the first TR in the first session')
json_info['first_pulse_ses-1'] = {'Description' : description}
description = ('Which of the logged scanner pulses is the time stamp of the first TR in the second session')
json_info['first_pulse_ses-2'] = {'Description' : description}
# Comments
description = ('Experimenters comment on pulse loggings in first session')
json_info['pulse_comment_ses-1'] = {'Description' : description}
description = ('Experimenters comment on pulse loggings in second session')
json_info['pulse_comment_ses-2'] = {'Description' : description}

# change file permissions to read:
permissions = os.stat(json_dir).st_mode
os.chmod(path=json_dir, mode=permissions | stat.S_IWUSR)
# save updated fieldmap json-file:
with open(json_dir, 'w') as out_file:
    json.dump(json_info, out_file, indent=2, sort_keys=True)
out_file.close()
# change file permissions back to read-only:
os.chmod(path=json_dir, mode=permissions)

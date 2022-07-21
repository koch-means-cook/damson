# Import packages
import sys
import os
import json
import stat
import pandas as pd


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
add_dir = os.path.join(base_dir, 'sourcedata', 'NAV_Subject_Info.xlsx')
add = pd.read_excel(add_dir)

# Copy unblinded intervention
add.loc[:,'intervention_ses-1_ub'] = add.loc[:,'Intervention_T2']
add.loc[:,'intervention_ses-2_ub'] = add.loc[:,'Intervention_T3']

# Add blinded intervention codes
add.loc[:, 'intervention'] = add.loc[:, 'Intervention']
add.loc[add.loc[:, 'intervention'] == 'Placebo / Placebo', 'intervention'] = 'C/C'
add.loc[add.loc[:, 'intervention'] == 'L-DOPA / Placebo', 'intervention'] = 'A/B'
add.loc[add.loc[:, 'intervention'] == 'Placebo / L-DOPA', 'intervention'] = 'B/A'
s = pd.Series(add.loc[:, 'intervention'])
add.loc[:,'intervention_ses-1'] = s.str[0]
add.loc[:,'intervention_ses-2'] = s.str[2]

# Find overlapping subjects
participants = participants.set_index('old_id', drop=False)
add = add.set_index('ID', drop=False)
idx_participants = pd.Index(participants.loc[:,'old_id'])
idx_add = pd.Index(add.loc[:,'ID'])
overlap = idx_participants.intersection(idx_add)

# For overlapping subjects, add intervention columns to participants.tsv
participants.loc[overlap, 'intervention'] = add.loc[overlap,'intervention']
participants.loc[overlap, 'intervention_ses-1'] = add.loc[overlap,'intervention_ses-1']
participants.loc[overlap, 'intervention_ses-2'] = add.loc[overlap,'intervention_ses-2']
participants.loc[overlap, 'intervention_ses-1_ub'] = add.loc[overlap,'intervention_ses-1_ub']
participants.loc[overlap, 'intervention_ses-2_ub'] = add.loc[overlap,'intervention_ses-2_ub']
participants.loc[overlap, 'mg_by_bodyweight'] = add.loc[overlap,'mg_by_bodyweight']
participants.loc[overlap, 'comments'] = add.loc[overlap,'Comments']

# Add incomplete logfiles
incomp_log = pd.read_excel(os.path.join(base_dir, 'sourcedata', 'NAV_Incomplete_Logfiles.xlsx'))
incomp_log = incomp_log.set_index('ID', drop=False)
idx_incomp = pd.Index(incomp_log.loc[:,'ID'])
overlap = idx_participants.intersection(idx_incomp)
participants.loc[:, 'incomplete_logfile'] = 0
participants.loc[overlap, 'incomplete_logfile'] = 1

# Add Feedbackphase timeouts
timeout_log = pd.read_excel(os.path.join(base_dir, 'sourcedata', 'NAV_FeedbackPhase_Timeouts.xlsx'))
# Split runs
s = pd.Series(timeout_log.loc[:, 'ID'])
timeout_log.loc[:, 'session'] = s.str[-1]
timeout_log.loc[:, 'ID'] = s.str[0:-2]
timeout_log = timeout_log.pivot_table(index='ID', columns='session', values='Ph2_timeouts')
# Add timeouts to participants.tsv
timeout_log.loc[:, 'ID'] = timeout_log.index.astype('int64')
timeout_log = timeout_log.set_index('ID', drop=False)
idx_timeout = pd.Index(timeout_log.loc[:,'ID'])
overlap = idx_participants.intersection(idx_timeout)
participants.loc[overlap, 'fb_timeouts_ses-1'] = timeout_log.loc[overlap, '2']
participants.loc[overlap, 'fb_timeouts_ses-2'] = timeout_log.loc[overlap, '3']


# Overwrite old participants.tsv
participants.to_csv(participants_dir, sep = '\t', index=False)


# Change .json information
# open the .json file of participants.tsv:
json_dir = os.path.join(base_dir, 'bids', 'participants.json')
with open(json_dir,'r') as in_file:
    json_info = json.load(in_file)
in_file.close()

# Intervention overall
description = ('Blind intervention plan for both sessions, A for L-DOPA / B for Placebo / C for placebo')
json_info['intervention'] = {'Description' : description}
# Intervention of 1 session
description = ('Intervention code for first session, A for L-DOPA / B for Placebo / C for placebo')
json_info['intervention_ses-1'] = {'Description' : description}
# Intervention of 2 session
description = ('Intervention code for second session, A for L-DOPA / B for Placebo / C for placebo')
json_info['intervention_ses-2'] = {'Description' : description}
# Unblinded Intervention of 1 session
description = ('Unblinded intervention for first session')
json_info['intervention_ses-1_ub'] = {'Description' : description}
# Unblinded Intervention of 2 session
description = ('Unblinded intervention for second session')
json_info['intervention_ses-2_ub'] = {'Description' : description}
# Dosage
description = ('Intervention dosage in mg per kg bodyweight')
json_info['mg_by_bodyweight'] = {'Description' : description}
# Comments
description = ('Comments during data collection')
json_info['comments'] = {'Description' : description}
# Incomplete logfiles
description = ('Flag to show missing/corrupted logfiles')
json_info['incomplete_logfiles'] = {'Description' : description}
# Feedback phase timeouts
description = ('Number time limit of trial was exceeded during feedback phase in session 1')
json_info['fb_timeouts_ses-1'] = {'Description' : description}
description = ('Number time limit of trial was exceeded during feedback phase in session 2')
json_info['fb_timeouts_ses-2'] = {'Description' : description}

# change file permissions to read:
permissions = os.stat(json_dir).st_mode
os.chmod(path=json_dir, mode=permissions | stat.S_IWUSR)
# save updated fieldmap json-file:
with open(json_dir, 'w') as out_file:
    json.dump(json_info, out_file, indent=2, sort_keys=True)
out_file.close()
# change file permissions back to read-only:
os.chmod(path=json_dir, mode=permissions)

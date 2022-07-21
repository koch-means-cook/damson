# !/usr/bin/env python3

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
# Cluster
elif 'linux' in sys.platform:
    # Base path
    base_dir = os.path.join(os.sep, 'home', 'mpib', 'koch', 'damson')

# Load participants.tsv as data frame
participants_dir = os.path.join(base_dir, 'bids', 'participants.tsv')
participants = pd.read_csv(participants_dir, sep='\t', header=0,
                           index_col=False)

# Change group column
idx = ['younger' in x for x in participants.loc[:,'participant_id']]
participants.loc[:, 'group'] = 'older'
participants.loc[idx,'group'] = 'younger'


# Map old and new IDs
with open(os.path.join(base_dir, 'sourcedata', 'id_link.json')) as json_file:
    sub_map = json.load(json_file)

# Swap keys and values
sub_map = {value:key for key, value in sub_map.items()}

# Enter old ID for each new ID
for id_count, id in enumerate(participants.loc[:,'participant_id']):

    sub_code = id[4:]
    participants.loc[id_count, 'old_id'] = sub_map[sub_code]

# Sort participants.tsv by new ID
participants = participants.sort_values(by=['participant_id'])

# Overwrite old participants ID
participants.to_csv(participants_dir, sep = '\t', index=False)


# Change .json information
# open the .json file of participants.tsv:
json_dir = os.path.join(base_dir, 'bids', 'participants.json')
with open(json_dir,'r') as in_file:
    json_info = json.load(in_file)
in_file.close()
# Age
description = ('Age in years as in the initial session')
json_info["age"]["Description"] = description
# Group
description = ('Age group of participant, older for older age group' +
               '/younger for younger age group')
json_info["group"]["Description"] = description
# Sex
description = ('self-rated by participant, M for male/F for female')
json_info["sex"]["Description"] = description
# Old ID
description = 'Old id as used by the scanner'
json_info['old_id'] = {'Description' : description}

# change file permissions to read:
permissions = os.stat(json_dir).st_mode
os.chmod(path=json_dir, mode=permissions | stat.S_IWUSR)
# save updated fieldmap json-file:
with open(json_dir, 'w') as out_file:
    json.dump(json_info, out_file, indent=2, sort_keys=True)
out_file.close()
# change file permissions back to read-only:
os.chmod(path=json_dir, mode=permissions)

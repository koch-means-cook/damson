#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Jul 27 12:30:46 2020

@author: koch
"""

import sys
import os
import json
import glob
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
    
# Get paths to seq info
path_seq = os.path.join(base_dir,
                              'bids',
                              'task-*.json')
files_seq = glob.glob(path_seq)
files_seq.sort()


# ===
# Set general task names
# ===

# Give message to user
print('Enter general task names...')

# Navigation task
# Open navigation seq json
with open(files_seq[0], 'r') as file:
    json_info = json.load(file)
file.close()
# Change task name
json_info['TaskName'] = 'Arena_task'
# Save navigation seq json
with open(files_seq[0], 'w') as file:
    json.dump(json_info, file, indent=2, sort_keys=True)
file.close()

# Resting state seq
with open(files_seq[1], 'r') as file:
    json_info = json.load(file)
file.close()
# Change task name
json_info['TaskName'] = 'Resting_state'
# Save Resting state seq json
with open(files_seq[1], 'w') as file:
    json.dump(json_info, file, indent=2, sort_keys=True)
file.close()




# ===
# Insert empty events file for resting state
# ===

# Give message to user
print('Updating resting_state event files...')

# Get template for resting_state events
template = pd.DataFrame(columns=['onset',
                                 'duration',
                                 'trial_type',
                                 'stim_file'])

# Get all resting state event files
files_rs = os.path.join(base_dir, 'bids', '*', '*', 'func', '*task-rest_events.tsv')
files_rs = glob.glob(files_rs)
files_rs.sort()

# Save empty template for each participant and session
for file in files_rs:
    template.to_csv(file,
                    sep='\t',
                    header=True)



# Give message to user
print('...done!')


        
    
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
    
#base_dir = '/Users/koch/Tardis/damson'

# Get id link between old and new ID
with open(os.path.join(base_dir, 'sourcedata', 'id_link.json')) as json_file:
    sub_map = json.load(json_file)
# Get problem cases
problem_path = os.path.join(base_dir,
                             'derivatives',
                             'preprocessing',
                             'heudiconv',
                             'problem_cases.txt')
with open(problem_path, 'r') as problem_cases:
    problems = problem_cases.read().splitlines()
    problem_cases.close()

# Cut out session from problem cases
problems = [x[0:-2] for x in problems]
# Translate to new ID
problems = [sub_map[x] for x in problems]

# Create event template
template = pd.DataFrame()
template['onset'] = ' '
template['duration'] = ' '


# Loop over problem participants
for sub_count, sub in enumerate(problems):

    # Get paths to fieldmaps
    path_phasediff = os.path.join(base_dir,
                                  'bids',
                                  'sub-' + sub,
                                  '*',
                                  'fmap',
                                  '*phasediff.json')
    path_mag = os.path.join(base_dir,
                                  'bids',
                                  'sub-' + sub,
                                  '*',
                                  'fmap',
                                  '*magnitude1.json')
    path_navevents = os.path.join(base_dir,
                                  'bids',
                                  'sub-' + sub,
                                  '*',
                                  'func',
                                  '*task-nav_events.tsv')
    path_rsevents = os.path.join(base_dir,
                                  'bids',
                                  'sub-' + sub,
                                  '*',
                                  'func',
                                  '*task-rest_events.tsv')
    files_phasediff = glob.glob(path_phasediff)
    files_phasediff.sort()
    files_mag = glob.glob(path_mag)
    files_mag.sort()
    files_navevents = glob.glob(path_navevents)
    files_navevents.sort()
    files_rsevents = glob.glob(path_rsevents)
    files_rsevents.sort()

    # Loop over sessions
    for ses_count in range(2):

        # Get Echo1
        with open(files_mag[ses_count], 'r') as file:
            json_info = json.load(file)
        file.close()
        echo1 = json_info['EchoTime']


        # change file permissions to write:
        permissions = os.stat(files_phasediff[ses_count]).st_mode
        os.chmod(path=files_phasediff[ses_count], mode=permissions | stat.S_IWUSR)
        # Get echo 2
        with open(files_phasediff[ses_count], 'r') as file:
            json_info = json.load(file)
        file.close()
        echo2 = json_info['EchoTime']

        # Enter echo1 and 2 into phasediff json
        json_info['EchoTime1'] = echo1
        json_info['EchoTime2'] = echo2

        #print(echo1, echo2)

        # Save phasediff json with echo1 and echo2 fields
        with open(files_phasediff[ses_count], 'w') as out_file:
            json.dump(json_info, out_file, indent=2, sort_keys=True)
        out_file.close()
        # change file permissions back to read-only:
        os.chmod(path=files_phasediff[ses_count], mode=permissions)

        # Give message to user
        print('Fieldmap information updated: ' + os.path.basename(files_phasediff[ses_count]))

        # Open event file and if empty, fill with template
        with open(files_navevents[ses_count], 'r') as file:
            navevents = file.readlines()
        file.close()
        if len(navevents) == 0:
            with open(files_navevents[ses_count], 'w') as file:
                file.writelines('onset\tduration')
            file.close()
            print('nav event file template created')
            
        # Open event file and if empty, fill with template
        with open(files_rsevents[ses_count], 'r') as file:
            rsevents = file.readlines()
        file.close()
        if len(rsevents) == 0:
            with open(files_rsevents[ses_count], 'w') as file:
                file.writelines('onset\tduration')
            file.close()
            print('resting state event file template created')

        
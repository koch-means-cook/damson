#!/usr/bin/env python

# Import packages
import sys
import os
import numpy as np
import json

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

# Get link between old and new ids
with open(os.path.join(base_dir, 'sourcedata', 'id_link.json')) as json_file:
    sub_map = json.load(json_file)
# Add 'sub-' prefix to new IDs for easier comparison with converted
# participants
sub_map = {key: 'sub-' + value for key, value in sub_map.items()}

# Check if some participants were not converted at all
# Form list of converted participants
bids_list = np.array(os.listdir(os.path.join(base_dir, 'bids')))
bids_index = [i for i, s in enumerate(bids_list) if 'sub-' in s]
bids_list = bids_list[bids_index]
bids_list = np.sort(bids_list)

# Convert to lists and get missing participants in bids directory
sub_list = list(sub_map.values())
bids_list = list(bids_list)
sub_missing = list(set(sub_list).difference(bids_list))
sub_missing = np.sort(sub_missing)

# Add both sessions to participants ot convert in case whole participant is
# missing
to_convert = sub_missing
# Invert dictionary for easier mapping
sub_map = {value: key for key, value in sub_map.items()}
# Get all RAW_IDs based on missing BIDS handle
to_convert = [sub_map[bids_id] for bids_id in to_convert]
to_convert = np.sort(to_convert)
# add '_1' and '_2' to all RAW_IDs sinde they are missing completely
to_convert = np.append(np.char.array(to_convert) + '_1',
                       np.char.array(to_convert) + '_2')

# Add single missing cases
# Loop over subjects
for sub_count, sub_id in enumerate(bids_list):
    # Loop over sessions
    for ses_count, ses_id in enumerate(np.arange(1,3)):
        sub_handle = os.path.join(sub_id + '_' + 'ses-' + str(ses_id))
        main_path = os.path.join(base_dir,
                                 'bids',
                                 sub_id,
                                 'ses-' + str(ses_id))
        # Check if any of the required files are missing
        anat = os.path.join(main_path,
                            'anat',
                             sub_handle + '_T' + str(ses_id) + 'w.nii.gz')
        nav = os.path.join(main_path,
                           'func',
                           sub_handle + '_task-nav_bold.nii.gz')
        rest = os.path.join(main_path,
                           'func',
                           sub_handle + '_task-rest_bold.nii.gz')
        ap = os.path.join(main_path,
                           'fmap',
                           sub_handle + '_dir-AP_epi.nii.gz')
        pa = os.path.join(main_path,
                           'fmap',
                           sub_handle + '_dir-PA_epi.nii.gz')
        mag1 = os.path.join(main_path,
                           'fmap',
                           sub_handle + '_magnitude1.nii.gz')
        mag2 = os.path.join(main_path,
                           'fmap',
                           sub_handle + '_magnitude2.nii.gz')
        phase = os.path.join(main_path,
                           'fmap',
                           sub_handle + '_phasediff.nii.gz')
        # Form list of files
        paths = [anat, nav, rest, ap, pa, mag1, mag2, phase]
        # Check for existance
        check = [os.path.exists(path) for path in paths]
        # in case any file is missing
        if False in check:
            # Add RAW_ID with session to to_convert
            to_convert = np.append(to_convert,
                                   sub_map[sub_id] + '_' + str(ses_id))

# Convert to char array
to_convert = np.char.array(to_convert)
to_convert = np.sort(to_convert)

# Save .txt file with problem cases
save_dir = os.path.join(base_dir, 'derivatives', 'preprocessing', 'heudiconv')
if not os.path.exists(save_dir):
    os.makedirs(save_dir)
with open(os.path.join(save_dir, 'problem_cases.txt'), 'w') as f:
    for line_count in np.arange(len(to_convert)):
        f.write(to_convert[line_count] + '\n')

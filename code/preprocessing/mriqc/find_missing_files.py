#!/usr/bin/env python

# Import packages
import sys
import os
import numpy as np

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

# Form list of participants
sub_list = np.array(os.listdir(os.path.join(base_dir, 'bids')))
sub_index = [i for i, s in enumerate(sub_list) if 'sub' in s]
sub_list = sub_list[sub_index]

# Form list of files calculated by mriqc
mriqc_list = np.array(
        os.listdir(
                os.path.join(base_dir, 'derivatives', 'preprocessing', 'mriqc')
                )
        )
mriqc_index = [i for i, s in enumerate(mriqc_list) if '.html' in s]
mriqc_list = mriqc_list[mriqc_index]
mriqc_index = [i for i, s in enumerate(mriqc_list) if 'sub' in s]
mriqc_list = mriqc_list[mriqc_index]

# Generate dict with all files that should be there
file_dict = np.concatenate([
        # T1w
        [s + '_ses-1_T1w.html' for s in sub_list],
        # T2w
        [s + '_ses-2_T2w.html' for s in sub_list],
        # nav
        [s + '_ses-1_task-nav_bold.html' for s in sub_list],
        [s + '_ses-2_task-nav_bold.html' for s in sub_list],
        # rest
        [s + '_ses-1_task-rest_bold.html' for s in sub_list],
        [s + '_ses-2_task-rest_bold.html' for s in sub_list]
        ]
        )
file_dict = np.sort(file_dict)
file_dict = dict(zip(file_dict, np.zeros(len(file_dict), dtype=bool)))

# Go through list and check for files
for s in file_dict:
    if s in mriqc_list:
        file_dict[s] = True

# Extract only missing files
missing_files = [k for k,v in file_dict.items() if not v]
missing_files = np.sort(missing_files)

# Save .txt file with with missing files
save_dir = os.path.join(base_dir, 'derivatives', 'preprocessing', 'mriqc')
with open(os.path.join(save_dir, 'missing_files.txt'), 'w') as f:
    for line_count in np.arange(len(missing_files)):
        f.write(missing_files[line_count] + '\n')

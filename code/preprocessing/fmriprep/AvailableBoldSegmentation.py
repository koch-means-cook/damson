#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Aug 28 13:15:43 2020

@author: koch
"""

import os
import numpy as np
import pandas as pd
import numpy
import copy
import glob
from nilearn import image
import argparse

# base_path = '/Users/koch/Tardis/damson'

# Function to see which segmentations are present in the bold data
def AvailableSegmentation(base_path) :   

    # Get list of all subjects
    sub_list = os.path.join(base_path,
                                'derivatives',
                                'preprocessing',
                                'fmriprep')
    sub_list = next(os.walk(sub_list))[1]
    sub_list.sort()
    
    data = pd.DataFrame()
    
    # Give message to user
    print('Extracting available segmentation for bold modailty...')
    
    # For all segmentation approaches
    for seg_type in ['aparcaseg', 'aseg'] :
        
        # Load segmentation tables
        seg_path = os.path.join(base_path,
                                'derivatives',
                                'preprocessing',
                                'fmriprep',
                                'desc-' + seg_type + '_dseg.tsv')
        full_seg = pd.read_csv(seg_path, sep='\t')
        
        
        # Load image file
        for sub_id in sub_list :
            img_files = os.path.join(base_path,
                                    'derivatives',
                                    'preprocessing',
                                    'fmriprep',
                                    sub_id,
                                    '*',
                                    'func',
                                    '*T1w_desc-' + seg_type + '*')
            img_files = glob.glob(img_files)
            
            # for all image files
            for file in img_files :
                # Get all segmentation areas present in segmentation image
                seg_img = image.load_img(file)
                seg_data = seg_img.get_fdata()
                seg_data = np.unique(seg_data)
                # Select only present segmentations
                match = [full_seg['index'][x] in seg_data for x in np.arange(len(full_seg))]
                seg_match = copy.deepcopy(full_seg.loc[match, :])
                # Add relevant columns
                file = file.split('/')[-1]
                extra_cols = file.split('_')
                ses = extra_cols[1]
                task = extra_cols[2]
                space = extra_cols[3]
                seg_match['sub_id'] = sub_id
                seg_match['seg_type'] = seg_type
                seg_match['ses_id'] = ses
                seg_match['task'] = task
                seg_match['space'] = space
                
                # Append data
                data = data.append(seg_match)
                
    # Give message to user
    print('Saveing output...')
                
    # Save output
    save_file = os.path.join(base_path,
                                'derivatives',
                                'preprocessing',
                                'fmriprep',
                                'available_seg.tsv')
    data.to_csv(save_file, sep='\t', header=True, index=False)
    
    # Give message to user
    print('...done!')


# Get arguments parswd via commandline
parser = argparse.ArgumentParser(description='DAMSON decoding script')
parser.add_argument('--base_path',
                    default=None,
                    type=str,
                    required=True,
                    help='path to DAMSON repository',
                    metavar='BASE_PATH')
args = parser.parse_args()

# Call function with user inputs
AvailableSegmentation(base_path=args.base_path)


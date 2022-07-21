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
import nilearn
from nilearn.masking import intersect_masks

# Function to create masks from fmriprep segmentation
def GetFsMask(base_path,
              train_test_modality,
              sub_id,
              seg_type,
              mask_index,
              save_mask) :

    # Load segmentation table
    seg_path = os.path.join(base_path,
                            'derivatives',
                            'preprocessing',
                            'fmriprep',
                            'desc-' + seg_type + '_dseg.tsv')
    seg = pd.read_csv(seg_path, sep='\t')


    # Sort mask index
    if isinstance(mask_index, list) : 
        mask_index.sort()

    # Get mask name and value based on what is provided
    if not isinstance(mask_index, list) :
        mask_value = [copy.deepcopy(mask_index)]
    else :
        mask_value = copy.deepcopy(mask_index)
    mask_name = [seg.loc[seg['index'] == x, 'name'].values[0] for x in mask_value]

    # load segmentation image of both sessions
    img_path = os.path.join(base_path,
                            'derivatives',
                            'preprocessing',
                            'fmriprep',
                            sub_id,
                            '*',
                            'func',
                            '*task-nav*space-T1w_desc-' + seg_type + '*')
    img_path = glob.glob(img_path)
    img_ses1 = nilearn.image.load_img(img_path[0])
    img_ses2 = nilearn.image.load_img(img_path[1])

    # Convert images to matrices
    data_ses1 = img_ses1.get_data()
    #np.where(data_ses1 == 2011)
    data_ses2 = img_ses2.get_data()
    #np.where(data_ses2 == 2011)

    # Mask requested values to 1
    data_ses1 = [np.array(data_ses1 == x, dtype=int) for x in mask_value]
    data_ses1 = sum(data_ses1)
    data_ses2 = [np.array(data_ses2 == x, dtype=int) for x in mask_value]
    data_ses2 = sum(data_ses2)

    # Intersect masks
    data_intersect = sum([data_ses1, data_ses2])
    data_intersect[data_intersect != 2] = 0
    data_intersect[data_intersect != 0] = 1

    # Parse binarized values back to img
    mask_intersect = nilearn.image.new_img_like(img_ses1, data_intersect)

    # If requested, save mask to nii.gz
    if save_mask :
        out_dir = os.path.join(base_path, 'derivatives', 'decoding',
                               train_test_modality, sub_id)
        # Create directory in case it does not exist
        if not os.path.exists(out_dir):
            os.makedirs(out_dir)
        # Save img
        out_file = os.path.join(out_dir,
                                (sub_id + '_seg-' + seg_type +
                                 '_mask-' + '-'.join(map(str, mask_value)) +
                                 '.nii.gz'))
        mask_intersect.to_filename(out_file)

    return(mask_intersect)


# base_path = os.path.join(os.path.expanduser('~'), 'Tardis', 'damson')
# sub_id = 'sub-younger001'
# seg_type = 'aparcaseg'
# mask_index = [10, 49]
# intersect_threshold = 0
# save_mask = True

# bla = GetFsMask(base_path=base_path,
#                 sub_id=sub_id,
#                 seg_type=seg_type,
#                 mask_index=mask_index,
#                 intersect_threshold=intersect_threshold,
#                 save_mask=save_mask)

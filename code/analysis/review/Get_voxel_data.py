#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue May  3 14:03:55 2022

@author: koch
"""

import os
import numpy as np
import pandas as pd
import numpy
import sys
import argparse
import nilearn

#base_path = '/Users/koch/Tardis/damson'

def Get_voxel_data(base_path):

    # Load function to load mask
    sys.path.append(os.path.join(base_path,
                                 'code',
                                 'decoding',
                                 'utils'))
    from GetFsMask import GetFsMask

    # Get all participants
    path = os.path.join(base_path, 'bids', 'participants.tsv')
    participants = pd.read_csv(path, sep = '\t', na_values='n/a')

    # Get list of all participants
    sub_list = participants.participant_id.tolist()

    # Set type of segmentation used for mask generation
    mask_seg = 'aparcaseg'
    # Get all masks (combination of single mask indices)
    mask_list = list([
        # HC
        list([17,53]),
        # EVC
        list([1005,2005,1011,2011,1021,2021]),
        # Ishtmus cingulate (rough RSC)
        list([1010,2010]),
        # Entorhinal
        list([1006,2006]),
        # Right precentral gyrus
        list([1024]),
        # MTL
        list([17, 53, 1006, 1016, 2006, 2016])])

    # Allocate empty data frame holding number of voxels for each mask and
    # participant
    out = pd.DataFrame(columns=('participant_id',
                                'mask_index',
                                'n_voxels'))

    # Loop over all participants
    print('Calculating n of voxels per mask...')
    for sub_id in sub_list:
        print('\t' + sub_id + '...')
        # Loop over each mask
        for mask_index in mask_list:

            # Get participant-specific intersection of masks for both sessions
            mask_intersect = GetFsMask(base_path=base_path,
                                       train_test_modality='train-raw_test-raw',
                                       sub_id=sub_id,
                                       seg_type=mask_seg,
                                       mask_index=mask_index,
                                       save_mask=False)
            # Convert nifti image object to matrix
            mask_intersect = nilearn.image.get_data(mask_intersect)
            # Count number of 1 in mask matrix (number of masked voxels)
            n_voxels = np.sum(mask_intersect)

            # Append number of voxels in data table
            out = out.append({'participant_id':sub_id,
                              'mask_index':'-'.join(str(i) for i in mask_index),
                              'n_voxels':n_voxels},
                             ignore_index = True)

    # Save output
    out_file = os.path.join(base_path,
                            'derivatives',
                            'analysis',
                            'review',
                            'data_n_voxel.tsv')
    print('Writing output to ' + out_file + '...')
    out.to_csv(out_file,
               sep = '\t',
               na_rep='n/a',
               header=True,
               index=False)
    print('...done!')


# # Enable command line parsing of arguments
parser = argparse.ArgumentParser(description='Script to get number of voxels for each mask of each participant')
parser.add_argument('--base_path',
                    default=None,
                    type=str,
                    required=True,
                    help='path to DAMSON repository',
                    metavar='BASE_PATH')
args = parser.parse_args()

# Call function
Get_voxel_data(base_path = args.base_path)

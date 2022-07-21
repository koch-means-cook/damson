#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Aug  3 11:05:17 2020

@author: koch
"""

import os
import sys
import json
import nilearn
from nilearn.masking import apply_mask
import pandas as pd
import copy
import matplotlib.pyplot as plt
import numpy as np


# Function to load raw data into TR x Voxels format including preprocessing
def CreateRawMatrix(base_path,
                    sub_id,
                    mask_seg,
                    mask_index,
                    smoothing_fwhm=0,
                    essential_confounds=True,
                    detrend=True,
                    high_pass=1/128,
                    pull_extremes=False,
                    ext_std_thres=8,
                    standardize='zscore'):
    
    # ===    
    # Import own functions
    # ===
    sys.path.append(os.path.join(base_path,
                                 'code',
                                 'decoding',
                                 'utils'))
    from GetFsMask import GetFsMask
    from PullExtremes import PullExtremes
    
    # Get TR from sequence info file
    seq_info = os.path.join(base_path, 'bids', 'task-nav_bold.json')
    with open(seq_info, 'r') as in_file:
        json_data = json.load(in_file)
    in_file.close()
    tr = json_data["RepetitionTime"]
    
    # Get intersection of masks for both sessions
    mask_intersect = GetFsMask(base_path=base_path,
                               train_test_modality='train-raw_test-raw',
                               sub_id=sub_id,
                               seg_type=mask_seg,
                               mask_index=mask_index,
                               save_mask=True)

    # Allocate lists holding loaded raw images, preprocessed raw matrices, 
    # and confound variables for both sessions
    nii_raw = list()
    nii_mat = list()
    conf = list()
    
    # Chceking
    conf_check = list()
    before_confounds = list()
    before_detrend = list()
    before_pb = list()
    before_zs = list()
    
    # # Smoothing check
    # mask_mat = list()
    # bla = mask_intersect.get_fdata()
    # bla = apply_mask(imgs=mask_intersect,
    #                    mask_img=mask_intersect,
    #                    smoothing_fwhm=smoothing_fwhm, ensure_finite=True)
    # apply
    # mask_mat.append(
    #         apply_mask(imgs=mask_intersect,
    #                    mask_img=mask_intersect,
    #                    smoothing_fwhm=smoothing_fwhm, ensure_finite=True)
    #         )
    
    # Get preprocessed raw matrices for both sessions
    for ses_count, ses_id in enumerate(['ses-1', 'ses-2']):
        
        # Load raw images
        file_pattern = sub_id + '_' + ses_id + '_task-nav_space-T1w_desc-'
        file = os.path.join(base_path,
                            'derivatives',
                            'preprocessing',
                            'fmriprep',
                            sub_id,
                            ses_id,
                            'func',
                            file_pattern + 'preproc_bold.nii.gz')
        nii_raw.append(nilearn.image.load_img(file))
        
        # Mask loaded data with intersected mask
        nii_mat.append(
            apply_mask(imgs=nii_raw[ses_count],
                       mask_img=mask_intersect,
                       smoothing_fwhm=smoothing_fwhm)
            )
        
        
        # Check if smoothing before masking or together with masking produces 
        # different outcomes
        # smoothed_before = copy.deepcopy(nii_raw[ses_count])
        # smoothed_before = nilearn.image.smooth_img(imgs=nii_raw[ses_count],
        #                                            fwhm=smoothing_fwhm)
        # smoothed_before = nilearn.masking.apply_mask(imgs=smoothed_before,
        #                                               mask_img=file,
        #                                               smoothing_fwhm=None)
        # smoothed_together = copy.deepcopy(nii_mat[ses_count])
        # np.array_equal(smoothed_before, smoothed_together)
        
        
        # Load motion confounds
        file_pattern = sub_id + '_' + ses_id + '_task-nav_desc-'
        file = os.path.join(base_path,
                            'derivatives',
                            'preprocessing',
                            'fmriprep',
                            sub_id,
                            ses_id,
                            'func',
                            file_pattern + 'confounds_regressors.tsv')
        conf = pd.read_csv(file, sep='\t')
        # Replace possible NaN in first line with mean of column
        nan_cols = conf.loc[0,].isnull()
        conf.loc[0,nan_cols] = conf.loc[:,nan_cols].mean(axis=0)
        
        # If requested, focus on essential confounds
        if essential_confounds:
            # Mark patterns for essential columns (FD, motion)
            tar = ['framewise', 'trans_x', 'trans_y', 'trans_z', 'rot_x', 'rot_y', 'rot_z']
            # Add first 10 noise components
            for x in np.arange(10):
                tar.append('a_comp_cor_0' + str(x))
            # Restrict columns to essential columns
            tar_cols = conf.columns.str.contains('|'.join(tar))
            conf = conf.loc[:, tar_cols]
            # Eliminate derivative and power columns
            conf = conf.loc[:, ~conf.columns.str.contains('|'.join(['power', 'derivative']))]
            
        
        # Bring into numpy format for parsing to signal.clean
        conf = conf.to_numpy()
        
        # Save confounds for check
        conf_check.append(conf)
        
        # Split  preprocessing in case pull extremes is required
        if pull_extremes:
            # Save unedited time courses
            before_confounds.append(copy.deepcopy(nii_mat[ses_count]))
            
            # Clean signal of confounds
            nii_mat[ses_count] = nilearn.signal.clean(signals=nii_mat[ses_count],
                                                      confounds=conf,
                                                      t_r=tr,
                                                      high_pass=high_pass,
                                                      detrend=False,
                                                      standardize=False)
            # Save data before detrend
            before_detrend.append(copy.deepcopy(nii_mat[ses_count]))
    
            # Detrend signal (confounds, high-pass filter, detrend)
            nii_mat[ses_count] = nilearn.signal.clean(signals=nii_mat[ses_count],
                                                      confounds=None,
                                                      t_r=tr,
                                                      high_pass=None,
                                                      detrend=detrend,
                                                      standardize=False)
            # save data before pull back of extremes
            before_pb.append(copy.deepcopy(nii_mat[ses_count]))
            
            # Pull extreme values towards mean
            nii_mat[ses_count] = PullExtremes(nii_mat[ses_count],
                                              threshold_std=ext_std_thres)
            # Save data before zscore
            before_zs.append(copy.deepcopy(nii_mat[ses_count]))
            
            # Zscore signal
            nii_mat[ses_count] = nilearn.signal.clean(signals=nii_mat[ses_count],
                                                      confounds=None,
                                                      t_r=tr,
                                                      high_pass=None,
                                                      detrend=False,
                                                      standardize=standardize)
        # In case pull extremes is not required all preprocessing can be done 
        # in one step
        else:
            nii_mat[ses_count] = nilearn.signal.clean(signals=nii_mat[ses_count],
                                                      confounds=conf,
                                                      t_r=tr,
                                                      high_pass=high_pass,
                                                      detrend=True,
                                                      standardize=standardize)


    # Plot timecourses
    # plt.close('all')
    # fig = plt.figure()
    # # Before preproc
    # ax1 = plt.subplot2grid((5, 2), (0,0))
    # ax1.plot(before_confounds[0][:,8])
    # ax1.set_title('Before preproc, ses-1')
    # ax2 = plt.subplot2grid((5, 2), (0,1))
    # ax2.plot(before_confounds[1][:,8])
    # ax2.set_title('Before preproc, ses-2')
    # # Before detrend
    # ax3 = plt.subplot2grid((5, 2), (1,0))
    # ax3.plot(before_detrend[0][:,8])
    # ax3.set_title('Before detrend, ses-1')
    # ax4 = plt.subplot2grid((5, 2), (1,1))
    # ax4.plot(before_detrend[1][:,8])
    # ax4.set_title('Before detrend, ses-2')
    # # before pull-back
    # ax5 = plt.subplot2grid((5, 2), (2,0))
    # ax5.plot(before_pb[0][:,8])
    # ax5.set_title('Before pull-back, ses-1')
    # ax6 = plt.subplot2grid((5, 2), (2,1))
    # ax6.plot(before_pb[1][:,8])
    # ax6.set_title('Before pull-back, ses-2')
    # # Before zscore
    # ax7 = plt.subplot2grid((5, 2), (3,0))
    # ax7.plot(before_zs[0][:,8])
    # ax7.set_title('Before zscore, ses-1')
    # ax8 = plt.subplot2grid((5, 2), (3,1))
    # ax8.plot(before_zs[1][:,8])
    # ax8.set_title('Before zscore, ses-2')
    # # After preproc
    # ax9 = plt.subplot2grid((5, 2), (4,0))
    # ax9.plot(nii_mat[0][:,8])
    # ax9.set_title('After preproc, ses-1')
    # ax10 = plt.subplot2grid((5, 2), (4,1))
    # ax10.plot(nii_mat[1][:,8])
    # ax10.set_title('After preproc, ses-2')
    
    # plt.tight_layout()
    
        
    # Return results
    return(nii_mat)
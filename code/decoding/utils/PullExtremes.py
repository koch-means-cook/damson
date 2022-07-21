#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Aug  3 10:52:36 2020

@author: koch
"""

import numpy as np
import copy


# Function to pull extreme values
def PullExtremes(data,threshold_std=5):
    # Data is TR x Voxels
    # Get mean and std of each voxel time course
    timecourse_mean = np.mean(data,axis=0)
    timecourse_std = np.std(data,axis=0)
    # Get threshold for extreme positive and negative values
    thresh_pos = timecourse_mean + threshold_std * timecourse_std
    thresh_neg = timecourse_mean - threshold_std * timecourse_std
    
    # Give message to user
    Data2 = np.zeros(data.shape, dtype=bool)
    for i in range(data.shape[1]):
        Data2[:,i] = (data[:,i] >= thresh_pos[i]) | (data[:,i] <= thresh_neg[i]) 
    print('There are %d extreme data points before correction' % (np.sum(Data2)))
    
    # Form result
    data_out = copy.deepcopy(data)
    # Find index for all within-voxel-values above or below extreme thresholds
    for i in range(data_out.shape[1]):
        ind_pos = data_out[:,i] >= thresh_pos[i]
        ind_neg = data_out[:,i] <= thresh_neg[i]
        # If within a TR any voxel was above/below threshold half it's 
        # distance to the mean
        for j,(P,N) in enumerate(zip(ind_pos, ind_neg)):
            if P: data_out[j,i] = (
                    timecourse_mean[i] + 
                    0.5 * (abs(timecourse_mean[i] - data_out[j,i]))
                    )
            if N: data_out[j,i] = (
                    timecourse_mean[i] - 
                    0.5 * (abs(timecourse_mean[i] - data_out[j,i]))
                    )
    
    # Give message to user
    Data2 = np.zeros(data_out.shape, dtype=bool)
    for i in range(data_out.shape[1]):
        Data2[:,i] = (
            (data_out[:,i] >= thresh_pos[i]) | (data_out[:,i] <= thresh_neg[i])
            )
    print('After correction: %d extremes' % (np.sum(Data2)))
    
    # Return result
    return(data_out)

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Aug  3 11:13:22 2020

@author: koch
"""

import pandas as pd
import numpy as np
import imblearn
from imblearn.over_sampling import SMOTE
from sklearn.datasets import make_classification
import random



# Function to (down- or up-) sample conditions to equal amount of all event 
# types in a fold
def GetBalancedTrainingData(conditions,
                            raw_mat,
                            hold_out_split,
                            split_level,
                            balancing_option,
                            balance_strategy,
                            n_bins=6):

    # Restrict data to split
    split_mask = conditions[split_level] != hold_out_split
    split_data = conditions.loc[split_mask]
    split_trs = raw_mat[split_mask]
    
    # Pre-allocate return variables
    sample = pd.DataFrame()
    sampled_cond = pd.DataFrame()
    sampled_trs = np.empty(shape=(0,raw_mat.shape[1]))
    
    # Get counts of each event type in fold
    bins = np.arange(n_bins) + 1
    counts = [np.count_nonzero(split_data['event_type'] == x)
              for x in bins]
    
    
    # - - -
    # Downsampling
    # - - -
    if balancing_option == 'downsample':
        # Get event with lowest count
        min_count = np.min(counts)
        
        # Get x events based on sampling type
        for bin_count, bin_id in enumerate(np.arange(1, n_bins+1)):
            bin_data = split_data.loc[split_data['event_type'] == bin_id, :]
            
            # If desired, take x longest events
            if balance_strategy == 'longest':
                bin_data = bin_data.nlargest(min_count, columns=['duration'])
            # if desired, take x random events
            if balance_strategy == 'random':
                bin_data = bin_data.sample(n=min_count, replace=False)
                
            # Append remaining events for each split and event type
            sample = sample.append(bin_data)
        
        # Sort resampled data into correct order
        sample = sample.sort_index()
        
        # Get mask of which events stayed and which events were eliminated
        sample_mask = np.array(
            [conditions.index.values[index] in sample.index.values
             for index in np.arange(len(conditions.index.values))]
            )
        
        # Restrict data to downsampled subset
        sampled_cond = conditions[sample_mask]
        sampled_trs = raw_mat[sample_mask]
    
    
    # - - -
    # Upsampling
    # - - -
    if balancing_option == 'upsample':
        # Get event with highest count
        max_count = np.max(counts)
        
        # Get x events based on sampling type
        for bin_count, bin_id in enumerate(np.arange(1, n_bins+1)):
            bin_mask = split_data['event_type'] == bin_id
            bin_data = split_data.loc[bin_mask , :]
            bin_trs = split_trs[bin_mask,:]
            
            # Get number of events to sample
            n_curr_examples = counts[bin_count]
            #print(n_curr_examples)
            n_sample_examples = max_count - n_curr_examples
            # If number of examples to sample is at least double of current 
            # examples only sample remaining difference once all examples have 
            # been repeated once
            multiples = int(np.floor(n_sample_examples / n_curr_examples))
            n_sample_examples = n_sample_examples - (multiples * n_curr_examples)
            
            # If desired, take x longest events
            if balance_strategy == 'longest':
                sample_index = bin_data.nlargest(n_sample_examples,
                                                 columns=['duration']).index
            # if desired, take x random events
            if balance_strategy == 'random':
                sample_index = bin_data.sample(n=n_sample_examples,
                                               replace=False).index
            # create mask from indexed subdata
            sample_mask = [True if index in sample_index else False
                           for index in bin_data.index]
            # Restrict conditions and raw data with mask
            sample_data = bin_data.loc[sample_mask, :]
            sample_trs = bin_trs[sample_mask, :]
                
            # In case of n_sample_examples >= n * n_curr_examples add all
            # events as additional samples n times
            for i in np.arange(multiples):
                sample_data = sample_data.append(bin_data)
                sample_trs = np.append(sample_trs, bin_trs, axis=0)
                
            # Append remaining events for each split and event type
            sampled_cond = sampled_cond.append(sample_data)
            sampled_trs = np.append(sampled_trs, sample_trs, axis=0)
        
        # Add resampled data to full conditions and raw data
        sampled_cond = split_data.append(sampled_cond)
        sampled_trs = np.append(split_trs, sampled_trs, axis=0)
        
    # - - -
    # SMOTE
    # - - -
    if balancing_option == 'SMOTE':
        
        # Balance strategy not relevant
        
        # X_data, y_labels = make_classification(n_samples = 1000,
        #                             n_features = 200,
        #                             n_informative=4,
        #                             n_classes = 6)
        # oversample = SMOTE()
        # X2_data, y2_labels = oversample.fit_resample(X_data,y_labels)
        
        
        # how can I get only the data created by SMOTE resmapling?
            # Easier to append to old data!
        # split_data
        X_data = split_trs
        y_labels = split_data['event_type']
        # Create SMOTE sampling object to create new synthetic data points
        oversample = SMOTE()
        
        # ---
        # k_neighbors needs to be set to by min_number_of_examples - 1
        # SMOTE uses X nearest neighbors (lowest euclidean distance) to create
        # new sythetic data lying between the original datapoint and the
        # nearest neighbors (if there are only 2 data points for a class this
        # means the highest nearest neighbor count possible is 1)
        # ---
        
        # Set k_neighbors to default or to highest value possible if smaller
        # than default
        # get default parameter
        k_neighbors_default = oversample.get_params()['k_neighbors']
        # Get maximum of k_neighbors based on minimum of examples
        # max k_neighbors = min examples - 1
        k_neighbors_max = np.min(counts) - 1
        # Set to default or if not possible, to possible max
        if k_neighbors_max > k_neighbors_default:
            k_neighbors = k_neighbors_default
        else:
            k_neighbors = k_neighbors_max 
        oversample  = oversample.set_params(k_neighbors = k_neighbors)
        print('\t' + 'Hold-out split: ' + str(hold_out_split) + '\t' + 'SMOTE k_neighbors = ' + str(k_neighbors))
        # Set seed so synthetic data is always the same
        np.random.seed(666)
        # Create balanced set adding synthetic data
        X2_data, y2_labels = oversample.fit_resample(X_data,y_labels)
        # Reset seed
        np.random.seed()
        # Find synthetic data points (appended to end of original data)
        new_labels = y2_labels[len(y_labels):]
        new_trs = X2_data[len(X_data):]
        
        # Create label output (synthetic data will have NaN on every column
        # except label)
        sampled_cond = sampled_cond.append(split_data)
        new_cond = pd.DataFrame({'event_type':new_labels})
        sampled_cond = pd.concat([sampled_cond, new_cond], ignore_index=True)
        # Add new sythetic TRs to raw data
        sampled_trs = np.append(split_trs, new_trs, axis=0)
        

    # Return (up- or down-) sampled conditions and raw data
    return(sampled_cond, sampled_trs)
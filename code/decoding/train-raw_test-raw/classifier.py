#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Jul 29 16:24:50 2020

@author: koch
"""

import os
import numpy as np
import pandas as pd
import numpy
import sys
import argparse

# Main function for decoding and saving results
def main(base_path,
         sub_id,
         mask_seg,
         mask_index,
         event_file,
         classifier,
         smoothing_fwhm=0,
         essential_confounds=True,
         detrend=True,
         high_pass=1/128,
         pull_extremes=False,
         ext_std_thres=8,
         standardize='zscore',
         n_bins=6,
         balancing_option='upsample',
         balance_strategy='longest',
         x_val_split='fold',
         buffering=False,
         testset_buffer=False,
         perm=False,
         n_perm=0,
         within_session=False,
         n_folds_within = 4,
         reorganize=False):

    # base_path = os.path.join(os.path.expanduser('~'), 'Tardis', 'damson')
    # sub_id = 'sub-older068'
    # mask_seg = 'aparcaseg'
    # mask_index = [1024]
    # event_file = 'walk-fwd'
    # classifier = 'logreg'
    # smoothing_fwhm = 3
    # essential_confounds = True
    # detrend = True
    # high_pass = 1/128
    # pull_extremes = False
    # ext_std_thres = 8
    # standardize = 'zscore'
    # n_bins = 6
    # balancing_option = 'SMOTE'
    # balance_strategy = 'longest'
    # x_val_split='sub_fold'
    # buffering=False
    # testset_buffer=False
    # perm=True
    # n_perm=10
    # within_session=True
    # n_folds_within = 3
    # reorganize=True
    
    
    # Turn of .loc wanings
    pd.options.mode.chained_assignment = None  # default='warn'
    
    # ===
    # Print parameters for output file
    # ===
    parameters = {'base_path' : base_path,
                  'sub_id' : sub_id,
                  'mask_seg' : mask_seg,
                  'mask_index' : mask_index,
                  'event_file' : event_file,
                  'classifier' : classifier,
                  'smoothing_fwhm' : smoothing_fwhm,
                  'essential_confounds' : essential_confounds,
                  'detrend' : detrend,
                  'high_pass' : high_pass,
                  'pull_extremes' : pull_extremes,
                  'ext_std_thres' : ext_std_thres,
                  'standardize' : standardize,
                  'n_bins' : n_bins,
                  'balancing_option' : balancing_option,
                  'balance_strategy' : balance_strategy,
                  'x_val_split': x_val_split,
                  'buffering' : buffering,
                  'perm': perm,
                  'n_perm': n_perm,
                  'within_session': within_session,
                  'n_folds_within': n_folds_within,
                  'reorganize': reorganize}
    print('Used parameters:')
    for key, val in parameters.items() :
        print('\t', key, ':', val)
    
    # Warn about combination of buffer=False & testset_buffer=True (cannot be 
    # combined)
    if (not buffering) & testset_buffer :
        print('\n', 'WARNING:', '\n',
              'Cannot combine unbuffered training and buffered testing set.', '\n',
              'Falling back to unbuffered testing set', '\n')
        testset_buffer = False
        
    # Warn about combination of 'fold'/'session' xval split and within session
    # decoding (needs to use sub_fold)
    if within_session & (x_val_split !=  'sub_fold'):
        print('\n', 'WARNING:', '\n',
              'Cannot combine x_val_split == "fold"/"session" with within-session decoding.', '\n',
              'Falling back to x_val_split = "sub_fold"', '\n')
        x_val_split = 'sub_fold'
    
    # ===    
    # Import own functions specific for train-raw_test-raw
    # ===
    sys.path.append(os.path.join(base_path, 'code', 'decoding', 'train-raw_test-raw', 'utils'))
    from CreateRawMatrix import CreateRawMatrix
    from CreateConditions import CreateConditions
    from AverageMultiTrEvents import AverageMultiTrEvents
    from RawClassification import RawClassification
    # ===    
    # Import own generel decoding functions
    # ===
    sys.path.append(os.path.join(base_path, 'code', 'decoding', 'utils'))
    from CreateOutput import CreateOutput
    
    
    # Sort inputs with length > 1
    if isinstance(mask_index, list) :
        mask_index.sort()
    
    # ===
    # Get raw data matrices (TR x voxel)
    # ===
    
    # Give message to user
    print('Loading raw data...')
    
    raw_mat = CreateRawMatrix(base_path=base_path,
                              sub_id=sub_id,
                              mask_seg=mask_seg,
                              mask_index=mask_index,
                              smoothing_fwhm=smoothing_fwhm,
                              essential_confounds=essential_confounds,
                              detrend=detrend,
                              high_pass=high_pass,
                              pull_extremes=pull_extremes,
                              ext_std_thres=ext_std_thres,
                              standardize=standardize)
    
    # Get number of TRs in first session
    n_tr_ses_1 = raw_mat[0].shape[0]
    n_tr_ses_2 = raw_mat[1].shape[0]
    
    # Concatenate scanning sessions
    raw_mat = np.concatenate([raw_mat[0], raw_mat[1]], axis=0)
    
    # Check if any TRs are weird
    # Same values too often (pos or neg, round to 5 digits after comma)
    check = np.round(np.abs(raw_mat), decimals=5)
    for i in np.arange(len(check)):
        count = np.unique(check[i,:], return_counts=True)[1]
        count = count / np.sum(count)
        # Throw error if same value happens more than 10 times
        if any(count >= 0.1):
            sys.exit('min 10% of example ' + str(i) + ' is same value ')
    
    # ===
    # Loading condition file
    # ===
    
    # Give message to user
    print('Loading condition file...')
    
    # Get condition file
    cond = CreateConditions(base_path=base_path,
                            sub_id=sub_id,
                            raw_mat=raw_mat,
                            n_tr_ses_1=n_tr_ses_1,
                            event_file=event_file)
    
    # Get mask for TRs in which events are decodable
    condition_mask = np.array(cond.event_type.notnull())
    
    # Mask raw data and condition file
    raw_mat = raw_mat[condition_mask, :] 
    cond = cond.loc[condition_mask,:]
    # Sort conditions file to fit raw mat
    cond = cond.sort_values(by=['session', 'fold', 'tr'])
    
    # Average patterns for events happening over mutiple TRs
    cond, raw_mat = AverageMultiTrEvents(cond = cond,
                                         raw_mat = raw_mat)
    
    # Get fold for within_session decoding (allows different fold number)
    cond.loc[:, 'sub_fold'] = 0
    for i_session in np.unique(cond.loc[:,'session']):
        for i_dir in np.arange(1, n_bins+1):
            dir_mask = np.logical_and(cond.loc[:, 'session'] == i_session,
                                          cond.loc[:, 'event_type'] == i_dir)
            n_dir = np.sum(dir_mask)
            split = (
                np.tile(np.arange(1, n_folds_within+1),
                        int(np.ceil(n_dir/n_folds_within)))[np.arange(n_dir)]
                )
            split.sort()
            cond.loc[dir_mask, 'sub_fold'] = split
    
    
    # If requested, reorganize folds within session to be as balanced as
    # possible
    if reorganize:
        for i_session in np.unique(cond.loc[:,'session']):
            for i_dir in np.arange(1, n_bins+1):
                if buffering :
                    for i_buffer in np.arange(1,3) :
                        dir_mask = np.logical_and(cond.loc[:, 'session'] == i_session,
                                                  cond.loc[:, 'event_type'] == i_dir)
                        dir_mask = np.logical_and(dir_mask, 
                                                  cond.loc[:, 'buffer'] == i_buffer)
                        n_dir = np.sum(dir_mask)
                        # Reorganize fold (sub_fold already organized due to constrains
                        # of within session decoding (e.g. fewer events))
                        new_fold = np.tile([2*i_session-1,2*i_session],
                                           int(np.ceil(n_dir/2)))[np.arange(n_dir)]
                        new_fold.sort()
                        cond.loc[dir_mask, 'fold'] = new_fold
                else :
                    dir_mask = np.logical_and(cond.loc[:, 'session'] == i_session,
                                              cond.loc[:, 'event_type'] == i_dir)
                    n_dir = np.sum(dir_mask)
                    # Reorganize fold (sub_fold already organized due to constrains
                    # of within session decoding (e.g. fewer events))
                    new_fold = np.tile([2*i_session-1,2*i_session],
                                       int(np.ceil(n_dir/2)))[np.arange(n_dir)]
                    new_fold.sort()
                    cond.loc[dir_mask, 'fold'] = new_fold
    
    
    # bla_mask =  np.logical_and(cond.loc[:, 'fold'] == 1,
    #                            cond.loc[:, 'event_type'] == 2)
    # bla_mask = np.logical_and(bla_mask,
    #                           cond.loc[:, 'buffer'] == 2)
    # cond.loc[bla_mask, 'fold']
    
        

    # ===
    # Decoding
    # ===
    
    # Give message to user
    print('Decoding...')
    
    # Extract event types and sessions (fold vs. session) for cross-validation
    session_label = cond[x_val_split]
    
    # Create df to hold number of events for each event_type in each split
    counts = pd.DataFrame(np.zeros([n_bins, len(np.unique(session_label))]),
                          columns=['hold_out_split_' + str(int(x)) 
                                   for x in np.unique(session_label)])
    
    # Create df to hold classification accuracy
    acc = np.zeros(len(np.unique(session_label)))
    
    # Create column to hold predictions
    cond['prediction'] = 0
    # Create columns to hold prediction probability
    proba_cols = np.array(
        ['proba_bin_' + str(x) for x in (np.arange(n_bins) + 1)]
        )
    cond[proba_cols] = 0
    # Create columns to hold correlation with mean patterns
    cor_cols = np.array(
        ['corr_mean_pattern_bin_' + str(x) for x in (np.arange(n_bins) + 1)]
        )
    cond[cor_cols] = 0
    
    
    # Decoding if buffering is specified:
    if buffering:
    
        # Split data by buffer
        for buffer in np.unique(cond['buffer']):
            
            train_mask = cond['buffer'] == buffer
            
            # cond_buffer = copy.deepcopy(cond.loc[buffer_mask, :])
            # raw_mat_buffer = copy.deepcopy(raw_mat[buffer_mask, :])
            
            if within_session:
                for i_session in np.unique(cond['session']):
                    
                    train_mask_session = np.logical_and(train_mask,
                                                cond['session'] == i_session)
                                        
                    # cond_buffer_within = copy.deepcopy(cond_buffer.loc[within_mask, :])
                    # raw_mat_buffer_within = copy.deepcopy(raw_mat_buffer[within_mask, :])
                    
                    if not perm:
                        # Classify betas (includes leave-one-out)
                        result_cond, acc, acc_across, counts = (
                            RawClassification(base_path=base_path,
                                              raw_mat=raw_mat,
                                              cond=cond,
                                              train_mask=train_mask_session,
                                              classifier=classifier,
                                              n_bins=n_bins,
                                              x_val_split=x_val_split,
                                              balancing_option=balancing_option,
                                              balance_strategy=balance_strategy,
                                              buffering=buffering,
                                              testset_buffer=testset_buffer,
                                              perm=False)
                            )
                        # Give message to user
                        print('Saving output...')
                        
                        CreateOutput(base_path=base_path,
                                     train_test_modality='train-raw_test-raw',
                                     conditions=result_cond,
                                     n_bins=n_bins,
                                     sub_id=sub_id,
                                     mask_seg=mask_seg,
                                     mask_index=mask_index,
                                     classifier=classifier,
                                     smoothing_fwhm=smoothing_fwhm,
                                     essential_confounds=essential_confounds,
                                     detrend=detrend,
                                     high_pass=high_pass,
                                     ext_std_thres=ext_std_thres,
                                     standardize=standardize,
                                     event_file=event_file,
                                     balancing_option=balancing_option,
                                     balance_strategy=balance_strategy,
                                     x_val_split=x_val_split,
                                     testset_buffer=testset_buffer,
                                     proba_cols=proba_cols,
                                     cor_cols=cor_cols,
                                     event_counts=counts,
                                     accuracy=acc,
                                     accuracy_across=acc_across,
                                     session_label=session_label,
                                     buffer=buffer,
                                     perm=perm,
                                     within_session=i_session,
                                     reorganize=reorganize)
                        
                    elif perm:
                        # Create chained permutation data frames
                        permutation_cond = pd.DataFrame()
                        permutation_acc = pd.DataFrame()
                        permutation_acc_across = pd.DataFrame()
                        permutation_counts = pd.DataFrame()
                        # Loop over permutations, each run shuffeling labels in a different manner
                        for i_perm in np.arange(n_perm):
                            
                            # Give message to user:
                            print('Permutation count: ' + str(i_perm))
                            
                            # Classification with permuted labels
                            result_cond, acc_perm, acc_across_perm, counts_perm = (
                                RawClassification(base_path=base_path,
                                                  raw_mat=raw_mat,
                                                  cond=cond,
                                                  train_mask=train_mask_session,
                                                  classifier=classifier,
                                                  n_bins=n_bins,
                                                  x_val_split=x_val_split,
                                                  balancing_option=balancing_option,
                                                  balance_strategy=balance_strategy,
                                                  buffering=buffering,
                                                  testset_buffer=testset_buffer,
                                                  perm=perm)
                                )
                            # Add variable of permutation
                            result_cond['i_perm'] = i_perm
                            #acc_perm['i_perm'] = i_perm
                            counts_perm['i_perm'] = i_perm
                            # Chain permutation results to one data frame
                            permutation_cond = permutation_cond.append(result_cond, ignore_index = True)
                            permutation_acc = np.append(permutation_acc, acc_perm)
                            permutation_acc_across = np.append(permutation_acc_across, acc_across_perm)
                            permutation_counts = permutation_counts.append(counts_perm, ignore_index = True)

                        # Give message to user
                        print('Saving output...')
                        CreateOutput(base_path=base_path,
                                     train_test_modality='train-raw_test-raw',
                                     conditions=permutation_cond,
                                     n_bins=n_bins,
                                     sub_id=sub_id,
                                     mask_seg=mask_seg,
                                     mask_index=mask_index,
                                     classifier=classifier,
                                     smoothing_fwhm=smoothing_fwhm,
                                     essential_confounds=essential_confounds,
                                     detrend=detrend,
                                     high_pass=high_pass,
                                     ext_std_thres=ext_std_thres,
                                     standardize=standardize,
                                     event_file=event_file,
                                     balancing_option=balancing_option,
                                     balance_strategy=balance_strategy,
                                     x_val_split=x_val_split,
                                     testset_buffer=testset_buffer,
                                     proba_cols=proba_cols,
                                     cor_cols=cor_cols,
                                     event_counts=permutation_counts,
                                     accuracy=permutation_acc,
                                     accuracy_across=permutation_acc_across,
                                     session_label=session_label,
                                     buffer=buffer,
                                     perm=perm,
                                     within_session=i_session,
                                     reorganize=reorganize)
                        
            elif not within_session:
                # No permutation
                if not perm:
                    # Classify betas (includes leave-one-out)
                    result_cond, acc, acc_across, counts = RawClassification(base_path=base_path,
                                                                 raw_mat=raw_mat,
                                                                 cond=cond,
                                                                 train_mask=train_mask,
                                                                 classifier=classifier,
                                                                 n_bins=n_bins,
                                                                 x_val_split=x_val_split,
                                                                 balancing_option=balancing_option,
                                                                 balance_strategy=balance_strategy,
                                                                 buffering=buffering,
                                                                 testset_buffer=testset_buffer,
                                                                 perm=perm)
                    
                    # ===
                    # Create output
                    # ===
                    
                    # Give message to user
                    print('Saving output...')
                    
                    CreateOutput(base_path=base_path,
                                 train_test_modality='train-raw_test-raw',
                                 conditions=result_cond,
                                 n_bins=n_bins,
                                 sub_id=sub_id,
                                 mask_seg=mask_seg,
                                 mask_index=mask_index,
                                 classifier=classifier,
                                 smoothing_fwhm=smoothing_fwhm,
                                 essential_confounds=essential_confounds,
                                 detrend=detrend,
                                 high_pass=high_pass,
                                 ext_std_thres=ext_std_thres,
                                 standardize=standardize,
                                 event_file=event_file,
                                 balancing_option=balancing_option,
                                 balance_strategy=balance_strategy,
                                 x_val_split=x_val_split,
                                 testset_buffer=testset_buffer,
                                 proba_cols=proba_cols,
                                 cor_cols=cor_cols,
                                 event_counts=counts,
                                 accuracy=acc,
                                 accuracy_across=acc_across,
                                 session_label=session_label,
                                 buffer=buffer,
                                 perm=perm,
                                 reorganize=reorganize)
                    
                # Permuting training labels
                elif perm:
                    # Create chained permutation data frames
                    permutation_cond = pd.DataFrame()
                    permutation_acc = pd.DataFrame()
                    permutation_acc_across = pd.DataFrame()
                    permutation_counts = pd.DataFrame()
                    # Loop over permutations, each run shuffeling labels in a different manner
                    for i_perm in np.arange(n_perm):
                        
                        # Give message to user:
                        print('Permutation count: ' + str(i_perm))
                        
                        # Classification with permuted labels
                        result_cond, acc_perm, acc_across_perm, counts_perm = (
                            RawClassification(base_path=base_path,
                                              raw_mat=raw_mat,
                                              cond=cond,
                                              train_mask=train_mask,
                                              classifier=classifier,
                                              n_bins=n_bins,
                                              x_val_split=x_val_split,
                                              balancing_option=balancing_option,
                                              balance_strategy=balance_strategy,
                                              buffering=buffering,
                                              testset_buffer=testset_buffer,
                                              perm=perm)
                            )
                        # Add variable of permutation
                        result_cond['i_perm'] = i_perm
                        counts_perm['i_perm'] = i_perm
                        # Chain permutation results to one data frame
                        permutation_cond = permutation_cond.append(result_cond, ignore_index = True)
                        permutation_acc = np.append(permutation_acc, acc_perm)
                        permutation_acc_across = np.append(permutation_acc_across, acc_across_perm)
                        permutation_counts = permutation_counts.append(counts_perm, ignore_index = True)
                        
                    # ===
                    # Create output
                    # ===
                    
                    # Give message to user
                    print('Saving output...')
                    
                    CreateOutput(base_path=base_path,
                                 train_test_modality='train-raw_test-raw',
                                 conditions=permutation_cond,
                                 n_bins=n_bins,
                                 sub_id=sub_id,
                                 mask_seg=mask_seg,
                                 mask_index=mask_index,
                                 classifier=classifier,
                                 smoothing_fwhm=smoothing_fwhm,
                                 essential_confounds=essential_confounds,
                                 detrend=detrend,
                                 high_pass=high_pass,
                                 ext_std_thres=ext_std_thres,
                                 standardize=standardize,
                                 event_file=event_file,
                                 balancing_option=balancing_option,
                                 balance_strategy=balance_strategy,
                                 x_val_split=x_val_split,
                                 testset_buffer=testset_buffer,
                                 proba_cols=proba_cols,
                                 cor_cols=cor_cols,
                                 event_counts=permutation_counts,
                                 accuracy=permutation_acc,
                                 accuracy_across=permutation_acc_across,
                                 session_label=session_label,
                                 buffer=buffer,
                                 perm=perm,
                                 reorganize=reorganize)
                    
            
    elif not buffering:
        if within_session:
            for i_session in np.unique(cond['session']):
                
                train_mask = cond.loc[:,'session'] == i_session
                
                if not perm:
                    # Classify betas (includes leave-one-out)
                    result_cond, acc, acc_across, counts = (
                        RawClassification(base_path=base_path,
                                          raw_mat=raw_mat,
                                          cond=cond,
                                          train_mask=train_mask,
                                          classifier=classifier,
                                          n_bins=n_bins,
                                          x_val_split=x_val_split,
                                          balancing_option=balancing_option,
                                          balance_strategy=balance_strategy,
                                          buffering=buffering,
                                          testset_buffer=testset_buffer)
                        )
                    # Give message to user
                    print('Saving output...')
                    
                    CreateOutput(base_path=base_path,
                                 train_test_modality='train-raw_test-raw',
                                 conditions=result_cond,
                                 n_bins=n_bins,
                                 sub_id=sub_id,
                                 mask_seg=mask_seg,
                                 mask_index=mask_index,
                                 classifier=classifier,
                                 smoothing_fwhm=smoothing_fwhm,
                                 essential_confounds=essential_confounds,
                                 detrend=detrend,
                                 high_pass=high_pass,
                                 ext_std_thres=ext_std_thres,
                                 standardize=standardize,
                                 event_file=event_file,
                                 balancing_option=balancing_option,
                                 balance_strategy=balance_strategy,
                                 x_val_split=x_val_split,
                                 testset_buffer=testset_buffer,
                                 proba_cols=proba_cols,
                                 cor_cols=cor_cols,
                                 event_counts=counts,
                                 accuracy=acc,
                                 accuracy_across=acc_across,
                                 session_label=session_label,
                                 perm=perm,
                                 within_session=i_session,
                                 reorganize=reorganize)
                    
                elif perm:
                    # Create chained permutation data frames
                    permutation_cond = pd.DataFrame()
                    permutation_acc = pd.DataFrame()
                    permutation_acc_across = pd.DataFrame()
                    permutation_counts = pd.DataFrame()
                    # Loop over permutations, each run shuffeling labels in a different manner
                    for i_perm in np.arange(n_perm):
                        
                        # Give message to user:
                        print('Permutation count: ' + str(i_perm))
                        
                        # Classification with permuted labels
                        result_cond, acc_perm, acc_across_perm, counts_perm = (
                            RawClassification(base_path=base_path,
                                              raw_mat=raw_mat,
                                              cond=cond,
                                              train_mask=train_mask,
                                              classifier=classifier,
                                              n_bins=n_bins,
                                              x_val_split=x_val_split,
                                              balancing_option=balancing_option,
                                              balance_strategy=balance_strategy,
                                              buffering=buffering,
                                              testset_buffer=testset_buffer,
                                              perm=perm)
                            )
                        # Add variable of permutation
                        result_cond['i_perm'] = i_perm
                        counts_perm['i_perm'] = i_perm
                        # Chain permutation results to one data frame
                        permutation_cond = permutation_cond.append(result_cond, ignore_index = True)
                        permutation_acc = np.append(permutation_acc, acc_perm)
                        permutation_acc_across = np.append(permutation_acc_across, acc_across_perm)
                        permutation_counts = permutation_counts.append(counts_perm, ignore_index = True)

                    # Give message to user
                    print('Saving output...')
                    CreateOutput(base_path=base_path,
                                 train_test_modality='train-raw_test-raw',
                                 conditions=permutation_cond,
                                 n_bins=n_bins,
                                 sub_id=sub_id,
                                 mask_seg=mask_seg,
                                 mask_index=mask_index,
                                 classifier=classifier,
                                 smoothing_fwhm=smoothing_fwhm,
                                 essential_confounds=essential_confounds,
                                 detrend=detrend,
                                 high_pass=high_pass,
                                 ext_std_thres=ext_std_thres,
                                 standardize=standardize,
                                 event_file=event_file,
                                 balancing_option=balancing_option,
                                 balance_strategy=balance_strategy,
                                 x_val_split=x_val_split,
                                 testset_buffer=testset_buffer,
                                 proba_cols=proba_cols,
                                 cor_cols=cor_cols,
                                 event_counts=permutation_counts,
                                 accuracy=permutation_acc,
                                 accuracy_across=permutation_acc_across,
                                 session_label=session_label,
                                 perm=perm,
                                 within_session=i_session,
                                 reorganize=reorganize)
                    
        elif not within_session:
            
            # No restrictions to train data
            train_mask = cond.shape[0] * [True]
            
            if not perm:
                # Classify betas (includes leave-one-out)
                result_cond, acc, acc_across, counts = RawClassification(base_path=base_path,
                                                                         raw_mat=raw_mat,
                                                                         cond=cond,
                                                                         train_mask=train_mask,
                                                                         classifier=classifier,
                                                                         n_bins=n_bins,
                                                                         x_val_split=x_val_split,
                                                                         balancing_option=balancing_option,
                                                                         balance_strategy=balance_strategy,
                                                                         buffering=buffering,
                                                                         testset_buffer=testset_buffer)
                    
                # ===
                # Create output
                # ===
                
                # Give message to user
                print('Saving output...')
                
                CreateOutput(base_path=base_path,
                             train_test_modality='train-raw_test-raw',
                             conditions=result_cond,
                             n_bins=n_bins,
                             sub_id=sub_id,
                             mask_seg=mask_seg,
                             mask_index=mask_index,
                             classifier=classifier,
                             smoothing_fwhm=smoothing_fwhm,
                             essential_confounds=essential_confounds,
                             detrend=detrend,
                             high_pass=high_pass,
                             ext_std_thres=ext_std_thres,
                             standardize=standardize,
                             event_file=event_file,
                             balancing_option=balancing_option,
                             balance_strategy=balance_strategy,
                             x_val_split=x_val_split,
                             testset_buffer=testset_buffer,
                             proba_cols=proba_cols,
                             cor_cols=cor_cols,
                             event_counts=counts,
                             accuracy=acc,
                             accuracy_across=acc_across,
                             session_label=session_label,
                             perm=perm,
                             reorganize=reorganize)
                
            elif perm:
                # Create chained permutation data frames
                permutation_cond = pd.DataFrame()
                permutation_acc = pd.DataFrame()
                permutation_acc_across = pd.DataFrame()
                permutation_counts = pd.DataFrame()
                # Loop over permutations, each run shuffeling labels in a different manner
                for i_perm in np.arange(n_perm):
                    
                    # Give message to user:
                    print('Permutation count: ' + str(i_perm))
                    
                    # Classification with permuted labels
                    result_cond, acc_perm, acc_across_perm, counts_perm = (
                        RawClassification(base_path=base_path,
                                          raw_mat=raw_mat,
                                          cond=cond,
                                          train_mask=train_mask,
                                          classifier=classifier,
                                          n_bins=n_bins,
                                          x_val_split=x_val_split,
                                          balancing_option=balancing_option,
                                          balance_strategy=balance_strategy,
                                          buffering=buffering,
                                          testset_buffer=testset_buffer,
                                          perm=perm)
                        )
                    # Add variable of permutation
                    result_cond['i_perm'] = i_perm
                    counts_perm['i_perm'] = i_perm
                    # Chain permutation results to one data frame
                    permutation_cond = permutation_cond.append(result_cond, ignore_index = True)
                    permutation_acc = np.append(permutation_acc, acc_perm)
                    permutation_acc_across = np.append(permutation_acc_across, acc_across_perm)
                    permutation_counts = permutation_counts.append(counts_perm, ignore_index = True)
                    
                # ===
                # Create output
                # ===
                
                # Give message to user
                print('Saving output...')
                
                CreateOutput(base_path=base_path,
                             train_test_modality='train-raw_test-raw',
                             conditions=permutation_cond,
                             n_bins=n_bins,
                             sub_id=sub_id,
                             mask_seg=mask_seg,
                             mask_index=mask_index,
                             classifier=classifier,
                             smoothing_fwhm=smoothing_fwhm,
                             essential_confounds=essential_confounds,
                             detrend=detrend,
                             high_pass=high_pass,
                             ext_std_thres=ext_std_thres,
                             standardize=standardize,
                             event_file=event_file,
                             balancing_option=balancing_option,
                             balance_strategy=balance_strategy,
                             x_val_split=x_val_split,
                             testset_buffer=testset_buffer,
                             proba_cols=proba_cols,
                             cor_cols=cor_cols,
                             event_counts=permutation_counts,
                             accuracy=permutation_acc,
                             accuracy_across=permutation_acc_across,
                             session_label=session_label,
                             perm=perm,
                             reorganize=reorganize)
    
        print('...done!')



# # Enable command line parsing of arguments
parser = argparse.ArgumentParser(description='DAMSON decoding script')
parser.add_argument('--base_path',
                    default=None,
                    type=str,
                    required=True,
                    help='path to DAMSON repository',
                    metavar='BASE_PATH')
parser.add_argument('--sub_id',
                    default=None,
                    type=str,
                    required=True,
                    help='participant to be processed (e.g. sub-younger001)',
                    metavar='SUB_ID')
parser.add_argument('--mask_seg',
                    default=None,
                    type=str,
                    required=True,
                    choices=['aseg', 'aparcaseg'],
                    help='FreeSurfer segmentation type to use (influences mask indices)',
                    metavar='MASK_SEG')
parser.add_argument('--mask_index',
                    nargs='+',
                    default=None,
                    type=int,
                    required=True,
                    help='Codes of segmentations to use as masks (based on segmentation type, if multiple then masks are combined)',
                    metavar='MASK_INDEX')
parser.add_argument('--event_file',
                    default=None,
                    type=str,
                    required=True,
                    help='(standard) events to be used (e.g. walk-fwd)',
                    metavar='EVENT_FILE')
parser.add_argument('--classifier',
                    default=None,
                    type=str,
                    required=True,
                    choices=['svm', 'logreg'],
                    help='classifier to use for prediction',
                    metavar='CLASSIFIER')
parser.add_argument('--smoothing_fwhm',
                    default=None,
                    type=int,
                    required=True,
                    help='FWHM of smoothing kernel applied before masking (in mm)',
                    metavar='FWHM')
parser.add_argument('--essential_confounds',
                    default=None,
                    type=bool,
                    required=True,
                    help='Bool if confounds should be narrowed down to motion, noise, and FD',
                    metavar='ESSENTIAL_CONFOUNDS')
parser.add_argument('--detrend',
                    default=None,
                    type=bool,
                    required=True,
                    help='boolean to use "detrend" option for nilearns signal.clean',
                    metavar='DETREND')
parser.add_argument('--high_pass',
                    default=None,
                    type=float,
                    required=True,
                    help='high pass filter value for nilearns signal.clean',
                    metavar='HIGH_PASS')
parser.add_argument('--pull_extremes',
                    default=False,
                    type=bool,
                    required=True,
                    help='boolean to include pulling extreme data towards the mean',
                    metavar='PULL_EXTREMES')
parser.add_argument('--ext_std_thres',
                    default=None,
                    type=int,
                    required=True,
                    help='max std allowed of a value before being pulled towards the mean',
                    metavar='STD_THRES')
parser.add_argument('--standardize',
                    default=None,
                    type=str,
                    required=True,
                    help='standardize argument to nilearns signal.clean (e.g. "zscore")',
                    metavar='STANDARDIZE')
parser.add_argument('--n_bins',
                    default=None,
                    type=int,
                    required=True,
                    help='number of directional bins',
                    metavar='N_BINS')
parser.add_argument('--balancing_option',
                    default=None,
                    type=str,
                    required=True,
                    choices=['downsample', 'upsample', 'SMOTE', 'none'],
                    help='Type of sampling to balance events',
                    metavar='BALANCING_OPTION')
parser.add_argument('--balance_strategy',
                    default=None,
                    type=str,
                    required=True,
                    choices=['longest', 'random'],
                    help='way to chose events to up- or downsample during balancing',
                    metavar='BALANCE_STRATEGY')
parser.add_argument('--x_val_split',
                    default=None,
                    type=str,
                    required=True,
                    choices=['fold', 'session', 'sub_fold'],
                    help='way to chose folds for cross-validation',
                    metavar='X_VAL_SPLIT')
parser.add_argument('--buffering',
                    dest='buffering',
                    action='store_true',
                    default=False,
                    help='If flag is used buffering will be applied to training set (separate odd and even events)')
parser.add_argument('--testset_buffer',
                    dest='testset_buffer',
                    action='store_true',
                    default=False,
                    help='If flag is used not only the training set will be buffered, but also the testing set')
parser.add_argument('--perm',
                    dest='perm',
                    action='store_true',
                    default=False,
                    help='boolean to permute labels to assess random distribution of predicitons')
parser.add_argument('--n_perm',
                    default=0,
                    type=int,
                    required=False,
                    help='number of permutations to perform',
                    metavar='N_PERM')
parser.add_argument('--within_session',
                    dest='within_session',
                    action='store_true',
                    default=False,
                    help='boolean to perform corss validation only within the same session')
parser.add_argument('--n_folds_within',
                    default=4,
                    choices=[2,3,4],
                    type=int,
                    required=False,
                    help='Number of folds within a session (2, 3, or 4) if within session decoding is performed',
                    metavar='N_FOLDS_WITHIN')
parser.add_argument('--reorganize',
                    dest='reorganize',
                    action='store_true',
                    default=False,
                    help='boolean to abandon classic split of session at half of all events and instead put half of all events of one event type into each fold')
args = parser.parse_args()

# Call main function
main(base_path=args.base_path,
     sub_id=args.sub_id,
     mask_seg=args.mask_seg,
     mask_index=args.mask_index,
     event_file=args.event_file,
     classifier=args.classifier,
     smoothing_fwhm=args.smoothing_fwhm,
     essential_confounds=args.essential_confounds,
     detrend=args.detrend,
     high_pass=args.high_pass,
     ext_std_thres=args.ext_std_thres,
     standardize=args.standardize,
     n_bins=args.n_bins,
     balancing_option=args.balancing_option,
     balance_strategy=args.balance_strategy,
     x_val_split=args.x_val_split,
     buffering=args.buffering,
     testset_buffer=args.testset_buffer,
     perm=args.perm,
     n_perm=args.n_perm,
     within_session=args.within_session,
     n_folds_within=args.n_folds_within,
     reorganize=args.reorganize)


# python3 classifier.py --base_path /home/mpib/koch/damson --sub_id sub-younger002 --mask brain_mask --event_file walk-fwd --smoothing_fwhm 3 --detrend True --high_pass 0.0078125 --ext_std_thres 8 --standardize zscore --n_bins 6 --downsample True --downsample_type longest --x_val_split fold


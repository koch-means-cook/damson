#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Sep 23 18:11:49 2020

@author: koch
"""

import os
import sys
import copy
import numpy as np
import pandas as pd
from sklearn import metrics


def RawClassification(base_path,
                      raw_mat,
                      cond,
                      train_mask,
                      classifier,
                      n_bins,
                      x_val_split,
                      balancing_option,
                      balance_strategy,
                      buffering=False,
                      testset_buffer=False,
                      perm=False):
    
    sys.path.append(os.path.join(base_path, 'code', 'decoding', 'utils'))
    from Classify import Classify
    from GetBalancedTrainingData import GetBalancedTrainingData
    
    
    # Detect within-session decoding
    within_session = len(np.unique(cond.loc[train_mask, 'session'])) == 1
    
    if within_session :
        # Get session
        i_session = np.unique(cond.loc[train_mask, 'session'])[0]
        # Restrict decoding data to session
        session_mask = cond.loc[:,'session'] == i_session
        cond = cond.loc[session_mask]
        raw_mat = raw_mat[session_mask, :]
        # Restrict taining mask to current session
        train_mask = train_mask.loc[session_mask]
    
    # Create conditions and folds to train on (will always keep buffer if 
    # specified, while buffer is dropable in testing set)
    train_cond = copy.deepcopy(cond.loc[train_mask,:])
    train_raw_mat = copy.deepcopy(raw_mat[train_mask,:])
    session_label = train_cond[x_val_split]
    
    
    # If buffer should be included set the training and testing conditions
    # file to be equal (so both include a buffer)
    if testset_buffer :
        cond = copy.deepcopy(train_cond)
        raw_mat = copy.deepcopy(train_raw_mat)
    
    # Create df to hold number of events for each event_type in split of the 
    # training set & testing set
    counts = pd.DataFrame(np.zeros([n_bins, len(np.unique(session_label))]),
                          columns=['hold_out_split_' + str(int(x)) 
                                   for x in np.unique(session_label)])
    counts = counts.append(counts)
    counts['set'] = np.repeat(['train', 'test'], counts.shape[0]/2)
    
    # Create df to hold classification accuracy
    acc = np.zeros(len(np.unique(session_label)))
    
    # Create column to hold predictions
    cond.loc[:,'prediction'] = 0
    # Create columns to hold prediction probability
    proba_cols = np.array(
        ['proba_bin_' + str(x) for x in (np.arange(n_bins) + 1)]
        )
    cond.loc[:,proba_cols] = 0
    # Create columns to hold correlation with mean patterns
    cor_cols = np.array(
        ['corr_mean_pattern_bin_' + str(x) for x in (np.arange(n_bins) + 1)]
        )
    cond.loc[:,cor_cols] = 0
    
    
    # Loop over hold out sets for cross validation
    for hold_out_count, hold_out_split in enumerate(np.unique(session_label)):
        
        # Get unbalanced training set
        train_set_mask = np.array(session_label != hold_out_split)
        
        # mask conditions and data
        train_set_cond = train_cond.loc[train_set_mask, :]
        train_set_raw = train_raw_mat[train_set_mask, :]
        
        # Get balance of events
        # Training
        counts_mask_train = np.where(counts.loc[:, 'set'] == 'train')[0]
        counts.iloc[counts_mask_train,hold_out_count] = np.array(
            [sum(train_set_cond.loc[:,'event_type'] == x) 
             for x in np.arange(1,n_bins+1)]
            )
        
        # In case requested, balance events within training set
        if balancing_option != 'none':
        
            # Give message to user
            print('Balancing events within training set...')
            
            # Get balanced training data according to strategy
            train_set_cond, train_set_raw = (
                GetBalancedTrainingData(conditions=train_cond,
                                        raw_mat=train_raw_mat,
                                        hold_out_split=hold_out_split,
                                        split_level=x_val_split,
                                        balancing_option=balancing_option,
                                        balance_strategy=balance_strategy,
                                        n_bins=n_bins)
                )
        
        # Get test set (in case of testset_buffer == False this will use 
        # events form both buffers)
        test_mask = np.array(cond[x_val_split] == hold_out_split)
        test_cond = np.array(cond.loc[test_mask, 'event_type'])
        test_raw = raw_mat[test_mask]
        
        # Get balance of events
        # Testing
        counts_mask_test = np.where(counts.loc[:, 'set'] == 'test')[0]
        counts.iloc[counts_mask_test,hold_out_count] = np.array(
            [sum(test_cond == x) for x in np.arange(1,n_bins+1)]
            )
        
        # Get mask for folds of training set (for permutation)
        train_set_fold_mask = train_set_cond[x_val_split]
        
        # Print balance of events without considering balancing (in case not
        # permutation, otherwise too much 
        # text output for log)
        if not perm:
            print('\tBalance of events:')
            print('\t\thold_out_split', int(hold_out_split), ':')
            mask = np.where(counts.loc[:, 'set'] == 'train')[0]
            print('\t\t\ttrain:', '\t',
                  np.array(counts.iloc[mask,hold_out_count]))
            mask = np.where(counts.loc[:, 'set'] == 'test')[0]
            print('\t\t\ttest:', '\t', 
                  np.array(counts.iloc[mask,hold_out_count]))
        
        # Throw error in case there are 0 cases of at least one direction of training
        if 0 in np.array(counts.iloc[counts_mask_train,hold_out_count]):
            sys.exit('At least one direction in training data without example.')
        # Warn about missing examples in training set (can be dealt with by 
        # weighting accuracy scores)
        if 0 in np.array(counts.iloc[counts_mask_test,hold_out_count]):
            #sys.exit('At least one direction in testing data without example.')
            print('\n', 'WARNING:', '\n',
                  'At least one direction in testing data without example', '\n')
                  

        # Convert training conditions to single column of events
        train_set_cond = train_set_cond.loc[:,'event_type']
        
        # Print balance of events considering balancing (in case not
        # permutation, otherwise too much text output for log)
        if not perm:
            print('\tBalance of events AFTER balancing:')
            print('\t\thold_out_split', int(hold_out_split), ':')
            print('\t\t\ttrain:', '\t',
                  np.array(
                      [sum(train_set_cond == x) for x in np.arange(1,n_bins+1)])
                  )
        
        # predict classes with selected classifier
        pred, pred_proba = Classify(train_func=train_set_raw,
                                    train_cond=train_set_cond,
                                    test_func=test_raw,
                                    train_fold_mask=train_set_fold_mask,
                                    classifier=classifier,
                                    n_bins=n_bins,
                                    perm=perm)
        
        # Add prediction to conditions file
        cond.loc[test_mask, 'prediction'] = pred
        # Add prediction probability
        cond.loc[test_mask, proba_cols] = np.array(pred_proba)
        
        # Save classification accuracy (adjusted for tets set imbalance)
        clf_acc = metrics.balanced_accuracy_score(y_true=test_cond,
                                                  y_pred=pred, 
                                                  sample_weight=None,
                                                  adjusted=False)
        acc[hold_out_count] = clf_acc
        # not adjusted for test set imbalance
        # clf_acc = np.equal(pred, test_cond)
        # acc[hold_out_count] = np.sum(clf_acc) / len(clf_acc)
       
    
        # Also calculate correlation
        cor = np.zeros([test_cond.shape[0], n_bins])
        # Mean pattern for each bin
        mean_pattern = np.array(
            [np.mean(train_set_raw[train_set_cond == x], axis=0)
             for x in np.arange(n_bins)+ 1]
            )
        for bin_count, bin_id in enumerate(np.arange(n_bins)+ 1):
            # Correlate each mean pattern with each direction representation in 
            # held-out set
            bin_mask = test_cond == bin_id
            # If there are events of this specific bin correlate it with mean 
            # patterns
            if any(bin_mask == True):
                cor[bin_mask] = [np.corrcoef(x, mean_pattern)[0][1:(n_bins+1)] 
                                 for x in test_raw[bin_mask]]
                
        # Add event type and prediction
        cor = pd.DataFrame(cor)
        cor.loc[:, 'event_type'] = test_cond
        
        # Add correlations for hold out set to full results
        cond.loc[test_mask, cor_cols] = np.array(
            cor[np.arange(n_bins)]
            )
    
    # Get adjusted accuracy over all examples rather than within folds
    acc_across = metrics.balanced_accuracy_score(y_true=cond.event_type,
                                                 y_pred=cond.prediction, 
                                                 sample_weight=None,
                                                 adjusted=False)
    
    return(cond, acc, acc_across, counts)
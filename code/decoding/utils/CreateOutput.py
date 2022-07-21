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
import copy

 
def CreateOutput(base_path,
                 train_test_modality,
                 conditions,
                 n_bins,
                 sub_id,
                 mask_seg,
                 mask_index,
                 classifier,
                 smoothing_fwhm,
                 essential_confounds,
                 detrend,
                 high_pass,
                 ext_std_thres,
                 standardize,
                 event_file,
                 balancing_option,
                 balance_strategy,
                 x_val_split,
                 proba_cols,
                 cor_cols,
                 event_counts,
                 accuracy,
                 accuracy_across,
                 session_label,
                 testset_buffer,
                 buffer=None,
                 perm=False,
                 within_session=None,
                 reorganize=False):
    
    # In case of single input, parse to list for compatibillity
    if not isinstance(mask_index, list) : 
        mask_index = [mask_index]
    # Combine arguzments > 1 to string
    mask_index = '-'.join(map(str, mask_index))
    
    # Update fold column in case of within_session analysis
    if within_session and x_val_split == 'sub_fold':
        conditions.loc[:, 'fold'] = conditions.loc[:, 'sub_fold']
    
    # ===
    # Output: Prediction (incl correlation)
    # ===
    
    # Get predictions for each event type
    pred = [np.array(conditions.loc[conditions.event_type == x, 'prediction'])
            for x in (np.arange(n_bins)+1)]
    if perm:
        perm_mask = [np.array(conditions.loc[conditions.event_type == x, 'i_perm'])
            for x in (np.arange(n_bins)+1)]
    
    # Form output file
    conditions.loc[: ,'participant_id'] = sub_id
    conditions.loc[: ,'mask_seg'] = mask_seg
    conditions.loc[: ,'mask_index'] = mask_index
    conditions.loc[: ,'classifier'] = classifier
    conditions.loc[: ,'smoothing_fwhm'] = smoothing_fwhm
    conditions.loc[: ,'essential_confounds'] = essential_confounds
    conditions.loc[: ,'detrend'] = detrend
    conditions.loc[: ,'high_pass'] = high_pass
    conditions.loc[: ,'ext_std_thres'] = ext_std_thres
    conditions.loc[: ,'standardize'] = standardize
    conditions.loc[: ,'n_bins'] = n_bins
    conditions.loc[: ,'event_file'] = event_file
    conditions.loc[: ,'balancing_option'] = balancing_option
    conditions.loc[: ,'balance_strategy'] = balance_strategy
    conditions.loc[: ,'x_val_split'] = x_val_split
    conditions.loc[: ,'testset_buffer'] = testset_buffer
    
    # Load participants.tsv to get additional information about participant
    participants_file = os.path.join(base_path, 'bids', 'participants.tsv')
    participants = pd.read_csv(participants_file, sep='\t')
    participants = participants.loc[participants['participant_id'] == sub_id,:]
    conditions.loc[: ,'age'] = participants['age'].values[0]
    conditions.loc[: ,'sex'] = participants['sex'].values[0]
    conditions.loc[: ,'group'] = participants['group'].values[0]
    conditions.loc[conditions['session'] == 1, 'intervention'] = (
        participants['intervention_ses-1'].values[0]
        )
    conditions.loc[conditions['session'] == 2, 'intervention'] = (
        participants['intervention_ses-2'].values[0]
        )
    
    # Order output
    col_order = ['participant_id',
                 'age',
                 'sex',
                 'group',
                 'intervention',
                 'mask_seg',
                 'mask_index',
                 'classifier',
                 'smoothing_fwhm',
                 'essential_confounds',
                 'detrend',
                 'high_pass',
                 'ext_std_thres',
                 'standardize',
                 'n_bins',
                 'event_file',
                 'balancing_option',
                 'balance_strategy',
                 'x_val_split',
                 'testset_buffer',
                 'session',
                 'fold',
                 'buffer',
                 'event_type',
                 'tr_adj',
                 'tr',
                 'event',
                 'duration',
                 'multi_event',
                 'prediction']
    col_order = col_order + proba_cols.tolist()
    col_order = col_order + cor_cols.tolist()
    if perm:
        col_order = col_order + ['i_perm']
    # In case columns do not exist replace them with NA
    for col in col_order :
        if not col in conditions.columns.tolist():
            conditions.loc[:,col] = None
    conditions = conditions[col_order]
    
    # Create directory to save data to
    if buffer != None:
        out_dir = os.path.join(base_path, 'derivatives', 'decoding',
                               train_test_modality, sub_id, 'buffer')
    elif buffer == None:
        out_dir = os.path.join(base_path, 'derivatives', 'decoding',
                                   train_test_modality, sub_id, 'no_buffer')
        
    # Create directory in case it does not exist
    if not os.path.exists(out_dir):
        os.makedirs(out_dir)
        
    # Get pattern of save-file
    if buffer != None:
        out_file_pattern = os.path.join(out_dir,
                                (sub_id + '_' + train_test_modality + '_events-' + 
                                 event_file + 
                                 '_mask-' + mask_index + 
                                 '_xval-' + x_val_split +
                                 '_clf-' + classifier +
                                 '_buffer-' + str(int(buffer))))
    elif buffer == None:
        out_file_pattern = os.path.join(out_dir,
                                (sub_id + '_' + train_test_modality + '_events-' + 
                                 event_file + 
                                 '_mask-' + mask_index + 
                                 '_xval-' + x_val_split +
                                 '_clf-' + classifier))
    # Add within session count
    if within_session != None:
        out_file_pattern = out_file_pattern + '_within-' + str(int(within_session))
    # Add reorganize option(organizing folds for best event distribution)
    if reorganize:
        out_file_pattern = out_file_pattern + '_reorg'
    # Add if balancing was done with SMOTE
    if balancing_option == 'SMOTE':
        out_file_pattern = out_file_pattern + '_SMOTE'
    # Add is data is permuted
    if perm:
        out_file_pattern = out_file_pattern + '_perm'
    
    
    out_file = out_file_pattern + '_pred.tsv'
    conditions.to_csv(out_file,
                      sep='\t',
                      na_rep='n/a',
                      header=True,
                      index=False)

    
    
    # ===
    # Output: Event statistics
    # ===
    
    # Save event statistics into data frame
    event_stats = event_counts
    
    # Form combined intervention column (one value out of both sessions)
    intervention = (participants['intervention_ses-1'].values[0] + 
                    participants['intervention_ses-2'].values[0])
    if intervention == 'CC': intervention = 'C'
    
    # Add informative columns
    event_stats.loc[:, 'participant_id'] = sub_id
    event_stats.loc[:, 'age'] = participants['age'].values[0]
    event_stats.loc[:, 'sex'] = participants['sex'].values[0]
    event_stats.loc[:, 'group'] = participants['group'].values[0]
    event_stats.loc[:, 'intervention'] = intervention
    event_stats.loc[:, 'n_bins'] = n_bins
    event_stats.loc[:, 'event_type'] = np.tile(np.unique(conditions.loc[:,'event_type']),
                                               int(len(event_stats) / len(np.unique(conditions.loc[:,'event_type']))))
    event_stats.loc[:, 'participant_id'] = sub_id
    event_stats.loc[:, 'event_file'] = event_file
    event_stats.loc[:, 'balancing_option'] = balancing_option
    event_stats.loc[:, 'x_val_split'] = x_val_split
    event_stats.loc[:, 'testset_buffer'] = testset_buffer
    
    # Save output
    out_file = out_file_pattern + '_eventstats.tsv'
    event_stats.to_csv(out_file,
                       sep='\t',
                       na_rep='n/a',
                       index=False)
    
    
    # ===
    # Output: Classification accuracy
    # ===
    
    # Parse to data frame
    # In case only single digit (e.g. when training FWD but testing BWD)
    if accuracy.shape == () :
        accuracy = pd.DataFrame(np.array([accuracy]), columns=['clf_acc'])
    else:
        accuracy = pd.DataFrame(accuracy, columns=['clf_acc'])
    # For accross fold accuracy
    if accuracy_across.shape == () :
        accuracy_across = pd.DataFrame(np.array([accuracy_across]), columns=['clf_acc'])
    else:
        accuracy_across = pd.DataFrame(accuracy_across, columns=['clf_acc'])
    # add held out split
    accuracy_across.loc[:, 'held_out_split'] = 'across'
    if not perm:
        accuracy.loc[:, 'held_out_split'] = np.array(np.unique(session_label))
    elif perm:
        accuracy.loc[:, 'held_out_split'] = np.tile(np.unique(session_label),
                                                    int(len(accuracy)/len(np.unique(session_label))))
        accuracy.loc[:, 'i_perm'] = np.repeat(np.arange(len(accuracy)/len(np.unique(session_label))),
                                              len(np.unique(session_label)))
        # Add only perm number for across-fold accuracy
        accuracy_across.loc[:, 'i_perm'] = np.arange(len(accuracy_across))
        
    # Append fold-specific and across-fold accuracy values
    accuracy = accuracy.append(accuracy_across)
    # Sort after permutation is permuted
    # if perm :
    #     accuracy = accuracy.sort_values(by='i_perm')
    
    # Add informative columns
    accuracy.loc[:, 'participant_id'] = sub_id
    accuracy.loc[:, 'age'] = participants['age'].values[0]
    accuracy.loc[:, 'sex'] = participants['sex'].values[0]
    accuracy.loc[:, 'group'] = participants['group'].values[0]
    accuracy.loc[:, 'intervention'] = intervention
    accuracy.loc[:, 'mask_seg'] = mask_seg
    accuracy.loc[:, 'mask_index'] = mask_index
    accuracy.loc[:, 'classifier'] = classifier
    accuracy.loc[:, 'smoothing_fwhm'] = smoothing_fwhm
    accuracy.loc[:, 'essential_confounds'] = essential_confounds
    accuracy.loc[:, 'detrend'] = detrend
    accuracy.loc[:, 'high_pass'] = high_pass
    accuracy.loc[:, 'ext_std_thres'] = ext_std_thres
    accuracy.loc[:, 'standardize'] = standardize
    accuracy.loc[:, 'n_bins'] = n_bins
    accuracy.loc[:, 'event_file'] = event_file
    accuracy.loc[:, 'balancing_option'] = balancing_option
    accuracy.loc[:, 'balance_strategy'] = balance_strategy
    accuracy.loc[:, 'x_val_split'] = x_val_split
    accuracy.loc[: ,'testset_buffer'] = testset_buffer
    
    # Save output
    out_file = out_file = out_file_pattern + '_acc.tsv'
    accuracy.to_csv(out_file,
                    sep='\t',
                    na_rep='n/a',
                    header=True,
                    index=False)
    
    
    # ===
    # Output: Confusion matrix
    # ===
    
    # Function to extract aligned predictions and confusion function from raw 
    # prediction
    def GetConfFunc(predictions, n_bins):
    
        # Get counts each class got predicted
        conf_mat = np.zeros([n_bins, n_bins])
        pred_event = np.arange(n_bins) + 1
        # For each class
        for x in np.arange(n_bins):
            # Get number of predictions of all classes
            pred_counts = np.array(
                [np.count_nonzero(predictions[x] == i) for i in pred_event]
                )
            conf_mat[x,:] = pred_counts
        
        # Shift correct direction to 3rd position for each class
        conf_mat = [np.roll(conf_mat[x], -x) for x in np.arange(n_bins)]
        conf_mat = [np.roll(conf_mat[x], 2) for x in np.arange(n_bins)]
        conf_mat = np.array(conf_mat)
        
        # Collapse predictions across directions
        aligned_pred = np.sum(conf_mat, axis=0)
        # Standardize based on total predictions
        conf_fun = aligned_pred / np.sum(aligned_pred)
        
        return conf_mat, aligned_pred, conf_fun
    
    # Get confusion function for unpermuted data
    if not perm:
        conf_mat, aligned_pred, conf_fun = GetConfFunc(pred, n_bins)
        # Form output file
        conf = pd.DataFrame(conf_mat)
        deg_steps = 360 / n_bins
        conf.columns=np.roll(np.arange(n_bins) * deg_steps, 2).astype(str)
        conf.loc[:, 'prediction'] = np.core.defchararray.add(
            np.array('raw_prediction_bin_'), np.arange(1,n_bins+1).astype(str)
            )
        # Add confusion function to conf
        conf_add = copy.deepcopy(conf)
        conf_add.iloc[0, 0:n_bins] = aligned_pred
        conf_add.iloc[0, n_bins] = 'aligned_prediction'
        conf_add.iloc[1, 0:n_bins] = conf_fun
        conf_add.iloc[1,n_bins] = 'confusion_function'
        conf_add = conf_add.iloc[0:2,:]
        conf = conf.append(conf_add)
        start_cols = np.array(conf.columns.tolist())
        start_cols = start_cols[np.arange(-1, len(start_cols)-1, 1)]
    # For permuted data get confusion function for each permutation and append
    elif perm:
        conf = pd.DataFrame()
        for i_perm in np.unique(conditions.i_perm):
            pred_perm = [pred[x][perm_mask[x] == i_perm] 
                         for x in np.arange(n_bins)]
            conf_mat_perm, aligned_pred_perm, conf_fun_perm = (
                GetConfFunc(pred_perm, n_bins))
            # Form output file
            conf_perm = pd.DataFrame(conf_mat_perm)
            deg_steps = 360 / n_bins
            conf_perm.columns=np.roll(np.arange(n_bins) * deg_steps, 2).astype(str)
            conf_perm.loc[:, 'prediction'] = np.core.defchararray.add(
                np.array('raw_prediction_bin_'), np.arange(1,n_bins+1).astype(str)
                )
            # Add confusion function to conf
            conf_add = copy.deepcopy(conf_perm)
            conf_add.iloc[0, 0:n_bins] = aligned_pred_perm
            conf_add.iloc[0, n_bins] = 'aligned_prediction'
            conf_add.iloc[1, 0:n_bins] = conf_fun_perm
            conf_add.iloc[1,n_bins] = 'confusion_function'
            conf_add = conf_add.iloc[0:2,:]
            conf_perm = conf_perm.append(conf_add)
            conf_perm.loc[:, 'i_perm'] = i_perm
            start_cols = np.array(conf_perm.columns.tolist())
            start_cols = start_cols[np.arange(-1, len(start_cols)-1, 1)]
            # Append data frame for each permutation
            conf = conf.append(conf_perm)
    
    
    # Add extra columns
    conf.loc[:, 'participant_id'] = sub_id
    conf.loc[:, 'age'] = participants['age'].values[0]
    conf.loc[:, 'sex'] = participants['sex'].values[0]
    conf.loc[:, 'group'] = participants['group'].values[0]
    conf.loc[:, 'intervention'] = intervention
    conf.loc[:, 'mask_seg'] = mask_seg
    conf.loc[:, 'mask_index'] = mask_index
    conf.loc[:, 'classifier'] = classifier
    conf.loc[:, 'smoothing_fwhm'] = smoothing_fwhm
    conf.loc[:, 'essential_confounds'] = essential_confounds
    conf.loc[:, 'detrend'] = detrend
    conf.loc[:, 'high_pass'] = high_pass
    conf.loc[:, 'ext_std_thres'] = ext_std_thres
    conf.loc[:, 'standardize'] = standardize
    conf.loc[:, 'n_bins'] = n_bins
    conf.loc[:, 'event_file'] = event_file
    conf.loc[:, 'balancing_option'] = balancing_option
    conf.loc[:, 'balance_strategy'] = balance_strategy
    conf.loc[:, 'x_val_split'] = x_val_split
    conf.loc[:, 'testset_buffer'] = testset_buffer
    
    # Order columns for output
    col_order = ['participant_id',
                 'age',
                 'sex',
                 'group',
                 'intervention',
                 'mask_seg',
                 'mask_index',
                 'classifier',
                 'smoothing_fwhm',
                 'essential_confounds',
                 'detrend',
                 'high_pass',
                 'ext_std_thres',
                 'standardize',
                 'n_bins',
                 'event_file',
                 'balancing_option',
                 'balance_strategy',
                 'x_val_split',
                 'testset_buffer']
    for i in np.arange(len(start_cols)):        
        col_order.append(start_cols[i])
    # If a column does not exist replace it with none
    for col in col_order :
        if not col in conf.columns.tolist() :
            conf[col] = None
    conf = conf[col_order]
    
    # Save output
    out_file = out_file_pattern + '_conf.tsv'
    conf.to_csv(out_file,
                sep='\t',
                na_rep='n/a',
                header=True,
                index=False)
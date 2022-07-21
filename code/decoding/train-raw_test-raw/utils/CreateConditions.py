#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Aug  3 11:11:19 2020

@author: koch
"""

import sys
import pandas as pd
import numpy as np
import os
import copy


# Get condition file to train/test classifier
def CreateConditions(base_path,
                     sub_id,
                     raw_mat,
                     n_tr_ses_1,
                     event_file):

    
    
    # Create conditions file with event for each TR
    cond = pd.DataFrame()
    cond.insert(0, 'tr', np.arange(raw_mat.shape[0]), allow_duplicates=False)
    cond.insert(0, 'tr_adj', cond.tr + 2, allow_duplicates=False)
    
    # Load events
    beh = pd.DataFrame()
    for ses_count, ses_id in enumerate(['ses-1', 'ses-2']):
        file = os.path.join(base_path,
                            'derivatives',
                            'preprocessing',
                            'logfile',
                            sub_id,
                            ses_id,
                            (sub_id + '_' + ses_id +
                             '_task-nav_events-standard-' + event_file +
                             '.tsv'))
        ses = pd.read_csv(file, sep='\t')
        # Make trs of second session relative to tr count of first session
        if ses_count != 0:
            ses.tr = ses.tr + n_tr_ses_1
            ses.tr_adj = ses.tr_adj + n_tr_ses_1
        # Make event number in second session relative ot first session
            n_events_first_ses = beh.event.max()
            ses.event = ses.event + n_events_first_ses
        beh = beh.append(ses)
    
    # Throw error if number of TRs in behavioral file is higher than the number
    # of TRs in the image file
    # Get number of TRs in second session
    n_tr_ses_2 = raw_mat.shape[0] - n_tr_ses_1
    if np.max(beh.loc[beh['fold'] == 2, 'tr']) > n_tr_ses_1:
        print('Max TR in beh file (ses-1): ', np.max(beh.loc[beh['fold'] == 2, 'tr']))
        print('N TRs in functional (ses-1): ', n_tr_ses_1)
        sys.exit('More TRs in behavioral file than in functional data')
    if np.max(beh.loc[beh['fold'] == 4, 'tr']) > n_tr_ses_2 + n_tr_ses_1:
        print('Max TR in beh file (ses-2): ', np.max(beh.loc[beh['fold'] == 4, 'tr']))
        print('N TRs in functional (ses-2): ', n_tr_ses_2 + n_tr_ses_1)
        sys.exit('More TRs in behavioral file than in functional data')
    
    
    # Adjust tr counts to python format
    beh['tr'] = beh['tr'] - 1
    beh['tr_adj'] = beh['tr_adj'] - 1
    
    # Find which events happened during which TR
    events = np.array([np.unique(beh.event[beh.tr == x])
                    for x in np.arange(raw_mat.shape[0])])
    # Find how many logs of an event are inside one TR
    events_counts = np.array(
        [np.unique(beh.event[beh.tr == x],return_counts=True)[1]
         for x in np.arange(raw_mat.shape[0])]
        )
    # Find all TRs with multiple events
    multi_event_index = np.array(
        [len(events[x]) for x in np.arange(raw_mat.shape[0])]
        )
    multi_event_index = np.where(multi_event_index > 1)[0]
    
    # Find which TR is in which fold
    folds = np.array([np.unique(beh.fold[beh.tr == x])
                    for x in np.arange(raw_mat.shape[0])])
    multi_fold_index = np.array(
        [len(folds[x]) for x in np.arange(raw_mat.shape[0])]
        )
    multi_fold_index = np.where(multi_fold_index > 1)[0]
    
    # Find which buffer happened during which TR
    buffer = np.array(
        [np.unique(beh.buffer[beh.tr == x])
         for x in np.arange(raw_mat.shape[0])]
        )
    # Find how many logs of a buffer are inside one TR
    buffer_counts = np.array(
        [np.unique(beh.buffer[beh.tr == x], return_counts=True)[1]
         for x in np.arange(raw_mat.shape[0])]
        )
    multi_buffer_index = np.array(
        [len(buffer_counts[x]) for x in np.arange(raw_mat.shape[0])]
        )
    multi_buffer_index = np.where(multi_buffer_index > 1)[0]
    
    
    # Create column marking multi_events in one TR
    cond.insert(0, 'multi_event', False, allow_duplicates=True)
    cond.loc[multi_event_index, 'multi_event'] = True
    
    # Assign TRs with multiple events/buffers to event/buffer that takes
    # up most time in the TR
    for i in multi_event_index:
        max_ind = np.where(events_counts[i] == np.max(events_counts[i]))[0]
        events[i] = events[i][max_ind]
        #print(i, events[i])
        # In case multiple events happened equally often take the event that 
        # appears first
        if len(events[i]) > 1:
            events[i] = events[i][0]
    
    for i in multi_buffer_index:
        max_ind = np.where(buffer_counts[i] == np.max(buffer_counts[i]))[0]
        buffer[i] = buffer[i][max_ind]
        # In case multiple events happened equally often take the event that 
        # appears first
        if len(buffer[i]) > 1:
            buffer[i] = buffer[i][0]
        
    # Add event_info column with relevant type of event (e.g. direction in 
    # case of walking forward)
    if event_file == 'stand': beh['event_info'] = 'standing'
    elif event_file == 'walk': beh['event_info'] = 'walking'
    elif event_file == 'stand-dir': beh['event_info'] = beh['bin_by_yaw']
    elif event_file == 'walk-fwd': beh['event_info'] = beh['bin_by_yaw']
    elif event_file == 'walk-bwd': beh['event_info'] = beh['bin_by_yaw']
    # Create a new column for turn combining location and yaw info
    elif event_file == 'turn': 
        beh['event_info'] = beh['turn_dir_by_yaw']
        beh.loc[beh['event_info'].isnull(), 'event_info'] = (
            beh.loc[beh['event_info'].isnull(), 'turn_dir_by_loc']
            )
    # Map event number to event type that happened
    event_number = np.unique(beh['event'])
    event_type = np.array(
        [np.unique(beh.loc[beh['event'] == x, 'event_info'])[0]
         for x in event_number]
        )
    event_dict = dict(zip(event_number, event_type))
    
    # Map event number to fold it was in
    event_fold = np.array(
        [np.unique(beh.loc[beh['event'] == x, 'fold'])[0]
         for x in event_number]
        )
    fold_dict = dict(zip(event_number, event_fold))
    
    # Map event number to duration
    duration_dict = dict(zip(event_number,
                             [len(beh.loc[beh['event'] == x,'event'])
                              for x in event_number]
                             ))
    
    # Add event, buffer, and fold to each TR
    # Post to int data type
    events_tr = copy.deepcopy(events)
    buffer_tr = copy.deepcopy(buffer)
    for x in np.arange(len(events)):
        events_tr[x] = np.sum(events[x])
        buffer_tr[x] = np.sum(buffer[x])
    events_tr = events_tr.astype(int)
    buffer_tr = buffer_tr.astype(int)
    # Add conditions column
    cond.insert(0, 'event', events_tr, allow_duplicates=True)
    cond.insert(0, 'buffer', buffer_tr, allow_duplicates=True)
    # Mark TRs in which no event happened
    cond.loc[cond.event == 0, 'event'] = np.nan
    cond.loc[cond.buffer == 0, 'buffer'] = np.nan
    
    # Add event type to each tr
    cond.insert(0, 'event_type', np.nan, allow_duplicates=True)
    for event_count in event_dict:
        cond.loc[cond.event == event_count, 'event_type'] = (
            event_dict[event_count]
            )
        
    # Add fold to each TR
    cond.insert(0, 'fold', np.nan, allow_duplicates=True)
    for event_count in fold_dict:
        cond.loc[cond.event == event_count, 'fold'] = (
            fold_dict[event_count]
            )
    
    # Adjust events for hemodynamic lag (event in TR x is decodable at TR x+2)
    # (separately for each session because shifting events by to could push a
    # session1 event into session2)
    trs_ses_1 = np.arange(n_tr_ses_1)
    trs_ses_2 = np.arange(n_tr_ses_1, raw_mat.shape[0])
    # Session 1
    cond.loc[trs_ses_1, 'event_type'] = cond.loc[trs_ses_1, 'event_type'].shift(2)
    cond.loc[trs_ses_1, 'event'] = cond.loc[trs_ses_1, 'event'].shift(2)
    cond.loc[trs_ses_1, 'buffer'] = cond.loc[trs_ses_1, 'buffer'].shift(2)
    cond.loc[trs_ses_1, 'fold'] = cond.loc[trs_ses_1, 'fold'].shift(2)
    # Session 2
    cond.loc[trs_ses_2, 'event_type'] = cond.loc[trs_ses_2, 'event_type'].shift(2)
    cond.loc[trs_ses_2, 'event'] = cond.loc[trs_ses_2, 'event'].shift(2)
    cond.loc[trs_ses_2, 'buffer'] = cond.loc[trs_ses_2, 'buffer'].shift(2)
    cond.loc[trs_ses_2, 'fold'] = cond.loc[trs_ses_2, 'fold'].shift(2)
    # Adjust TR and TR_adj for overview
    cond['tr'] = cond['tr'].shift(2)
    cond['tr_adj'] = cond['tr_adj'].shift(2)
    
    # Add session for each event
    cond.insert(0, 'session', np.nan, allow_duplicates=True)
    cond.loc[cond['fold'] == 1, 'session'] = 1
    cond.loc[cond['fold'] == 2, 'session'] = 1
    cond.loc[cond['fold'] == 3, 'session'] = 2
    cond.loc[cond['fold'] == 4, 'session'] = 2
    
    # Add duration for each event
    for x in event_number:
        cond.loc[cond['event'] == x, 'duration'] = duration_dict[x]
    
    # Return conditions file
    return(cond)
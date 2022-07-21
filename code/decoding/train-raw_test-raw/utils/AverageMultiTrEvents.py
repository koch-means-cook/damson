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


# Average all TRs in which the same event happened and adjust conditions file
# accodingly
def AverageMultiTrEvents(cond,
                         raw_mat):

    # Rest index of data frame
    cond = cond.reset_index(drop=True)

    # Create adjusted conditions file to return
    cond_adj = copy.deepcopy(cond)
    # Add end_tr column marking the last TR this event happened in
    cond_adj['tr_end'] = 0
    cond_adj['tr_adj_end'] = 0
    # Add column stating inclusion (will be false for multiple entries)
    cond_adj['inclusion'] = True

    # Go through events and find events which happened in multiple TRs
    for event_count, event_id in enumerate(np.unique(cond['event'])):

        # in case there are multiple entries for the same event
        if len(cond.loc[cond['event'] == event_id, 'event']) > 1:
            # Get location of all multiple event entries
            multi_loc = np.where(cond['event'] == event_id)[0]

            # Add last TR of same event to new columns
            cond_adj.loc[multi_loc[0], 'tr_end'] = (
                cond.loc[multi_loc[len(multi_loc)-1], 'tr'])
            cond_adj.loc[multi_loc[0], 'tr_adj_end'] = (
                cond.loc[multi_loc[len(multi_loc)-1], 'tr_adj'])

            # Mark entries for exclusion
            cond_adj.loc[multi_loc[1:], 'inclusion'] = False

            # Average patterns for multi entry events and store in first entry
            raw_mat[multi_loc[0]] = np.mean(raw_mat[multi_loc], axis=0)

    # Exclude all multiple event condition entries and TR vectors which are not
    # the first
    inclusion_mask = np.array(cond_adj['inclusion'])
    cond_adj = cond_adj.loc[inclusion_mask,:]
    raw_mat = raw_mat[inclusion_mask]

    # Add end_tr for all events which happened during a single TR
    single_mask = np.array(cond_adj['tr_end'] == 0)
    cond_adj.loc[single_mask, 'tr_end'] = cond_adj.loc[single_mask, 'tr']
    cond_adj.loc[single_mask, 'tr_adj_end'] = (
        cond_adj.loc[single_mask, 'tr_adj'])

    # Drop inclusion column
    cond_adj = cond_adj.drop('inclusion', axis=1)

    # Reset index
    cond_adj.reset_index(drop=True)


    return(cond_adj, raw_mat)

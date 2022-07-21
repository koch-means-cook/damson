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

# base_path = os.path.join(os.path.expanduser('~'), 'Tardis', 'damson')
# #sub_id = sub_id
# sub_id = 'sub-older053'
# mask_seg = 'aparcaseg'
# mask_index = [1011, 2011]
# # mask_index = 1011
# classifier = 'logreg'
# smoothing_fwhm = 3
# essential_confounds = True
# detrend = True
# high_pass = 1/128
# pull_extremes = False
# ext_std_thres = 8
# standardize = 'zscore'
# n_bins = 6

# Main function for decoding and saving results
def main(base_path,
         sub_id,
         mask_seg,
         mask_index,
         classifier,
         smoothing_fwhm=0,
         essential_confounds=True,
         detrend=True,
         high_pass=1/128,
         pull_extremes=False,
         ext_std_thres=8,
         standardize='zscore',
         n_bins=6):


    # ===
    # Print parameters for output file
    # ===
    parameters = {'base_path' : base_path,
                  'sub_id' : sub_id,
                  'mask_seg' : mask_seg,
                  'mask_index' : mask_index,
                  'event_file' : 'walk-bwd',
                  'classifier' : classifier,
                  'smoothing_fwhm' : smoothing_fwhm,
                  'essential_confounds' : essential_confounds,
                  'detrend' : detrend,
                  'high_pass' : high_pass,
                  'pull_extremes' : pull_extremes,
                  'ext_std_thres' : ext_std_thres,
                  'standardize' : standardize,
                  'n_bins' : n_bins,}
    print('Used parameters:')
    for key, val in parameters.items() :
        print('\t', key, ':', val)

    # ===
    # Import own functions specific for train-raw_test-raw
    # ===
    sys.path.append(os.path.join(base_path, 'code', 'decoding', 'train-raw_test-raw', 'utils'))
    from CreateRawMatrix import CreateRawMatrix
    from CreateConditions import CreateConditions
    from GetDownsampleMask import GetDownsampleMask
    from AverageMultiTrEvents import AverageMultiTrEvents
    sys.path.append(os.path.join(base_path, 'code', 'decoding', 'train-beta_test-beta', 'utils'))
    from CreateBetaMatrix import CreateBetaMatrix

    # ===
    # Import own generel decoding functions
    # ===
    sys.path.append(os.path.join(base_path, 'code', 'decoding', 'utils'))
    from Classify import Classify
    from CreateOutput import CreateOutput


    # Sort inputs with length > 1
    if isinstance(mask_index, list) :
        mask_index.sort()

    # ===
    # Load betas for training
    # ===

    # Give message to user
    print('Loading beta data...')

    beta_mat, beta_names = CreateBetaMatrix(base_path=base_path,
                                sub_id=sub_id,
                                mask_seg=mask_seg,
                                mask_index=mask_index,
                                smoothing_fwhm=smoothing_fwhm,
                                pull_extremes=pull_extremes,
                                ext_std_thres=ext_std_thres,
                                standardize=standardize)

    # ===
    # Load raw data for testing
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
                            event_file='walk-bwd')

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



    # ===
    # Decoding
    # ===

    # Give message to user
    print('Decoding...')

    # Create df to hold number of events for each event_type
    counts = pd.DataFrame(np.zeros([n_bins,1]),
                          columns=['counts'])
    counts['counts'] = [sum(cond['event_type'] == x) for x in np.arange(1,n_bins+1)]

    # Create variable to hold classification accuracy (no splits)
    acc = 0

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

    # Get training set conditions (betas)
    train_cond = [int(x.split('_')[3]) for x in beta_names]

    # Get test set conditions
    test_cond = cond['event_type']

    # Predict backwards walking raw data by forward walking beta data
    pred, pred_proba = Classify(train_func=beta_mat,
                                train_cond=train_cond,
                                test_func=raw_mat,
                                classifier=classifier,
                                n_bins=n_bins)

    # Add prediction to conditions file
    cond.loc[:,'prediction'] = pred
    # Add prediction probability
    cond.loc[:, proba_cols] = np.array(pred_proba)

    # Save classification accuracy
    clf_acc = np.equal(pred, test_cond)
    acc = np.sum(clf_acc) / len(clf_acc)

    # Also calculate correlation
    cor = np.zeros([test_cond.shape[0], n_bins])
    # Mean pattern for each bin
    mean_pattern = np.array(
        [np.mean(beta_mat[train_cond == x], axis=0)
         for x in (np.arange(n_bins)+ 1)]
        )
    for bin_count, bin_id in enumerate(np.arange(n_bins)+ 1):
        # Correlate each mean pattern with each direction representation in
        # held-out set
        bin_mask = test_cond == bin_id
        # If there are events of this specific bin correlate it with mean
        # patterns
        if any(bin_mask == True):
            cor[bin_mask] = [np.corrcoef(x, mean_pattern)[0][1:(n_bins+1)]
                             for x in raw_mat[bin_mask]]

    # Add event type and prediction
    cor = pd.DataFrame(cor)
    cor['event_type'] = np.array(test_cond)

    # Add correlations for hold out set to full results
    cond.loc[:, cor_cols] = np.array(cor[np.arange(n_bins)])

    # ===
    # Create output
    # ===

    # Give message to user
    print('Saving output...')

    CreateOutput(base_path=base_path,
                 train_test_modality='train-fwd_test-bwd',
                 conditions=cond,
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
                 event_file='walk-bwd',
                 downsample=None,
                 downsample_type=None,
                 x_val_split=None,
                 proba_cols=proba_cols,
                 cor_cols=cor_cols,
                 event_counts=counts,
                 accuracy=acc,
                 session_label=None)

    print('...done!')



# # Get sub_ids
# sub_list = next(os.walk(os.path.join(os.path.expanduser('~'), 'Tardis', 'damson', 'bids')))[1]
# sub_list.sort()
# sub_list = sub_list[4:len(sub_list )]

# # Loop over al participants
# for sub_id in sub_list:

#     print(sub_id)

#     # Set up
    # base_path = os.path.join(os.path.expanduser('~'), 'Tardis', 'damson')
    # #sub_id = sub_id
    # sub_id = 'sub-younger001'
    # mask_seg = 'aparcaseg'
    # mask_index = [1011, 2011]
    # # mask_index = 1011
    # event_file = 'walk-fwd'
    # classifier = 'svm'
    # smoothing_fwhm = 8
    # essential_confounds = True
    # detrend = True
    # high_pass = 1/128
    # pull_extremes = False
    # ext_std_thres = 8
    # standardize = 'zscore'
    # n_bins = 6
    # downsample = True
    # downsample_type = 'longest'
    # x_val_split='fold'

#     main(base_path=base_path,
#          sub_id=sub_id,
#          mask=mask,
#          event_file=event_file,
#          smoothing_fwhm=smoothing_fwhm,
#          detrend=detrend,
#          high_pass=high_pass,
#          ext_std_thres=ext_std_thres,
#          standardize=standardize,
#          n_bins=n_bins,
#          downsample=downsample,
#          downsample_type=downsample_type,
#          x_val_split=x_val_split)



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
args = parser.parse_args()

# Call main function
main(base_path=args.base_path,
     sub_id=args.sub_id,
     mask_seg=args.mask_seg,
     mask_index=args.mask_index,
     classifier=args.classifier,
     smoothing_fwhm=args.smoothing_fwhm,
     essential_confounds=args.essential_confounds,
     detrend=args.detrend,
     high_pass=args.high_pass,
     ext_std_thres=args.ext_std_thres,
     standardize=args.standardize,
     n_bins=args.n_bins)


# python3 classifier.py --base_path /home/mpib/koch/damson --sub_id sub-younger002 --mask brain_mask --event_file walk-fwd --smoothing_fwhm 3 --detrend True --high_pass 0.0078125 --ext_std_thres 8 --standardize zscore --n_bins 6 --downsample True --downsample_type longest --x_val_split fold

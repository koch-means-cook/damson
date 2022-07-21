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
from sklearn.model_selection import LeaveOneGroupOut
from sklearn.model_selection import cross_val_predict
from sklearn.svm import SVC
from sklearn.linear_model import LogisticRegression
import sys
import argparse
from sklearn.utils import shuffle




# Main function for decoding and saving results
def Classify(train_func,
             train_cond,
             test_func,
             train_fold_mask,
             classifier,
             n_bins,
             perm=False):

    # Initialize classifier objects
    svc = SVC(C=1.0,
              kernel='linear',
              shrinking=True,
              probability=False,
              tol=1e-3,
              cache_size=200,
              class_weight='balanced',
              max_iter=-1,
              decision_function_shape='ovr',
              break_ties=True)
    
    logreg = LogisticRegression(penalty='l2',
                                dual=False,
                                tol=1e-4,
                                C=1.0,
                                fit_intercept=True,
                                intercept_scaling=1,
                                class_weight='balanced',
                                random_state=None,
                                solver='lbfgs',
                                max_iter=1000,
                                multi_class='multinomial',
                                verbose=0,
                                warm_start=False,
                                n_jobs=None,
                                l1_ratio=None)

    # If requested, shuffle training labels for permutation
    if perm:
        # Shuffle labels within each fold
        for i_fold in np.unique(train_fold_mask):
            train_cond[train_fold_mask == i_fold] = shuffle(train_cond[train_fold_mask == i_fold]).to_numpy()
        
    # use requested classifier to predict classes of testing set
    if classifier == 'svm':
        svc.fit(X=train_func,
                y=train_cond)
        pred = svc.predict(X=test_func)
        # Don't predict probability for SVM
        pred_proba = np.zeros([test_func.shape[0], n_bins])
    elif classifier == 'logreg':
        logreg.fit(X=train_func,
                   y=train_cond)
        pred = logreg.predict(X=test_func)
        pred_proba = logreg.predict_proba(X=test_func)
    else:
        sys.exit('Classifier object not specified!')
    
    # Return predictions
    return(pred, pred_proba)
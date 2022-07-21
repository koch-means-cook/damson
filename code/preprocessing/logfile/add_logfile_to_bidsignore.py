#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Aug 27 10:54:33 2020

@author: koch
"""

import sys
import os

# Check if on cluster or on own machine (mounted server)
# Own machine
if 'darwin' in sys.platform:
    # Base path
    base_dir = os.path.join(os.sep, 'Volumes', 'MPRG-Neurocode', 'Users',
                            'christoph', 'damson')
# Cluster
elif 'linux' in sys.platform:
    # Base path
    base_dir = os.path.join(os.sep, 'home', 'mpib', 'koch', 'damson')
    
ignore_dir = os.path.join(base_dir, 'bids', '.bidsignore')

# Open ignore file in append mode and append logfile template
logfile_template = '*/*/beh/*_beh.tsv'
with open(ignore_dir, 'a') as file:
    file.write(logfile_template + '\n')
file.close()
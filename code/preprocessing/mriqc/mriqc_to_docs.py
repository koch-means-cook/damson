#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Jul 24 12:26:26 2020

@author: koch
"""

import os
import sys
import glob
import shutil

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
    

# Copy group reports to documentation folder
source_dir = os.path.join(base_dir, 'derivatives', 'preprocessing', 'mriqc')
target_dir = os.path.join(base_dir, 'documentation', 'docs')
files = glob.glob(os.path.join(source_dir, 'group_*.html'))
for f in files:
    shutil.copy(f, target_dir)
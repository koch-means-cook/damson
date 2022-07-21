#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Aug 27 10:45:11 2020

@author: koch
"""

import os
import sys
from pathlib import Path

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
    
bidsignore = os.path.join(base_dir, 'bids', '.bidsignore')
Path(bidsignore).touch()

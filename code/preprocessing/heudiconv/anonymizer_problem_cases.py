#!/usr/bin/env python

# Import packages
import sys
import os
import json


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

# Get link between old and new ids
with open(os.path.join(base_dir, 'sourcedata', 'id_link.json')) as json_file:
    sub_map = json.load(json_file)

# Unprocessed ID (will be input from heudiconv)
sid = sys.argv[-1]
if sid in sub_map:
    print(sub_map[sid])
else:
    # Stop in case the provdided key was not in the data set
    sys.exit('Error: Provided ID not part of data set')

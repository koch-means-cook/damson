#!/usr/bin/env python

# Import packages
import sys
import os
import json

# Make script path relative to mounted singularity image
base_dir = os.path.join('/input')

# Get link between old and new ids
with open(os.path.join(base_dir, 'id_link.json')) as json_file:
    sub_map = json.load(json_file)


# Unprocessed ID (will be input from heudiconv)
sid = sys.argv[-1]
if sid in sub_map:
    print(sub_map[sid])
else:
    # Stop in case the provdided key was not in the data set
    sys.exit('Error: Provided ID not part of data set')

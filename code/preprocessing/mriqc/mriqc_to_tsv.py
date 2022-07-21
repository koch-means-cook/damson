#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ======================================================================
# SCRIPT INFORMATION
# ======================================================================
# SCRIPT: POOL MRIQC DATA
# MAX PLANCK RESEARCH GROUP NEUROCODE
# MAX PLANCK INSTITUTE FOR HUMAN DEVELOPMENT
# LENTZEALLEE 94, 14195 BERLIN, GERMANY
# ======================================================================
# IMPORT RELEVANT PACKAGES
# ======================================================================
import json
import sys
import glob
from os.path import join as opj
import os
import pandas as pd
# ======================================================================
# DEFINE PATHS
# ======================================================================
# Check if on cluster or on own machine (mounted server)
# Own machine
if 'darwin' in sys.platform:
    # Base path
    base_dir = opj(os.sep, 'Volumes', 'MPRG-Neurocode', 'Users',
                            'christoph', 'damson')
# Cluster
elif 'linux' in sys.platform:
    # Base path
    base_dir = opj(os.sep, 'home', 'mpib', 'koch', 'damson')

# ======================================================================
# GET ALL .JSON FILES
# ======================================================================

mriqc_data = opj(base_dir, "derivatives", 'preprocessing', 'mriqc', '*', '*', '*', '*bold*.json')
json_files = glob.glob(mriqc_data)

df = pd.DataFrame({
    'Study': [],
    'Subject': [],
    'Session': [],
    'Modality': [],
    'RepetitionTime': [],
    'EchoTime': [],
    'MBFactor': [],
    'ImageType': [],
    'PartialFourier': [],
    'PixelBandwidth': [],
    'Resolution_x': [],
    'Resolution_y': [],
    'Resolution_z': [],
    'SliceThickness': [],
    'dvars_std': [],
    'tsnr': [],
    'fd_thres': [],
    'fd_mean': [],
    'fd_num': [],
    'fd_perc': [],
    'aqi': [],
})

for json_file in json_files:
    with open(json_file) as current_json_file:
        json_data = json.load(current_json_file)
        df = df.append({
            # add study information here:
            'Study': json_data["bids_meta"]["task_id"],
            'Subject': json_data["bids_meta"]["subject_id"],
            'Session': json_data["bids_meta"]["session_id"],
            'Modality': json_data["bids_meta"]["modality"],
            'RepetitionTime': json_data["bids_meta"]['RepetitionTime'],
            # Set MB factor to 0 if no multiband acceleration in study
            'MBFactor': json_data["bids_meta"]['MultibandAccelerationFactor'] if 'MultibandAccelerationFactor' in json_data["bids_meta"] else 0,
            'EchoTime': json_data["bids_meta"]['EchoTime'],
            # "ParallelReductionFactorInPlane"
            'PartialFourier': json_data["bids_meta"]['PartialFourier'],
            'PixelBandwidth': json_data["bids_meta"]['PixelBandwidth'],
            'Resolution_x': json_data['spacing_x'],
            'Resolution_y': json_data['spacing_y'],
            'Resolution_z': json_data['spacing_z'],
            'SliceThickness': json_data["bids_meta"]['SliceThickness'],
            'ImageType': json_data["bids_meta"]['ImageType'][5],
            # add mriqc metrics here:
            'dvars_std': json_data['dvars_std'],
            'tsnr': json_data['tsnr'],
            'fd_thres': json_data['provenance']['settings']['fd_thres'],
            'fd_mean': json_data['fd_mean'],
            'fd_num': json_data['fd_num'],
            'fd_perc': json_data['fd_perc'],
            'aqi': json_data['aqi']
        }, ignore_index=True)
    current_json_file.close()

file_name = opj(base_dir, "derivatives", "preprocessing", "mriqc", "mriqc_bold.tsv")
df.to_csv(file_name, index=False, sep='\t', encoding='utf-8')

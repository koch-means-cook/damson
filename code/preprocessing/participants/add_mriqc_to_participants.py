#usr/bin/python3

import os
from os.path import join as opj
import sys
import pandas as pd
import json
import stat

# Set paths
# Own machine
if 'darwin' in sys.platform:
    # Base path
    base_dir = opj(os.sep, 'Volumes', 'MPRG-Neurocode', 'Users',
                            'christoph', 'damson')
# Cluster
elif 'linux' in sys.platform:
    # Base path
    base_dir = opj(os.sep, 'home', 'mpib', 'koch', 'damson')


# Get path of tsv files to fuse
participants_dir = opj(base_dir, 'bids', 'participants.tsv')
mriqc_dir = opj(base_dir, 'derivatives', 'preprocessing', 'mriqc', 'mriqc_bold.tsv')
# Get path of json to alter
json_dir = os.path.join(base_dir, 'bids', 'participants.json')

# Load .tsv files as data frame
participants = pd.read_csv(participants_dir, sep='\t', header=0,
                           index_col=False)
mriqc = pd.read_csv(mriqc_dir, sep='\t')

# Sort data by id
mriqc = mriqc.sort_values(by='Subject')
mriqc = mriqc.reset_index(drop=True, inplace=False)

# Delete all MRIQC related columns to avoid duplicates
non_mriqc_cols = participants.columns.drop(list(participants.filter(regex='mriqc')))
participants = participants[non_mriqc_cols]


# Loop over resting state data or navigation data
for sequence in ['rest', 'nav']:

    # Loop over sessions
    for ses_count in [1, 2]:
        # set session name
        ses_name = 'ses-' + str(ses_count)

        # Restrict data to sequence
        data = mriqc[mriqc.loc[:,'Study'] == sequence]
        # Restrict data to session
        data = data[data.loc[:,'Session'] == ses_count]

        # Name relevant columns
        name = 'mriqc' + '_' + sequence + '_' + ses_name + '_'
        name_tsnr = name + 'tsnr'
        name_aqi = name + 'aqi'
        name_mean_fd = name + 'fd_mean'
        name_dvars_std = name + 'dvars_std'
        name_mb_factor = name + 'mb_factor'
        name_repetition_time = name + 'repetition_time'
        name_res_x = name + 'resolution_x'
        name_res_y = name + 'resolution_y'
        name_res_z = name + 'resolution_z'

        # Add columns with MRIQC data
        add = pd.DataFrame()
        add.loc[:,0] = data.loc[:,'tsnr']
        add.loc[:,1] = data.loc[:,'aqi']
        add.loc[:,2] = data.loc[:,'fd_mean']
        add.loc[:,3] = data.loc[:,'dvars_std']
        add.loc[:,4] = data.loc[:,'MBFactor']
        add.loc[:,5] = data.loc[:,'RepetitionTime']
        add.loc[:,6] = data.loc[:,'Resolution_x']
        add.loc[:,7] = data.loc[:,'Resolution_y']
        add.loc[:,8] = data.loc[:,'Resolution_z']

        # Name columns
        add.columns = [name_tsnr,
                       name_aqi,
                       name_mean_fd,
                       name_dvars_std,
                       name_mb_factor,
                       name_repetition_time,
                       name_res_x,
                       name_res_y,
                       name_res_z]

        # Drop index to append data
        add = add.reset_index(drop=True, inplace=False)

        # Append mriqc information
        participants = pd.concat([participants, add], axis=1)

        # Change .json information
        # open the .json file of participants.tsv:
        with open(json_dir,'r') as in_file:
            json_info = json.load(in_file)
        in_file.close()
        # tsnr
        description = ('temporal signal to noise (tsnr) value as calculated ' +
                       'by MRIQC for the ' +
                       str(ses_count) +
                       ' session of the ' +
                       str(sequence) +
                       ' sequence ')
        json_info[name_tsnr] = {'Description' : description}
        # aqi
        description = ('AFNI quality index (AQI) value as calculated by ' +
                       'MRIQC for the ' +
                       str(ses_count) +
                       ' session of the ' +
                       str(sequence) +
                       ' sequence ')
        json_info[name_aqi] = {'Description' : description}
        # mean_fd
        description = ('Mean framewise displacement (FD) value as calculated' +
                       'by MRIQC for the ' +
                       str(ses_count) +
                       ' session of the ' +
                       str(sequence) +
                       ' sequence ')
        json_info[name_mean_fd] = {'Description' : description}
        # dvars_std
        description = ('Normalized DVARS value as calculated' +
                       'by MRIQC for the ' +
                       str(ses_count) +
                       ' session of the ' +
                       str(sequence) +
                       ' sequence ')
        json_info[name_dvars_std] = {'Description' : description}
        # mb_factor
        description = ('MB Factor of parallel imaging as calculated' +
                       'by MRIQC for the ' +
                       str(ses_count) +
                       ' session of the ' +
                       str(sequence) +
                       ' sequence ')
        json_info[name_mb_factor] = {'Description' : description}
        # repetition time
        description = ('Repetition time as calculated' +
                       'by MRIQC for the ' +
                       str(ses_count) +
                       ' session of the ' +
                       str(sequence) +
                       ' sequence ')
        json_info[name_repetition_time] = {'Description' : description}
        # Resolution of x
        description = ('Resolution of x dimension as calculated' +
                       'by MRIQC for the ' +
                       str(ses_count) +
                       ' session of the ' +
                       str(sequence) +
                       ' sequence ')
        json_info[name_res_x] = {'Description' : description}
        # Resolution of y
        description = ('Resolution of y dimension as calculated' +
                       'by MRIQC for the ' +
                       str(ses_count) +
                       ' session of the ' +
                       str(sequence) +
                       ' sequence ')
        json_info[name_res_y] = {'Description' : description}
        # Resolution of z
        description = ('Resolution of z dimension as calculated' +
                       'by MRIQC for the ' +
                       str(ses_count) +
                       ' session of the ' +
                       str(sequence) +
                       ' sequence ')
        json_info[name_res_z] = {'Description' : description}

        # change file permissions to read:
        permissions = os.stat(json_dir).st_mode
        os.chmod(path=json_dir, mode=permissions | stat.S_IWUSR)
        # save updated fieldmap json-file:
        with open(json_dir, 'w') as out_file:
            json.dump(json_info, out_file, indent=2, sort_keys=True)
        out_file.close()
        # change file permissions back to read-only:
        os.chmod(path=json_dir, mode=permissions)

# Save participants.tsv
participants.to_csv(participants_dir, sep='\t', index=False)

# Preprocessing pipeline

## Preperation

### 01. **Create sub_list**

- ```.../code/preprocessing/sourcedata/create_sublist.py```
- Creates ```sub_list.txt``` file with all participants in the raw_data folder
- Creates ```id_link.json``` file linking all scanner IDs to BIDS-IDs in the raw_data folder
- Used by following scripts to know participant IDs

### 02. **Change folder structure**

- ```.../code/preprocessing/sourcedata/change_folderstructure.py```
- Adds additional level of directories to ```EPI```, ```Resting_State```,
and ```T1```/```T2```
- This makes sure that all ```.ima``` files are two folder levels deep
(e.g. ```.../TOPUP/Sequence_1/*.ima``` & ```.../EPI/EPI/*.ima```)
- The template which the Heudiconv BIDS conversion is based on requires
all ```*.ima``` files to be the same amount of folder levels after the
participant folder. This script makes sure this is true.
The ```EPI```, ```Resting_State```, ```T1```, and ```T2``` are only one folder
level down before this script runs

### 03. **Copy behavioral files to own folder**

- ```.../code/preprocessing/sourcedata/move_beh.py```
- Moves the logfiles showing the movement during the experiment from  ```sourcedata/mri/*/LOG``` to the ```sourcedata/beh``` directory
- Afterwards deletes the ```LOG``` directory to avoid confusion

---

## Convert raw data to BIDS

### 03. **heudiconv**

- ```.../code/preprocessing/heudiconv/heudiconv_tardis.sh```
- Converts all raw_data ```.ima``` files into bids conform ```nii.gz```files and
saves them to ```.../bids```
- Uses the ```anonymizer.py``` which translates the scanner ID to the new
BIDS-ID of the subject based on the ```.../sourcedata/id_link.json```
- Uses the ```heuristic.py``` to translate sequence names saved by the scanner
to new BIDS conform sequence names

### 04. **Find problem cases**

- ```.../code/preprocessing/heudiconv/find_problem_cases.py```
- Creates a list of participants that encountered problems during heudiconv
conversion to ```.../derivatives/preprocessing/heudiconv/problem_cases.txt```
- This list is used to run a separate conversion process for the problematic
participants

### 05. **Convert problem cases**

- ```.../code/preprocessing/heudiconv/convert_problem_cases_tardis.sh```
- Some participants can't be converted with heudiconv (header problems?) so
by running this script they are converted and the converted files renamed so
they are bids conform and in the right directory

### 06. **Refine problem cases**

- ```.../code/preprocessing/heudiconv/refine_problem_cases.py```
- When converting the problem cases by hand there is some information missing
which would otherwise be provided. This script adds missing files and
information for the problem participants
- Missing information includes:
     - Missing EchoTime1 and EchoTime2 in the
     e.g. ```.../bids/sub-younger001/ses-1/fmap/sub-younger001_ses-1_phasediff.json``` which
     can be replaced using the ```magnitude1.json``` EchoTime as EchoTime1 and
     the ```phasediff.json``` EchoTime as EchoTime2 (see [here](https://neuroimaging-core-docs.readthedocs.io/en/latest/pages/bids-validator.html)
     under 'Phasediff images')
     - Missing e.g. ```.../bids/sub-younger001/ses-1/func/sub-younger001_ses-1_task-rest_events.tsv``` which
     is replaced with an template identical to the other participants

### 07. **Add information to general BIDS files**

- ```.../code/preprocessing/heudiconv/add_general_information.py```
- Adds the full task names ('Arena_task' & 'Resting_state') to the respective
info files at ```.../bids/task-nav_bold.json```
and ```.../bids/task-rest_bold.json```
- Replaces the resting_state event file
(e.g. ```.../bids/sub-younger001/ses-1/sub-younger001_ses-1_task-rest_events.tsv```)
with an empty template identical for each participant and sessions since there
are no events during a resting state scan

### 08. **Create ```.bidsignore``` file**

- ```.../code/preprocessing/heudiconv/add_bidsignore.py```
- creates a ```.bidsignore``` file at the root of the bids directory which can
be filled with paths to files that should be ignored by the bids specification
- Some of the files we have to share have a format unfit for the ```.tsv``` file
format, i.e.:
     - Behavioral logfiles (e.g. ```.../bids/sub-older051/ses-1/beh/sub-older051_ses-1_task-nav_beh.tsv```)

---

## Deface imaging data

### 08. **pydeface:** Deface participants anatomical

- ```.../code/preprocessing/deface/deface_pydeface_tardis.sh```
- Defaces all anatomical images so faces cannot be reconstructed
- Leaves the defaced as well as the "faced" file

### 09. **pydeface:** Clean-up

- ```.../code/preprocessing/deface/deface_pydeface_cleanup_tardis.sh```
- will delete the "faced" file and replace it with the defaced file
- Renames the defaced file to the standard file

---

## Data quality assessment via **MRIQC**

### 10. **MRIQC:** participant level

- ```.../code/preprocessing/mriqc/mriqc_sub_level.sh```
- Creates MRIQC reports for each participant and saves them
into ```.../derivatives/preprocessing/mriqc```
- Files include a bunch of ```.html``` files and graphs

### 11. **MRIQC:** group level

- ```.../code/preprocessing/mriqc/mriqc_group_level.sh```
- Creates the MRIQC group report based on the participant reports and saves
it into ```.../derivatives/preprocessing/mriqc```

### 12. **MRIQC:** transform MRIQC data to ```.tsv```-file

- ```.../code/preprocessing/mriqc/mriqc_to_tsv.py```
- Extracts data points on specific MRIQC measures of the bold data for each
participant and saves them as a data table
to ```.../derivatives/preprocessing/mriqc/mriqc_bold.tsv```

### 13. **MRIQC:** copy group reports to documentation

- ```.../code/preprocessing/mriqc/mriqc_to_docs.py```
- Copies ```.html``` group reports to the documentation to be rendered on the
gitlab pages website for easy access

---

## Adjust ```participants.tsv```

### 14. **Add group and ID information to participants.tsv**

- ```.../code/preprocessing/participants/add_group_and_old_id.py```
- Enters group information (older/younger) and the pre-heudiconv ID to
the ```participants.tsv``` file in the bids directory
- Adds description of new colunns (group/pre-heudiconv ID)
to ```participants.json``` in bids directory

### 15. **Add experiments info to participants.tsv**

- ```.../code/preprocessing/participants/add_experiment_info.py```
- Enters additional information to ```participants.tsv``` file in the bids directory including:
    - Intervention (blinded code and unblinded)
    - Dosage (mg per kg bodyweight)
    - Comments during collection
    - Number of timeouts during feedback trials
- Adds description of new colunns to ```participants.json``` in bids directory

### 16. **Add scanner operator information to participants.tsv**

- ```.../code/preprocessing/participants/add_pulse_info.py```
- Enters additional information to ```participants.tsv``` file in the bids directory including:
     - Which scanner pulse log in the behavioral file was the first recorded TR
     - Comments of scanner operators


### 17. **Add MRIQC information to participants.tsv**

- ```.../code/preprocessing/participants/add_mriqc_to_participants.py```
- Enters MRIQC information to ```participants.tsv``` file in the
bids directory
- Adds description of new colunns to ```participants.json``` in bids
directory

### 18. **Add behavior to participants.tsv**

- ```.../code/preprocessing/participants/add_behavior.py```
- Takes behavioral information of feedback phase and adds it to ```participants.tsv```

---

## Preprocessing using **fMRIprep**

### 19. **fMRIprep:** Add fieldmap ```.json```-field

- ```.../code/preprocessing/fmriprep/change_topup_json.py```
- For distortion correction the ```.json```-file of the AP and PA fieldmaps
needs to have a "IntendedFor"-field which is added by this script
- The "IntendedFor"-field says that these files are used for distortion
correction
- Input to script: Path to bids directory (e.g. ```python3 change_topup_json.py ~/damson/bids```)

### 20. **fMRIprep:** Run fMRIprep

- ```.../code/preprocessing/fmriprep/fmriprep_tardis.sh```
- Pre-processes all participants according to fMRIprep pipeline
- Should not be run for all participants at the same time (tardis workload)

### 21. **Get all available segmentations in the bold modality**

- ```.../code/preprocessing/fmriprep/AvailableBoldSegmentation.py```
- Will produce a ```.tsv```-file giving all available segmentation indices
for each participant, session, and task at ```.../derivatives/preprocessing/fmriprep/available_seg.tsv```
- Not all segmentations mentioned in the full segmentation file
at ```.../derivatives/preprocessing/fmriprep/desc-aparcaseg_dseg.tsv```
and ```.../derivatives/preprocessing/fmriprep/desc-aseg_dseg.tsv``` are present
in the individual segmentation maps at
e.g. ```.../derivatives/preprocessing/fmriprep/sub-younger001/ses-1/func/sub-younger001_ses-1_task-nav_space-T1w_desc-aparcaseg_dseg.nii.gz```
- The table will help to use only ROIs present in the bold segmentation

---

## Add and process behavioral logfile data

### 22. **Add logfiles to participants BIDS directory**

- ```.../code/preprocessing/sourcedata/beh_to_bids.py```
- Will extract behavioral task-log files for each participant
from  ```.../sourcedata/beh``` and save them to
e.g. ```.../bids/sub-younger001/ses-1/beh/sub-younger001_ses-1_task-nav_beh.tsv``` for
every subject and session

### 23. **Mark participants with fluctuations in pulse logging**

- ```.../code/preprocessing/logfile/tardis_MarkPulseFluctuations.sh```
- During scanning of some participants the loggings of the scanner pulses was unaligned with the TR timings for some TRs
- This script marks these participants so they can be fixed in the next step
- Will add pulse fluctuation information to ```participants.tsv```

### 24. **Get adjustment for scanner drift**

- ```.../code/preprocessing/logfile/GetDriftAdjustment.R```
- Calculates the small drift the Unreal Engine internal clock shows in comparison to the scanner internal clock (causing scanning time stamps and movement log timestamps to drift apart)
- Creates ```.../derivatives/preprocessing/logfile/drift_adjustment.tsv```
- Created file is referenced by event files to adjust for clock drifts
- If pulse loggings of a participant were fluctuating, drift adjustment will be ```NA``` and the mean over all drift adjustments will be used for this participant in the next step

### 25. **Create logfile template**

- ```.../code/preprocessing/logfile/tardis_CreateRawEventfile_submit.sh```
- Takes the raw logfile and extracts basic information for each time stamp
including:
     - Position
     - Walking speed
     - Current TR
     - Viewing angle (as continuous value or bin)
     - Walking angle (as continuous value or bin)
     - Turning speed
     - Turning direction
- Also includes logical values marking periods of:
     - Walking (forward, backward, or both)
     - Turning (left and right)
- Results are saved as a ```.tsv``` file to
e.g. ```.../derivatives/preprocessing/logfile/sub-younger001/ses-1/sub-older051_ses-1_task-nav_events-raw.tsv``` for
each subject and session
- File is used to create BIDS conform event files and event files used in
decoding
- Calls the script ```.../code/preprocessing/logfile/CreateRawEventfile.R```
with the following options:
     - ```--sub_id=SUB_ID```: ID of participant to create Bids eventfile for
     - ```--ses_id=SES_ID```: Session ID to create Bids eventfile for
     (e.g. "ses-1")
     - ```--tr_tolerance=TR_TOLERANCE```: time in seconds added to tr if there
     is no immediate consecutive TR, will include additional logs to the last
     TR before pause (Default: ```0.1```)
     - ```--max_angle_diff_for_fwd=MAX_DIFFERENCE_ALLOWED```: Largest
     difference allowed between location-derived walking angle and YAW-derived
     walking angle (in degrees) while still counted as forward walking
     (Default: ```20```)
     - ```--min_angle_diff_for_bwd=MIN_DIFFERENCE_REQUIRED```: Minimum
     difference between location-derived walking angle and YAW-derived walking
     angle (in degrees) required to flag backwards walking (Default: ```160```)
     - ```--min_turn_speed_per_s=MIN_TURN_SPEED```: Minimum of turn speed
     required to flag turning (in degrees per second) (Default: ```5```)
     - ```--n_dir_bins=NUMBER_OF_BINS```: Number of directional bins (required
     to be even) (Default: ```6```)
     - ```--binshift=BINSHIFT```: Rotation of bin-boundaries in degrees (e.g.
     binshift = 30 -> bin1 [30,90] instead of [0,60]) (Default: ```0```)


### 26. **Incorporate scanner operator information into event files**

- ```.../code/preprocessing/logfile/CorrectPulseFluctuations.R```
- Will (if possible) realign TR pulses with behavioral time stamps by using the regular TR
- For participants in which the first scanner pulse log differs from the actual first TR the TR timings are adjusted
- Makes changes to ```.../derivatives/preprocessing_logfile/*/*/*_task-nav_events-raw.tsv```


### 27. **Create BIDS conform event file**

- ```.../code/preprocessing/logfile/tardis_CreateBIDSEventfile_submit.sh```
- Will create a BIDS conform event file for the ```task-nav_bold.nii.gz``` image
files and saves it to e.g. ```.../bids/sub-younger001/ses-1/func/sub-younger001_ses-1_task-nav_events.tsv``` along
with a ```.json``` file describing the different events
- Provides onset and duration for the following event types:
     - Standing
     - Walking
     - Walking_fwd
     - Walking_fwd for each direction bin
     - Walking_bwd
     - Walking_bwd for each direction bin
     - Turning
     - Tuning_left
     - Turning_right
     - Trial (additional information provided: Trial number)
     - Cue (additional information provided: Object, correct location)
     - Object Drop (additional information provided: Object, Drop location, correct location)
     - Object Grab (additional information provided: Object)
     - Inter trial interval (ITI)
     - Trial time outs
     - Current phase
     - Current environment
     - Landmark (additional information provided: Landmark position)
     - TR (additional information provided: TR number)
- If desired, also produces a time table of all events to
e.g. ```.../derivatives/preprocessing/logfile/sub-younger001/ses-1/sub-younger001_ses-1_event_timetable.pdf```
- Calls the script ```.../code/preprocessing/logfile/CreateBidsEventfile.R```
with the following options:
     - ```--sub_id=SUB_ID```: ID of participant to create Bids eventfile for
     - ```--ses_id=SES_ID```: Session ID to create Bids eventfile for (e.g.
     "ses-1")
     - ```--max_t_between_events=MAX_T_BETWEEN_EVENTS```: Maximum time allowed
     between events of the same type to still be counted as one event
     (Default: ```0.19```)
     - ```--min_event_duration=MIN_EVENT_DURATION```: Minimum time an event is
     allowed to last (exception: button presses) (Default: ```0```)
     - ```--n_dir_bins=N_DIR_BINS```: Total number of direction bins
     (Default: ```6```)
     - ```--save_timetable=SAVE_TIMETABLE```: Saving a time table plot of
     eventfile (Default: ```FALSE```)

### 28. **Add BIDS conform logfile to ```.bidsignore```**

- ```.../code/preprocessing/logfile/add_logfiles_to_bidsignore.py```
- Because of the special type of logging the output of the experiment the format
of the behavioral file is unfit for the ```.tsv``` format but should also be
shared

### 29. **Create serial "standard" eventfiles for decoding**

- ```.../code/preprocessing/logfile/tardis_CreateStandardEventfile_submit.sh```
- Will create a number of eventfiles incuding all serial time stamps of all
events of a certain event type along with the information given in
e.g. ```.../derivatives/preprocessing/logfile/sub-younger001/ses-1/sub-older051_ses-1_task-nav_events-raw.tsv```. These
event types include:
     - Standing (e.g. ```.../derivatives/preprocessing/logfile/sub-younger001/ses-1/sub-older051_ses-1_task-nav_events-standard-stand.tsv```)
     - Standing with viewing direction (e.g. ```.../derivatives/preprocessing/logfile/sub-younger001/ses-1/sub-older051_ses-1_task-nav_events-standard-stand-dir.tsv```)
     - Turning (e.g. ```.../derivatives/preprocessing/logfile/sub-younger001/ses-1/sub-older051_ses-1_task-nav_events-standard-turn.tsv```)
     - Walking forward with direction (e.g. ```.../derivatives/preprocessing/logfile/sub-younger001/ses-1/sub-older051_ses-1_task-nav_events-standard-walk-fwd.tsv```)
     - Walking backward with direction (e.g. ```.../derivatives/preprocessing/logfile/sub-younger001/ses-1/sub-older051_ses-1_task-nav_events-standard-walk-bwd.tsv```)
     - Walking (e.g. ```.../derivatives/preprocessing/logfile/sub-younger001/ses-1/sub-older051_ses-1_task-nav_events-standard-walk.tsv```)
- Calls the script ```.../code/preprocessing/logfile/CreateStandardEventfile.R```
with the following options:
     - ```--sub_id=SUB_ID```: ID of participant to create Bids eventfile for
     - ```--ses_id=SES_ID```: Session ID to create Bids eventfile for (e.g.
     "ses-1")
     - ```--max_t_between_events=MAX_T_BETWEEN_EVENTS```: Maximum time allowed
     between events of the same type to still be counted as one event
     (Default: ```0.19```)
     - ```--exclude_reposition_trs=EXCLUDE_REPOSITION_TR```: Excluding the whole
     TRs in which participant was repositioned. If TRUE, whole TR will be
     excluded (Default: ```TRUE```)
     - ```--min_event_duration=MIN_EVENT_DURATION```: Minimum time an event is
     allowed to last (exception: button presses) (Default: ```1```)
     - ```--exclude_transfer_phase=EXCLUDE_TRANSFER_PHASE```: Excluding transfer
     phase due to change of landmark and boundary. If TRUE, transfer phase will
     be excluded (Default: ```TRUE```)

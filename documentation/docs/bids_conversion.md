# BIDS conversion

BIDS conversion will be done by using
[heudiconv](https://github.com/nipy/heudiconv). DICOMs will be converted on the
TARDIS cluster using a **singlarity image**. A singularity image is a container
that encompasses all required packages and dependencies in itself. This means we
only have to download the image instead of looking for each package heudiconv
needs and download it by itself.

# How to download the singularity container

Rather simple: Use the command ```singularity pull docker://nipy/heudiconv:<version>```.

- **To pull a specific version**: Replace ```<version>``` with the version code
  code. In our case this is ```0.6.0```.
- **To get the latest version:** Write ```singularity pull docker://nipy/heudiconv:latest```
- The image will be saved to a file called ```heudiconv_0.6.0.sif``` (or in the
  second case ```heudiconv_latest.sif```)

# How to run the singularity container

What you have to do is call ```singularity run``` but with a bunch of extra
arguments. In the following you can find a list of all the arguments we need to
specify for it to run.

```bash
singularity run
-B <input directory>
-B <output directory>
-B <script directory>
<path to container>
-d <template how the dicom folder structure looks>
-s <which participant to convert>
--ses <which session to convert>
-o <where to save the output to>
-f <path to heuristic file>
--anon-cmd <path to anonymizer script>
-c <which converter to use>
-b (option to put output into BIDS structure)
--overwrite (allows overwriting existing files)
```

## Detailed information on arguments

**```-B <input directory> / <output directory> / <script directory>```**

- Example: ```/home/mpib/koch/damson/raw_data/mri:/input:ro```
- ```-B```flags that you will mount a path into the container
- For a container to work, all directories it works with need to be relative to
  the container and this is achieved by mounting them "inside" the container
- **Where is the input path:** ```/home/mpib/koch//damson/raw_data/mri```
- **What should this directory be called inside the container:** ```/input```
- **What are the container's permissions for this folder:** ```ro``` (read only),
  ```rw``` (read and write)

---

**```-d <template how the dicom folder structure looks>```**

- Example: ```"{subject}_{session}/*/*/*.ima"```
- An example of how the dicoms were saved in the raw data directory:
  ```.../10100002_1/EPI/EPI/0001.11260031669112529.ima```
  - The second ```EPI``` folder had to be added with a script since otherwise
  the ```.ima``` files would have been in differently deep folder structures
  (a problem for heudiconv)
- Participant codes were saved as e.g. ```10100002_1``` where the first bunch of
  numbers gave the participant code and the number after the underscore gave the
  session (1 or 2)
  - Detailed information on participant codes: $\overbrace{10}^{Group}\underbrace{10}_{Sex}\overbrace{0002}^{ID}$
  - **Group:** 10 = Younger adults, 20 = Older adults
  - **Sex:** 10 = Female, 20 = Male
- Adding the substitute ```{subject}``` and ```{session}``` to the template lets
  heudiconv know which subject and which session the ```.ima```files belong to
  (so when they are converted they will be saved as converted files for that
  subject and that session).
- The ```*``` are wildcards for any strings, translating to: *"Find all
  ```.ima``` files two folders down after the participant string"*

---

**```-s <which participant to convert>```**

- Example: ```10100002```
- This will substitute the ```{subject}``` in the dicom folder template

---

**```--ses <which session to convert>```**

- Example: ```1```
- This will substitute the ```{session}``` in the dicom folder template

---

**```-o <where to save the output to>```**

- Save to the mounted output folder ```/output```

---

**```-f <path to heuristic file>```**

- This path specifies the location of the ```heuristic.py``` file which gives
the rule of how different sequences should be named after the conversion
- This file looks into fields of the dicom info and you can name identifiers
which mark a specific sequence
  - Example: If it is a fieldmap at says ```fmap``` in the sequence identifier
  field

---

**```--anon-cmd <path to anonymizer script>```**

- Specifies location of ```anonymizer.py``` which takes the participant ID and
turns it into a new BIDS ID
- This is how the participants will be identified after the conversion
- Example: In = ```10100002```, out = ```sub-001```

---

**```-c <which converter to use>```**

- Example: ```dcm2niix```
- Specifies converter to use
- In case of a so called **"drypass"** you put a ```none``` here
  - A drypass is a converter run which does not convert BUT it gives you e.g.
  the dicom info files so you can check which fields could be used in the
  heuristic file to identify specific sequences

---

**```-b```**

- Tells converter to convert into BIDS standard

---

**```--overwrite```**

- Enables to overwrite previous converts in case you run heudiconv again

---

## Example for heudiconv command on cluster

```bash
singularity run -B ${PATH_INPUT}:/input:ro \
-B ${PATH_OUTPUT}:/output:rw -B ${PATH_CODE}/heudiconv:/code:ro \
${PATH_CONTAINER} -d /input/${DICOM_DIR_TEMPLATE} -s ${SUB} \
--ses ${SES} -o /output -f /code/${H_FILE} \
--anon-cmd /code/${ANON_FILE} -c dcm2niix -b --overwrite
```

- All ```${}``` components are variables specified in the script, see above
for examples
- ```\``` indicates a new line of the same command and is otherwise meaningless

# Folder structure before conversion

```
├── mri
│   ├── 034_MRI_sequences.pdf
│   ├── 10100002_1
│   │   ├── EPI
│   │   │   └── EPI
│   │   │       ├── 0001.11260031669112529.ima
│   │   │       └── ...
│   │   ├── Fieldmap
│   │   │   ├── Magnitude
│   │   │   │   ├── 0001.11252890608311897.ima
│   │   │   │   └── ...
│   │   │   └── Phase
│   │   │       ├── 0001.11253125288212201.ima
│   │   │       └── ...
│   │   ├── LOG
│   │   │   └── 034_10100002_2_NAV_170804_1121.log
│   │   ├── Resting_State
│   │   │   └── Resting_State
│   │   │       ├── 0001.09560932686442471.ima
│   │   │       └── ...
│   │   ├── T1
│   │   │   └── T1
│   │   │       ├── 0001.09541995061540537.ima
│   │   │       └── ...
│   │   └── TOPUP
│   │       ├── Sequence_1
│   │       │   ├── 0001.1008317848145024.ima
│   │       │   └── ...
│   │       └── Sequence_2
│   │           ├── 0001.10090844782445685.ima
│   │           └── ...
│   ├── 10100002_2
│   │   ├── ...
│   ├── ...
├── ...
```

# Folder structure after conversion (BIDS)

```
├── CHANGES
├── dataset_description.json
├── participants.json
├── participants.tsv
├── README
├── sub-younger001
│   ├── ses-1
│   │   ├── anat
│   │   │   ├── sub-younger001_ses-1_T1w_defaced.nii.gz
│   │   │   ├── sub-younger001_ses-1_T1w.json
│   │   │   └── sub-younger001_ses-1_T1w.nii.gz
│   │   ├── fmap
│   │   │   ├── sub-younger001_ses-1_dir-AP_epi.json
│   │   │   ├── sub-younger001_ses-1_dir-AP_epi.nii.gz
│   │   │   ├── sub-younger001_ses-1_dir-PA_epi.json
│   │   │   ├── sub-younger001_ses-1_dir-PA_epi.nii.gz
│   │   │   ├── sub-younger001_ses-1_magnitude1.json
│   │   │   ├── sub-younger001_ses-1_magnitude1.nii.gz
│   │   │   ├── sub-younger001_ses-1_magnitude2.json
│   │   │   ├── sub-younger001_ses-1_magnitude2.nii.gz
│   │   │   ├── sub-younger001_ses-1_phasediff.json
│   │   │   └── sub-younger001_ses-1_phasediff.nii.gz
│   │   ├── func
│   │   │   ├── sub-younger001_ses-1_task-nav_bold.json
│   │   │   ├── sub-younger001_ses-1_task-nav_bold.nii.gz
│   │   │   ├── sub-younger001_ses-1_task-nav_events.tsv
│   │   │   ├── sub-younger001_ses-1_task-rest_bold.json
│   │   │   ├── sub-younger001_ses-1_task-rest_bold.nii.gz
│   │   │   └── sub-younger001_ses-1_task-rest_events.tsv
│   │   ├── sub-younger001_ses-1_scans.json
│   │   └── sub-younger001_ses-1_scans.tsv
│   └── ses-2
│       ├── anat
│       │   ├── sub-younger001_ses-2_T2w_defaced.nii.gz
│       │   ├── sub-younger001_ses-2_T2w.json
│       │   └── sub-younger001_ses-2_T2w.nii.gz
│       ├── fmap
│       │   ├── sub-younger001_ses-2_dir-AP_epi.json
│       │   ├── sub-younger001_ses-2_dir-AP_epi.nii.gz
│       │   ├── sub-younger001_ses-2_dir-PA_epi.json
│       │   ├── sub-younger001_ses-2_dir-PA_epi.nii.gz
│       │   ├── sub-younger001_ses-2_magnitude1.json
│       │   ├── sub-younger001_ses-2_magnitude1.nii.gz
│       │   ├── sub-younger001_ses-2_magnitude2.json
│       │   ├── sub-younger001_ses-2_magnitude2.nii.gz
│       │   ├── sub-younger001_ses-2_phasediff.json
│       │   └── sub-younger001_ses-2_phasediff.nii.gz
│       ├── func
│       │   ├── sub-younger001_ses-2_task-nav_bold.json
│       │   ├── sub-younger001_ses-2_task-nav_bold.nii.gz
│       │   ├── sub-younger001_ses-2_task-nav_events.tsv
│       │   ├── sub-younger001_ses-2_task-rest_bold.json
│       │   ├── sub-younger001_ses-2_task-rest_bold.nii.gz
│       │   └── sub-younger001_ses-2_task-rest_events.tsv
│       ├── sub-younger001_ses-2_scans.json
│       └── sub-younger001_ses-2_scans.tsv
├── sub-younger002
│   ├── ...
├── ...
```

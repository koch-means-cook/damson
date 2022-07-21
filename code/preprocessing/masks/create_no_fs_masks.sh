#!/usr/bin/bash

# ===
# Define paths
# ===
# define home directory
PATH_BASE="/home/mpib/${USER}"
# define the name of the project:
PROJECT_NAME="damson"
# Define path to repository
PATH_REP="${PATH_BASE}/${PROJECT_NAME}"
PATH_BIDS="${PATH_REP}/bids"
# Define path to script to run
PATH_CODE="${PATH_REP}/code/decoding/train-beta_test-beta"
# path to the log directory:
PATH_LOG="${PATH_BASE}/${PROJECT_NAME}/logs/decoding/train-beta_test-beta/$(date '+%Y%m%d_%H%M')"
# Path to return to once job is submitted
PATH_RETURN=$(pwd)
# Path to MNINLin reference image for transform
PATH_MNI=""
# Path to mask to create in T1w space (put in loop if multiple)
PATH_MASK="mask-rsc_space-MNI152NLin.nii.gz"

# ===
# Create directories
# ===

# create directory for log files:
if [ ! -d ${PATH_LOG} ]; then
	mkdir -p ${PATH_LOG}
fi

# ===
# Define decoding parameters
# ===
BASE_PATH=${PATH_REP}
MASK_SEG="aparcaseg"
MASK_LIST=("1011 2011" "17 53" "1006 2006" "1024 2024")
# "1011 2011": Bilateral lateral occipital
# "17 53": Bilateral HC
# "1006 2006": Bilateral Entorhinal
# "1024 2024": Bilateral Praecentral
EVENT_FILE="walk-fwd"
CLASSIFIER="logreg"
# CLASSIFIER="logreg"
SMOOTHING_FWHM=3
PULL_EXTREMES="True"
EXT_STD_THRES=8
STANDARDIZE="zscore"
N_BINS=6
X_VAL_SPLIT="fold"



# ===
# Define job parameters for cluster
# ===
# maximum number of cpus per process:
N_CPUS=2
# maximum number of threads per process:
N_THREADS=2
# memory demand in *GB*
MEM_GB=6
# memory demand in *MB*
MEM_MB="$((${MEM_GB} * 1000))"
# user-defined subject list
PARTICIPANTS=$1
# Get participants to work on
cd ${PATH_BIDS}
SUB_LIST=sub-*
# Only overwrite sub_list with provided input if not empty
if [ ! -z "${PARTICIPANTS}" ]; then
  echo "Specific participant ID supplied"
  # Overwrite sub_list with supplied participant
  SUB_LIST=${PARTICIPANTS}
fi

# ===
# Run fMRIprep
# ===
# loop over all subjects:
for SUB in ${SUB_LIST}; do

  PATH_OUT="${PATH_BASE}/damson/derivatives/preprocessing/masks/${SUB}"
  # create output directory:
  if [ ! -d ${PATH_OUT} ]; then
  	mkdir -p ${PATH_OUT}
  fi

	# Get job name
	JOB_NAME="create_no_fs_masks_${SUB}"
	# Create job file
	echo "#!/bin/bash" > job.slurm
	# name of the job
	echo "#SBATCH --job-name ${JOB_NAME}" >> job.slurm
	# set the expected maximum running time for the job:
	echo "#SBATCH --time 2:00:00" >> job.slurm
	# determine how much RAM your operation needs:
	echo "#SBATCH --mem ${MEM_GB}GB" >> job.slurm
	# determine number of CPUs
	echo "#SBATCH --cpus ${N_CPUS}" >> job.slurm
	# write to log folder
	echo "#SBATCH --output ${PATH_LOG}/slurm-${JOB_NAME}.%j.out" >> job.slurm

	# Load virtual env
	echo "source /etc/bash_completion.d/virtualenvwrapper" >> job.slurm
	echo "workon damson" >> job.slurm

  # Command to create RSC mask
	echo "antsApplyTransforms \
  -i ${PATH_MASK} \
  -t ${PATH_BASE}/damson/derivatives/preprocessing/fmriprep/${SUB}/anat/${SUB}_from-MNI152Lin_to-T1w_mode-image_xfm.h5 \
  -r ${PATH_MNI} \
  -o ${PATH_OUT}/${SUB}_space-T1w_mask-rsc.nii.gz" >> job.slurm

	# submit job to cluster queue and remove it to avoid confusion:
	sbatch job.slurm
	rm -f job.slurm

done

# Return to path when script was started
cd ${PATH_RETURN}

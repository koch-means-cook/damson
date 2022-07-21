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
PATH_CODE="${PATH_REP}/code/decoding/train-raw_test-raw"
# path to the log directory:
PATH_LOG="${PATH_BASE}/${PROJECT_NAME}/logs/decoding/train-raw_test-raw/$(date '+%Y%m%d_%H%M')"
# Path to return to once job is submitted
PATH_RETURN=$(pwd)

# ===
# Create directories
# ===
# create output directory:
if [ ! -d ${PATH_OUT} ]; then
	mkdir -p ${PATH_OUT}
fi
# create directory for log files:
if [ ! -d ${PATH_LOG} ]; then
	mkdir -p ${PATH_LOG}
fi

# ===
# Define decoding parameters
# ===
BASE_PATH=${PATH_REP}
MASK_SEG="aparcaseg"
MASK_LIST=("1005 2005 1011 2011 1021 2021" "1010 2010" "17 53" "1006 2006" "1024" "17 53 1006 2006 1016 2016")
# "1005 2005 1011 2011 1021 2021": Bilat Cuneus. Bilateral lateral occipital, bilateral pericalcarine
# "1010 2010": Bilateral isthmus of cingulate (rough RSC)
# "17 53": Bilateral HC
# "1006 2006": Bilateral Entorhinal
# "1024 2024": Bilateral Praecentral
# "17 53 1006 2006 1016 2016": Bilateral MTL (enorhinal + HC + paraHC)
EVENT_FILE="walk-fwd"
CLASSIFIER="logreg"
SMOOTHING_FWHM=3
ESSENTIAL_CONFOUNDS="True"
DETREND="True"
HIGH_PASS=0.0078125 #1/128
PULL_EXTREMES="False"
EXT_STD_THRES=8
STANDARDIZE="zscore"
N_BINS=6
BALANCING_OPTION="upsample"
BALANCE_STRATEGY="longest"
N_FOLDS_WITHIN=3



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

	# Get job name
	JOB_NAME="raw_decoding_within_${SUB}"
	# Create job file
	echo "#!/bin/bash" > job.slurm
	# name of the job
	echo "#SBATCH --job-name ${JOB_NAME}" >> job.slurm
	# set the expected maximum running time for the job:
	echo "#SBATCH --time 12:00:00" >> job.slurm
	# determine how much RAM your operation needs:
	echo "#SBATCH --mem ${MEM_GB}GB" >> job.slurm
	# determine number of CPUs
	echo "#SBATCH --cpus-per-task ${N_CPUS}" >> job.slurm
	# write to log folder
	echo "#SBATCH --output ${PATH_LOG}/slurm-${JOB_NAME}.%j.out" >> job.slurm

	# Load virtual env
	echo "source /etc/bash_completion.d/virtualenvwrapper" >> job.slurm
	echo "workon damson" >> job.slurm

	# Loop over given mask combinations
	for ((i = 0; i < ${#MASK_LIST[@]}; i++)); do

		# Within session x-val, unbuffered
		echo "python3 ${PATH_CODE}/classifier.py \
		--base_path ${PATH_REP} \
		--sub_id ${SUB} \
		--mask_seg ${MASK_SEG} \
		--mask_index ${MASK_LIST[$i]} \
		--event_file ${EVENT_FILE} \
		--classifier ${CLASSIFIER} \
		--smoothing_fwhm ${SMOOTHING_FWHM} \
		--essential_confounds ${ESSENTIAL_CONFOUNDS} \
		--detrend ${DETREND} \
		--high_pass ${HIGH_PASS} \
		--pull_extremes ${PULL_EXTREMES} \
		--ext_std_thres ${EXT_STD_THRES} \
		--standardize ${STANDARDIZE} \
		--n_bins ${N_BINS} \
		--balancing_option ${BALANCING_OPTION} \
		--balance_strategy ${BALANCE_STRATEGY} \
		--x_val_split 'sub_fold' \
		--within_session \
		--n_folds_within ${N_FOLDS_WITHIN} \
		--reorganize" >> job.slurm

	done


	# submit job to cluster queue and remove it to avoid confusion:
	sbatch job.slurm
	rm -f job.slurm

done

# Return to path when script was started
cd ${PATH_RETURN}

#!/usr/bin/bash

# ===
# Define paths
# ===
# define home directory
PATH_BASE="/home/mpib/${USER}/damson"
PATH_FUNCTION="${PATH_BASE}/code/preprocessing/logfile/CreateRawEventfile.R"
PATH_LOG="${PATH_BASE}/logs/preprocessing/logfile/CreateRawEventfile/$(date '+%Y%m%d_%H%M')"
PATH_SEQ_INFO="${PATH_BASE}/bids/task-nav_bold.json"
PATH_RETURN=$(pwd)

# ===
# Create directories
# ===
# create directory for log files:
if [ ! -d ${PATH_LOG} ]; then
	mkdir -p ${PATH_LOG}
fi

# ===
# Define job parameters for cluster
# ===
# maximum number of cpus per process:
N_CPUS=1
# memory demand in *GB*
MEM_GB=2

# ===
# Define parameters of script
# ===
TR_TOLERANCE=0.1
MAX_ANGLE_DIFF_FOR_FWD=20
MIN_ANGLE_DIFF_FOR_BWD=160
MIN_TURN_SPEED_PER_S=5
N_DIR_BINS=6
BINSHIFT=0


# ===
# Loop over subjects
# ===
cd ${PATH_BASE}/bids
SUB_LIST=sub-*
# user-defined subject list
PARTICIPANTS=$1
# Only overwrite sub_list with provided input if not empty
if [ ! -z "${PARTICIPANTS}" ]; then
  echo "Specific participant ID supplied"
  # Overwrite sub_list with supplied participant
  SUB_LIST=${PARTICIPANTS}
fi

for SUB in ${SUB_LIST}; do

	# Create job name job
	JOB_NAME="CreateRawEventfile_${SUB}"

	# Create job to submit
	echo "#!/bin/bash" > job.slurm
	# name of the job
	echo "#SBATCH --job-name ${JOB_NAME}" >> job.slurm
	# set the expected maximum running time for the job:
	echo "#SBATCH --time 1:00:00" >> job.slurm
	# determine how much RAM your operation needs:
	echo "#SBATCH --mem ${MEM_GB}GB" >> job.slurm
	# request multiple cpus
	echo "#SBATCH --cpus-per-task ${N_CPUS}" >> job.slurm
	# write (output) log to log folder
	echo "#SBATCH --output ${PATH_LOG}/slurm-${JOB_NAME}.%j.out" >> job.slurm


	# Change directory for here package (R)
	echo "cd ${PATH_BASE}/bids/${SUB}" >> job.slurm

	# Load R version
	echo "module unload R" >> job.slurm
	echo "module load R/4.0.0" >> job.slurm

	# ===
	# Loop over sessions (both sessions in one job)
	# ===
	for SES in 1 2; do

		# Get logfile to convert
		#LOG_FILE="${PATH_BASE}/bids/${SUB}/ses-${SES}/beh/${SUB}_ses-${SES}_task-nav_logfile.log"

		# Run script to convert logfile to eventfile
		echo Rscript ${PATH_FUNCTION} --sub_id ${SUB} \
		 --ses_id ses-${SES} \
		 --tr_tolerance ${TR_TOLERANCE} \
		 --max_angle_diff_for_fwd ${MAX_ANGLE_DIFF_FOR_FWD} \
		 --min_angle_diff_for_bwd ${MIN_ANGLE_DIFF_FOR_BWD} \
		 --min_turn_speed_per_s ${MIN_TURN_SPEED_PER_S} \
		 --n_dir_bins ${N_DIR_BINS} \
		 --binshift ${BINSHIFT} >> job.slurm

	 done

	 # Submit job for both sessions in one job
	 sbatch job.slurm
	 rm -f job.slurm

	 # Give message to user
	 echo "Submitted job: ${SUB}"

 done

# Return to path where job was submitted from
 cd ${PATH_RETURN}

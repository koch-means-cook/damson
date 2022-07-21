#!/usr/bin/bash

# ===
# Define paths
# ===
# define home directory
PATH_BASE="/home/mpib/${USER}/damson"
PATH_FUNCTION="${PATH_BASE}/code/preprocessing/logfile/CreateStandardEventfile.R"
PATH_LOG="${PATH_BASE}/logs/preprocessing/logfile/CreateStandardEventfile/$(date '+%Y%m%d_%H%M')"
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
N_CPUS=2
# memory demand in *GB*
MEM_GB=2

# ===
# Define parameters of script
# ===
MAX_T_BETWEEN_EVENTS=0.19
EXCLUDE_REPOSITION_TRS=TRUE
MIN_EVENT_DURATION=1
EXCLUDE_TRANSFER_PHASE=TRUE



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
	JOB_NAME="CreateStandardEventfile_${SUB}"

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

		# Run script to convert logfile to eventfile
		echo Rscript ${PATH_FUNCTION} --sub_id ${SUB} \
		 --ses_id ses-${SES} \
		 --max_t_between_events ${MAX_T_BETWEEN_EVENTS} \
		 --exclude_reposition_trs ${EXCLUDE_REPOSITION_TRS} \
		 --min_event_duration ${MIN_EVENT_DURATION} \
		 --exclude_transfer_phase ${EXCLUDE_TRANSFER_PHASE} >> job.slurm

	 done

	 # Submit job for both sessions in one job
	 sbatch job.slurm
	 rm -f job.slurm

	 # Give message to user
	 echo "Submitted job: ${SUB}"

 done

 cd ${PATH_RETURN}

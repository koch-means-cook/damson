#!/usr/bin/bash

# ===
# Define paths
# ===
# path to the base directory:
PATH_BASE="/home/mpib/${USER}"
# PATH_BASE="/mnt/beegfs/home/${USER}"
# define the name of the project:
PROJECT_NAME="damson"
# define the name of the current task:
TASK_NAME="mriqc"
# define the path to the script main directory:
PATH_CODE="${PATH_BASE}/${PROJECT_NAME}/code/preprocessing"
# set MRIQC version
MRIQC_VERSION="0.15.1"
# define the path to the singularity container:
PATH_CONTAINER="${PATH_BASE}/tools/${PROJECT_NAME}/${TASK_NAME}_${MRIQC_VERSION}.sif"
# path to the data directory (in bids format):
PATH_INPUT="${PATH_BASE}/${PROJECT_NAME}/bids"
# path to the output directory:
PATH_OUTPUT="${PATH_BASE}/${PROJECT_NAME}/derivatives/preprocessing/${TASK_NAME}"
# Path to cache where templates are stored which MRIQC needs for analysis
PATH_CACHE="$HOME/.cache"
# path to the working directory:
PATH_WORK="${PATH_BASE}/${PROJECT_NAME}/work/${TASK_NAME}"
# path to the log directory:
PATH_LOG="${PATH_BASE}/${PROJECT_NAME}/logs/preprocessing/${TASK_NAME}/$(date '+%Y%m%d_%H%M')"
# Path to return to after job submission
PATH_RETURN=$(pwd)

# set framewise displacement threshold
FD_THRES="0.3"

# ===
# Create directories
# ===
# create output directory:
if [ ! -d ${PATH_OUTPUT} ]
then
	mkdir -p ${PATH_OUTPUT}
fi
# create working directory:
if [ ! -d ${PATH_WORK} ]
then
	mkdir -p ${PATH_WORK}
fi
# create directory for log files:
if [ ! -d ${PATH_LOG} ]
then
	mkdir -p ${PATH_LOG}
else
	# remove old log files inside the log container:
	rm -r ${PATH_LOG}/*
fi

# ===
# Define job parameters for cluster
# ===
# maximum number of cpus per process:
N_CPUS=5
# memory demand in *GB*
MEM_GB=9

# read in participants to process and compare to BIDS_LIST
cd ${PATH_INPUT}
SUB_LIST=sub-*
# user-defined subject list
PARTICIPANTS=$1
# Only overwrite sub_list with provided input if not empty
if [ ! -z "${PARTICIPANTS}" ]; then
  echo "Specific participant ID supplied"
  # Overwrite sub_list with supplied participant
  SUB_LIST=${PARTICIPANTS}
fi
# declare an array with sessions you want to run:
declare -a SESSIONS=("1" "2")

# ===
# Run MRIQC
# ===
# Loop over supplied participants
for SUB in ${SUB_LIST}; do

	SUB_LABEL=${SUB:4}
	# loop over all sessions:
	for SES in ${SESSIONS[@]}; do
		# name of the job
		JOB_NAME="mriqc_sub-${SUB_LABEL}_ses-${SES}"
		# Create jobfile
		echo "#!/bin/bash" > job.slurm
		# Pas name of the job
		echo "#SBATCH --job-name ${JOB_NAME}" >> job.slurm
		# set the expected maximum running time for the job:
		echo "#SBATCH --time 24:00:00" >> job.slurm
		# determine how much RAM your operation needs:
		echo "#SBATCH --mem ${MEM_GB}GB" >> job.slurm
		# request multiple cpus:
		echo "#SBATCH --cpus-per-task ${N_CPUS}" >> job.slurm
		# write (output) log to log folder:
		echo "#SBATCH --output ${PATH_LOG}/slurm-${JOB_NAME}.%j.out" >> job.slurm

		# define the main command:
		echo "export SINGULARITYENV_TEMPLATEFLOW_HOME=/cache" >> job.slurm
		echo "singularity run \
		-B ${PATH_INPUT}:/input:ro \
		-B ${PATH_OUTPUT}:/output:rw \
		-B ${PATH_WORK}:/work:rw \
		-B ${PATH_CACHE}:/cache:rw \
		${PATH_CONTAINER} \
		/input/ \
		/output/ \
		participant \
    --participant-label ${SUB_LABEL} \
		--session-id ${SES} \
    -w /work/ \
		--verbose-reports \
		--write-graph \
		--fd_thres ${FD_THRES} \
		--n_cpus ${N_CPUS} \
		--mem_gb ${MEM_GB} \
		--no-sub" >> job.slurm
		# submit job to cluster queue and remove it to avoid confusion:
		sbatch job.slurm
		rm -f job.slurm
	done
done

# Return to path where job was submitted from
cd ${PATH_RETURN}

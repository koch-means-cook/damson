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
PATH_CODE="${PATH_REP}/code/analysis/confusion_function"
# path to the log directory:
PATH_LOG="${PATH_BASE}/${PROJECT_NAME}/logs/analysis/confusion_function/$(date '+%Y%m%d_%H%M')"
# Path to return to once job is submitted
PATH_RETURN=$(pwd)

# ===
# Create directories
# ===
# create directory for log files:
if [ ! -d ${PATH_LOG} ]; then
	mkdir -p ${PATH_LOG}
fi

# ===
# Define parameters
# ===
MODALITY="raw"
EVENTS="walk-fwd"
XVAL_SPLIT="sub_fold"
CLF="logreg"
MOD_LIST=("pred" "proba" "corr")
BUFFERING="FALSE"
REORGANIZE="TRUE"
WITHIN_SESSION="TRUE"
PLOT_FITS="TRUE"

# ===
# Define job parameters for cluster
# ===
# maximum number of cpus per process:
N_CPUS=2
# maximum number of threads per process:
N_THREADS=2
# memory demand in *GB*
MEM_GB=2
# memory demand in *MB*
MEM_MB="$((${MEM_GB} * 1000))"

# ===
# Run curve fitting
# ===
# Get job name
JOB_NAME="damson_curve_fitting"
# Create job file
echo "#!/bin/bash" > job.slurm
# name of the job
echo "#SBATCH --job-name ${JOB_NAME}" >> job.slurm
# set the expected maximum running time for the job:
echo "#SBATCH --time 2:00:00" >> job.slurm
# determine how much RAM your operation needs:
echo "#SBATCH --mem ${MEM_GB}GB" >> job.slurm
# determine number of CPUs
echo "#SBATCH --cpus-per-task ${N_CPUS}" >> job.slurm
# write to log folder
echo "#SBATCH --output ${PATH_LOG}/slurm-${JOB_NAME}.%j.out" >> job.slurm

# Load R version
echo "unload R" >> job.slurm
echo "module load R/4" >> job.slurm


# Loop over different possible outputs
for ((k = 0; k < ${#MOD_LIST[@]}; k++)); do

	# Raw
	# Within session
	echo "Rscript ${PATH_CODE}/CurveFitting.R \
	--training "raw" \
	--testing "raw" \
	--events ${EVENTS} \
	--xval_split "sub_fold" \
	--clf "logreg" \
	--mod ${MOD_LIST[$k]} \
	--buffering "FALSE" \
	--reorganize "TRUE" \
	--within_session "TRUE" \
	--plot_fits ${PLOT_FITS}" >> job.slurm

done

# Submit job
sbatch job.slurm
rm -f job.slurm

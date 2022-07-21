#!/usr/bin/bash

# ===
# Define paths
# ===
# define home directory
PATH_BASE="/home/mpib/${USER}/damson"
PATH_FUNCTION="${PATH_BASE}/code/preprocessing/logfile/PlotPath.R"
PATH_LOG="${PATH_BASE}/logs/preprocessing/logfile/PlotPath/$(date '+%Y%m%d_%H%M')"
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
MEM_GB=1

# ===
# Define parameters of script
# ===
SUB_ID=$1
#SES_ID='ses-1'
ONLY_FINAL_FRAME='FALSE'
ONLY_FEEDBACK_PHASE='TRUE'
INCLUDE_INFORMATION='FALSE'


# Create job name job
JOB_NAME="PlotPath_${SUB_ID}"

# Create job to submit
echo "#!/bin/bash" > job.slurm
# name of the job
echo "#SBATCH --job-name ${JOB_NAME}" >> job.slurm
# set the expected maximum running time for the job:
echo "#SBATCH --time 12:00:00" >> job.slurm
# determine how much RAM your operation needs:
echo "#SBATCH --mem ${MEM_GB}GB" >> job.slurm
# request multiple cpus
echo "#SBATCH --cpus-per-task ${N_CPUS}" >> job.slurm
# write (output) log to log folder
echo "#SBATCH --output ${PATH_LOG}/slurm-${JOB_NAME}.%j.out" >> job.slurm

# Load R version
echo "module unload R" >> job.slurm
echo "module load R/4.0.0" >> job.slurm

# Run script to plot trial paths
echo "Rscript ${PATH_FUNCTION} --sub_id ${SUB_ID} --ses_id 'ses-1' --only_final_frame ${ONLY_FINAL_FRAME} --only_feedback_phase ${ONLY_FEEDBACK_PHASE} --include_information ${INCLUDE_INFORMATION}" >> job.slurm
echo "Rscript ${PATH_FUNCTION} --sub_id ${SUB_ID} --ses_id 'ses-2' --only_final_frame ${ONLY_FINAL_FRAME} --only_feedback_phase ${ONLY_FEEDBACK_PHASE} --include_information ${INCLUDE_INFORMATION}" >> job.slurm

# Submit job for both sessions in one job
sbatch job.slurm
rm -f job.slurm

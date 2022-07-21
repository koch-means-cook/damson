#!/usr/bin/bash

# ===
# Define paths
# ===
# define home directory
PATH_BASE="/home/mpib/${USER}/damson"
PATH_FUNCTION="${PATH_BASE}/code/preprocessing/logfile/MarkPulseFluctuations.R"
PATH_LOG="${PATH_BASE}/logs/preprocessing/logfile/MarkPulseFluctuations/$(date '+%Y%m%d_%H%M')"
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
TR_TOLERANCE=0.1


# Create job name job
JOB_NAME="MarkPulseFluctuations"

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

# Load R version
echo "module unload R" >> job.slurm
echo "module load R/4.0.0" >> job.slurm

# Change directory for here package (R)
echo "cd ${PATH_BASE}/bids/${SUB}" >> job.slurm

# Run script to convert logfile to eventfile
echo "Rscript ${PATH_FUNCTION} --tr_tolerance ${TR_TOLERANCE}" >> job.slurm

# Submit job for both sessions in one job
sbatch job.slurm
rm -f job.slurm

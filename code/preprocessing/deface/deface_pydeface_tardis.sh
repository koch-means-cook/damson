#!/bin/bash

# ===
# Define paths
# ===
# define home directory
PATH_BASE="/home/mpib/${USER}"
# path to the container:
PATH_CONTAINER="${PATH_BASE}/tools/damson/pydeface_latest.sif"
# path to the log directory:
PATH_LOG="${PATH_BASE}/damson/logs/preprocessing/deface/$(date '+%Y%m%d_%H%M')"
# path to the data directory (in bids format):
PATH_BIDS="${PATH_BASE}/damson/bids"

# ===
# Create relevant directories
# ===
# create directory for log files:
if [ ! -d ${PATH_LOG} ]; then
	mkdir -p ${PATH_LOG}
fi

# ===
# Define  parameters
# ===
# Number of CPUs
N_CPU=1
# Memory demand
MEM_MB=4000
MEM_GB=$((${MEM_MB}/1000))

# ===
# Run Pydeface for T1 images
# ===
for FILE in ${PATH_BIDS}/*/*/anat/*T1w.nii.gz; do
	# to just get filename from a given path:
	FILE_BASENAME="$(basename -- $FILE)"
	# get the parent directory:
	FILE_PARENT="$(dirname "$FILE")"
	# Get jobname
	JOB_NAME="pydeface_${FILE_BASENAME}"
	# Create job file
	echo "#!/bin/bash" > job.slurm
	# name of the job
	echo "#SBATCH --job-name ${JOB_NAME}" >> job.slurm
	# set the expected maximum running time for the job:
	echo "#SBATCH --time 1:00:00" >> job.slurm
	# determine how much RAM your operation needs:
	echo "#SBATCH --mem ${MEM_GB}GB" >> job.slurm
	# determine number of CPUs
	echo "#SBATCH --cpus-per-task ${N_CPU}" >> job.slurm
	# write to log folder
	echo "#SBATCH --output ${PATH_LOG}/slurm-${JOB_NAME}.%j.out" >> job.slurm
	# define the main command:
	echo "singularity run -B ${FILE_PARENT}:/input:rw ${PATH_CONTAINER} pydeface /input/${FILE_BASENAME} --force" >> job.slurm
	# submit job to cluster queue and remove it to avoid confusion:
	sbatch job.slurm
	rm -f job.slurm
done


# ===
# Run Pydeface for T2 images
# ===
for FILE in ${PATH_BIDS}/*/*/anat/*T2w.nii.gz; do
	# to just get filename from a given path:
	FILE_BASENAME="$(basename -- $FILE)"
	# get the parent directory:
	FILE_PARENT="$(dirname "$FILE")"
	# Get jobname
	JOB_NAME="pydeface_${FILE_BASENAME}"
	# Create job file
	echo "#!/bin/bash" > job.slurm
	# name of the job
	echo "#SBATCH --job-name ${JOB_NAME}" >> job.slurm
	# set the expected maximum running time for the job:
	echo "#SBATCH --time 1:00:00" >> job.slurm
	# determine how much RAM your operation needs:
	echo "#SBATCH --mem ${MEM_GB}GB" >> job.slurm
	# determine number of CPUs
	echo "#SBATCH --cpus-per-task ${N_CPU}" >> job.slurm
	# write to log folder
	echo "#SBATCH --output ${PATH_LOG}/slurm-${JOB_NAME}.%j.out" >> job.slurm
	# define the main command:
	echo "singularity run -B ${FILE_PARENT}:/input:rw ${PATH_CONTAINER} pydeface /input/${FILE_BASENAME} --force" >> job.slurm
	# submit job to cluster queue and remove it to avoid confusion:
	sbatch job.slurm
	rm -f job.slurm
done

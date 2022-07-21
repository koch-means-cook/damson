#!/usr/bin/bash

# ===
# Define paths
# ===
# define home directory
PATH_BASE="/home/mpib/${USER}"
PATH_BASE_CONTAINER="/mnt/beegfs/home/${USER}"
# define the name of the project:
PROJECT_NAME="damson"
# define the name of the current task:
TASK_NAME="fmriprep"
# path to the current shell script:
PATH_SCRIPT="${PATH_BASE}/${PROJECT_NAME}/code/preprocessing"
# cd into the directory of the current script:
cd "${PATH_SCRIPT}/${TASK_NAME}"
# path to the fmriprep ressources folder:
PATH_FMRIPREP="${PATH_BASE}/tools/${PROJECT_NAME}"
PATH_FMRIPREP_CONTAINER="${PATH_BASE_CONTAINER}/tools/${PROJECT_NAME}"
# path to the fmriprep singularity image:
PATH_CONTAINER="${PATH_FMRIPREP_CONTAINER}/${TASK_NAME}_20.0.6.sif"
# path to the freesurfer license file on tardis:
PATH_FS_LICENSE="${PATH_FMRIPREP}/fs_license.txt"
# path to the data directory (in bids format):
PATH_BIDS="${PATH_BASE}/${PROJECT_NAME}/bids"
PATH_BIDS_CONTAINER="${PATH_BASE_CONTAINER}/${PROJECT_NAME}/bids"
# path to the output directory:
PATH_OUT="${PATH_BASE}/${PROJECT_NAME}/derivatives/preprocessing"
PATH_OUT_CONTAINER="${PATH_BASE_CONTAINER}/${PROJECT_NAME}/derivatives/preprocessing"
# path to the working directory:
PATH_WORK="${PATH_BASE}/${PROJECT_NAME}/work/${TASK_NAME}"
PATH_WORK_CONTAINER="${PATH_BASE_CONTAINER}/${PROJECT_NAME}/work/${TASK_NAME}"
# Path to cache where templates are stored which MRIQC needs for analysis
PATH_CACHE="$HOME/.cache"
# path to the log directory:
PATH_LOG="${PATH_BASE}/${PROJECT_NAME}/logs/preprocessing/${TASK_NAME}/$(date '+%Y%m%d_%H%M')"
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
# Define job parameters for cluster
# ===
# maximum number of cpus per process:
N_CPUS=8
# maximum number of threads per process:
N_THREADS=8
# memory demand in *GB*
MEM_GB=35
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

	# create label of participant (full ID without "sub-")
	SUB_LABEL=${SUB:4}
	echo ${SUB_LABEL}
	# create participant-specific working directory:
	PATH_WORK_SUB="${PATH_WORK}/sub-${SUB_LABEL}"
	if [ ! -d ${PATH_WORK_SUB} ]; then
		mkdir -p ${PATH_WORK_SUB}
	fi
	PATH_WORK_SUB_CONTAINER="${PATH_WORK_CONTAINER}/sub-${SUB_LABEL}"

	# Get job name
	JOB_NAME="fmriprep_sub-${SUB_LABEL}"
	# Create job file
	echo "#!/bin/bash" > job.slurm
	# name of the job
	echo "#SBATCH --job-name ${JOB_NAME}" >> job.slurm
	# set the expected maximum running time for the job:
	echo "#SBATCH --time 23:59:00" >> job.slurm
	#echo "#SBATCH --partition long" >> job.slurm
	#echo "#SBATCH --time=02-00" >> job.slurm
	# determine how much RAM your operation needs:
	echo "#SBATCH --mem ${MEM_GB}GB" >> job.slurm
	# determine number of CPUs
	echo "#SBATCH --cpus-per-task ${N_CPUS}" >> job.slurm
	# write to log folder
	echo "#SBATCH --output ${PATH_LOG}/slurm-${JOB_NAME}.%j.out" >> job.slurm

	# Make templates in cache accessible to fMRIprep
	echo "export SINGULARITYENV_TEMPLATEFLOW_HOME=/cache/templateflow" >> job.slurm

	# echo "singularity run \
	# --cleanenv \
	# --contain \
	# -B /mnt/beegfs/home/koch/damson/bids:/input:ro \
	# -B /mnt/beegfs/home/koch/damson/derivatives/preprocessing:/output:rw \
	# -B /mnt/beegfs/home/koch/tools/damson:/utilities:ro \
	# -B /mnt/beegfs/home/koch/damson/work/fmriprep/sub-older051:/work:rw \
	# /mnt/beegfs/home/koch/tools/damson/fmriprep_20.0.6.sif \
	# --fs-license-file /utilities/fs_license.txt \
	# /input/ \
	# /output/ \
	# participant --participant_label older051 \
	# -w /work/ \
	# --mem_mb 3500 \
	# --nthreads 8 \
	# --omp-nthreads 8 \
	# --write-graph --stop-on-first-crash \
	# --output-spaces T1w fsnative MNI152Lin fsaverage \
	# --no-submm-recon \
	# --notrack \
	# --verbose \
	# --resource-monitor" >> job.slurm

	# V 20.0.6.
	# echo "singularity run \
	# --contain \
	# --cleanenv \
	# -B ${PATH_BIDS_CONTAINER}:/input:ro \
	# -B ${PATH_OUT_CONTAINER}:/output:rw \
	# -B ${PATH_FMRIPREP_CONTAINER}:/utilities:ro \
	# -B ${PATH_WORK_SUB_CONTAINER}:/work:rw \
	# -B ${PATH_CACHE}:/cache:rw \
	# ${PATH_CONTAINER} \
	# --fs-license-file /utilities/fs_license.txt \
	# /input/ \
	# /output/ \
	# participant --participant_label ${SUB_LABEL} \
	# -w /work/ \
	# --mem_mb ${MEM_MB} \
	# --nthreads ${N_CPUS} \
	# --omp-nthreads ${N_THREADS} \
	# --write-graph --stop-on-first-crash \
	# --output-spaces T1w fsnative MNI152Lin fsaverage \
	# --no-submm-recon \
	# --notrack \
	# --verbose \
	# --resource-monitor" >> job.slurm

	echo "singularity run \
	--contain \
	--cleanenv \
	-B ${PATH_BIDS}:/input:ro \
	-B ${PATH_OUT}:/output:rw \
	-B ${PATH_FMRIPREP}:/utilities:ro \
	-B ${PATH_WORK_SUB}:/work:rw \
	-B ${PATH_CACHE}:/cache:rw \
	${PATH_CONTAINER} \
	--fs-license-file /utilities/fs_license.txt \
	/input/ \
	/output/ \
	participant --participant_label ${SUB_LABEL} \
	-w /work/ \
	--mem_mb ${MEM_MB} \
	--nthreads ${N_CPUS} \
	--omp-nthreads ${N_THREADS} \
	--write-graph --stop-on-first-crash \
	--output-spaces T1w fsnative MNI152Lin fsaverage \
	--no-submm-recon \
	--notrack \
	--verbose \
	--resource-monitor" >> job.slurm

	# define the fmriprep command:
	# echo "singularity run --cleanenv -B ${PATH_BIDS}:/input:ro \
	# -B ${PATH_OUT}:/output:rw -B ${PATH_FMRIPREP}:/utilities:ro \
	# -B ${PATH_WORK_SUB}:/work:rw ${PATH_CONTAINER} \
	# --fs-license-file /utilities/fs_license.txt \
	# /input/ /output/ participant --participant_label ${SUB_LABEL} \
	#  -w /work/ --mem_mb ${MEM_MB} --nthreads ${N_CPUS} \
	#  --omp-nthreads ${N_THREADS} --write-graph --stop-on-first-crash \
	# --output-space T1w fsnative fsaverage \
	# --template MNI152NLin2009cAsym \
	# --no-submm-recon \
	# --notrack --verbose --resource-monitor" >> job.slurm

  # V 1.2.2
	# echo "singularity run --cleanenv -B ${PATH_BIDS}:/input:ro \
	# -B ${PATH_OUT}:/output:rw -B ${PATH_FMRIPREP}:/utilities:ro \
	# -B ${PATH_WORK_SUB}:/work:rw ${PATH_CONTAINER} \
	# --fs-license-file /utilities/fs_license.txt \
	# /input/ /output/ participant --participant_label ${SUB_LABEL} \
	#  -w /work/ --mem_mb ${MEM_MB} --nthreads ${N_CPUS} \
	#  --omp-nthreads ${N_THREADS} --write-graph --stop-on-first-crash \
	# --output-space T1w fsnative template fsaverage \
	# --no-submm-recon \
	# --notrack --verbose --resource-monitor" >> job.slurm

	# V 1.5.8. with general Work dir and no recon all
	# echo "singularity run --cleanenv -B /home/mpib/koch/damson/bids:/input:ro \
	# -B /home/mpib/koch/damson/derivatives/preprocessing:/output:rw -B /home/mpib/koch/tools/damson:/utilities:ro \
	# -B /home/mpib/koch:/work:rw /home/mpib/koch/tools/damson/fmriprep_1.5.8.sif \
	# --fs-license-file /utilities/fs_license.txt \
	# /input/ /output/ participant --participant_label older051 \
	#  -w /work/ --mem_mb 35000 --nthreads 8 \
	#  --omp-nthreads 8 --write-graph --stop-on-first-crash \
	# --output-spaces T1w fsnative MNI152Lin fsaverage \
	# --no-submm-recon --fs-no-reconall \
	# --notrack --verbose --resource-monitor" >> job.slurm



	# submit job to cluster queue and remove it to avoid confusion:
	sbatch job.slurm
	rm -f job.slurm

done

# Return to path when script was started
cd ${PATH_RETURN}

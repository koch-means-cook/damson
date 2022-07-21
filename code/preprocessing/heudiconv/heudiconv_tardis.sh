#!/bin/sh

# ===
# Env variables
# ===
# Define Heudiconv version
HEUDICONV_VERSION="0.6.0"

# ===
# Define paths
# ===
# Repo path
PATH_BASE="/home/mpib/${USER}"
# data input directory
PATH_INPUT="${PATH_BASE}/damson/sourcedata"
# output directory for bids format data
PATH_OUTPUT="${PATH_BASE}/damson/bids"
# Working directory to not use standard /temp folder
PATH_WORK="${PATH_BASE}/damson/work/heudiconv"
# singularity containter
PATH_CONTAINER="${PATH_BASE}/tools/damson/heudiconv_${HEUDICONV_VERSION}.sif"
# scripts
PATH_CODE="${PATH_BASE}/damson/code/preprocessing"
# heuristic file
H_FILE="heuristic.py"
# Anonymizer file
ANON_FILE="anonymizer.py"
# Ensure anon file is executable
chmod +x "${PATH_CODE}/heudiconv/${ANON_FILE}"
# Save path for logfiles
PATH_LOGS="${PATH_BASE}/damson/logs/preprocessing/heudiconv/$(date '+%Y%m%d_%H%M')"
# Path to list of participants
PATH_SUBLIST="${PATH_BASE}/damson/sourcedata/sub_list.txt"

# ===
# Create directories
# ===
# Output directory
if [ ! -d ${PATH_OUTPUT} ]; then
  mkdir -p ${PATH_OUTPUT}
  echo "created ${PATH_OUTPUT}"
fi
# Log directory
if [ ! -d ${PATH_LOGS} ]; then
  mkdir -p ${PATH_LOGS}
  echo "created ${PATH_LOGS}"
fi
# Work directory
if [ ! -d ${PATH_WORK} ]; then
  mkdir -p ${PATH_WORK}
  echo "created ${PATH_WORK}"
fi

# ===
# Cluster job parameters
# ===
# Number of CPUs
N_CPU=1
# Memory demand
MEM_GB=6
MEM_MB="$((${MEM_GB}*1000))"
# Participants
SUB_LIST=$(cat ${PATH_SUBLIST} | tr '\n' ' ')
# Enable user input for single Participants
PARTICIPANTS=$1
# Only overwrite sub_list with provided input if not empty
if [ ! -z "${PARTICIPANTS}" ]; then
  echo "Specific participant ID supplied"
  # Overwrite sub_list with supplied participant
  SUB_LIST=${PARTICIPANTS}
fi


# ===
# Run Heudiconv
# ===
# Initialize participant counter
SUB_COUNT=0
# Loop over all participants
for SUB in ${SUB_LIST}; do
  # Counter
  SUB_COUNT=$((SUB_COUNT+1))
  # get the subject number with zero padding:
	SUB_PAD=$(printf "%03d\n" $SUB_COUNT)
  # loop over all sessions:
	for SES in `seq 1 2`; do
		# define the dicom template for the heudiconv command:
		DICOM_DIR_TEMPLATE="{subject}_{session}/*/*/*.ima"
    #DICOM_FILES_1="{subject}_{session}/*/*.ima"
    #DICOM_FILES_2="{subject}_{session}/*/*/*.ima"
		# check the existence of thes input files and continue if data is missing:
		if [ ! -d ${PATH_INPUT}/mri/${SUB}_${SES}* ]; then
			echo "No data input available for ${SUB} session ${SES}!"
			continue
		fi

    # Create jobname
    JOB_NAME="heudiconv_${SUB}_ses-${SES}"

    # Create jobfile for tardis
    echo "#!/bin/bash" > job.slurm
    echo "#SBATCH --job-name ${JOB_NAME}" >> job.slurm
  	# set the expected maximum running time for the job:
		echo "#SBATCH --time 12:00:00" >> job.slurm
		# determine how much RAM your operation needs:
		echo "#SBATCH --mem ${MEM_GB}GB" >> job.slurm
		# request multiple cpus
		echo "#SBATCH --cpus-per-task ${N_CPU}" >> job.slurm
		# write (output) log to log folder
		echo "#SBATCH --output ${PATH_LOGS}/slurm-${JOB_NAME}.%j.out" >> job.slurm

		# define the heudiconv command:
    #echo "singularity run -W ${PATH_WORK} -B ${PATH_INPUT}:/input:ro \
		#-B ${PATH_OUTPUT}:/output:rw -B ${PATH_CODE}/heudiconv:/code:ro \
		#${PATH_CONTAINER} -d /input/${DICOM_DIR_TEMPLATE} -s ${SUB} \
		#--ses ${SES} -o /output -f /code/${H_FILE} \
		#--anon-cmd /code/${ANON_FILE} -c dcm2niix -b --overwrite" >> job.slurm

    echo "singularity run --contain -W ${PATH_WORK} -B ${PATH_INPUT}:/input:ro \
		-B ${PATH_OUTPUT}:/output:rw -B ${PATH_CODE}/heudiconv:/code:ro \
		${PATH_CONTAINER} -d /input/mri/${DICOM_DIR_TEMPLATE} -s ${SUB} \
		--ses ${SES} -o /output -f /code/${H_FILE} \
		--anon-cmd /code/${ANON_FILE} -c dcm2niix -b --overwrite" >> job.slurm

		# submit job to cluster queue and remove it to avoid confusion:
		sbatch job.slurm
		rm -f job.slurm
  done
done

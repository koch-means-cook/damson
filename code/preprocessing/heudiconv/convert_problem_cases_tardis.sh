#!/bin/sh

# ===
# Define paths
# ===
# Repo path
PATH_BASE="/home/mpib/${USER}"
PATH_BIDS="${PATH_BASE}/damson/bids"
# data input directory
PATH_INPUT="${PATH_BASE}/damson/sourcedata/mri"
# Log file path
PATH_LOGS="${PATH_BASE}/damson/logs/preprocessing/heudiconv/$(date '+%Y%m%d_%H%M')"
PATH_PROBLEMS="${PATH_BASE}/damson/derivatives/preprocessing/heudiconv/problem_cases.txt"

# ===
# Create logfile folder
# ===
if [ ! -d ${PATH_LOGS} ]; then
  mkdir -p ${PATH_LOGS}
  echo "created ${PATH_LOGS}"
fi

# ===
# Create jobfiles for custom conversion
# ===
# Read missing participants from .txt file
PARTICIPANTS=$(cat ${PATH_PROBLEMS} | tr '\n' ' ')
# Loop over missing participants including session
for SUB in ${PARTICIPANTS}; do
  # Get ID without session
  RAW_ID=${SUB:0:8}
  # Get BIDS sub-id with anonymizer script
  BIDS_ID=$(python3 anonymizer_problem_cases.py ${RAW_ID} 2>&1)
  # Get session based on ID ending
  SES=${SUB:(-1)}
  # Create specific main path
  PATH_MAIN="${PATH_BIDS}/sub-${BIDS_ID}/ses-${SES}"
  # Make all directories if they don't exist already
  # main
  if [ ! -d "${PATH_MAIN}" ]; then
    mkdir -p "${PATH_MAIN}"
    echo "created ${PATH_MAIN}"
  fi
  # anat
  if [ ! -d "${PATH_MAIN}/anat" ]; then
    mkdir -p "${PATH_MAIN}/anat"
    echo "created ${PATH_MAIN}/anat"
  fi
  # func
  if [ ! -d "${PATH_MAIN}/func" ]; then
    mkdir -p "${PATH_MAIN}/func"
    echo "created ${PATH_MAIN}/func"
  fi
  # fmap
  if [ ! -d "${PATH_MAIN}/fmap" ]; then
    mkdir -p "${PATH_MAIN}/fmap"
    echo "created ${PATH_MAIN}/fmap"
  fi

  # Job specifications
  # Set job name
  JOB_NAME="heudiconv_problem_sub-${RAW_ID}_ses-${SES}"
  # Memory
  MEM_GB=6
  # number of CPUs
  N_CPU=1


  # create job file
  echo "#!/bin/bash" > job.slurm
  # Name job
  echo "#SBATCH --job-name ${JOB_NAME}" >> job.slurm
  # set the expected maximum running time for the job:
  echo "#SBATCH --time 12:00:00" >> job.slurm
  # determine how much RAM your operation needs:
  echo "#SBATCH --mem ${MEM_GB}GB" >> job.slurm
  # request multiple cpus
  echo "#SBATCH --cpus-per-task ${N_CPU}" >> job.slurm
  # write (output) log to log folder
  echo "#SBATCH --output ${PATH_LOGS}/slurm-${JOB_NAME}.%j.out" >> job.slurm

  # ===
  # Convert problem files if they not already exist
  # ===
  # All possible files to convert
  ANAT="sub-${BIDS_ID}_ses-${SES}_T${SES}w"
  NAV="sub-${BIDS_ID}_ses-${SES}_task-nav"
  REST="sub-${BIDS_ID}_ses-${SES}_task-rest"
  AP="sub-${BIDS_ID}_ses-${SES}_dir-AP_epi"
  PA="sub-${BIDS_ID}_ses-${SES}_dir-PA_epi"
  MAG="sub-${BIDS_ID}_ses-${SES}_magnitude"
  PHASE="sub-${BIDS_ID}_ses-${SES}_phasediff"
  # Convert ANAT
  if [ ! -f "${PATH_MAIN}/anat/${ANAT}" ]; then
    echo "dcm2niix -z y -o ${PATH_MAIN}/anat/ -f ${ANAT} \
    ${PATH_INPUT}/${SUB}/T${SES}/T${SES}" >> job.slurm
  fi
  # Convert NAV
  if [ ! -f "${PATH_MAIN}/func/${NAV}_bold" ]; then
    echo "dcm2niix -z y -o ${PATH_MAIN}/func/ -f ${NAV}_bold \
    ${PATH_INPUT}/${SUB}/EPI/EPI" >> job.slurm
    # Create empty event file
    echo "touch ${PATH_MAIN}/func/${NAV}_events.tsv" >> job.slurm
  fi
  # Convert REST
  if [ ! -f "${PATH_MAIN}/func/${REST}_bold" ]; then
    echo "dcm2niix -z y -o ${PATH_MAIN}/func/ -f ${REST}_bold \
    ${PATH_INPUT}/${SUB}/Resting_State/Resting_State" >> job.slurm
    # Create empty event file
    echo "touch ${PATH_MAIN}/func/${REST}_events.tsv" >> job.slurm
  fi
  # Convert TOPUP AP (Sequence_1)
  if [ ! -f "${PATH_MAIN}/fmap/${AP}" ]; then
    echo "dcm2niix -z y -o ${PATH_MAIN}/fmap/ -f ${AP} \
    ${PATH_INPUT}/${SUB}/TOPUP/Sequence_1" >> job.slurm
  fi
  # Convert TOPUP PA (Sequence_2)
  if [ ! -f "${PATH_MAIN}/fmap/${PA}" ]; then
    echo "dcm2niix -z y -o ${PATH_MAIN}/fmap/ -f ${PA} \
    ${PATH_INPUT}/${SUB}/TOPUP/Sequence_2" >> job.slurm
  fi
  # Convert Magnitude FMAP
  if [ ! -f "${PATH_MAIN}/fmap/${MAG}" ]; then
    echo "dcm2niix -z y -o ${PATH_MAIN}/fmap/ -f ${MAG} \
    ${PATH_INPUT}/${SUB}/Fieldmap/Magnitude" >> job.slurm
    # Creates four files which have to be renamed
    echo "mv ${PATH_MAIN}/fmap/${MAG}_e1.json \
    ${PATH_MAIN}/fmap/${MAG}1.json" >> job.slurm
    echo "mv ${PATH_MAIN}/fmap/${MAG}_e1.nii.gz \
    ${PATH_MAIN}/fmap/${MAG}1.nii.gz" >> job.slurm
    echo "mv ${PATH_MAIN}/fmap/${MAG}_e2.json \
    ${PATH_MAIN}/fmap/${MAG}2.json" >> job.slurm
    echo "mv ${PATH_MAIN}/fmap/${MAG}_e2.nii.gz \
    ${PATH_MAIN}/fmap/${MAG}2.nii.gz" >> job.slurm
  fi
  # Convert Phasediff FMAP
  if [ ! -f "${PATH_MAIN}/fmap/${PHASE}" ]; then
    echo "dcm2niix -z y -o ${PATH_MAIN}/fmap/ -f ${PHASE} \
    ${PATH_INPUT}/${SUB}/Fieldmap/Phase" >> job.slurm
    # Creates two files which have to be renamed
    echo "mv ${PATH_MAIN}/fmap/${PHASE}_e2_ph.json \
    ${PATH_MAIN}/fmap/${PHASE}.json" >> job.slurm
    echo "mv ${PATH_MAIN}/fmap/${PHASE}_e2_ph.nii.gz \
    ${PATH_MAIN}/fmap/${PHASE}.nii.gz" >> job.slurm
  fi

  # ===
  # Submit job
  # ===
  sbatch job.slurm
  rm -f job.slurm
done

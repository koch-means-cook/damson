#!/usr/bin/bash

# ===
# Define paths
# ===
# path to the base directory:
PATH_BASE="/home/mpib/${USER}"
# define the name of the project:
PROJECT_NAME="damson"
# define the name of the current task:
TASK_NAME="mriqc"
# define the path to the script main directory:
PATH_CODE="${PATH_BASE}/${PROJECT_NAME}/code/preprocessing"
# cd into the directory of the current task:
cd "${PATH_CODE}/${TASK_NAME}"
# set MRIQC version
MRIQC_VERSION="0.15.1"
# define the path to the singularity container:
PATH_CONTAINER="${PATH_BASE}/tools/${PROJECT_NAME}/${TASK_NAME}_${MRIQC_VERSION}.sif"
# path to the data directory (in bids format):
PATH_INPUT="${PATH_BASE}/${PROJECT_NAME}/bids"
# path to the output directory:
PATH_OUTPUT="${PATH_BASE}/${PROJECT_NAME}/derivatives/preprocessing/${TASK_NAME}"
# path to the working directory:
PATH_WORK="${PATH_BASE}/${PROJECT_NAME}/work/${TASK_NAME}"
# path to the log directory:
PATH_LOG=${PATH_BASE}/${PROJECT_NAME}/logs/preprocessing/${TASK_NAME}/$(date '+%Y%m%d_%H%M')
# path to the text file with all subject ids:
PATH_SUBLIST="${PATH_BASE}/${PROJECT_NAME}/sourcedata/sub_list.txt"

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
# Run MRIQC for group reports
# ===
# create group reports for the functional data:
singularity run --contain -B ${PATH_INPUT}:/input:ro \
-B ${PATH_OUTPUT}:/output:rw -B ${PATH_WORK}:/work:rw \
${PATH_CONTAINER} /input/ /output/ group --no-sub

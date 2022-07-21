#!/bin/bash

# ===
# Define paths
# ===
# define home directory
PATH_BASE="/home/mpib/${USER}"
# path to the data directory (in bids format):
PATH_BIDS="${PATH_BASE}/damson/bids"

# ===
# Remove original T1w images  and replace them with defaced ones
# ===
for FILE in ${PATH_BIDS}/*/*/anat/*T1w_defaced.nii.gz; do
	# get the file name without the _defaced extension:
	FILE_NEW="${FILE::-15}"
	FILE_NEW="${FILE_NEW}.nii.gz"
	# remove the undefaced T1w file:
	rm -rf ${FILE_NEW}
	echo "removed ${FILE_NEW}"
	# replace the original T1w image with the defaced version:
	mv ${FILE} ${FILE_NEW}
	echo "replaced with defaced version"
done

# ===
# Remove original T2w images  and replace them with defaced ones
# ===
for FILE in ${PATH_BIDS}/*/*/anat/*T2w_defaced.nii.gz; do
	# get the file name without the _defaced extension:
	FILE_NEW=${FILE::-15}
	FILE_NEW="${FILE_NEW}.nii.gz"
	# remove the undefaced T1w file:
	rm -rf ${FILE_NEW}
	echo "removed ${FILE_NEW}"
	# replace the original T1w image with the defaced version:
	mv ${FILE} ${FILE_NEW}
	echo "replaced with defaced version"
done

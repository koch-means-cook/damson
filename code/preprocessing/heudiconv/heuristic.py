#!/usr/bin/env python

import os

def create_key(template, outtype=('nii.gz',), annotation_classes=None):
	if template is None or not template:
		raise ValueError('Template must be a valid format string')
	return template, outtype, annotation_classes

def infotodict(seqinfo):

    # paths in BIDS format
	anat = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_{weight}w')
	rest = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_bold')
	task = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-nav_bold')
	fmap_topup = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_dir-{dir}_epi')
	fmap_mag = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_magnitude')
	fmap_phase = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_phasediff')

	info = {anat: [], rest: [], task: [], fmap_topup: [], fmap_mag: [], fmap_phase: []}
	last_run = len(seqinfo)

	for s in seqinfo:

		if ('T1w' in s.series_id or 'T2w' in s.series_id):
			info[anat].append({'item': s.series_id, 'weight': s.dcm_dir_name})
		if ('Resting_State' in s.dcm_dir_name):
			info[rest].append({'item': s.series_id})
		if ('EPI' in s.dcm_dir_name):
			info[task].append({'item': s.series_id})
		if ('Sequence_1' in s.dcm_dir_name):
			info[fmap_topup].append({'item': s.series_id, 'dir': 'AP'})
		if ('Sequence_2' in s.dcm_dir_name):
			info[fmap_topup].append({'item': s.series_id, 'dir': 'PA'})
		if ('Magnitude' in s.dcm_dir_name):
			info[fmap_mag].append({'item': s.series_id})
		if ('Phase' in s.dcm_dir_name):
			info[fmap_phase].append({'item': s.series_id})

	return info

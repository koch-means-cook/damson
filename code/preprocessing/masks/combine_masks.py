#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Oct 12 13:18:30 2020

@author: koch
"""

import os
import glob
from nilearn import masking
from nilearn import image

base_path = '/Users/koch/Tardis/damson'
mask = 'rsc'

def main(base_path,
         mask):
    
    # Get masks to combine (dependent on mask)
    if mask == 'rsc':
        mask_dir = os.path.join(base_path,
                                'derivatives',
                                'preprocessing',
                                'masks',
                                '*_mask-tal-ba*.nii.gz')
    # Get paths to mask images
    mask_imgs = glob.glob(mask_dir)
    
    loaded_imgs = [image.load_img(x) for x in mask_imgs]
    
    # Use paths to create union of mask
    comb = masking.intersect_masks(mask_imgs=loaded_imgs,
                                   threshold=0)
    
    # Save image to file
    file = os.path.join(base_path,
                        'derivatives',
                        'preprocessing',
                        'masks',
                        'space-MNI152Lin_mask-' + mask + '.nii.gz')
    comb.to_filename(file)
    
    # why is this producing only ba29-r ?
    
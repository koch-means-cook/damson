# Analysis pipeline

## 01. Within-session decoding

- ```.../decoding/train-raw_test-raw/tardis_classifier_within.sh```
- Will run the script ```.../decoding/train-raw_test-raw/classifier.py``` on the HPC separately for each participant and mask
- Will classify the travelled direction from the neural pattern present during an event based on a training set, separately within each of the two sessions (L-DOPA and Placebo)
- see ```python3 classifier.py --help``` for all input options to the decoding script
- Decoding ran with the following settings:

```
MASK_SEG="aparcaseg"
MASK_LIST=("1005 2005 1011 2011 1021 2021" "1010 2010" "17 53" "1006 2006" "1024" "17 53 1006 2006 1016 2016")
# "1005 2005 1011 2011 1021 2021": Bilat Cuneus. Bilateral lateral occipital, bilateral pericalcarine
# "1010 2010": Bilateral isthmus of cingulate (rough RSC)
# "17 53": Bilateral HC
# "1006 2006": Bilateral Entorhinal
# "1024 2024": Bilateral Praecentral
# "17 53 1006 2006 1016 2016": Bilateral MTL (enorhinal + HC + paraHC)
EVENT_FILE="walk-fwd"
CLASSIFIER="logreg"
SMOOTHING_FWHM=3
ESSENTIAL_CONFOUNDS="True"
DETREND="True"
HIGH_PASS=0.0078125 #1/128
PULL_EXTREMES="False"
EXT_STD_THRES=8
STANDARDIZE="zscore"
N_BINS=6
BALANCING_OPTION="upsample"
BALANCE_STRATEGY="longest"
N_FOLDS_WITHIN=3
```

- Will produce a set of files for each participant, session, and ROI at e.g. ```.../derivatives/decoding/train-raw_test-raw/sub-older065/no_buffer/sub-older065_train-raw_test-raw_events-walk-fwd_mask-17-53_xval-sub_fold_clf-logreg_within-1_reorg_acc.tsv```
- The different files are:
   - ```_acc.tsv```: Average classification accuracy for each hold-out-set as well as average over hold-out-sets
   - ```_conf.tsv```: Confusion matrix of classifier, aligned confusion matrix (centered at 0 deg), and classifier's confusion function
   - ```_eventstats.tsv```: Number of events in each training and test set for all hold-out-sets
   - ```_pred.tsv```: For each event the classifier's prediction and probability of each direction bin
- Will also produce masks of each ROI used for each participant, e.g. at ```.../derivatives/decoding/train-raw_test-raw/sub-older065/sub-older065_seg-aparcaseg_mask-17-53.nii.gz```

## 02. Permutation of within-session decoding

- ```.../code/decoding/train-raw_test-raw/tardis_classifier_perm_within.sh```
- Will run above step including a permutation of all training labels (permuted within folds) to produce chance-level classification
- Will produce all files mentioned above in the same location with the extra flag ```_perm_```, e.g. ```.../derivatives/decoding/train-raw_test-raw/sub-older065/no_buffer/sub-older065_train-raw_test-raw_events-walk-fwd_mask-17-53_xval-sub_fold_clf-logreg_within-1_reorg_perm_acc.tsv```
- See above for additional information

## 03. Curve fitting to confusion functions

- ```.../code/analysis/confusion_function/tardis_CurveFitting.sh```
- Will run the script ```.../code/analysis/confusion_function/CurveFitting.R``` on the HPC separately for each modality the functions can be fitted to (confusion matrix, classifier's confusion function, pattern correlation)
- Will fit the specified Gaussian model and Uniform model to the chosen confusion function
- Produces one file for each confusion modality and fitted model at e.g. ```.../derivatives/analysis/curve_fitting/training-raw_testing-raw_events-walk-fwd_xval-sub_fold_mod-proba_clf-logreg_reorg_within_fit-gauss.tsv```
   - Modality:
      - ```_mod-proba_```: Model fit to classifier's confusion function
      - ```_mod-pred_```: Model fit to confusion matrix
      - ```_mod-corr_```: Model fit to correlation of neural patterns (deprecated)
   - Model:
      - ```fit-gauss```: Gaussian model
      - ```fit-uni```: Uniform model
- If ```--plot_fits "TRUE"``` will plot fit of each model for each ROI at e.g. ```.../derivatives/analysis/curve_fitting/training-raw_testing-raw_events-walk-fwd_xval-sub_fold_mod-pred_clf-logreg_reorg_within_mask-17-53_fit.pdf```

## 04. Run main stats script

- ```.../code/analysis/stats/stats_main.Rmd```
- Will run all stats reported in the paper
- Will also create separate files containing behavioral performance and chance-level behavioral performance at ```.../code/analysis/stats/stats_main.Rmd``` and ```.../derivatives/analysis/behavioral/chance_performance.tsv``` (important for figures, see below)

## 05. Get number of voxels within each ROI

- ```.../code/analysis/review/Get_voxel_data.py```
- Will extract number of voxels within each participant's ROIs and save it at ```.../derivatives/analysis/review/data_n_voxel.tsv```
- Required for SI analyses, see below

## 06. Run SI stats

- ```.../code/analysis/stats/stats_si.Rmd```
- Will run all stats reported in the supplementary information of the paper

## 07. Create figures

- ```.../code/analysis/figures/figures.Rmd```
- Will create all figures displayed in the paper and SI as a .pdf and .png file at e.g. ```.../derivatives/analysis/figures/fig03.pdf```

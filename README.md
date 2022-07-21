# damson

# DopAmine Modulated Signals Of Navigation

Repository and documentation for DAMSON project in cooperation with Christian Baeuchl, Franka Gloeckner, Philipp Riedel, Johannes Petzold, Michael Smolka, Shu-Chen Li, and Nicolas Schuck.

The documentation website to the project can be found
[here](https://koch.mpib.berlin/damson/).

For information on the pipelines see ```.../documentation/docs/...```, specifically ```pipeline_preprocessing.md``` and ```pipeline_analysis.md```.

# File structure with description

```
├── README.md                                     | File you are reading right now
├── code                                          | Directory containing all scripts and code used
│   ├── analysis                                  | Directory containing all code for data analysis
│   │   ├── confusion_function
│   │   │   ├── CurveFitting.R                    | Script to fit models (Gauss/Uniform) to confusion function
│   │   │   └── tardis_CurveFitting.sh            | Shell script to run curve fitting on HPC
│   │   ├── demographics
│   │   │   └── demographics.Rmd                  | R notebook giving demographic information (age, gender, etc.)
│   │   ├── figures
│   │   │   └── figures.Rmd                       | R notebook to create all figures of main paper and SI
│   │   ├── review
│   │   │   └── Get_voxel_data.py                 | Python script to isolate n voxel of each ROI for each participant
│   │   ├── stats
│   │   │   ├── stats_main.Rmd                    | R notebook of all analyses reported in main paper
│   │   │   ├── stats_main_render.R               | R script to render "stats_main.Rmd" on HPC
│   │   │   └── stats_si.Rmd                      | R notebook of all analyses reported in SI
│   │   └── utils                                 | Set of general functions sourced over analysis pipeline
│   │       └── ...
│   ├── decoding                                  | Directory containing all code for decoding of walking direction from imaging data
│   │   ├── train-fwd_test-bwd                    | NEVER USED, directory contains all script to potentially train classifier on forward walking events and test on backward walking events
│   │   │   └── ...
│   │   ├── train-raw_test-raw                    | Directory containing all scripts required to run classification of walking direction from imaging data
│   │   │   ├── classifier.py                     | Main script to classify walking direction from imaging data, see ".../documentation/docs/pipeline_analysis.md" for further detail
│   │   │   ├── tardis_classifier_perm_within.sh  | Shell script to run classification with permuted training sets on HPC
│   │   │   ├── tardis_classifier_within.sh       | Shell script to run classification on HPC
│   │   │   └── utils                             | Set of general functions called during classification
│   │   │       └── ...
│   │   └── utils                                 | Set of general functions called during classification
│   │       └── ...
│   └── preprocessing                             | Directory containing scripts used for complete preprocessing of imaging and behavioral data
│       ├── deface                                | Directory containing scripts to deface imaging data, check ```.../documentation/docs/pipeline_preprocessing.md``` for further detail
│       │   └── ...
│       ├── fmriprep                              | Directory containing scripts to run fMRIprep on imaging data, check ```.../documentation/docs/pipeline_preprocessing.md``` for further detail
│       │   └── ...
│       ├── heudiconv                             | Directory containing scripts to run heudiconv BIDS conversion, check ```.../documentation/docs/pipeline_preprocessing.md``` for further detail
│       │   └── ...
│       ├── logfile                               | Directory containing scripts to convert participants movement in the environment into event-files important for training and testing the classifier, check ```.../documentation/docs/pipeline_preprocessing.md``` for further detail
│       │   ├── ...
│       │   └── utils                             | Directory containing independent functions to perform logfile conversion
│       │       └── ...
│       ├── masks                                 | DEPRECATED
│       │   └── ...
│       ├── mriqc                                 | Directory containing scripts to run MRI quality control on imaging data, check ```.../documentation/docs/pipeline_preprocessing.md``` for further detail
│       │   └── ...
│       └── participants                          | Directory containing scripts to fill participants.tsv in BIDS directory with important data, check ```.../documentation/docs/pipeline_preprocessing.md``` for further detail
│           └── ...
├── documentation                                 | Directory containing documentation files needed to reproduce pipelines
│   └── docs
│       ├── ...
│       ├── pipeline_analysis.md                  | Step-by-step guide to performed data analysis
│       └── pipeline_preprocessing.md             | Step-by-step guide to preprocessing of imaging and behavioral data
├── mkdocs.yml                                    | Irrelevant, file to aid deployment of documentation website in GitLab
├── renv                                          | Directory containing "virtual environment" of R, see documentation of renv package
│   └── ...
├── renv.lock                                     | The "requirements.txt" for renv, giving all packages and versions used
└── requirements.txt                              | All packages and versions used in python virtual environment
```

---

# License

All contents of this repository were written by Christoph Koch at the Max Planck Institute for Human Development, Berlin, Germany and is licensed under the Creative Commons Attribution 4.0 International Public License.
Please see http://creativecommons.org/licenses/by/4.0/ for details.

---

# Citation

If you use any of this content in your work please cite the related pre-print at https://www.biorxiv.org/content/10.1101/2021.08.18.456677v1

> L-DOPA enhances hippocampal direction signals in younger and older adults  
> Christoph Koch, Christian Bäuchl, Franka Glöckner, Philipp Riedel, Johannes Petzold, Michael Smolka, Shu-Chen Li, Nicolas W. Schuck  
> bioRxiv 2021.08.18.456677; doi: https://doi.org/10.1101/2021.08.18.456677

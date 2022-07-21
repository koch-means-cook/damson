# fMRIprep integration

Running the singularity container on tardis using the following commands:

```bash
singularity run \
--cleanenv \
-B ${PATH_BIDS}:/input:ro \               # Mount input folder
-B ${PATH_OUT}:/output:rw \               # Mount output folder
-B ${PATH_FMRIPREP}:/utilities:ro \       # Mount license flder
-B ${PATH_WORK_SUB}:/work:rw \            # Specify working dir for temp files
${PATH_CONTAINER} \                       # Specify container to run
--fs-license-file /utilities/fs_license.txt \ # Path to license file
/input/ \                                 # Path to input dir (mounted)
/output/ \                                # Path to outpur dir (mounted)
participant --participant_label ${SUB_GROUP}${SUB_PAD} \ # Example: "sub-younger001"
-w /work/ \                               # Path to working dir (mounted)
--mem_mb ${MEM_MB} \                      # How much memory for processing
--nthreads ${N_CPUS} \                    # Max N of threads for all processes
--omp-nthreads ${N_THREADS} \             # Max N of threads per process
--write-graph \                           # Write Nipype workflow graph
--stop-on-first-crash \                   # Force stopping in case of error
--output-spaces T1w fsnative MNI152Lin fsaverage \  # All spaces to save outputs in
--no-submm-recon \                        # Disable sub-mm recon (FOV issue)
--notrack \                               # Don't send info to developers
--verbose \                               # Additional info in log file
--resource-monitor                        # Keep track of MEM and CPU usage
```

---

# Issues

## FOV of ```orig.mgz``` too large

The FOV of the ```orig.mgz``` file seems to be too large (< 256). This produced
the following error message:

```
****************************************
ERROR! FOV=272.000 > 256
Include the flag -cw256 with recon-all!
Inspect orig.mgz to ensure the head is fully visible.
****************************************
```

For now I don't really know how to solve this other than using
```--no-submm-recon``` which skips the step.

I also don't know how the flag ```-cw256``` could be entered with the singularity
container. This flag seems to deal with the issue as well. See the following
links for more information on this error:

- https://github.com/poldracklab/smriprep/issues/29

- https://neurostars.org/t/freesurfer-error-fov-256/2171

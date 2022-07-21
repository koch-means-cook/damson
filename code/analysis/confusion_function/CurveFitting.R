
# Load libraries
packages = c("here",
             "data.table",
             "ggplot2",
             "plyr",
             "dplyr",
             "plotly",
             'viridis',
             'stringr',
             'lme4',
             'papeR',
             'binhf',
             'optparse')
invisible(lapply(packages, require, character.only = TRUE))


# training = 'raw'
# testing = 'raw'
# events = 'walk-fwd'
# xval_split = 'fold'
# clf = 'logreg'
# mod = 'proba'
# buffering = TRUE
# reorganize = TRUE
# within_session = FALSE
# plot_fits = FALSE

# Function to perform curve fitting
CurveFitting = function(training,
                        testing,
                        events,
                        xval_split,
                        clf,
                        mod,
                        buffering,
                        reorganize,
                        within_session,
                        plot_fits){
  
  # Set up paths and participants
  base_path = here::here()
  sub_list = list.dirs(file.path(base_path, 'derivatives', 'decoding',
                                 paste('train-', training,'_test-', testing,
                                       sep = ''),
                                 fsep=.Platform$file.sep),
                       recursive = FALSE,
                       full.names = FALSE)
  sub_list = sub_list[grep('sub-', sub_list)]
  
  # Load pre-written functions
  source_path = file.path(base_path, 'code', 'analysis', 'utils',
                          fsep = .Platform$file.sep)
  source_files = list.files(source_path, pattern = "[.][rR]$",
                            full.names = TRUE, recursive = TRUE)
  invisible(lapply(source_files, function(x) source(x)))
  
  # Give message to user
  message('Loading confusion functions...')
  
  # Check if confusion matrix or predicted probability should be used
  if(mod != 'pred'){
    # Use required data (buffered or not)
    data = LoadPred(base_path = base_path,
                    training = training,
                    testing = testing,
                    events = events,
                    mask = '*',
                    xval_split = xval_split,
                    clf = clf,
                    buffering = buffering,
                    average = FALSE,
                    perm = FALSE,
                    reorganize = reorganize,
                    within_session = within_session,
                    print_progress = FALSE)
    
    # Convert possibly wrong data types
    data$n_bins = as.numeric(data$n_bins)
    data$corr = as.numeric(data$corr)
    data$proba = as.numeric(data$proba)
    # Make intervention independent of session (for aggregation)
    data[session == 1 & intervention == 'A']$intervention = 'AB'
    data[session == 2 & intervention == 'A']$intervention = 'BA'
    data[session == 1 & intervention == 'B']$intervention = 'BA'
    data[session == 2 & intervention == 'B']$intervention = 'AB'
    # Get mean over all folds for each distance from target 
    # (e,g, 0, 60, 120, 180, -60, -120) and also across buffers
    data$proba = as.numeric(data$proba)
    data$corr = as.numeric(data$corr)
    if(!within_session){
      data = ddply(data,
                   .(participant_id, age, sex, group, intervention, mask_seg,
                     mask_index, classifier, smoothing_fwhm, essential_confounds,
                     detrend, high_pass, ext_std_thres, standardize, n_bins,
                     event_file, balancing_option, balance_strategy,
                     x_val_split, variable),
                   dplyr::summarise,
                   proba = mean(proba),
                   corr = mean(corr))  
    } else if(within_session){
      data = ddply(data,
                   .(participant_id, age, sex, group, intervention, session, mask_seg,
                     mask_index, classifier, smoothing_fwhm, essential_confounds,
                     detrend, high_pass, ext_std_thres, standardize, n_bins,
                     event_file, balancing_option, balance_strategy,
                     x_val_split, variable),
                   dplyr::summarise,
                   proba = mean(proba),
                   corr = mean(corr))
    }
    
    
    # Cast data into long format
    data = data.table(data)
    if(mod == 'proba'){
      data[, corr := NULL]
      data = dcast(data, ... ~ variable, value.var = 'proba')
    } else if(mod == 'corr'){
      data[, proba := NULL]
      data = dcast(data, ... ~ variable, value.var = 'corr')
    }
    
  } else if(mod == 'pred'){
    # Load confusion functions based on predictions
    data = LoadConf(base_path = base_path,
                    training = training,
                    testing = testing,
                    events = events,
                    mask = '*',
                    xval_split = xval_split,
                    clf = clf,
                    buffering = buffering,
                    perm = FALSE,
                    average_buffers = TRUE,
                    restrict = FALSE,
                    reorganize = reorganize,
                    within_session = within_session)
    
    # Eliminate prediction columns since it is not useful for this analysis
    data[, 'prediction':=NULL]
    # Cast data to long format
    data$value = as.factor(data$value)
    data = dcast(data, ... ~ variable, value.var = 'value')
    
  }
  
  # Get angles to fit function
  n_bins = as.numeric(unique(data$n_bins))
  bins = seq(n_bins)
  angles = (bins - bins[length(bins)/2]) * 60
  # Get all columns to fit function to
  fit_cols = bins
  # In case middle column should be excluded from fitting (which makes no sense,
  # middle column should only be excluded when scoring SSE)
  #fit_cols = c(1:((length(bins)/2)-1),((length(bins)/2)+1):length(bins))
  
  # Give message to user
  message('Fitting Gaussian and Uniform functions to data...')
  
  # Apply function fitting to confusion functions
  conf_cols = which(colnames(data) %in% angles)
  peak_col = conf_cols[n_bins/2]
  # Gaussian
  gauss_prec = data.table(apply(data,
                                1,
                                function(x) GaussFit(confusion_mat = as.numeric(x[conf_cols]),
                                                     angles = angles,
                                                     fit_cols = fit_cols)$par))
  colnames(gauss_prec) = 'gauss_prec'
  gauss_ll = data.table(apply(data,
                              1,
                              function(x) GaussFit(confusion_mat = as.numeric(x[conf_cols]),
                                                   angles = angles,
                                                   fit_cols = fit_cols)$value))
  colnames(gauss_ll) = 'gauss_ll'
  gauss_curve = data.table(t(apply(as.data.frame(gauss_prec),
                                   1,
                                   function(x) MyGauss(x, angles))))
  colnames(gauss_curve) = as.character(angles)
  # Get SSE of Gaussian
  data_sse = data.frame(data)
  gauss_sse = data.table(
    rowSums((as.numeric(as.matrix(data_sse[,conf_cols[-(n_bins/2)]])) - gauss_curve[,!'0'])^2)
    )
  colnames(gauss_sse) = 'gauss_sse'
  # Uniform
  uni_curve = data.table(t(apply(data,
                                 1,
                                 function(x) MyUniform(as.numeric(x[peak_col]),
                                                       angles))))
  colnames(uni_curve) = as.character(angles)
  # Get SSE of Uniform
  data_sse = data.frame(data)
  uni_sse = data.table(
    rowSums((as.numeric(as.matrix(data_sse[,conf_cols[-n_bins/2]])) - uni_curve[,!'0'])^2)
    )
  colnames(uni_sse) = 'uni_sse'
  uni_ll = data.table(apply(data,
                              1,
                              function(x) UniFit(confusion_mat = as.numeric(x[conf_cols]),
                                                   angles = angles,
                                                   fit_cols = fit_cols)$value))
  colnames(uni_ll) = 'uni_ll'
  
  # Fuse data to data frame
  data = data.table(data)
  base = data[,-..conf_cols]
  data_gauss = data.table(cbind(base,
                                gauss_prec,
                                gauss_ll,
                                gauss_sse,
                                gauss_curve))
  data_gauss = melt(data_gauss,
                    measure.vars = as.character(angles))
  data_uni = data.table(cbind(base,
                              uni_ll,
                              uni_sse,
                              uni_curve))
  data_uni = melt(data_uni,
                  measure.vars = as.character(angles))
  
  # Add column giving mod of confusion function
  data_gauss$mod = mod
  data_uni$mod = mod
  # Add column giving buffering
  data_gauss$buffering = buffering
  data_uni$buffering = buffering
  
  # Get fitted Gauss with higher resolution
  high_res = seq(-179.5, 180, by=0.5)
  high_res_gauss = data.table(t(apply(as.data.frame(gauss_prec),
                     1,
                     function(x) MyGauss(x, high_res))))
  colnames(high_res_gauss) = as.character(high_res)
  data_gauss_full = data.table(cbind(base,
                                     high_res_gauss))
  data_gauss_full = melt(data_gauss_full,
                         measure.vars = as.character(high_res))
  # Add radians column
  data_gauss_full$rad = as.numeric(as.character(data_gauss_full$variable))
  data_gauss_full$rad[data_gauss_full$rad < 0] = (
    data_gauss_full$rad[data_gauss_full$rad < 0] + 360)
  data_gauss_full$rad = data_gauss_full$rad * pi /180
  
  # Give message to user
  message('Saving output...')
  
  # Save fitting values
  # Create directory if it does not exist already
  save_dir = file.path(base_path,
                       'derivatives',
                       'analysis',
                       'curve_fitting',
                       fsep = .Platform$file.sep)
  if(!dir.exists(save_dir)){
    dir.create(save_dir)
  }
  
  # Create pattern giving analysis parameters for file name
  if(!buffering){
    file_pattern = file.path(save_dir,
                             paste('training-',training,
                                   '_testing-', testing,
                                   '_events-', events,
                                   '_xval-', xval_split,
                                   '_mod-', mod,
                                   '_clf-', clf,
                                   sep = ''),
                             fsep = .Platform$file.sep)
  } else if(buffering){
    file_pattern = file.path(save_dir,
                             paste('training-',training,
                                   '_testing-', testing,
                                   '_events-', events,
                                   '_xval-', xval_split,
                                   '_mod-', mod,
                                   '_clf-', clf,
                                   '_buffer',
                                   sep = ''),
                             fsep = .Platform$file.sep)
  }
  
  # Add additional name flags
  if(reorganize){
    file_pattern = paste(file_pattern,
                         '_reorg',
                         sep = '')
  }
  if(within_session){
    file_pattern = paste(file_pattern,
                         '_within',
                         sep = '')
  }
  
  
  # Save Gauss data
  file = paste(file_pattern, '_fit-gauss.tsv', sep = '')
  write.table(data_gauss,
              file = file,
              sep = '\t',
              na = 'n/a',
              row.names = FALSE,
              quote = FALSE)
  # Save Uniform data
  file = paste(file_pattern, '_fit-uni.tsv', sep = '')
  write.table(data_uni,
              file = file,
              sep = '\t',
              na = 'n/a',
              row.names = FALSE,
              quote = FALSE)
  # Save high res gauss curve
  file = paste(file_pattern, '_highres-gauss.tsv', sep = '')
  write.table(data_gauss_full,
              file = file,
              sep = '\t',
              na = 'n/a',
              row.names = FALSE,
              quote = FALSE)
  
  if(plot_fits){
    
    # Give message to user
    message('Plotting fits...')
    
    # Fuse all data (raw and fitted functions)
    data_plot = melt(data,
                     measure.vars = as.character(angles))
    data_plot$data = 'cf'
    data_gauss = data_gauss[,c('gauss_sse', 'gauss_ll', 'gauss_prec', 'buffering', 'mod'):=NULL]
    data_gauss$data = 'gauss'
    data_plot = rbind(data_plot, data_gauss)
    data_uni = data_uni[,c('uni_sse', 'buffering', 'mod'):=NULL]
    data_uni$data = 'uni'
    data_plot = rbind(data_plot, data_uni)
    # Eliminate "sub-" from substring for easier plotting
    data_plot$participant_id = substring(data_plot$participant_id, first=5)
    # Convert value to numeric for better y-axis
    data_plot$value = as.numeric(data_plot$value)
    
    
    for(mask in unique(data_plot$mask_index)){
      mask_data = data_plot[mask_index == mask]
      
      p = ggplot(data = mask_data, aes(x = variable, y = value, color = data)) +
        theme_bw() +
        geom_point(data=mask_data[data == 'cf'],
                   size = 1,
                   color = 'black') +
        geom_line(data=mask_data[data == 'gauss'],
                  aes(group=data),
                  size = 1,
                  alpha = 0.7) +
        geom_line(data=mask_data[data == 'uni'],
                  aes(group=data),
                  size = 1,
                  alpha = 0.7) +
        geom_hline(yintercept = 1/n_bins,
                   linetype = 'dashed',
                   color = 'black') +
        scale_color_viridis(option='D', discrete = TRUE) +
        labs(title = mask,
             x = 'Divergence from target',
             y = '%-correct') +
        theme(strip.text = element_text(size=5),
              legend.position = 'None',
              plot.title = element_text(face='bold', hjust = 0.5, size = 15),
              axis.text = element_text(size = 5))
      
      file = paste(file_pattern, '_mask-', mask, '_fit.pdf', sep = '')
      
      if(within_session){
        p = p + facet_wrap(~ participant_id + session)
        ggsave(file, plot = p, width = 10, height = 20)
      } else{
        p = p + facet_wrap(~ participant_id)  
        ggsave(file, plot = p, width = 10, height = 10)
      }
    }
  }
  
  # Give message to user
  message('...done!')
}


# Create options to pass to script
option_list = list(
  make_option(c('--training'),
              type='character',
              help='modality to use for training (e.g. "raw" or "beta")',
              metavar = 'TRAINING'),
  make_option(c('--testing'),
              type='character',
              help='modality to use for testing (e.g. "raw" or "beta")',
              metavar = 'TESTING'),
  make_option(c('--events'),
              type='character',
              help = 'Eventfile to use (e.g. "walk-fwd")',
              metavar = 'EVENTS'),
  make_option(c('--xval_split'),
              type='character',
              help = 'Split to use for cross validation. Options: ["fold", "session", "sub_fold"]',
              metavar = 'XVAL_SPLIT'),
  make_option(c('--clf'),
              type='character',
              help = 'Classifier results to fit function to (e.g. "svm" or "logreg")',
              metavar = 'CLF'),
  make_option(c('--mod'),
              type='character',
              help = 'Character describing modality to fit curve to. Options: ["pred", "proba", "corr"]',
              metavar = 'MOD'),
  make_option(c('--buffering'),
              type='logical',
              help = 'Bool if buffered data should be used, if FALSE unbuffered data will be used',
              metavar = 'BUFFERING'),
  make_option(c('--reorganize'),
              type='logical',
              help = 'Bool to choose data with reorganized direciton labels (only raw data!)',
              metavar = 'REORGANIZE'),
  make_option(c('--within_session'),
              type='logical',
              help = 'Bool to use data cross-validated within session',
              metavar = 'WITHIN_SESSION'),
  make_option(c('--plot_fits'),
              type='logical',
              help = 'Bool if fit should be printed as plot',
              metavar = 'PLOT_FITS'))


# provide options in list to be callable by script
opt_parser = OptionParser(option_list = option_list)
opt = parse_args(opt_parser)

# Call curve fitting function
CurveFitting(training = opt$training,
             testing = opt$testing,
             events = opt$events,
             xval_split = opt$xval_split,
             clf = opt$clf,
             mod = opt$mod,
             buffering = opt$buffering,
             reorganize = opt$reorganize,
             within_session = opt$within_session,
             plot_fits = opt$plot_fits)

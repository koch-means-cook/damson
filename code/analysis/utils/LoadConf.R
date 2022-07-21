library(data.table)
library(dplyr)
library(parallel)
library(stringr)

# Function to load confusion function data
LoadConf = function(base_path,
                    training,
                    testing,
                    events,
                    mask,
                    xval_split,
                    clf,
                    buffering,
                    perm = FALSE,
                    average_buffers = TRUE,
                    restrict = TRUE,
                    reorganize = FALSE,
                    within_session = FALSE,
                    SMOTE = FALSE){
  
  # base_path = here::here()
  # training = 'raw'
  # testing = 'raw'
  # events = 'walk-fwd'
  # mask = '*'
  # xval_split = 'sub_fold'
  # clf = 'logreg'
  # buffering = FALSE
  # perm = FALSE
  # average_buffers = TRUE
  # restrict = TRUE
  # reorganize = TRUE
  # within_session = TRUE
  # plot_fits = TRUE
  
  ToTable = function(file, buffering, within_session, restrict){
    # Load individual file
    temp = data.table::fread(file,
                             sep = '\t',
                             header = TRUE)
    
    # If buffered data, add buffer as column
    if(buffering){
      train_buffer = unlist(str_split(file, '_'))
      train_buffer = train_buffer[grep('buffer-', train_buffer)]
      train_buffer = unlist(str_split(train_buffer, '-'))[2]
      temp$train_buffer = as.numeric(train_buffer)
    }
    
    # If within session data, add session as column
    if(within_session){
      session = unlist(str_split(file, '_'))
      session = session[grep('within-', session)]
      session = unlist(str_split(session, '-'))[2]
      temp$session = as.numeric(session)
    }
    
    # If requested, restrict data to confusion function
    if(restrict & !buffering){
      temp = temp[prediction == 'confusion_function']
    } else if(restrict & buffering){
      temp = temp[prediction == 'aligned_prediction']
    }
    
    # Change sex variable coding because automatically interpreted as bool
    temp$sex = as.character(temp$sex)
    if(any(temp$sex == 'FALSE')){
      temp$sex = 'F'
    }
    
    return(temp)
  }
  
  # Get folder of saved data
  file_pattern = file.path(base_path,
                           'derivatives',
                           'decoding',
                           paste('train-', training, '_test-', testing,
                                 sep = ''),
                           '*',
                           fsep = .Platform$file.sep)
  
  # Select folder for buffered or unbuffered data
  if(buffering){
    file_pattern = file.path(file_pattern,
                             'buffer',
                             fsep = .Platform$file.sep)
  } else {
    file_pattern = file.path(file_pattern,
                             'no_buffer',
                             fsep = .Platform$file.sep)
    
  }
  
  # Find all files
  file_pattern = file.path(file_pattern,
                           paste('*', training, '*', testing, '*', events, '*',
                                 mask, '*', xval_split, '*', clf, '*conf.tsv',
                                 sep = ''),
                           fsep = .Platform$file.sep)
  files = Sys.glob(file_pattern)
  
  # Select permuted or unpermuted files
  perm_index = grepl('_perm_', files)
  if(perm){
    files = files[perm_index]
  } else {
    files = files[!perm_index]
  }
  
  # Select reorganized files
  reorg_index = grepl('_reorg', files)
  if(reorganize){
    files = files[reorg_index]
  } else {
    files = files[!reorg_index]
  }
  
  # Select within session files
  within_index = grepl('_within-', files)
  if(within_session){
    files = files[within_index]
  } else {
    files = files[!within_index]
  }
  
  # Select SMOTE files
  smote_index = grepl('_SMOTE', files)
  if(SMOTE){
    files = files[smote_index]
  } else {
    files = files[!smote_index]
  }
  
  
  # Load files
  # Apply load function to all files and store in list
  list = mclapply(files,
                  FUN = ToTable,
                  buffering = buffering,
                  within_session = within_session,
                  restrict = restrict,
                  mc.cores = 4)
  # Append each list element to one data table
  data = data.table(ldply(list, rbind))
  
  # Rename direction columns
  dir_cols = grep('.0', colnames(data))
  n_bins = length(dir_cols)
  cols = (dir_cols - dir_cols[n_bins/2]) * 360 / n_bins
  colnames(data)[dir_cols] = cols
  
  # Melt data
  data = melt(data,
              measure.vars = as.character(cols))
  data$variable = as.factor(data$variable)
  
  # For buffered data calculate confusion function from summed up predictions
  if(buffering){
    data = data[prediction == 'aligned_prediction']
    # Sum up aligned predictions of buffers
    data = data %>%
      group_by_at(colnames(data)[colnames(data) != 'train_buffer' &
                                   colnames(data) != 'value']) %>%
      dplyr::summarise(value = sum(value))
    # Calculate conf function from predictions
    data = data %>%
      group_by_at(colnames(data)[colnames(data) != 'variable' &
                                   colnames(data) != 'value']) %>%
      dplyr::mutate(value = value/sum(value))
    data[,'prediction'] = 'confusion_function'
  } else if(!buffering){
    data = data[prediction == 'confusion_function']
  }
  
  # Return result  
  return(data.table(data))
  
}
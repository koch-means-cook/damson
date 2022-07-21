library(data.table)
library(dplyr)
library(stringr)
library(parallel)

# Function to load classification accuracy
LoadAcc = function(base_path,
                   training,
                   testing,
                   events,
                   mask,
                   xval_split,
                   clf,
                   buffering,
                   perm = FALSE,
                   reorganize = FALSE,
                   within_session = FALSE,
                   acc_across_folds = FALSE,
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
  # reorganize = TRUE
  # within_session = TRUE
  # acc_across_folds = TRUE
  # SMOTE = TRUE
  
  ToTable = function(file_path, buffering, within_session){
    # Load individual file
    temp = data.table::fread(file_path,
                             sep = '\t',
                             header = TRUE)
    
    # Change sex variable coding because automatically interpreted as bool
    temp$sex = as.character(temp$sex)
    if(any(temp$sex == 'FALSE')){
      temp$sex = 'F'
    }
    
    # If buffered data, add buffer as column
    if(buffering){
      buffer = unlist(str_split(file_path, '_'))
      buffer = buffer[grep('buffer-', buffer)]
      buffer = unlist(str_split(buffer, '-'))[2]
      temp$buffer = as.numeric(buffer)
    }
    
    # If within session data, add session as column
    if(within_session){
      session = unlist(str_split(file_path, '_'))
      session = session[grep('within-', session)]
      session = unlist(str_split(session, '-'))[2]
      temp$session = as.numeric(session)
    }
    
    return(data.table(temp))
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
                                 mask, '*', xval_split, '*', clf, '*acc.tsv',
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

  # Apply load function to al files and store in list
  list = mclapply(files,
                  FUN = ToTable,
                  buffering = buffering,
                  within_session = within_session,
                  mc.cores = 4)
  # Append each list element to one data table
  data = data.table(ldply(list, rbind))
  
  # Restrict data to either fold-specific or across-fold accuracy
  # (describes how accuracy was calculated, either for each testing set 
  # individually or over pooled predictions across all folds)
  if(acc_across_folds){
    data = dplyr::filter(data, held_out_split == 'across')
  } else{
    data = dplyr::filter(data, held_out_split != 'across')
    data$held_out_split = as.numeric(data$held_out_split)
  }

  return(data)
}
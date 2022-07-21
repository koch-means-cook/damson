library(data.table)
library(stringr)

# Function to load classification accuracy
LoadEventStats = function(base_path,
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
                          SMOTE = FALSE){
  
  # training = 'raw'
  # testing = 'raw'
  # events = 'walk-fwd'
  # mask = '1011-2011'
  # clf = 'svm'
  # buffering = TRUE
  # perm = FALSE
  # within_session = TRUE
  # reorganize = TRUE
  
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
                                 mask, '*', xval_split, '*', clf,
                                 '*eventstats.tsv', sep = ''),
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
  data = data.table()
  for(file in files){
    
    # Load individual file
    temp = data.table::fread(file,
                             sep = '\t',
                             header = TRUE)
    
    # Change sex variable coding because automatically interpreted as bool
    temp$sex = as.character(temp$sex)
    if(any(temp$sex == 'FALSE')){
      temp$sex = 'F'
    }
    
    # If buffered data, add buffer as column
    if(buffering){
      buffer = unlist(str_split(file, '_'))
      buffer = buffer[grep('buffer-', buffer)]
      buffer = unlist(str_split(buffer, '-'))[2]
      temp$buffer = as.numeric(buffer)
    }
    
    # If within session data, add session as column
    if(within_session){
      session = unlist(str_split(file, '_'))
      session = session[grep('within-', session)]
      session = unlist(str_split(session, '-'))[2]
      temp$session = as.numeric(session)
    }
    
    # Add mask as column
    mask = unlist(str_split(file, '_'))
    mask = mask[grep('mask-', mask)]
    mask = unlist(str_split(mask, '-'))
    # Case of only one mask
    if(length(mask) < 3){
      mask = mask[2]
    } else if(length(mask >= 3)){
      mask = paste(mask[2:length(mask)], collapse = '-')
    }
    temp$mask_index = mask
    
    data = rbind(data, temp)
  }
  
  return(data)
}
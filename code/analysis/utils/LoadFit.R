library(data.table)

# Function to load fitting values
LoadFit = function(base_path,
                   train,
                   test,
                   events,
                   x_val_split,
                   mod,
                   clf,
                   fitted_function = 'logreg',
                   buffering,
                   perm = FALSE,
                   reorganize = FALSE,
                   within_session = FALSE,
                   SMOTE = FALSE){
  
  # base_path = here::here()
  # train = 'raw'
  # test = 'raw'
  # events = 'walk-fwd'
  # x_val_split = 'fold'
  # mod = 'proba'
  # clf = 'logreg'
  # fitted_function = 'gauss'
  # buffering = TRUE
  # perm = FALSE
  # reorganize = TRUE
  # within_session = FALSE
  
  # Get directory with fitting output
  load_dir = file.path(base_path,
                       'derivatives',
                       'analysis',
                       'curve_fitting',
                       fsep = .Platform$file.sep)
  
  # Get all files with fitting values
  files = file.path(load_dir,
                    paste('training-', train,
                          '_testing-', test,
                          '_events-', events,
                          '_xval-', x_val_split, 
                          '_mod-', mod,
                          '_clf-', clf,
                          '*',
                          '_fit-', fitted_function, '*.tsv',
                          sep = ''),
                    fsep = .Platform$file.sep)
  
  # Get list of all files
  files = Sys.glob(files)
  
  # Select buffered or unbuffered files
  buffer_index = grepl('_buffer_', files)
  if(buffering){
    files = files[buffer_index]
  } else {
    files = files[!buffer_index]
  }
  
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
  within_index = grepl('_within_', files)
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
  
  
  # Load all files and fuse them
  data = data.table()
  for(file in files){
    data = rbind(data,
                 data.table::fread(file, header = TRUE))
  }
  
  # Return results
  return(data)
}
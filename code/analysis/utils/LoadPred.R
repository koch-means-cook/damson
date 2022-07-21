library(data.table)
library(dplyr)
library(parallel)
library(binhf)
library(stringr)

# Function to load and format prediction and correlation
LoadPred = function(base_path,
                    training,
                    testing,
                    events,
                    mask,
                    xval_split,
                    clf,
                    buffering,
                    average = FALSE,
                    perm = FALSE,
                    reorganize = FALSE,
                    within_session = FALSE,
                    SMOTE = FALSE,
                    print_progress = FALSE){
  
  # base_path = here::here()
  # training = 'raw'
  # testing = 'raw'
  # events = 'walk-fwd'
  # mask = '*'
  # xval_split = 'fold'
  # clf = 'logreg'
  # buffering = TRUE
  # average = TRUE
  # perm = FALSE
  # reorganize = TRUE
  # within_session = FALSE
  # print_progress = FALSE
  
  ToTable = function(file, buffering, within_session, average, perm){
    # Load individual file
    temp = data.table::fread(file,
                             sep = '\t',
                             header = TRUE,
                             check.names = TRUE)
    
    # If buffered data, add buffer as column
    if(buffering){
      train_buffer = unlist(str_split(file, '_'))
      train_buffer = train_buffer[grep('buffer-', train_buffer)]
      train_buffer = unlist(str_split(train_buffer, '-'))[2]
      temp$train_buffer = as.numeric(train_buffer)
      # Rename buffer of testset event
      temp = dplyr::rename(temp, test_buffer = buffer)
    }
    
    # If within session data, get current session from 
    if(within_session){
      session = unlist(str_split(file, '_'))
      session = session[grep('within-', session)]
      session = unlist(str_split(session, '-'))[2]
    }
    
    # Change sex variable coding because automatically interpreted as bool
    temp$sex = as.character(temp$sex)
    if(any(temp$sex == 'FALSE')){
      temp$sex = 'F'
    }
    
    # Rename probability and correlation columns
    proba_cols = grep('proba_', colnames(temp))
    corr_cols = grep('corr_', colnames(temp))
    n_bins = length(proba_cols)
    divergence = binhf::shift((proba_cols - proba_cols[n_bins/2]) * 360/n_bins,
                              -n_bins/2+1)
    proba_names = paste('proba', divergence, sep = '_')
    corr_names = paste('corr', divergence, sep = '_')
    colnames(temp)[proba_cols] = proba_names
    colnames(temp)[corr_cols] = corr_names
    
    # Shift data accordingly to column names
    #temp = data.frame(temp)
    names = colnames(temp)
    event_col = grep('event_type', colnames(temp))
    steady_cols = seq(length(names))[-c(proba_cols, corr_cols)]
    temp = data.frame(
      t(
        apply(temp,
              1,
              function(x) x[c(steady_cols,
                              shift(proba_cols, -(as.numeric(x[event_col])-1)),
                              shift(corr_cols, -(as.numeric(x[event_col])-1)))])))
    
    colnames(temp) = names[c(steady_cols, proba_cols, corr_cols)]
    
    # Get new positions of proba and corr columns
    proba_cols = grep('proba_', colnames(temp))
    corr_cols = grep('corr_', colnames(temp))
    
    # Fuse probability and correlation into melted data frame
    temp = data.table(temp)
    # Melt probability
    data_proba = melt(temp, measure.vars = proba_cols, value.name = 'proba')
    levels(data_proba$variable) = divergence
    data_proba[,grep('corr', colnames(data_proba)):=NULL]
    # Melt correlation
    data_corr = melt(temp, measure.vars = corr_cols, value.name = 'corr')
    levels(data_corr$variable) = divergence
    data_corr[,grep('proba', colnames(data_corr)):=NULL]
    
    # Merge data based on identical columns
    temp = merge(data_corr, data_proba)
    
    # Pair intervention across session
    temp$intervention[temp$intervention == 'A' & temp$session == 1] = 'AB'
    temp$intervention[temp$intervention == 'A' & temp$session == 2] = 'BA'
    temp$intervention[temp$intervention == 'B' & temp$session == 1] = 'BA'
    temp$intervention[temp$intervention == 'B' & temp$session == 2] = 'AB'
    
    # If requested, get average of correlation and proba curves over participant
    if(average){
      
      # Get columns to average over
      cols = c('participant_id', 'group', 'mask_index', 'classifier',
               'event_file', 'intervention', 'train_buffer', 'i_perm',
               'variable')
      if(!buffering){
        # If training data was not buffered don't get a separate average for 
        # each buffer
        cols = cols[-grep('train_buffer', cols)]
      }
      if(!perm){
        # If there is no perm data, don't group by permutation when averaging
        cols = cols[-grep('i_perm', cols)]
      }
      # Average data according to inputs
      temp = temp %>%
        group_by_at(cols) %>%
        dplyr::summarise(value_proba = mean(as.numeric(proba)),
                         value_corr = mean(as.numeric(corr)))
    }
    
    # Add session column for within session data (doesn't have to be added 
    # earlier since all operations were done on single within session file, so 
    # sessions never got averaged)
    if(within_session){
      temp$session = as.numeric(session)
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
                                 mask, '*', xval_split, '*', clf, '*pred.tsv',
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
                  average = average,
                  perm = perm,
                  mc.cores = 4)
  # Append each list element to one data table
  data = data.table(ldply(list, rbind))
  
  # Change factor order of divergence
  data$variable = factor(data$variable,
                         levels = sort(as.numeric(levels(data$variable))))
  
  # If requested, also average over buffers (cant be done before because buffers
  # are separate files)
  if(average & buffering){
    
    # Get columns to average over
    cols = colnames(data)[colnames(data) != 'train_buffer' &
                            colnames(data) != 'value_proba' &
                            colnames(data) != 'value_corr']
    
    data = data %>%
      dplyr::group_by_at(cols) %>%
      dplyr::summarise(value_proba = mean(value_proba),
                       value_corr = mean(value_corr)) %>%
      as.data.table()

  }
  
  # If timecourse data (not averaged), sort after time course
  if(!average){
    data = data[order(participant_id, session, tr, event)]
  }
  
  return(data)
}
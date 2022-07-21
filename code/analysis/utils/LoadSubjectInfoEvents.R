library(data.table)
library(stringr)

# Function to load and format prediction and correlation
LoadSubjectInfoEvents = function(base_path,
                                 n_bins,
                                 buffering = FALSE){
  
  # Create data table to return results
  data_events = data.table()
  
  # Select files according to buffering
  if(buffering){
    files_pattern = file.path(base_path, 'derivatives', 'glm', 'buffer', 'info', '*', '*')
  } else if(!buffering){
    files_pattern = file.path(base_path, 'derivatives', 'glm', 'no_buffer', 'info', '*', '*')
  }
  files_events = file.path(files_pattern, '*_task-nav_subinfo.json')
  files_names = file.path(files_pattern, '*_task-nav_betanames.tsv')
  # Get all files to load
  files_events = Sys.glob(files_events)
  files_names = Sys.glob(files_names)
  
  # Load Subject Info Events for each participant and session
  for(i_sub in sub_list){
    for(i_ses in c('ses-1','ses-2')){
      
      # Get session number (to enter into data table)
      session = unlist(str_split(i_ses, '-'))[2]
      
      # Restrict files to participant and session
      file_events = files_events[grep(i_sub, files_events)]
      file_events = file_events[grep(i_ses, file_events)]
      file_names = files_names[grep(i_sub, files_names)]
      file_names = file_names[grep(i_ses, file_names)]
      
      # Load respective files
      temp_events = fromJSON(file_events)$onsets
      temp_names = data.table::fread(file_names,
                                     sep = '\t',
                                     header = TRUE)
      
      # For each walking direction
      for(i_dir in seq(n_bins)){
        # Get name of walking direction regressor in subject info
        dir_index = grep(paste('Walking_Fwd_Wal_', i_dir, '_Vis_', i_dir, sep = ''), temp_names$beta_names)
        for(i_split in dir_index){
          # Get onsets for each regressor and add to data table
          temp = data.table(onsets = temp_events[[i_split]])
          # Add identifying variables
          temp$event_type = i_dir
          temp$participant_id = i_sub
          temp$session = session
          temp$group = substr(i_sub, 5, nchar(i_sub) - 3)
          # Get fold and buffer to add to table
          fold = unlist(str_split(temp_names$beta_names[i_split], '_'))
          fold = fold[grep('Split', fold)]
          fold = unlist(str_split(fold, ''))[length(unlist(str_split(fold, '')))]
          fold = as.numeric(fold) + ((as.numeric(session) - 1) * 2)
          temp$fold = fold
          if(buffering){
            buffer = unlist(str_split(temp_names$beta_names[i_split], '_'))
            buffer = buffer[grep('Buffer', buffer)]
            buffer = unlist(str_split(buffer, ''))[length(unlist(str_split(buffer, '')))]
            buffer = as.numeric(buffer)
            temp$buffer = buffer
          }
          
          # Add data for each direction, fold, session, buffer, and participant 
          # together
          data_events = rbind(data_events, temp)
        }
      }
    }
  }
  
  # Sort data frame to be consecutive in time
  if(buffering){
    data_events = data_events[order(participant_id, buffer, session, fold, onsets)]
  } else{
    data_events = data_events[order(participant_id, session, fold, onsets)]
  }
  
  
  # Return data
  return(data_events)
}

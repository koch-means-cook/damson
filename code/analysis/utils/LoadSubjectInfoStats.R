library(data.table)
library(stringr)

# Function to load and format prediction and correlation
LoadSubjectInfoStats = function(base_path,
                                buffering = FALSE){
  
  # Create data table to return results
  data = data.table()
  
  # Select files according to buffering
  if(buffering){
    files_pattern = file.path(base_path, 'derivatives', 'glm', 'buffer', 'info', '*', '*')
  } else if(!buffering){
    files_pattern = file.path(base_path, 'derivatives', 'glm', 'no_buffer', 'info', '*', '*')
  }
  # get all subinfo stats file paths
  files_pattern = file.path(files_pattern, '*subinfo-stats.tsv')
  files = Sys.glob(files_pattern)

  # Load each stat
  for(file in files){
    temp = data.table::fread(file,
                             header = TRUE,
                             sep = '\t')
    # Add buffer as column
    if(buffering){
      buffer = unlist(str_split(temp$xval_event, '_'))
      buffer = buffer[grep('Buffer', buffer)]
      buffer = as.numeric(substr(buffer, 7, 7))
      temp$buffer = buffer  
    }
    # Add fold as column
    fold = unlist(str_split(temp$xval_event, '_'))
    fold = fold[grep('Split', fold)]
    fold = as.numeric(substr(fold, 6, 6))
    fold = fold + (2 * (as.numeric(substr(temp$ses_id, 5, 5)) - 1))
    temp$fold = fold
    # Cut fold and buffer from event name
    temp$xval_event = substr(temp$xval_event, 13, 23)
    # Combine stats of each participant
    data = rbind(data, temp)
  }
  
  # Rename factor levels of events
  data$xval_event = as.factor(data$xval_event)
  levels(data$xval_event) = seq(6)
  
  # Return data
  return(data)
}

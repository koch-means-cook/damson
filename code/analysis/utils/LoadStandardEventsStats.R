library(data.table)
library(dplyr)

# Function to load and format prediction and correlation
LoadStandardEventsStats = function(base_path,
                                   buffering = FALSE){
  
  # Create data table to return results
  data = data.table()
  
  # get all Standard Events stats file paths
  files_pattern = file.path(base_path,
                            'derivatives',
                            'preprocessing',
                            'logfile',
                            '*',
                            '*',
                            '*task-nav_events-standard-walk-fwd-stats.tsv')
  files = Sys.glob(files_pattern)

  # Load each stat
  for(file in files){
    temp = data.table::fread(file, header = TRUE, sep = '\t')
    # Combine stats of each participant
    data = rbind(data, temp)
  }
  
  # If buffer is not required sum up events over buffers and take shortest and 
  # longest event over buffer
  if(!buffering){
    cols = colnames(data)[colnames(data) != 'buffer' &
                            colnames(data) != 'n_events' &
                            colnames(data) != 'shortest' &
                            colnames(data) != 'longest']
    data = data %>%
      group_by_at(cols) %>%
      dplyr::summarise(n_events = sum(n_events),
                       shortest = min(shortest),
                       longest = max(longest))
      
  }
  
  data$bin_by_yaw = as.factor(data$bin_by_yaw)
  
  # Return data
  return(data.table(data))
}

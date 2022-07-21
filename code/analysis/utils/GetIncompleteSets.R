library(data.table)
library(stringr)

# Function to go through data to find missing participants and delete them
GetIncompleteSets = function(data,
                             sub_list,
                             buffering = FALSE){
  
  # Get general missing subjects (that did not run any session or buffer)
  participants = unique(data$participant_id)
  missing = sub_list[!sub_list %in% participants]

  data = data.table(data)
  incomplete_sets = c()
  
  if(buffering){
    # Take only full data sets (both buffers, both sessions)
    for(sub in unique(data$participant_id)){
      # See if each participant has two sessions
      temp = data[participant_id == sub]
      n_sessions = length(unique(temp$session))
      # If not, throw them out
      if(n_sessions < 2){
        incomplete_sets = c(incomplete_sets, sub)
        data = data[participant_id != sub]
      }
    }
    # After incomplete sessions are deleted, see if each complete sessions was 
    # performed in both buffers
    for(sub in unique(data$participant_id)){
      temp = data[participant_id == sub]
      n_sessions = length(unique(temp$session))
      for(i_session in seq(n_sessions)){
        temp = data[participant_id == sub & session == i_session]
        n_buffers = length(unique(temp$buffer))
        if(n_buffers < 2){
          incomplete_sets = c(incomplete_sets, sub)
          data = data[participant_id != sub]
        }
      }
    }
  } else if(!buffering){
    # Take only full data sets (both sessions)
    for(sub in unique(data$participant_id)){
      temp = data[participant_id == sub]
      n_sessions = length(unique(temp$session))
      if(n_sessions < 2){
        incomplete_sets = c(incomplete_sets, sub)
        data = data[participant_id != sub]
      }
    }
  }
  
  # Fuse all missing cases, eliminate duplicates, and sort
  incomplete_sets = c(missing, incomplete_sets)
  incomplete_sets = unique(incomplete_sets)
  incomplete_sets = sort(incomplete_sets)
  
  return(incomplete_sets)
}
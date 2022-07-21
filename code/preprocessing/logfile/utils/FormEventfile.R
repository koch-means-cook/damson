#=====================Function to separate events===========================

FormEventfile = function(data,
                         max_t_between_events,
                         event_name,
                         min_event_duration){
  
  # In case provided data is empty (events of this type do not exist) return
  # an empty event file
  if(nrow(data) == 0){
    events = data.table(matrix(NA, 0, 3))
    colnames(events) = c('Onset', 'Event', 'Duration')
    
    
    # If not then calculate number of events
  } else{
    
    # Create column to hold start of event and it's number
    data$event_nr = NA
    
    # Find separate events by finding difference in timestamp (threshold given by 
    # user)
    time_jump = c(TRUE, diff(data$t) >= max_t_between_events)
    n_jumps = length(which(time_jump))
    
    # In case there are more than one event
    if(n_jumps > 1){
      
      # Number different events
      data$event_nr[time_jump] = seq(n_jumps)
      
      # Find endpoints of previous event (no previous event to first event)
      end_event = (which(time_jump) - 1)[2:n_jumps]
      
      # Add endpoint of last event
      end_event = c(end_event, nrow(data))
      
      # Get duration from start and endpoint of event
      onset_event = data$t[time_jump]
      duration_event = data$t[end_event] - onset_event
      
      
      # In case of only a single event
    } else if(n_jumps == 1){
      
      # Onset and duration are determined by first and last entry
      onset_event = data$t[time_jump]
      duration_event = data$t[nrow(data)] - onset_event
    }
    
    # Form bids conform event file
    events = data.table(onset_event)
    events$Event = event_name
    events$Duration = duration_event
    colnames(events) = c('Onset', 'Event', 'Duration')
    
    # Exclude events not longer than threshold given by user
    events = events[Duration >= min_event_duration]
  }
  
  
  # Return event file
  return(events)
}
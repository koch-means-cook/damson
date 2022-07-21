
library(data.table)
library(dplyr)


SplitEvents = function(data,
                       session,
                       direction_resolved,
                       max_t_between_events,
                       min_event_duration){
  
  # Get time jumps to separate events
  time_jump = c(1,
                which(diff(data$t) >= max_t_between_events) + 1)
  data$time_jump = 0
  data$time_jump[time_jump] = 1
  # Get angle changes to separate events
  angle_jump = c(1,
                 which(diff(data$bin_by_yaw) != 0) + 1)
  data$angle_jump = 0
  # if specified, events have to be consistent in their direction
  if(direction_resolved){
    data$angle_jump[angle_jump] = 1  
  }
  
  # Get different events depending on combined criteria 
  data$event_jump = (data$time_jump + 
                       data$angle_jump)
  event_jump = which(data$event_jump != 0)
  # Number each log of the same event with the same number
  data$event = 0
  for(event_count in seq(length(event_jump))){
    event_start = event_jump[event_count]
    data$event[event_start:nrow(data)] = event_count
  }
  
  # Total number of events (before exclusion)
  events_total = max(unique(data$event))
  
  # Get duration of each event
  events = data.table()
  events$n = unique(data$event)
  events$duration = 0
  for(n_event in events$n){
    t = data[event == n_event]$t
    t_start = t[1]
    t_end = t[length(t)]
    t = t_end - t_start
    # Round to 1 digit after comma (to not exclude e.g. 0.99)
    events$duration[n_event] = round(t, 1)
  }
  
  # Eliminate events based on min duration
  events = events[duration >= min_event_duration]
  data  = data[event %in% events$n]
  # Relabel event number
  for(event_count in seq(length(unique(data$event)))){
    event_name = unique(data$event)[event_count]
    data[event == event_name]$event = event_count
  }
  
  # Get number of events left
  events_cut = nrow(events)
  
  # Separate folds of run (by equal event count in both folds)
  events_split = events_cut/2
  # If non-even number of events randomly assign left event to any fold
  if(events_split %% 1 != 0){
    events_split = sample(c(events_split + 0.5, events_split - 0.5), 1)
  }
  # Set fold for each half of events
  data$fold = 0
  # Different folds for sessions
  ses_folds = list(c(1,2), c(3,4))
  data[event <= events_split]$fold = ses_folds[[session]][1]
  data[event > events_split]$fold = ses_folds[[session]][2]
  
  # Recount events in fold
  data$event_in_fold = 0
  for(fold_count in seq(length(unique(data$fold)))){
    
    fold_id = unique(data$fold)[fold_count]
    
    for(event_count in seq(length(unique(data[fold == fold_id]$event)))){
      event_name = unique(data[fold == fold_id]$event)[event_count]
      data[event == event_name]$event_in_fold = event_count
    }
  }
  
  
  # Set buffer for events
  data$buffer = 0
  data[event %% 2 == 1]$buffer = 1
  data[event %% 2 == 0]$buffer = 2
  
  # Select relevant columns
  data = data %>%
    dplyr::select(t,
           x,
           y,
           speed,
           turn_speed_by_loc,
           turn_speed_by_yaw,
           turn_dir_by_loc,
           turn_dir_by_yaw,
           angle_by_loc,
           angle_by_yaw,
           bin_by_loc,
           bin_by_yaw,
           tr,
           tr_adj,
           buffer,
           event,
           event_in_fold,
           fold)
  data = data.table(data)
  
  return(data)
  
}
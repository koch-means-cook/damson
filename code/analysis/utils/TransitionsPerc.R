# Function to count percentages of transitions in following events
TransitionsPerc = function(data, n_bins){
  
  x = data$transitions
  
  # Get possible transitions
  trans = seq(n_bins)
  trans = trans - n_bins/2
  
  # Overall number of events
  n_events = length(x)
  
  # Initialize array holding counts for each transition
  counts = trans * 0
  
  # Count possible transitions
  for(trans_count in seq(length(trans))){
    trans_id = trans[trans_count]
    counts[trans_count] = sum(as.numeric(x == trans_id), na.rm = TRUE)
  }
  
  # Get relative transitions
  counts = counts / n_events
  names(counts) = trans
  
  return(counts)
}
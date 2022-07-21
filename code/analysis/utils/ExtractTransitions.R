library(data.table)

# Function to extract transition structure in raw decoding
ExtractTransitions = function(data, n_bins, beta = FALSE){
  
  data = data.table(data)
  
  # Get only one entry per event (since event types are consistent within an 
  # event) (only for raw data)
  if(!beta){
    data = data[!duplicated(event)]  
  }
  
  # Add distance of following events
  data$transitions = c(NA, diff(as.numeric(data$event_type)))
  
  # Get maximum distance of two bins in circular space
  max_shift_pos = n_bins/2
  max_shift_neg = (n_bins/2 - 1) * (-1)
  
  # Transform bin distances to circular space
  data[transitions > max_shift_pos]$transitions = (
    data[transitions > max_shift_pos]$transitions - 6
  )
  data[transitions < max_shift_neg]$transitions = (
    data[transitions < max_shift_neg]$transitions + 6
  )
  
  # If beta data, add time gap
  if(beta){
    data$time_gap = c(NA, diff(as.numeric(data$onsets)))
  }
  
  # If raw data, add TR gap between following events
  if(!beta){
    data$tr_gap = c(NA, diff(as.numeric(data$tr)))
  }
  
  
  return(data)
}
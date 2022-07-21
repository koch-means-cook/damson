
# Function to get opposite direction bin 

OppositeBin = function(direction,
                       n_bins){
  
  # Get circular opposite of bin
  if(direction > n_bins/2){
    op = direction - (n_bins/2)
  } else if(direction <= n_bins/2){
    op = direction + (n_bins/2)
  }
  
  return(op)
}
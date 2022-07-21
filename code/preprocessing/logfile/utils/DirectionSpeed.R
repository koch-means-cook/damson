#=====================Function to calculate movement speed in UnrealUnits/ms====

DirectionSpeed <- function(curr_x, curr_y, curr_t, prev_x, prev_y, prev_t){
  
  # Get euclidean distance between points
  distance = sqrt(
    sum(
      (c(curr_x, curr_y) - c(prev_x, prev_y))^2
    )
  )
  
  # Get time passed between logs
  time = curr_t - prev_t
  
  # Get speed per passed time
  speed = round(distance / time, 4)
  
  return(speed)
}
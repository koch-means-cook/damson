#=====================Function to calculate turning direction and speed per 
# timeunit================================================================

TurningSpeed <- function(curr_angle, curr_t, prev_angle, prev_t){
  
  # Skip line if any of compared angles is NA (e.g. not calculated because no 
  # movement)
  if(is.na(curr_angle) | is.na(prev_angle)){
    turn_dir = NA
    turn_speed = NA
    
    # Otherwise calculate angle
  } else{
    # Get shortest distance between two angles (because cyclic measure)
    if(curr_angle > prev_angle){
      left = abs(curr_angle - prev_angle)
      right = 360 - abs(curr_angle - prev_angle)
    } else if(curr_angle < prev_angle){
      left = 360 - abs(curr_angle - prev_angle)
      right = abs(curr_angle - prev_angle)
    } else if(curr_angle == prev_angle){
      right = 0
      left = 0
    }
    
    # Take direction and length of shortest turn
    if(right < left){
      turn_dir = 'right'
      turn_length = right
    } else if(right > left){
      turn_dir = 'left'
      turn_length = left
    } else if(right == left){
      turn_dir = NA
      turn_length = 0
    }
    
    # Get time window in which turn was performed
    turn_time = curr_t - prev_t
    
    # Calculate distance per timeunit to get speed
    turn_speed = round(turn_length / turn_time, 4)
    
  }
  
  # Form and pass output list
  output = list('direction' = turn_dir,
                'speed' = turn_speed)
  return(output)
}
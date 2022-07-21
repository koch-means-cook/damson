#=====================Function to get discrepancy between location and yaw angles===========================

AngleDiff = function(angle_1,
                     angle_2){
  
  # Skip line if any of compared angles is NA (e.g. not calculated because no 
  # movement)
  if(is.na(angle_1) | is.na(angle_2)){
    turn_length = NA
    
    # Otherwise calculate angle
  } else{
    # Get shortest distance between two angles (because cyclic measure)
    if(angle_1 > angle_2){
      left = abs(angle_1 - angle_2)
      right = 360 - abs(angle_1 - angle_2)
    } else if(angle_1 < angle_2){
      left = 360 - abs(angle_1 - angle_2)
      right = abs(angle_1 - angle_2)
    } else if(angle_1 == angle_2){
      right = 0
      left = 0
    }
    
    # Take length of shortest turn
    if(right < left){
      turn_length = right
    } else if(right > left){
      turn_length = left
    } else if(right == left){
      turn_length = 0
    }
    
  }
  
  return(turn_length)
  
}
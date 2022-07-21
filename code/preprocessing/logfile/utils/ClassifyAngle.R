#=====================Function to classify direction angles into bins===========

# variable number of bins (subclasses), bins coded with a natural number 
ClassifyAngle <- function(angle, numberSubclasses, binShift){
  
  # Calculated output variable:
  angleSubclass <-0
  
  # for loop which checks if the angle is in the range between (0 to 360/x); 
  # (360/x to 2* 360/x); ... 
  #   If the angle is -1 (person did not move) ==> Angle category will be -1, 
  #     too.
  #   If the conditions do not apply ==> Angle = 0!
  #   Because of binShift this had to be slightly adjusted (adding the bin shift
  #     to the angle as well as taking care of the last subclass
  #     since it surpasses the 360 ==> 0 border)
  for(i in 1:numberSubclasses){
    
    if(is.na(angle)){
      angleSubclass <- NA
      
    } else if(angle >= (0 + ((i-1)*360/numberSubclasses) + binShift) && angle < (i * (360/numberSubclasses) + binShift)){
      angleSubclass <- i
      
    } else if(i == numberSubclasses && angle >= (0 + ((i-1)*360/numberSubclasses) + binShift) || between(angle, 0, binShift)){
      angleSubclass <- i
      
    }
  }
  
  return(angleSubclass)
}
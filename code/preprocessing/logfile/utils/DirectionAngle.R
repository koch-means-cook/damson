#=====================Function to calculate angle the subject is facing while 
# walking=========================================================

DirectionAngle <- function(curr_x, curr_y, prev_x, prev_y){
  
  # Function description:
  #   Use the consecutive positions of the subject (x1/y1) and (x2/y2) to determine the angle
  #     the subject was heading. 
  #     If a person did not move at all the value is -1
  
  coordX1 = prev_x
  coordY1 = prev_y
  coordX2 = curr_x
  coordY2 = curr_y
  
  # Allocate variables
  deltaX <- 0
  deltaY <- 0
  headDirectionAngle <- 0
  
  # if any of the location data is NA, return NA
  if(any(is.na(c(prev_x, prev_y, curr_x, curr_y)))){
    headDirectionAngle = NA
    
    # Otherwise calculate angle by consecutive locations
  } else{
    # Calculate distances deltaX & deltaY the subject traveled on the x & y coordinate.
    deltaX <- as.numeric(coordX2) - as.numeric(coordX1)
    deltaY <- as.numeric(coordY2) - as.numeric(coordY1)
    
    # Calculate angle person is heading:
    #     Seven possible cases: Four cases + three special cases:
    #
    #         Case #1:  deltaX > 0, deltaY >= 0
    #         Case #2:  deltaX < 0. deltaY >= 0
    #         Case #3:  deltaX < 0, deltaY <= 0
    #         Case #4:  deltaX > 0, deltaY <= 0
    #
    #         Special case #1:    deltaX == 0, deltaY >= 0
    #         Special case #2:    deltaX == 0, deltaY <= 0
    #         Special case #3:    deltaX == 0, deltaY == 0
    
    
    #         Case #1:  deltaX > 0, deltaY >= 0
    if(deltaX > 0 & deltaY >= 0) {
      headDirectionAngle <- ((atan(deltaY/deltaX)*180)/pi) + 0;
      
      #         Case #2:  deltaX < 0. deltaY >= 0 
    } else if(deltaX < 0 & deltaY >= 0) {
      headDirectionAngle <- ((atan(deltaY/deltaX)*180)/pi) + 180;
      
      #         Case #3:  deltaX < 0, deltaY <= 0    
    } else if(deltaX < 0 & deltaY <= 0) {
      headDirectionAngle <- ((atan(deltaY/deltaX)*180)/pi) + 180;
      
      #         Case #4:  deltaX > 0, deltaY <= 0    
    } else if(deltaX > 0 & deltaY <= 0) {
      headDirectionAngle <- ((atan(deltaY/deltaX)*180)/pi) + 360;
      
      #         Special case #1:    deltaX == 0, deltaY >= 0     
    } else if(deltaX == 0 & deltaY > 0) {
      headDirectionAngle <- 90;
      
      #         Special case #2:    deltaX == 0, deltaY <= 0    
    } else if(deltaX == 0 & deltaY < 0) {
      headDirectionAngle <- 270;
      
      #         Special case #3:    deltaX == 0, deltaY == 0
    } else if(deltaX == 0 & deltaY == 0) {
      headDirectionAngle <- NA;
    }
  }
  
  return(round(headDirectionAngle, 4))
}
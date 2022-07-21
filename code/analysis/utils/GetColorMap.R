
# Function to return custom color mapping for plots
GetColorMap = function(figure_names = FALSE){
  
  if(figure_names){
    # Color mapping dictionary
    color_map = c('EVC' = '#8DD4C7',
                  'RSC' ='#FFFDB3',
                  'Left Motor' = '#FB8072',
                  'Hippocampus' = '#FDB462',
                  'Entorhinal\nCortex' = '#B3DE69',
                  'MTL' = '#000000')
  } else{
    # Color mapping dictionary
    color_map = c('EVC' = '#8DD4C7',
                  'lat. Occ. (Vis)' = '#8DD4C7',
                  'Isthmus Cing. (RSC)' ='#FFFDB3',
                  'Precentral (M1)' = '#BEBAD9',
                  'Precentral L (M1)' = '#FB8072',
                  'Precentral R (M1)' = '#80B1D3',
                  'HC' = '#FDB462',
                  'Entorhinal' = '#B3DE69',
                  'MTL' = '#000000')
  }

  return(color_map)
}
library(data.table)
library(plyr)


# Funciton to rename ROIs in data tables
RenameROIs = function(data){
  
  # Get mask factor levels
  data = data.table(data)
  data$mask_index = as.factor(data$mask_index)
  
  # Map old to new names
  old_names = levels(data$mask_index)
  new_names = old_names
  new_names[old_names == '1011-2011'] = 'lat. Occ. (Vis)'
  new_names[old_names == '1005-1011-1021-2005-2011-2021'] = 'EVC'
  new_names[old_names == '1010-2010'] = 'Isthmus Cing. (RSC)'
  new_names[old_names == '1024-2024'] = 'Precentral (M1)'
  new_names[old_names == '1024'] = 'Precentral L (M1)'
  new_names[old_names == '2024'] = 'Precentral R (M1)'
  new_names[old_names == '17-53'] = 'HC'
  new_names[old_names == '1006-2006'] = 'Entorhinal'
  new_names[old_names == '17-53-1006-1016-2006-2016'] = 'MTL'
  
  # Rename factor levels with name mapping
  data$mask_index = plyr::mapvalues(data$mask_index,
                                    from = old_names,
                                    to = new_names)
  
  # Order mask names alphabetically
  data$mask_index = factor(data$mask_index, levels = sort(new_names))

  
  return(data)
}
library(data.table)
library(plyr)
library(dplyr)
library(stringr)
library(parallel)

# Function to load classification accuracy
LoadFuncEvents = function(base_path){
  
  ToTable = function(file_path){
    # Load individual file
    temp = data.table::fread(file_path,
                             sep = '\t',
                             header = TRUE,
                             na.strings = 'n/a')
    
    return(data.table(temp))
  }
  
  # Get folder of saved data
  file_pattern = file.path(base_path,
                           'bids',
                           '*',
                           '*',
                           'func',
                           '*_task-nav_events.tsv',
                           fsep = .Platform$file.sep)
  files = Sys.glob(file_pattern)

  # Apply load function to al files and store in list
  list = mclapply(files,
                  FUN = ToTable,
                  mc.cores = 4)
  # Append each list element to one data table
  data = data.table(ldply(list, rbind))

  return(data)
}
library(data.table)
library(dplyr)
library(stringr)
library(parallel)

# Function to load classification accuracy
LoadRawEvents = function(base_path){
  
  # base_path = here::here()
  
  ToTable = function(file_path){
    # Load individual file
    temp = data.table::fread(file_path,
                             sep = '\t',
                             header = TRUE,
                             na.strings = 'n/a')
    
    # Add participant as column
    id = unlist(str_split(basename(file_path), '_'))
    id = id[grep('sub-', id)]
    temp$participant_id = id
    
    # If within session data, add session as column
    session = unlist(str_split(basename(file_path), '_'))
    session = session[grep('ses-', session)]
    session = unlist(str_split(session, '-'))[2]
    temp$session = as.numeric(session)
    
    return(data.table(temp))
  }

  # Find all files
  file_pattern = file.path(base_path,
                           'derivatives',
                           'preprocessing',
                           'logfile',
                           '*',
                           '*',
                           '*_task-nav_events-raw.tsv',
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
# Clean workspace
rm(list = ls())

# Load required libraries
library(ggplot2)
library(plotrix)
library(data.table)
library(jsonlite)
library(plotly)
library(plyr)
library(stringr)
library(viridis)
library(optparse)
library(here)

MarkPulseFluctuations = function(tr_tolerance){
  
  # Get base path
  base_path = file.path(here::here(), fsep = .Platform$file.sep)
  
  # Load participant.tsv
  participant_dir = file.path(base_path,
                              'bids',
                              'participants.tsv',
                              fsep = .Platform$file.sep)
  participants = data.table(
    read.table(participant_dir, header = TRUE, sep = '\t')
  )
  

  # Convert any '.' that may appear in colnames due to false saving of 
  # participants tsv
  cols = colnames(participants)
  cols = gsub('\\.', '-', cols)
  colnames(participants) = cols
  
  # Add columns about pulse fluctuations
  participants$`pulse_fluc_ses-1` = FALSE
  participants$`pulse_fluc_ses-2` = FALSE
  participants$`pulse_fluc_first_short_ses-1` = 0
  participants$`pulse_fluc_first_short_ses-2` = 0
  participants$`pulse_fluc_n_short_ses-1` = 0
  participants$`pulse_fluc_n_short_ses-2` = 0
  participants$`pulse_fluc_first_long_ses-1` = 0
  participants$`pulse_fluc_first_long_ses-2` = 0
  participants$`pulse_fluc_n_long_ses-1` = 0
  participants$`pulse_fluc_n_long_ses-2` = 0
  participants$`pulse_log_diff_min_ses-1` = 0
  participants$`pulse_log_diff_min_ses-2` = 0
  participants$`pulse_log_diff_max_ses-1` = 0
  participants$`pulse_log_diff_max_ses-2` = 0
  
  # Load adjustment for unreal time logging and scanner time logging drifting apart
  file = file.path(base_path,
                   'derivatives',
                   'preprocessing',
                   'logfile',
                   'drift_adjustment.tsv',
                   fsep = .Platform$file.sep)
  adjustment = read.table(file, sep = '\t', header = TRUE)
  adjustment = data.table(adjustment)
  colnames(adjustment) = c('sub', 'ses', 'adj', 'rmse', 'max_t_diff')
  
  # Get repetition time
  tr = jsonlite::fromJSON(file.path(base_path, 'bids', 'task-nav_bold.json', fsep = .Platform$file.sep))
  tr = tr$RepetitionTime
  
  # Find all logfiles and store file paths in list
  logfile_path = file.path(base_path,
                           'bids',
                           '*',
                           '*',
                           'beh',
                           paste('*',
                                 '*',
                                 'task-nav',
                                 'beh.tsv',
                                 sep = '_'),
                           fsep = .Platform$file.sep)
  files = Sys.glob(logfile_path)
  
  # Give message to user
  cat('Adding out-of-synch pulses...\n')
  
  
  # Loop over each logfile
  for(file in files){
    # Load each line of logfile
    alldata = readLines(file)  
    # Select only lines logging scanner pulses
    pulses = alldata[grep('Scanner Pulse', alldata)]
    # Isolate time stamp in scanner-log lines
    pulses = data.table(t(matrix(unlist(strsplit(pulses, "\\|")), nrow = 3)))
    pulses = dplyr::select(pulses, c(V2))
    # Store all timestamps in array
    colnames(pulses) = 't'
    pulses$t = as.numeric(pulses$t)
    
    # Get ID and session of subject from file name
    sub_id = unlist(str_split(basename(file), '_'))[1]
    ses_id = unlist(str_split(basename(file), '_'))[2]
    # Get participant specific adjustment for drift
    adj = adjustment[sub == sub_id & ses == ses_id]
    adj = adj$adj
    
    # Give message to user
    cat('\t', paste(sub_id, ses_id, sep = '_'), '...\n')
    
    # Remove duplicates in timestamps (e.g. first scanner pulses are logged twice)
    pulses = pulses[!duplicated(pulses)]
    # Adjust for drift using participant specific adjustment
    pulses$t = round(pulses$t * adj, 2)
    
    # Number of overall pulses
    n_pulses = nrow(pulses)
    
    # Max and min of pulse intervals
    min_pulse_diff = min(diff(pulses$t))
    max_pulse_diff = max(diff(pulses$t))
    
    # Get first deviation of pulse timing
    # For pulses that were too close to each other
    if(any(diff(pulses$t) < tr - tr_tolerance)){
      under = which(diff(pulses$t) < tr - tr_tolerance)
      first_under = under[1]
      n_under = length(under)
    } else{
      first_under = 0
      n_under = 0
    }
    # For pulses that were too far apart from each other
    if(any(diff(pulses$t) > tr + tr_tolerance)){
      over = which(diff(pulses$t) > tr + tr_tolerance)[1]
      first_over = over[1]
      n_over= length(over)
    } else{
      first_over = 0
      n_over = 0
    }
    
    # True or False if scanner pulses are out of sync
    if(n_under != 0 | n_over != 0){
      fluc = TRUE
    } else if(n_under == 0 & n_over == 0){
      fluc = FALSE
    }
    
    # Add variables to participant ID
    # For first session
    if(substr(ses_id, nchar(ses_id), nchar(ses_id)) == 1){
      participants[participant_id == sub_id]$`pulse_fluc_ses-1` = fluc
      participants[participant_id == sub_id]$`pulse_fluc_first_short_ses-1` = first_under
      participants[participant_id == sub_id]$`pulse_fluc_n_short_ses-1` = n_under
      participants[participant_id == sub_id]$`pulse_fluc_first_long_ses-1` = first_over
      participants[participant_id == sub_id]$`pulse_fluc_n_long_ses-1` = n_over
      participants[participant_id == sub_id]$`pulse_log_diff_min_ses-1` = min_pulse_diff
      participants[participant_id == sub_id]$`pulse_log_diff_max_ses-1` = max_pulse_diff
      # For second session
    } else if(substr(ses_id, nchar(ses_id), nchar(ses_id)) == 2){
      participants[participant_id == sub_id]$`pulse_fluc_ses-2` = fluc
      participants[participant_id == sub_id]$`pulse_fluc_first_short_ses-2` = first_under
      participants[participant_id == sub_id]$`pulse_fluc_n_short_ses-2` = n_under
      participants[participant_id == sub_id]$`pulse_fluc_first_long_ses-2` = first_over
      participants[participant_id == sub_id]$`pulse_fluc_n_long_ses-2` = n_over
      participants[participant_id == sub_id]$`pulse_log_diff_min_ses-2` = min_pulse_diff
      participants[participant_id == sub_id]$`pulse_log_diff_max_ses-2` = max_pulse_diff
    }
    
  }
  
  # Save updated participants.tsv
  write.table(participants, file = participant_dir, sep = '\t',
              row.names = FALSE, na = 'n/a', col.names = colnames(participants))
  
  # Update json file description for new columns
  json_dir = file.path(base_path, 'bids', 'participants.json', fsep = .Platform$file.sep)
  json = jsonlite::fromJSON(json_dir)
  json$`pulse_fluc_ses-1`$Description = 'Bool if scanner pulse logging in behavioral file got out of sync during ses-1. TRUE if got out of sync.'
  json$`pulse_fluc_first_short_ses-1`$Description = 'First TR that showed a too short interval between scanner pulse logs in ses-1. 0 if there were none.'
  json$`pulse_fluc_n_short_ses-1`$Description = 'Number of scanner pulse logs with a too short interval between one another in ses-1. 0 if there were none.'
  json$`pulse_fluc_first_long_ses-1`$Description = 'First TR that showed a too long interval between scanner pulse logs in ses-1. 0 if there were none.'
  json$`pulse_fluc_n_long_ses-1`$Description = 'Number of scanner pulse logs with a too long interval between one another in ses-1. 0 if there were none.'
  json$`pulse_log_diff_min_ses-1`$Description = 'Shortest interval between two consecutive scanner pulse logs in ses-1'
  json$`pulse_log_diff_max_ses-1`$Description = 'Longest interval between two consecutive scanner pulse logs in ses-1'
  json$`pulse_fluc_ses-2`$Description = 'Bool if scanner pulse logging in behavioral file got out of sync during ses-2. TRUE if got out of sync.'
  json$`pulse_fluc_first_short_ses-2`$Description = 'First TR that showed a too short interval between scanner pulse logs in ses-2. 0 if there were none.'
  json$`pulse_fluc_n_short_ses-2`$Description = 'Number of scanner pulse logs with a too short interval between one another in ses-2. 0 if there were none.'
  json$`pulse_fluc_first_long_ses-2`$Description = 'First TR that showed a too long interval between scanner pulse logs in ses-2. 0 if there were none.'
  json$`pulse_fluc_n_long_ses-2`$Description = 'Number of scanner pulse logs with a too long interval between one another in ses-2. 0 if there were none.'
  json$`pulse_log_diff_min_ses-2`$Description = 'Shortest interval between two consecutive scanner pulse logs in ses-2'
  json$`pulse_log_diff_max_ses-2`$Description = 'Longest interval between two consecutive scanner pulse logs in ses-2'
  # Save json file
  json = jsonlite::toJSON(json, factor = 'string', pretty = TRUE, auto_unbox = TRUE)
  write(json, file = json_dir, )
  
  # Give message to user
  cat('...done!\n')
  
}


# Create options to pass to script
option_list = list(
  make_option(c('--tr_tolerance'),
              type='numeric',
              help='+/- tolerance that when exceeded will flag an out of sync scanner pulse logging',
              metavar = 'TR_TOLERANCE'))


# provide options in list to be callable by script
opt_parser = OptionParser(option_list = option_list)
opt = parse_args(opt_parser)

# Call function with arguments provided by user
MarkPulseFluctuations(tr_tolerance = opt$tr_tolerance)


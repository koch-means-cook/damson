
# Clean workspace
rm(list = ls())

# Load required libraries
library(ggplot2)
library(plotrix)
library(data.table)
library(rjson)
library(plotly)
library(plyr)
library(stringr)
library(viridis)
library(optparse)
library(here)
library(jsonlite)
library(tidyr)


# Function to convert logfile to eventfile
CreateStandardEventfile = function(sub_id,
                                   ses_id,
                                   max_t_between_events,
                                   exclude_reposition_trs,
                                   min_event_duration,
                                   exclude_transfer_phase,
                                   n_bins = 6){
  
  # sub_id = 'sub-younger013'
  # ses_id = 'ses-2'
  # max_t_between_events = 0.19
  # exclude_reposition_trs = TRUE
  # min_event_duration = 1
  # exclude_transfer_phase = TRUE
  # n_bins = 6

  # Get base path
  base_path = file.path(here::here(), fsep = .Platform$file.sep)
  
  # Load pre-written functions
  source_path = file.path(base_path, 'code', 'preprocessing', 'logfile',
                          'utils', fsep = .Platform$file.sep)
  source_files = list.files(source_path, pattern = "[.][rR]$",
                            full.names = TRUE, recursive = TRUE)
  invisible(lapply(source_files, function(x) source(x)))
  
  
  # ===
  # Loading prepared logfile
  # ===
  
  # Give message to user
  cat('Loading prepared logfile...\n')
  
  # Load raw event file
  file = file.path(base_path,
                   'derivatives',
                   'preprocessing',
                   'logfile',
                   sub_id,
                   ses_id,
                   paste(sub_id,
                         ses_id,
                         'task-nav',
                         'events-raw.tsv',
                         sep = '_'),
                   fsep = .Platform$file.sep)
  data = data.table(read.table(file = file,
                               sep = '\t',
                               header = TRUE,
                               check.names = FALSE,
                               na.strings = 'n/a'))
  
  
  # ===
  # Apply exclusion criteria
  # ===
  
  # Give message to user
  cat('Applying exclusion criteria...\n')
  
  # Exclude reposition TR if specified
  if(exclude_reposition_trs){
    # Exclude TRs during which participant was repositioned (adjusted for 
    # hemodynamic lag!)
    reposition_tr = data[type == 'Reposition']$tr_adj
    data = data[!(tr_adj %in% reposition_tr)]
    
    # If not specified, eliminate only reposition entries since they cancel 
    # continuous movement
  } else if(!exclude_reposition_trs){
    data = data[type != 'Reposition']
  }
  
  # If specified, exclude transfer phase
  if(exclude_transfer_phase){
    # Get end of feedback phase from BIDS event file
    file = file.path(base_path,
                     'bids',
                     sub_id,
                     ses_id,
                     'func',
                     paste(sub_id,
                           ses_id,
                           'task-nav',
                           'events.tsv',
                           sep = '_'),
                     fsep = .Platform$file.sep)
    bids_events = data.table(read.table(file = file,
                                        sep = '\t',
                                        header = TRUE,
                                        check.names = FALSE))
    t_end_feedback = (bids_events[event == 'Phase_Feedback']$onset + 
                        bids_events[event == 'Phase_Feedback']$duration)
    # Cut of Transfer phase
    data = data[t <= t_end_feedback]
  }
  
  # Exclude all logs that happened outside of any TR
  
  
  
  # ===
  # Isolate events relevant for decoding
  # ===
  
  data_walking = data[walking == TRUE]
  data_walking_fwd = data[walking_fwd == TRUE]
  data_walking_bwd = data[walking_bwd == TRUE]
  data_turning = data[turning_by_loc == TRUE | turning_by_yaw == TRUE]
  data_standing = data[walking == FALSE]
  # Getting direction during standing needs YAW information
  data_standing_dir = data[walking == FALSE & !is.na(angle_by_yaw)]
  
  
  
  # ===
  # Split events into folds and buffers
  # ===
  
  # Give message to user
  cat('Splitting events into folds and buffers...\n')
  
  # Get session to assign folds (1&2 vs. 3&4)
  session = as.numeric(substr(ses_id, 5, 5))
  
  # Split events
  # General walking (direction irrelevant, includes fwd & bwd)
  data_walking = SplitEvents(data = data_walking,
                             session = session,
                             direction_resolved = FALSE,
                             max_t_between_events = max_t_between_events,
                             min_event_duration = min_event_duration)
  # Walking forward into specific direction
  data_walking_fwd = SplitEvents(data = data_walking_fwd,
                                 session = session,
                                 direction_resolved = TRUE,
                                 max_t_between_events = max_t_between_events,
                                 min_event_duration = min_event_duration)
  # Walking backward into specific direction
  data_walking_bwd = SplitEvents(data = data_walking_bwd,
                                 session = session,
                                 direction_resolved = TRUE,
                                 max_t_between_events = max_t_between_events,
                                 min_event_duration = min_event_duration)
  # General turning (direction irrelevant)
  data_turning = SplitEvents(data = data_turning,
                             session = session,
                             direction_resolved = FALSE,
                             max_t_between_events = max_t_between_events,
                             min_event_duration = min_event_duration)
  # General standing still (viewing direction irrelevant)
  data_standing = SplitEvents(data = data_standing,
                              session = session,
                              direction_resolved = FALSE,
                              max_t_between_events = max_t_between_events,
                              min_event_duration = min_event_duration)
  # Standing still while looking into specific direction
  data_standing_dir = SplitEvents(data = data_standing_dir,
                                  session = session,
                                  direction_resolved = TRUE,
                                  max_t_between_events = max_t_between_events,
                                  min_event_duration = min_event_duration)


  # ===
  # Save standard eventfiles
  # ===

  # Give message to user
  cat('Saving standard eventfiles...\n')
  
  # Form list of eventfiles to save and their names
  eventfile_list = list(data_walking,
                        data_walking_fwd,
                        data_walking_bwd,
                        data_turning,
                        data_standing,
                        data_standing_dir)
  eventfile_names = list('events-standard-walk.tsv',
                         'events-standard-walk-fwd.tsv',
                         'events-standard-walk-bwd.tsv',
                         'events-standard-turn.tsv',
                         'events-standard-stand.tsv',
                         'events-standard-stand-dir.tsv')
  
  # Save eventfiles
  for(file_count in seq(length(eventfile_list))){
    
    file = file.path(base_path,
                     'derivatives',
                     'preprocessing',
                     'logfile',
                     sub_id,
                     ses_id,
                     paste(sub_id,
                           ses_id,
                           'task-nav',
                           eventfile_names[[file_count]],
                           sep = '_'),
                     fsep = .Platform$file.sep)
    
    # Save eventfile as .tsv
    fwrite(eventfile_list[[file_count]],
           file = file,
           sep = '\t',
           row.names = FALSE,
           col.names = TRUE,
           na = 'n/a',
           quote = FALSE)

  }
  
  # Get event statistics for walking events
  data_walking_fwd$sub_id = sub_id
  data_walking_fwd$ses_id = ses_id
  
  # Get length of each event
  event_stats_walk_fwd = data_walking_fwd %>%
    mutate(bin_by_yaw = factor(bin_by_yaw, levels = seq(n_bins))) %>%
    group_by(sub_id, ses_id, fold, buffer, bin_by_yaw, event) %>%
    dplyr::summarise(event_length = max(t) - min(t))

  # Get number of events and max and min duration
  event_stats_walk_fwd = event_stats_walk_fwd %>%
    group_by(sub_id, ses_id, fold, buffer, bin_by_yaw) %>%
    dplyr::summarise(n_events = length(event),
                     shortest = round(min(event_length), 2),
                     longest = round(max(event_length), 2)) %>%
    tidyr::complete(bin_by_yaw, fill = list(n_events = 0,
                                            shortest = 0,
                                            longest = 0))
  
  # Save event statistics
  file = file.path(base_path,
                   'derivatives',
                   'preprocessing',
                   'logfile',
                   sub_id,
                   ses_id,
                   paste(sub_id,
                         ses_id,
                         'task-nav',
                         'events-standard-walk-fwd-stats.tsv',
                         sep = '_'),
                   fsep = .Platform$file.sep)
  # Save as .tsv
  fwrite(event_stats_walk_fwd,
         file = file,
         sep = '\t',
         row.names = FALSE,
         col.names = TRUE,
         na = 'n/a',
         quote = FALSE)
  
}

# Create options to pass to script
option_list = list(
  make_option(c('--sub_id'),
              type='character',
              help='ID of participant to create Bids eventfile for',
              metavar = 'SUB_ID'),
  make_option(c('--ses_id'),
              type='character',
              help='Session ID to create Bids eventfile for (e.g. "ses-1")',
              metavar = 'SES_ID'),
  make_option(c('--max_t_between_events'),
              type='numeric',
              default = 0.19,
              help = 'Maximum time allowed between events of the same type to still be counted as one event',
              metavar = 'MAX_T_BETWEEN_EVENTS'),
  make_option(c('--exclude_reposition_trs'),
              type='logical',
              default = TRUE,
              help = 'Excluding the whole TRs in which participant was repositioned. If TRUE, whole TR will be excluded',
              metavar = 'EXCLUDE_REPOSITION_TR'),
  make_option(c('--min_event_duration'),
              type='numeric',
              default = 1,
              help = 'Minimum time an event is allowed to last (exception: button presses)',
              metavar = 'MIN_EVENT_DURATION'),
  make_option(c('--exclude_transfer_phase'),
              type='logical',
              default = TRUE,
              help = 'Excluding transfer phase due to change of landmark and boundary. If TRUE, transfer phase will be excluded',
              metavar = 'EXCLUDE_TRANSFER_PHASE'))


# provide options in list to be callable by script
opt_parser = OptionParser(option_list = option_list)
opt = parse_args(opt_parser)

# Call function with arguments provided by user
CreateStandardEventfile(sub_id = opt$sub_id,
                        ses_id = opt$ses_id,
                        max_t_between_events = opt$max_t_between_events,
                        exclude_reposition_trs = opt$exclude_reposition_trs,
                        min_event_duration = opt$min_event_duration,
                        exclude_transfer_phase = opt$exclude_transfer_phase)


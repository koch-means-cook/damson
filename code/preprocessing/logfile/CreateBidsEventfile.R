
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


# Function to convert logfile to eventfile
CreateBidsEventfile = function(sub_id,
                               ses_id,
                               max_t_between_events,
                               min_event_duration,
                               n_dir_bins,
                               save_timetable){

  # sub_id = 'sub-older097'
  # ses_id = 'ses-1'
  # max_t_between_events = 0.19
  # min_event_duration = 0.5
  # n_dir_bins = 6
  # save_timetable = TRUE


  # Get base path
  base_path = file.path(here::here(), fsep = .Platform$file.sep)
  
  # Load pre-written functions
  source_path = file.path(base_path, 'code', 'preprocessing', 'logfile',
                          'utils', fsep = .Platform$file.sep)
  source_files = list.files(source_path, pattern = "[.][rR]$",
                            full.names = TRUE, recursive = TRUE)
  invisible(lapply(source_files, function(x) source(x)))
  
  # Load information about pulse fluctuations
  participants_dir = file.path(base_path, 'bids', 'participants.tsv')
  participants = data.table(
    read.table(participants_dir, sep = '\t', header = TRUE, na.strings = 'n/a',
               check.names = FALSE))
  
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
  # Get time drift adjustment
  # ===
  
  # Load adjustment
  file = file.path(base_path,
                   'derivatives',
                   'preprocessing',
                   'logfile',
                   'drift_adjustment.tsv',
                   fsep = .Platform$file.sep)
  adjustment = read.table(file, sep = '\t', header = TRUE)
  adjustment = data.table(adjustment)
  colnames(adjustment) = c('sub', 'ses', 'adj', 'rmse', 'max_t_diff')
  adjustment = adjustment[sub == sub_id & ses == ses_id]
  adjustment = adjustment$adj
  
  
  # ===
  # Get Onset/duration of events
  # ===
  
  # Give message to user
  cat('Isolating Onset and Duration of events...\n')
  
  
  # Get standing events
  standing = data[walking == FALSE]
  events_standing = FormEventfile(standing,
                                  max_t_between_events = max_t_between_events,
                                  event_name = 'Standing',
                                  min_event_duration = min_event_duration)
  
  # Get general walking events (without separating fwd/bwd, viewing dir,
  # walking dir)
  walking = data[walking == TRUE]
  events_walking = FormEventfile(walking,
                                 max_t_between_events = max_t_between_events,
                                 event_name = 'Walking',
                                 min_event_duration = min_event_duration)
  
  # Events for walking forward
  walking_fwd = walking[walking_fwd == TRUE]
  events_walking_fwd = FormEventfile(walking_fwd,
                                     max_t_between_events = max_t_between_events,
                                     event_name = 'Walking_Fwd',
                                     min_event_duration = min_event_duration)
  
  # Events for walking backwards
  walking_bwd = walking[walking_bwd == TRUE]
  events_walking_bwd = FormEventfile(walking_bwd,
                                     max_t_between_events = max_t_between_events,
                                     event_name = 'Walking_Bwd',
                                     min_event_duration = min_event_duration)
  
  # Events for walking into different directions
  # Create template to append events for all bins
  events_walking_fwd_dir = data.table(matrix(NA, 0, 3))
  colnames(events_walking_fwd_dir) = c('Onset', 'Event', 'Duration')
  # Loop over different direction bins
  for(direction in seq(n_dir_bins)){
    # Reset template for specific direction
    events = events_walking_fwd_dir[0,]
    # Get name of event for each direction
    event_name = paste('Walking_Fwd_Wal_',
                       direction,
                       '_Vis_',
                       direction,
                       sep = '')
    # Restrict walking data to certain direction
    walking_fwd_dir = walking_fwd[bin_by_yaw == direction]
    # Isolate events for each direction
    events = FormEventfile(walking_fwd_dir,
                           max_t_between_events = max_t_between_events,
                           event_name = event_name,
                           min_event_duration = min_event_duration)
    # Append each direction-specific event file
    events_walking_fwd_dir = rbind(events_walking_fwd_dir, events)
  }
  
  # Events for walking into different directions
  # Create template to append events for all bins
  events_walking_bwd_dir = data.table(matrix(NA, 0, 3))
  colnames(events_walking_bwd_dir) = c('Onset', 'Event', 'Duration')
  # Loop over different direction bins
  for(direction in seq(n_dir_bins)){
    # Reset template for specific direction
    events = events_walking_bwd_dir[0,]
    # Get name of event for each direction
    event_name = paste('Walking_Bwd_Wal_',
                       OppositeBin(direction = direction,
                                   n_bins = n_dir_bins),
                       '_Vis_',
                       direction,
                       sep = '')
    # Restrict walking data to certain direction
    walking_bwd_dir = walking_bwd[bin_by_yaw == direction]
    # Isolate events for each direction
    events = FormEventfile(walking_bwd_dir,
                           max_t_between_events = max_t_between_events,
                           event_name = event_name,
                           min_event_duration = min_event_duration)
    # Append each direction-specific event file
    events_walking_bwd_dir = rbind(events_walking_bwd_dir, events)
  }
  
  # Events for turning (rotating)
  turning = data[turning_by_loc == TRUE | turning_by_yaw == TRUE]
  events_turning = FormEventfile(data = turning,
                                 max_t_between_events = max_t_between_events,
                                 event_name = 'Turning',
                                 min_event_duration = min_event_duration)
  
  # Events for turning right
  turning_right = turning[turning_right_by_loc == TRUE | turning_right_by_yaw == TRUE]
  events_turning_right = FormEventfile(data = turning_right,
                                       max_t_between_events = max_t_between_events,
                                       event_name = 'Turning_Right',
                                       min_event_duration = min_event_duration)
  
  # Events for turning left
  turning_left = turning[turning_left_by_loc == TRUE | turning_left_by_yaw == TRUE]
  events_turning_left = FormEventfile(data = turning_left,
                                      max_t_between_events = max_t_between_events,
                                      event_name = 'Turning_Left',
                                      min_event_duration = min_event_duration)
  
  
  # Load logfile for events not related to movement
  logfile_path = file.path(base_path,
                           'bids',
                           sub_id,
                           ses_id,
                           'beh',
                           paste(sub_id,
                                 ses_id,
                                 'task-nav',
                                 'beh.tsv',
                                 sep = '_'),
                           fsep = .Platform$file.sep)
  alldata = readLines(logfile_path)
  
  # Get time of first pulse
  pulses = alldata[grep('Scanner Pulse', alldata)]
  pulses = data.table(t(matrix(unlist(strsplit(pulses, "\\|")), nrow = 3)))
  pulses = dplyr::select(pulses, c(V2))
  colnames(pulses) = 't'
  pulses$t = as.numeric(pulses$t)
  
  # Remove duplicates in timestamps (e.g. first scanner pulses are logged twice)
  pulses = pulses[!duplicated(pulses)]
  
  # If there were no fluctuations in pulse logging:
  # Adjust for Unreal drift
  pulses$t = round(pulses$t * adjustment, 2)
  # Time of first pulse
  t_first_pulse = pulses$t[1]
  
  # Events for TR
  events_tr = data.table()
  # Get repetition time
  tr = jsonlite::fromJSON(file.path(base_path, 'bids', 'task-nav_bold.json', fsep = .Platform$file.sep))
  tr = tr$RepetitionTime
  
  # if there were pulse fluctuations, the TRs were calculated and won't need to 
  # be checked
  pulse_fluc = unlist(
    c(participants[participant_id == sub_id, 'pulse_fluc_ses-1'],
      participants[participant_id == sub_id, 'pulse_fluc_ses-2'])
    )
  if(pulse_fluc[as.numeric(substr(ses_id, 5, 5))]){
    onsets = ddply(data, 'tr', dplyr::summarise, t = t[1])
    events_tr$Onset = onsets$t
    events_tr$Duration = tr
    events_tr$Event = 'TR'
    events_tr$Tr_Count = seq(nrow(events_tr))
  } else{
    events_tr$Onset = pulses$t
    # Get duration of events
    events_tr$Duration = c(diff(events_tr$Onset), tr)
    events_tr$Event = 'TR'
    # Number of TRs in Raw logfile is upper boundary for number of events
    # Ignore NAs introduced by scanner pulses taking longer than 2.36s
    trs_raw = sort(unique(data$tr[!is.nan(data$tr)]))
    # In case pulses were sent too close to each other (< 0.1s) and 
    # depending on when it was send (e.g. between to timestamps of the logfile)
    # a TR might not be logged in the raw file (since in the time between two 
    # scanner pulses there was not logging of movement). If this is the case 
    # artifically insert a TR. This will make all following TRs unsuited for 
    # analysis since logfiles and recorded TRs do not match anymore which is 
    # addressed in another script 
    if(any(diff(pulses$t) < 0.1) & length(trs_raw) < nrow(pulses)){
      trs_raw = sort(c(trs_raw, which(diff(pulses$t) < 0.1)))
    }
    # Adjust number of TRs to raw eventfile if they do not match
    if(length(trs_raw) < nrow(events_tr)){
      events_tr = events_tr[1:length(trs_raw),]
    }
    events_tr$Tr_Count = seq(nrow(events_tr))
    
    # Check if TRs counts line up (no TR was skipped/eliminated
    if(any(events_tr$Tr_Count != trs_raw)){
      stop('TRs between raw eventfile and bids eventfile do not line up')
    }
  }
  
  # Get shown cues
  events_cue = alldata[grep('Cue', alldata)]
  events_cue = data.table(
    t(matrix(unlist(strsplit(events_cue, "\\|")), nrow = 5))
  )
  events_cue = dplyr::select(events_cue, c(V2, V5))
  colnames(events_cue) = c('Onset', 'Object')
  # Get times cues started (since given cue and start of cue is not logged at 
  # the same time)
  time_cue = alldata[grep('CUE_start', alldata)]
  time_cue = data.table(
    t(matrix(unlist(strsplit(time_cue, "\\|")), nrow = 3))
  )
  time_cue = dplyr::select(time_cue, V2)
  colnames(time_cue) = 'Onset'
  # Take only complete CUE presentation (missing cue starts can be introduced
  # by dropping the object during the ITI period)
  if(nrow(time_cue) < nrow(events_cue)){
    events_cue = events_cue[0:nrow(time_cue),]
  }
  # Set time cues started (number of given cues and started cues match)
  events_cue$Onset = as.numeric(time_cue$Onset)
  # Adjust for Unreal time drift
  events_cue$Onset = round(events_cue$Onset * adjustment, 2)
  # Adjust cue time to new t=0 (first scanner pulse)
  events_cue$Onset = events_cue$Onset - t_first_pulse
  # Add duration (always the same length of cue, 4s, time between CUE_start and 
  # FIX_start)
  events_cue$Duration = 4
  # Cut repetitive pattern from object name
  events_cue$Object = str_remove(events_cue$Object, 'Neuro2.Obj.t_')
  # Give event name
  events_cue$Event = 'Cue'
  
  # ITIs
  events_iti = alldata[grep('ITI_start', alldata)]
  events_iti = data.table(
    t(matrix(unlist(strsplit(events_iti, "\\|")), nrow = 3))
  )
  events_iti = dplyr::select(events_iti, V2)
  colnames(events_iti) = 'Onset'
  events_iti$Onset = as.numeric(events_iti$Onset)
  # Adjust for Unreal time drift
  events_iti$Onset = round(events_iti$Onset * adjustment, 2)
  # Fixed duration for all ITIs (2s, time between ITI_start and NAVI_start)
  events_iti$Duration = 2
  # Give event name
  events_iti$Event = 'ITI'
  # Adjust time to new t=0 (first scanner pulse)
  events_iti$Onset = events_iti$Onset - t_first_pulse
  
  # Grabs
  events_grab = alldata[grep('Grab', alldata)]
  events_grab = data.table(
    t(matrix(unlist(strsplit(events_grab, "\\|")), nrow = 8))
  )
  events_grab = dplyr::select(events_grab, c(V2, V3, V4))
  colnames(events_grab) = c('Onset', 'Event', 'Object')
  events_grab$Onset = as.numeric(events_grab$Onset)
  # Adjust for Unreal time drift
  events_grab$Onset = round(events_grab$Onset * adjustment, 2)
  # Adjust time to new t=0 (first scanner pulse)
  events_grab$Onset = events_grab$Onset - t_first_pulse
  # Cut repetitive pattern from object name
  events_grab$Object = str_remove(events_grab$Object, 'Neuro2.Obj.t_')
  # Duration for grab is 0 (since only button press)
  events_grab$Duration = 0
  
  # Trial Time-Outs
  events_timeout = alldata[grep('TimeOutTrial', alldata)]
  # in case there are any trials where time ran out
  if(length(events_timeout) != 0){
    # Form event file
    events_timeout = data.table(
      t(matrix(unlist(strsplit(events_timeout, "\\|")), nrow = 3))
    )
    events_timeout = dplyr::select(events_timeout, V2)
    colnames(events_timeout) = 'Onset'
    events_timeout$Onset = as.numeric(events_timeout$Onset)
    # Adjust for Unreal time drift
    events_timeout$Onset = round(events_timeout$Onset * adjustment, 2)
    # Adjust time to new t=0 (first scanner pulse)
    events_timeout$Onset = events_timeout$Onset - t_first_pulse
    events_timeout$Event = 'Trial_Time_Out'
    # Duration of event is 0
    events_timeout$Duration = 0
    
    # In case there are no timed out trials
  } else if(length(events_timeout) == 0){
    # Create empty event file
    events_timeout = data.table(matrix(NA, 0, 3))
    colnames(events_timeout) = c('Onset', 'Event', 'Duration')
  }
  
  
  # Phases
  # Find all phase changes ("Tranfer" typo on purpose, that's what it say in 
  # the log)
  events_phase = c(alldata[grep('StartPhase1', alldata)],
                   alldata[grep('StartPhase2', alldata)],
                   alldata[grep('Start Final Tranfer', alldata)])
  events_phase = data.table(
    t(matrix(unlist(strsplit(events_phase, '\\|')), nrow = 3))
  )
  events_phase = dplyr::select(events_phase, c(V2, V3))
  colnames(events_phase) = c('Onset', 'Event')
  events_phase$Onset = as.numeric(events_phase$Onset)
  # Adjust for Unreal time drift
  events_phase$Onset = round(events_phase$Onset * adjustment, 2)
  # Adjust time to new t=0 (first scanner pulse)
  events_phase$Onset = events_phase$Onset - t_first_pulse
  # Get duration
  events_phase$Duration = c(diff(events_phase$Onset),
                            data$t[nrow(data)] - events_phase$Onset[nrow(events_phase)])
  # Rename events to phase starts
  events_phase[Event == 'StartPhase1']$Event = 'Phase_Encoding'
  events_phase[Event == 'StartPhase2']$Event = 'Phase_Feedback'
  events_phase[Event == 'Start Final Tranfer']$Event = 'Phase_Transfer'
  
  
  # Get correct locations of all used objects
  correct_locations = alldata[grep('Show', alldata)]
  correct_locations = data.table(
    t(matrix(unlist(strsplit(correct_locations, "\\|")), nrow = 8))
  )
  correct_locations = dplyr::select(correct_locations, c(V4, V6, V8))
  colnames(correct_locations) = c('Object', 'X_Correct', 'Y_Correct')
  # Cut repetitive pattern from object name
  correct_locations$Object = str_remove(correct_locations$Object,
                                        'Neuro2.Obj.t_')
  # Remove duplicates because location stays the same
  correct_locations = unique(correct_locations)
  
  
  # Drops
  events_drop = alldata[grep('\\|Drop', alldata)]
  events_drop = data.table(
    t(matrix(unlist(strsplit(events_drop, "\\|")), nrow = 8))
  )
  events_drop = dplyr::select(events_drop, c(V2, V3, V4, V6, V8))
  colnames(events_drop) = c('Onset', 'Event', 'Object', 'X_Drop', 'Y_Drop')
  events_drop$Onset = as.numeric(events_drop$Onset)
  # Adjust for Unreal time drift
  events_drop$Onset = round(events_drop$Onset * adjustment, 2)
  # Adjust time to new t=0 (first scanner pulse)
  events_drop$Onset = events_drop$Onset - t_first_pulse
  # Cut repetitive pattern from object name
  events_drop$Object = str_remove(events_drop$Object, 'Neuro2.Obj.t_')
  # Enter correct locations to drop events
  events_drop$X_Correct = 0
  events_drop$Y_Correct = 0
  for(object in correct_locations$Object){
    X_Correct = as.numeric(correct_locations[Object == object]$X_Correct)
    Y_Correct = as.numeric(correct_locations[Object == object]$Y_Correct)
    events_drop[Object == object]$X_Correct = X_Correct
    events_drop[Object == object]$Y_Correct = Y_Correct
  }
  # Delete correct locations in transfer phase since there is no correct 
  # solution but different solutions according to boundary or landmark shift
  begin_transfer = events_phase[Event == 'Phase_Transfer']$Onset
  events_drop[Onset > begin_transfer]$X_Correct = NA
  events_drop[Onset > begin_transfer]$Y_Correct = NA
  # Set duration to 0 since it is only a button press
  events_drop$Duration = 0
  
  
  # Environments
  # Environments are changed with reposition to other arena (0|0, 30000|0,
  # 60000|0)
  events_environment = alldata[grep('Reposition', alldata)]
  events_environment = data.table(
    t(matrix(unlist(strsplit(events_environment, "\\|")), nrow = 11))
  )
  events_environment = dplyr::select(events_environment, c(V2, V3, V5, V7))
  colnames(events_environment) = c('Onset', 'Event', 'X', 'Y')
  events_environment$Onset = as.numeric(events_environment$Onset)
  # Adjust for Unreal time drift
  events_environment$Onset = round(events_environment$Onset * adjustment, 2)
  # Adjust for first time pulse
  events_environment$Onset = events_environment$Onset - t_first_pulse
  events_environment$X = as.numeric(events_environment$X)
  # Get environment (three different possible environments, reposition to new 
  # environment ALWAYS ports the player to center of that environment: 
  # (0|0) vs. (30000|0) vs. (60000|0)
  events_environment[X == 0]$Event = 'Environment_1'
  events_environment[X == 30000]$Event = 'Environment_2'
  events_environment[X == 60000]$Event = 'Environment_3'
  # Fuse events to one in case they don't change
  change_lines = c(1, (which(diff(events_environment$X) != 0)) + 1)
  events_environment = events_environment[change_lines,]
  # Get duration of events
  events_environment$Duration = c(diff(events_environment$Onset),
                                  data$t[nrow(data)] - events_environment$Onset[nrow(events_environment)])
  # Delete unneccessary columns
  events_environment = dplyr::select(events_environment, c('Onset',
                                                    'Event',
                                                    'Duration'))
  
  # Trials
  # Each trial starts with the Cue onset
  events_trials = alldata[grep('CUE_start', alldata)]
  events_trials = data.table(
    t(matrix(unlist(strsplit(events_trials, "\\|")), nrow = 3))
  )
  events_trials = dplyr::select(events_trials, V2)
  colnames(events_trials) = 'Onset'
  events_trials$Onset = as.numeric(events_trials$Onset)
  # Adjust for Unreal time drift
  events_trials$Onset = round(events_trials$Onset * adjustment, 2)
  # Adjust for first pulse
  events_trials$Onset = events_trials$Onset - t_first_pulse
  # Name trials
  events_trials$Event = 'Trial'
  events_trials$Trial = seq(nrow(events_trials))
  # Get duration of Trial by last Drop/Grab before next trial
  events_trials$Duration = 0
  for(trial in seq(nrow(events_trials) - 1)){
    lower = events_trials$Onset[trial]
    upper = events_trials$Onset[trial + 1]
    
    drop_time = events_drop[Onset > lower & Onset <= upper]$Onset
    grab_time = events_grab[Onset > lower & Onset <= upper]$Onset
    
    trial_end = max(c(drop_time, grab_time))
    events_trials$Duration[trial] = trial_end - events_trials$Onset[trial]
  }
  # Duration of last trial given by last drop (no grabs in transfer phase)
  last_drop = events_drop$Onset[nrow(events_drop)]
  events_trials[nrow(events_trials)]$Duration = (last_drop - events_trials[nrow(events_trials)]$Onset)
  
  
  # Landmark position
  # Get logs of all LMs positions at beginning of logfile
  lm_pos = alldata[grep('LMLoc', alldata)]
  lm_pos = data.table(
    t(matrix(unlist(strsplit(lm_pos, "=")), nrow = 2))
  )
  lm_pos = lm_pos$V2
  # Get location of LM for each environment
  lm_pos = data.table(str_split(lm_pos, ',', simplify = TRUE))
  colnames(lm_pos) = c('X', 'Y', 'Z')
  lm_pos = dplyr::select(lm_pos, c('X', 'Y'))
  lm_pos$X = as.numeric(lm_pos$X)
  lm_pos$Y = as.numeric(lm_pos$Y)
  lm_pos$Environment = seq(nrow(lm_pos))
  # Environment changes are the same as landmark changes (t already relative to 
  # first scanner pulse and adjusted for unreal drift)
  events_lm = events_environment
  # Add position of LM for each environment
  events_lm$X_Landmark = 0
  events_lm$Y_Landmark = 0
  # Environment 1
  events_lm[Event == 'Environment_1']$X_Landmark = lm_pos[Environment == 1]$X
  events_lm[Event == 'Environment_1']$Y_Landmark = lm_pos[Environment == 1]$Y
  # Environment 2
  events_lm[Event == 'Environment_2']$X_Landmark = lm_pos[Environment == 2]$X
  events_lm[Event == 'Environment_2']$Y_Landmark = lm_pos[Environment == 2]$Y
  # Environment 3
  events_lm[Event == 'Environment_3']$X_Landmark = lm_pos[Environment == 3]$X
  events_lm[Event == 'Environment_3']$Y_Landmark = lm_pos[Environment == 3]$Y
  # Changed position of landmark in env 1 during transfer phase
  lm_pos_trans = grep('LM Movement', alldata) + 1
  lm_pos_trans = alldata[lm_pos_trans]
  # If there was a transfer phase and a third environment, get the updated position
  if(length(lm_pos_trans != 0)){
    lm_pos_trans = data.table(
      t(matrix(unlist(str_split(lm_pos_trans, ' ')), nrow = 9))
    )
    lm_pos_trans = dplyr::select(lm_pos_trans, c(V6, V9))
    colnames(lm_pos_trans) = c('X', 'Y')
    # In case there was no transfer phase use placeholder
  } else{
    lm_pos_trans = data.frame(matrix(0,2,2))
    colnames(lm_pos_trans) = c('X', 'Y')
    lm_pos_trans$X = '0,'
    lm_pos_trans$Y = 0
    lm_pos_trans = data.table(lm_pos_trans)
  }
  
  # Raise error is landmark reposition is not identical in transfer phase
  if(lm_pos_trans$X[1] != lm_pos_trans$X[2]){
    stop('Reposition of landmark during transfer phase has more than 1 value.')
  }
  # Transform into numeric values (+ deleting comma in x coordinate)
  lm_pos_trans$X = unlist(str_split(lm_pos_trans$X, ','))[1]
  lm_pos_trans$X = as.numeric(lm_pos_trans$X)
  lm_pos_trans$Y = as.numeric(lm_pos_trans$Y)
  # Update LM position in Env 1 during transfer phase
  start_transfer = events_phase[Event == 'Phase_Transfer']$Onset
  events_lm[Onset >= start_transfer & Event == 'Environment_1']$X_Landmark = lm_pos_trans$X[1]
  events_lm[Onset >= start_transfer & Event == 'Environment_1']$Y_Landmark = lm_pos_trans$Y[1]
  # Rename events
  events_lm[Onset >= start_transfer & Event == 'Environment_1']$Event = 'Lm_Env_1_Pos_2'
  events_lm[Event == 'Environment_1']$Event = 'Lm_Env_1_Pos_1'
  events_lm[Event == 'Environment_2']$Event = 'Lm_Env_2'
  events_lm[Event == 'Environment_3']$Event = 'Lm_Env_3'
  
  
  
  
  
  # ===
  # Merge all events
  # ===
  
  # Give message to user
  cat('Merging all events...\n')
  
  # Create template for all events
  events = data.table(matrix(NA, 0, 3))
  colnames(events) = c('Onset', 'Event', 'Duration')
  events$Onset = as.numeric(events$Onset)
  events$Event = as.character(events$Event)
  events$Duration = as.numeric(events$Duration)
  
  # List all event files
  event_list = list(events_cue,
                    events_drop,
                    events_grab,
                    events_lm,
                    events_tr,
                    events_environment,
                    events_iti,
                    events_phase,
                    events_standing,
                    events_timeout,
                    events_trials,
                    events_turning,
                    events_turning_left,
                    events_turning_right,
                    events_walking,
                    events_walking_bwd,
                    events_walking_bwd_dir,
                    events_walking_fwd,
                    events_walking_fwd_dir)
  
  # Merge all events
  for(count in seq(length(event_list))){
    events = rbind(events, event_list[[count]], fill = TRUE)
  }
  # Sort by Onset
  events = events[order(Onset)]
  
  
  # ===
  # Plot time-table of events
  # ===
  
  # Save plot only if specified
  if(save_timetable){
    
    # Give message to user
    cat('Plotting time table of events...\n')
    
    # prepare data for plotting
    data_plot = events
    end_encoding = data_plot[Event == 'Phase_Encoding']$Onset + data_plot[Event == 'Phase_Encoding']$Duration
    end_feedback = data_plot[Event == 'Phase_Feedback']$Onset + data_plot[Event == 'Phase_Feedback']$Duration
    
    # Plot time table of events
    p_time_table = ggplot(data=data_plot, aes(x = Event, y = Onset, color = Event, fill = Event)) +
      coord_flip() +
      geom_crossbar(aes(ymin = Onset, ymax = Onset + Duration),
                    width = 0.8,
                    fatten = 0) +
      geom_hline(yintercept = end_encoding,
                 color = 'black',
                 linetype = 'dashed') +
      geom_hline(yintercept = end_feedback,
                 color = 'black',
                 linetype = 'dashed') +
      scale_color_viridis(option = 'D', discrete = TRUE) +
      scale_fill_viridis(option = 'D', discrete = TRUE) +
      scale_y_continuous(breaks = seq(0, max(data_plot$Onset), by = 200),
                         expand = c(0,0)) +
      labs(title = paste(sub_id, '_', ses_id,  ' - Event Time-Table',
                         sep = ''),
           y = 'Event Onset and Duration') +
      theme(legend.position = 'none',
            plot.title = element_text(face = 'bold', hjust = 0.5),
            axis.title.y = element_blank())
    
    # Get location to save plot
    save_dir = file.path(base_path,
                         'derivatives',
                         'preprocessing',
                         'logfile',
                         sub_id,
                         ses_id,
                         fsep = .Platform$file.sep)
    
    # If folder does not exist yet, create it
    if(!dir.exists(save_dir)){
      dir.create(save_dir, recursive = TRUE)
    }
    
    # Add filename to save path
    save_file = file.path(save_dir,
                          paste(sub_id, ses_id, 'event_timetable.pdf', sep = '_'),
                          fsep = .Platform$file.sep)
    
    # Save plot
    ggsave(save_file, width = 30, height = 10, units = 'in')
    
  }
  
  
  # ===
  # Save eventfile
  # ===
  
  # Give message to user
  cat('Saving eventfile...\n')
  
  # Round output to two digits after comma (milliseconds)
  events$Onset = round(events$Onset, 2)
  events$Duration = round(events$Duration, 2)
  
  # Rename column to bids standard
  events = plyr::rename(events, c(Onset = 'onset',
                                  Duration = 'duration',
                                  Event = 'event',
                                  Object = 'object',
                                  X_Drop = 'x_drop',
                                  Y_Drop = 'y_drop',
                                  X_Correct = 'x_correct',
                                  Y_Correct = 'y_correct',
                                  X_Landmark = 'x_landmark',
                                  Y_Landmark = 'y_landmark',
                                  Trial = 'trial',
                                  Tr_Count = 'tr_count'))
  
  # Add subject and session columns
  events$subject = sub_id
  events$session = as.numeric(substr(ses_id, 5, 5))
  
  # Add intervention column
  file = file.path(base_path, 'bids', 'participants.tsv',
                   fsep = .Platform$file.sep)
  participants = data.table(read.table(file = file,
                                       sep = '\t',
                                       header = TRUE,
                                       check.names = FALSE))
  participants = participants[participant_id == sub_id]
  intervention = c(participants$`intervention_ses-1`,
                   participants$`intervention_ses-2`)
  events$intervention = intervention[as.numeric(substr(ses_id, 5, 5))]
  
  # Set new column order
  col_order = c('onset', 'duration', 'event', 'subject', 'session',
                'intervention', 'tr_count', 'trial', 'object', 'x_drop', 'y_drop',
                'x_correct', 'y_correct', 'x_landmark', 'y_landmark')
  setcolorder(events, col_order)
  
  # Specify path to save eventfile to (bids specification)
  event_path = file.path(base_path,
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
  # Save eventfile as .tsv
  fwrite(events,
         file = event_path,
         sep = '\t',
         row.names = FALSE,
         col.names = TRUE,
         na = 'n/a',
         quote = FALSE)
  
  
  # ===
  # Write .json file for eventfile
  # ===
  
  # # Give message to user
  # cat('Writing and saving .json-file for eventfile...\n')
  # 
  # # Create json object
  # json = list()
  # 
  # # Fill fields of jason object with description
  # json$onset$Description = 'Onset of event in seconds relative to first scanner pulse'
  # json$duration$Description = 'Duration of event starting at the time of onset. Duration of 0 indicates button press'
  # json$event$Description = 'Action performed during event'
  # json$event$Events$Cue$Description = 'Picture of object to place in environment displayed for 4 seconds. Environment is still visible in the background'
  # json$event$Events$Drop$Description = 'Object is dropped/placed at location'
  # json$event$Events$Environment_1$Description = 'Participant is in first, unchanged environment'
  # json$event$Events$Environment_2$Description = 'Participant is in second, changed environment to see possible transfer effects'
  # json$event$Events$Grab$Description = 'Object is picked up at location. All objects during encoding phase or objects with large errors during Feedback phase'
  # json$event$Events$ITI$Description = 'Inter trial interval between sets of five consecutive trials lasting two seconds. Environment not visible during ITI.'
  # json$event$Events$Lm_Env_1_Pos_1$Description = 'Landmark at first position (before change) in first environment. During transfer phase the landmark position changes to see effects on object placement'
  # json$event$Events$Lm_Env_1_Pos_2$Description = 'Landmark at second position (after change) in first environment. During transfer phase the landmark position changes to see effects on object placement'
  # json$event$Events$Lm_Env_2$Description = 'Landmark at position for Environment 2. The landmak in environment 2 does not change during the transfer phase'
  # json$event$Events$Lm_Env_3$Description = 'Landmark at position for Environment 3. The landmak in environment 3 does not change during the transfer phase'
  # json$event$Events$Phase_Encoding$Description = 'Encoding phase of experiment in which subject learns object locations by picking them up'
  # json$event$Events$Phase_Feedback$Description = 'Feedback phase of experiment in which subject places objects at learned locations and gets feedback about location'
  # json$event$Events$Phase_Transfer$Description = 'Transfer phase of experiment in which either landmark position or boundary size of arena changes to see influence on object placement'
  # json$event$Events$Standing$Description = 'Participant is not moving'
  # json$event$Events$TR$Description = 'TR recorded by MRI scanner'
  # json$event$Events$Trial$Description = 'Trial to place object at learned location. Ends either with object placement (if correct) or object pickup (in case of larger error)'
  # json$event$Events$Trial_Time_Out$Description = 'Signal that trial time was exceeded. Object is dropped in place'
  # json$event$Events$Turning$Description = 'Subject turning in virtual environment. Turning while standing still only possible to detect when YAW is logged (beginning of Feedback phase). Direction unspecified'
  # json$event$Events$Turning_left$Description = 'Subject turning left in virtual environment. Turning while standing still only possible to detect when YAW is logged (beginning of Feedback phase)'
  # json$event$Events$Turning_right$Description = 'Subject turning right in virtual environment. Turning while standing still only possible to detect when YAW is logged (beginning of Feedback phase)'
  # json$event$Events$Walking$Description = 'Subject walking in virtual environment. Forward or backward movement can only be distinguished once YAW is logged (beginning Feedback phase).'
  # json$event$Events$Walking_Bwd$Description = 'Subject walking backwards. Direction unspecified.'
  # json$event$Events$Walking_Fwd$Description = 'Subject walking forward. Direction unspecified.'
  # json$event$Events$Phase_Encoding$Description = 'Participant is not moving'
  # #json$subject$Description = 'Subject scanned'
  # #json$session$Description = 'Session scanned. Two sessions in total'
  # #json$intervention$Description = 'Intervention for given session. Pattern either (A/B), (B/A), or (C/C). Partially unblinded: (C/C) meaning placebo in both sessions.'
  # json$tr_count$Description = 'Number of TR recorded in respective time window.'
  # json$trial$Description = 'Trial number. Only relevant for events of type Trial'
  # json$object$Description = 'Object cued, grabbed, or dropped for specific events'
  # json$x_drop$Description = 'x coordinate of location object was dropped in drop events'
  # json$y_drop$Description = 'y coordinate of location object was dropped in drop events'
  # json$x_correct$Description = 'x coordinate of correct location for dropped object. No correct location during Transfer phase because location changes based on boundary or landmark based transfer'
  # json$y_correct$Description = 'y coordinate of correct location for dropped object. No correct location during Transfer phase because location changes based on boundary or landmark based transfer'
  # json$x_landmark$Description = 'x coordinate of landmark position during landmark position event'
  # json$y_landmark$Description = 'y coordinate of landmark position during landmark position event'
  # 
  # # Save json file to bids specified location
  # json = jsonlite::toJSON(json, pretty = TRUE)
  # json_path = file.path(base_path,
  #                       'bids',
  #                       sub_id,
  #                       ses_id,
  #                       'func',
  #                       paste(sub_id,
  #                             ses_id,
  #                             'task-nav',
  #                             'events.json',
  #                             sep = '_'),
  #                       fsep = .Platform$file.sep)
  # write(json, json_path)
  
  # Give message to user
  cat('Successfully created eventfile. \n\n')
  
}

# sub_id,
# ses_id,
# max_t_between_events,
# min_event_duration,
# save_timetable

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
  make_option(c('--min_event_duration'),
              type='numeric',
              default = 0,
              help = 'Minimum time an event is allowed to last (exception: button presses)',
              metavar = 'MIN_EVENT_DURATION'),
  make_option(c('--n_dir_bins'),
              type='numeric',
              default = 6,
              help = 'Total number of direction bins',
              metavar = 'N_DIR_BINS'),
  make_option(c('--save_timetable'),
              type='logical',
              default = FALSE,
              help = 'Saving a time table plot of eventfile',
              metavar = 'SAVE_TIMETABLE'))


# provide options in list to be callable by script
opt_parser = OptionParser(option_list = option_list)
opt = parse_args(opt_parser)

# Call function with arguments provided by user
CreateBidsEventfile(sub_id = opt$sub_id,
                    ses_id = opt$ses_id,
                    max_t_between_events = opt$max_t_between_events, 
                    min_event_duration = opt$min_event_duration,
                    n_dir_bins = opt$n_dir_bins,
                    save_timetable = opt$save_timetable)





library(here)
library(dplyr)
library(plyr)
library(data.table)

# Function to exclude participants in a standardized manner
GetExcludes = function(modality,
                       xval_split,
                       buffering,
                       reorganize,
                       within_session = FALSE,
                       return_reasons = FALSE){

  # modality = 'raw'
  # xval_split = 'sub_fold'
  # buffering = FALSE
  # reorganize = TRUE
  # within_session = TRUE
  # return_reason = TRUE

  # Set min events required in a training set to exclude participants
  min_events_req_train = 1
  
  # Get base path
  base_path = here::here()
  
  # Load used function
  file = file.path(base_path, 'code', 'analysis', 'utils', 'LoadEventStats.R')
  source(file)
  
  # Load participants.tsv
  file = file.path(base_path, 'bids', 'participants.tsv')
  participants = data.table::fread(file,
                                   sep = '\t',
                                   check.names = FALSE,
                                   header = TRUE,
                                   na.strings = 'n/a')
  
  # Prepare data frame for exclusion reason
  reason = data.table()
  
  # Basic exclusion: Did not complete the task
  idx = participants$incomplete_logfile == 1
  c0_excl = participants$participant_id[idx]
  if(length(c0_excl) != 0){
    c0_excl_reason = data.frame(id = c0_excl,
                                reason = 'incomplete_task',
                                session = NA)
    reason = rbind(reason, c0_excl_reason)
  }
  
  # Second exclusion criterion: Too many timeouts during feedback
  timeout_limit = 10
  # Ses 1
  idx = participants$`fb_timeouts_ses-1` > 10
  # Skip NAs (already excluded since these are incomplete files)
  idx[is.na(idx)] = FALSE
  c1_ses1_excl = participants$participant_id[idx]
  if(length(c1_ses1_excl) != 0){
    c1_ses1_excl_reason = data.frame(id = c1_ses1_excl,
                                     reason = 'task_performance',
                                     session = 1)
    reason = rbind(reason, c1_ses1_excl_reason)
  }
  
  # Ses 2
  idx = participants$`fb_timeouts_ses-2` > 10
  idx[is.na(idx)] = FALSE
  c1_ses2_excl = participants$participant_id[idx]
  if(length(c1_ses2_excl)){
    c1_ses2_excl_reason = data.frame(id = c1_ses2_excl,
                                     reason = 'task_performance',
                                     session = 2)
    reason = rbind(reason, c1_ses2_excl_reason)  
  }
  
  # Second exclusion criterion: Uncorrectd pulse fluctuations
  # Ses 1
  idx = as.logical(participants$`pulse_fluc_ses-1`) == TRUE &
    as.logical(participants$pulse_fluc_corrected) == FALSE
  c2_ses1_excl = participants$participant_id[idx]
  if(length(c2_ses1_excl) != 0){
    c2_ses1_excl_reason = data.frame(id = c2_ses1_excl,
                                     reason = 'pulse_fluctuations',
                                     session = 1)
    reason = rbind(reason, c2_ses1_excl_reason)
  }
  
  # Ses 2
  idx = as.logical(participants$`pulse_fluc_ses-2`) == TRUE &
    as.logical(participants$pulse_fluc_corrected) == FALSE
  c2_ses2_excl = participants$participant_id[idx]
  if(length(c2_ses2_excl)){
    c2_ses2_excl_reason = data.frame(id = c2_ses2_excl,
                                     reason = 'pulse_fluctuations',
                                     session = 2)
    reason = rbind(reason, c2_ses2_excl_reason)
  }
  
  # Third exclusion criterion: Less than x example for any event in a fold
  # (not buffer specific since low events in any buffer are reason for exclude)
  if(modality == 'raw' & within_session == TRUE){
    data_events = LoadEventStats(base_path = base_path,
                                 training = modality,
                                 testing = modality,
                                 events = 'walk-fwd',
                                 mask = '1024',
                                 xval_split = xval_split,
                                 clf = 'logreg',
                                 buffering = buffering,
                                 perm = FALSE,
                                 reorganize = reorganize,
                                 within_session = within_session)
    if(nrow(data_events) == 0){
      stop('Event file is empty')
    }
    
    # Find participants with low examples of a class in a fold
    data_stats = data_events %>%
      dplyr::filter(set == 'train') %>%
      reshape2::melt(measure.vars = c('hold_out_split_1',
                                      'hold_out_split_2',
                                      'hold_out_split_3')) %>%
      dplyr::select(participant_id,
                    group,
                    intervention,
                    session,
                    event_type,
                    set,
                    variable,
                    value) %>%
      dplyr::group_by(participant_id,
                      group,
                      intervention,
                      session) %>%
      dplyr::summarize(min = min(value))
    
    # Find number of sessions of each participant (if lower than 2, need to exclude)
    data_sessions = data_stats %>%
      dplyr::group_by(participant_id, group, intervention) %>%
      dplyr::summarise(n_sessions = length(session))
    one_session_excl = data_sessions$participant_id[data_sessions$n_sessions != 2]
    if(length(one_session_excl) != 0){
      one_session_excl_reason = data.frame(id = one_session_excl,
                                           reason = 'missing_session',
                                           session = NA)
      reason = rbind(reason, one_session_excl_reason)  
    }
  
    # Get participant IDs
    c3_ses1_excl = data_stats$participant_id[data_stats$min < min_events_req_train & data_stats$session == 1]
    if(length(c3_ses1_excl) != 0){
      c3_ses1_excl_reason = data.frame(id = c3_ses1_excl,
                                       reason = 'low_class_examples',
                                       session = 1)
      reason = rbind(reason, c3_ses1_excl_reason)
    }
    c3_ses2_excl = data_stats$participant_id[data_stats$min < min_events_req_train & data_stats$session == 2]
    if(length(c3_ses2_excl) != 0){
      c3_ses2_excl_reason = data.frame(id = c3_ses2_excl,
                                       reason = 'low_class_examples',
                                       session = 2)
      reason = rbind(reason, c3_ses2_excl_reason)
    }
    
  }else{
    
    data_events = LoadEventStats(base_path = base_path,
                                 training = modality,
                                 testing = modality,
                                 events = 'walk-fwd',
                                 mask = '1024',
                                 xval_split = xval_split,
                                 clf = 'logreg',
                                 buffering = buffering,
                                 perm = FALSE,
                                 reorganize = reorganize,
                                 within_session = within_session)
    if(nrow(data_events) == 0){
      stop('Event file is empty')
    }
    
    # Find people with only one buffer
    data_buffer = data_events %>%
      dplyr::filter(event_type == 1,
                    set == 'train') %>%
      dplyr::group_by(participant_id) %>%
      dplyr::summarise(n_buffers = length(buffer))
    single_buffer = data_buffer$participant_id[data_buffer$n_buffers != 2]
    if(length(single_buffer) != 0){
      single_buffer_reason = data.frame(id = single_buffer,
                                        reason = 'missing_buffer',
                                        session = NA)
      reason = rbind(reason, single_buffer_reason)
    }
    
    # Find participants with low examples of a class in a fold
    if(xval_split == 'fold'){
      data_stats = data_events %>%
        dplyr::filter(set == 'train') %>%
        reshape2::melt(measure.vars = c('hold_out_split_1',
                                        'hold_out_split_2',
                                        'hold_out_split_3',
                                        'hold_out_split_4')) %>%
        dplyr::select(participant_id,
                      group,
                      intervention,
                      event_type,
                      set,
                      variable,
                      value) %>%
        dplyr::group_by(participant_id,
                        group,
                        intervention) %>%
        dplyr::summarize(min = min(value))
      
    } else if(xval_split == 'session'){
      data_stats = data_events %>%
        dplyr::filter(set == 'train') %>%
        reshape2::melt(measure.vars = c('hold_out_split_1',
                                        'hold_out_split_2')) %>%
        dplyr::select(participant_id,
                      group,
                      intervention,
                      event_type,
                      set,
                      variable,
                      value) %>%
        dplyr::group_by(participant_id,
                        group,
                        intervention) %>%
        dplyr::summarize(min = min(value))
    }
    
    # Get participant IDs with missing events
    c3_across_excl = unique(
      c(data_stats$participant_id[data_stats$min < min_events_req_train])
      )
    if(length(c3_across_excl) != 0){
      c3_across_excl_reason = data.frame(id = c3_across_excl,
                                         reason = 'low_class_examples',
                                         session = NA)
      reason = rbind(reason, c3_across_excl_reason)
    }
    
  }

  # Combine criterions
  basic_excl = sort(unique(c0_excl))
  
  # performance and scanning based exclusions
  perf_excl = sort(unique(c(c1_ses1_excl,
                            c1_ses2_excl,
                            c2_ses1_excl,
                            c2_ses2_excl)))
  
  # event based exclusions
  if(within_session){
    ev_excl = sort(unique(c(c3_ses1_excl,
                            c3_ses2_excl)))
  } else{
    ev_excl = sort(unique(c3_across_excl))
  }
  
  # Get people who don't have any data to be loaded
  loaded_participants= unique(data_events$participant_id)
  full_participants = unique(participants$participant_id)
  no_data_excl = unique(
    full_participants[!full_participants %in% loaded_participants]
    )
  if(length(no_data_excl) != 0){
    no_data_excl_reason = data.frame(id = no_data_excl,
                                     reason = 'no_data',
                                     session = NA)
    reason = rbind(reason, no_data_excl_reason)
  }
  
  # Pool all excludes
  excl = sort(unique(c(basic_excl, perf_excl, ev_excl, no_data_excl)))
  
  # Sort reason of exclusion by participant
  reason = reason[order(id)]
  
  # for within session decoding exclude all participants who have only one of two sessions
  if(within_session){
    excl = sort(unique(c(excl, one_session_excl)))
  }
  # For buffered decoding, exclude all participants with only one buffer
  if(buffering){
    excl = sort(unique(c(excl, single_buffer)))
  }
  
  if(return_reasons){
    return_list = list('excl' = excl, 'reason' = reason)
    return(return_list)
  } else{
    return(excl)
  }
  
  
}
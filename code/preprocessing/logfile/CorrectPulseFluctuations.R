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

CorrectPulseFluctuations = function(){
  
  # Get base path
  base_path = file.path(here::here(), fsep = .Platform$file.sep)
  
  # Load pre-written functions
  source_path = file.path(base_path, 'code', 'analysis', 'utils',
                          fsep = .Platform$file.sep)
  source_files = list.files(source_path, pattern = "[.][rR]$",
                            full.names = TRUE, recursive = TRUE)
  invisible(lapply(source_files, function(x) source(x)))
  
  # Load participant.tsv
  participant_dir = file.path(base_path,
                              'bids',
                              'participants.tsv',
                              fsep = .Platform$file.sep)
  participants = data.table(
    read.table(participant_dir, header = TRUE, sep = '\t', check.names = FALSE,
               na.strings = 'n/a')
  )
  
  # Add column to mark corrected participants
  participants$pulse_fluc_corrected = FALSE
  
  # Get TR
  file = file.path(base_path, 'bids', 'task-nav_bold.json',
                   fsep = .Platform$file.sep)
  t_rep = jsonlite::fromJSON(file)
  t_rep = t_rep$RepetitionTime
  
  # Get participants and first scanner pulses of each session in which pulses fluctuate
  sub_ses_1 = participants$participant_id[as.logical(participants$`pulse_fluc_ses-1`) == TRUE]
  fp_ses_1 = participants$`first_pulse_ses-1`[as.logical(participants$`pulse_fluc_ses-1`) == TRUE]
  sub_ses_2 = participants$participant_id[as.logical(participants$`pulse_fluc_ses-2`) == TRUE]
  fp_ses_2 = participants$`first_pulse_ses-2`[as.logical(participants$`pulse_fluc_ses-2`) == TRUE]
  
  # Give message to user
  cat('Session 1...\n')
  
  for(sub_count in seq(length(sub_ses_1))){
    
    # Give message to user
    cat('\t', sub_ses_1[sub_count], '...\n')
    
    # Load standard log file
    file = file.path(base_path, 'derivatives', 'preprocessing', 'logfile',
                     sub_ses_1[sub_count], 'ses-1', '*_ses-1_*raw.tsv',
                     fsep = .Platform$file.sep)
    file = Sys.glob(file)
    log = read.table(file, sep = '\t', header = TRUE, na.strings = 'n/a')
    log = data.table(log)
    
    if(!is.na(fp_ses_1[sub_count])){
      # Get time of first pulse
      t_first_pulse = log[tr == fp_ses_1[sub_count]]$t[1]
      log = data.frame(log)
      
      # Get number of TRs
      json = file.path(base_path, 'bids', sub_ses_1[sub_count], 'ses-1', 'func',
                       '*_task-nav_bold.json',
                       fsep = .Platform$file.sep)
      json = Sys.glob(json)
      json = jsonlite::fromJSON(json)
      n_trs = json$dcmmeta_shape[4]
      
      # Get TR timing for each recorded TR (based on repetition time)
      pulses = seq(from = t_first_pulse,
                   by = t_rep,
                   length.out = n_trs)
      
      # Mark pulses in logfile
      log$tr = 0
      for(tr_count in seq(length(pulses))){
        index = which.min(abs(log$t - pulses[tr_count]))
        log$tr[index] = tr_count
      }
      
      # Fill tr column according to pulses
      for(line in seq(fp_ses_1[sub_count], nrow(log))){
        if(log$tr[line] == 0){
          log$tr[line] = log$tr[line - 1]
        }
      }
      
      # Set non-collected TRs to NA
      log$tr[log$tr == 0] = NA
      
      # Adjusted TR according to HRF lag
      log$tr_adj = log$tr + 2
      
      # Adjust time of log to first scanner pulse
      log$t = log$t - t_first_pulse
      
      # Save logfile
      write.table(x = log, file = file, sep = '\t', na = 'n/a',
                  row.names = FALSE)
      
      # Mark correction in participants file
      participants$pulse_fluc_corrected[participants$participant_id == sub_ses_1[sub_count]] = TRUE
    }
  }
    
  
  # Give message to user
  cat('Session 2...\n')
  
  # Participants with fluctuations in session 2
  for(sub_count in seq(length(sub_ses_2))){
    
    # Give message to user
    cat('\t', sub_ses_2[sub_count], '...\n')
    
    # Load standard log file
    file = file.path(base_path, 'derivatives', 'preprocessing', 'logfile',
                     sub_ses_2[sub_count], 'ses-2', '*_ses-2_*raw.tsv',
                     fsep = .Platform$file.sep)
    file = Sys.glob(file)
    log = read.table(file, sep = '\t', header = TRUE, na.strings = 'n/a')
    log = data.table(log)
    
    if(!is.na(fp_ses_2[sub_count])){
      # Get time of first pulse
      t_first_pulse = log[tr == fp_ses_2[sub_count]]$t[1]
      log = data.frame(log)
      
      # Get number of TRs
      json = file.path(base_path, 'bids', sub_ses_2[sub_count], 'ses-2', 'func',
                       '*_task-nav_bold.json',
                       fsep = .Platform$file.sep)
      json = Sys.glob(json)
      json = jsonlite::fromJSON(json)
      n_trs = json$dcmmeta_shape[4]
      
      # Get TR timing for each recorded TR (based on repetition time)
      pulses = seq(from = t_first_pulse,
                   by = t_rep,
                   length.out = n_trs)
      
      # Mark pulses in logfile
      log$tr = 0
      for(tr_count in seq(length(pulses))){
        index = which.min(abs(log$t - pulses[tr_count]))
        log$tr[index] = tr_count
      }
      
      # Fill tr column according to pulses
      for(line in seq(fp_ses_2[sub_count], nrow(log))){
        if(log$tr[line] == 0){
          log$tr[line] = log$tr[line - 1]
        }
      }
      
      # Set non-collected TRs to NA
      log$tr[log$tr == 0] = NA
      
      # Adjusted TR according to HRF lag
      log$tr_adj = log$tr + 2
      
      # Adjust time of log to first scanner pulse
      log$t = log$t - t_first_pulse
      
      # Save logfile
      write.table(x = log, file = file, sep = '\t', na = 'n/a',
                  row.names = FALSE)
      
      # Mark correction in participants file
      participants$pulse_fluc_corrected[participants$participant_id == sub_ses_2[sub_count]] = TRUE
    }
  }
  
  # If participants file not empty, write to tsv
  if(nrow(participants) > 0){
    write.table(x = participants, file = participant_dir, sep = '\t', na = 'n/a',
                row.names = FALSE)
  }
  
}

# Run function
CorrectPulseFluctuations()


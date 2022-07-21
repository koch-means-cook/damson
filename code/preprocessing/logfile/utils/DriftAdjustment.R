
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
DriftAdjustment = function(sub_id,
                           ses_id,
                           min_adj,
                           max_adj,
                           steps,
                           only_minimum){
  
  # sub_id = 'sub-younger001'
  # ses_id = 'ses-1'
  # min_adj = 1
  # max_adj = 1.006
  # steps = 600
  # only_minimum = FALSE
  
  # Get base path
  base_path = file.path(here::here(), fsep = .Platform$file.sep)
  
  # ===
  # Get real TR
  # ===
  
  tr = fromJSON(file.path(base_path, 'bids', 'task-nav_bold.json',
                          fsep = .Platform$file.sep))
  tr = tr$RepetitionTime
  
  
  # ===
  # Get scanner pulses
  # ===
  
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
  # Make time of pulses relative to first pulse when task started (10th)
  pulses$t = pulses$t - pulses$t[10]
  
  # ===
  # Take only consistent pulse intervals
  # ===
  
  # 10th pulse and onwards, others were differently spaced during reading of
  # instruction
  pulses = pulses[10:nrow(pulses)]
  # In case there were jumps in TR recording (difference > 2.36 + noise) take 
  # only the first consecutive interval
  time_jump = which(diff(pulses$t) > 2.6)
  if(length(time_jump) != 0){
    pulses = pulses[0:time_jump[1]]
  }
  
  
  # ===
  # Compare optimal and Unreal time pulses
  # ===
  
  # Get optimal spacing of TRs
  pulses$n = seq(nrow(pulses))
  pulses$optimal = tr * (pulses$n - 1)
  
  # Get difference between optimal spacing and scan time log of Unreal
  pulses$difference = pulses$t - pulses$optimal
  
  # ggplot(pulses, aes(x = n, y = difference)) +
  #   geom_line() +
  #   geom_hline(yintercept = 0, linetype = 'dashed') +
  #   labs(title = 'Difference between optimal TR spacing and Scanner pulses logged by Unreal',
  #        x = 'Number of TR',
  #        y = 'Time difference in s (Optimal time - Pulse log time)') +
  #   theme(plot.title = element_text(face = 'bold', hjust = 0.5))
  
  # ===
  # Get adjustment for scanner drift
  # ===
  
  adjust = data.frame(seq(from = min_adj, to = max_adj, length.out = steps))
  colnames(adjust) = 'adj'
  adjust$rmse = 0
  adjust$max_t_diff = 0
  
  # Get RMSE between optimal TR spacing and Unreal spacing
  for(adj_count in seq(nrow(adjust))){
    
    # Adjust spacing
    adj = adjust$adj[adj_count]
    corrected = pulses$t * adj
    
    # Get RMSE (since it is normalize for amount of scanner pulses)
    sse = sum((corrected - pulses$optimal)^2)
    rmse = sqrt(sse / length(corrected))
    
    # Enter rmse
    adjust$rmse[adj_count] = rmse
    
    # Get strongest time difference between optimal and adjusted time
    # min since unreal clock is faster
    adjust$max_t_diff[adj_count] = min(corrected - pulses$optimal)
  }
  
  # ===
  # Return adjustment and SSE 
  # ===
  
  adjust = data.table(adjust)
  
  # If requested, return only the value with the lowest RMSE
  if(only_minimum){
    adjust = adjust[rmse == min(rmse)]
  }
  
  return(adjust)
  
}
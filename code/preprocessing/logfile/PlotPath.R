
library(data.table)
library(ggplot2)
library(gganimate)
library(ggforce)
library(gifski)
library(av)
library(stringr)
library(optparse)
library(here)
library(png)
library(grid)
library(transformr)

PlotPath = function(sub_id,
                    ses_id,
                    only_final_frame = TRUE,
                    only_feedback_phase = TRUE,
                    include_information = FALSE){

# sub_id = 'sub-younger001'
# ses_id = 'ses-1'
# only_final_frame = FALSE
# only_feedback_phase = TRUE
# include_information = TRUE
  
  # Get base path
  base_path = file.path(here::here(), fsep = .Platform$file.sep)
  
  # Load cone picture
  file = file.path(base_path,
                   'code',
                   'preprocessing',
                   'logfile',
                   'PlotPath_cone.png',
                   fsep = .Platform$file.sep)
  cone = png::readPNG(file)
  # Turn image into grob
  cone = grid::rasterGrob(cone)
  
  
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
  data = data.table::fread(file = file,
                           sep = '\t',
                           header = TRUE,
                           check.names = FALSE,
                           na.strings = 'n/a')
  
  # Plot positions
  # data = data[x > 20000]
  # ggplot(data = data, aes(x = x, y = y)) +
  #   geom_point() +
  #   coord_fixed()
  
  # boundary radius transfer phase: 6500? (max y sub-older052_ses-2 = 6057 at x != 0)
  
  # Load BIDS eventfile
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
  bids_events = data.table::fread(file = file,
                                  sep = '\t',
                                  header = TRUE,
                                  check.names = FALSE,
                                  na.strings = 'n/a')
  
  # Data for each trial
  trial = bids_events[event == 'Trial']
  # Data for each drop (number of drops matches number of trials)
  drop = bids_events[event == 'Drop']
  # Landmark position for each event
  landmark_positions = bids_events[event == 'Lm_Env_1_Pos_1' |
                                     event == 'Lm_Env_1_Pos_2' |
                                     event == 'Lm_Env_2' |
                                     event == 'Lm_Env_3']
  lm = data.table(matrix(0, nrow(trial), 3))
  colnames(lm) = c('trial', 'x_landmark', 'y_landmark')
  lm$trial = trial$trial
  for(n_trial in as.numeric(lm$trial)){
    onset = trial$onset[n_trial]
    for(lm_pos_count in seq(nrow(landmark_positions))){
      lower = landmark_positions$onset[lm_pos_count]
      upper = landmark_positions$onset[lm_pos_count] + landmark_positions$duration[lm_pos_count]
      if(data.table::between(onset, lower = lower, upper = upper)){
        lm$x_landmark[n_trial] = landmark_positions$x_landmark[lm_pos_count]
        lm$y_landmark[n_trial] = landmark_positions$y_landmark[lm_pos_count]
        lm$env[n_trial] = landmark_positions$event[lm_pos_count]
      }
    }
  }
  # Get environment
  lm$env = substr(lm$env, 1, 8)
  lm[env == 'Lm_Env_1']$env = 'Environment 1'
  lm[env == 'Lm_Env_2']$env = 'Environment 2'
  lm[env == 'Lm_Env_3']$env = 'Environment 3'
  
  # Add columns to store object location, drop location, landmark location, 
  # distance
  data_cut = data[0,]
  data_cut$object_x = NA
  data_cut$object_y = NA
  data_cut$drop_x = NA
  data_cut$drop_y = NA
  data_cut$landmark_x = NA
  data_cut$landmark_y = NA
  data_cut$trial = NA
  # For each trial add object location, drop location, landmark location
  for(event in seq(nrow(trial))){
    lower = trial$onset[event]
    upper = (trial$onset[event] + trial$duration[event])
    temp = data[data.table::between(t,
                                    lower = lower,
                                    upper = upper,
                                    incbounds = TRUE)]
    temp$object_x = drop$x_correct[event]
    temp$object_y = drop$y_correct[event]
    temp$drop_x = drop$x_drop[event]
    temp$drop_y = drop$y_drop[event]
    temp$landmark_x = lm$x_landmark[event]
    temp$landmark_y = lm$y_landmark[event]
    
    temp$trial = event
    data_cut = rbind(data_cut, temp)
  }
  
  # data_cut$object_x = as.numeric(data_cut$object_x)
  # data_cut$object_y = as.numeric(data_cut$object_y)
  
  # Get trials to render
  if(only_feedback_phase == TRUE){
    trials = seq(30)
  } else{
    trials = seq(max(unique(data_cut$trial)))
  }
  
  # Loop over trials
  for(trial_nr in trials){
    
    # Select data for trial
    data_plot = data_cut[trial == trial_nr]
    
    # Create column controlling size of drop location (size increases when drop 
    # has been pressed)
    data_plot$drop = 1
    t_drop = drop$onset[trial_nr]
    data_plot[t >= t_drop]$drop = 10
    
    # Create column controlling size of connecting path between drop and object
    data_plot$connect = 0.2
    data_plot[t >= t_drop]$connect = 1
    
    # Create column giving distance between drop and object location
    data_plot$distance = round(
      sqrt(
        (unique(data_plot$object_x) - unique(data_plot$drop_x))^2 + 
          (unique(data_plot$object_y) - unique(data_plot$drop_y))^2),
      2)
    
    # Create column giving environment
    data_plot$env = lm$env[trial_nr]
    
    # Add headlines for plotted values
    data_plot$headline_time = 'Time'
    data_plot$headline_distance = 'Distance'
    data_plot$headline_trial = 'Trial'
    
    # Set arena boundaries for environment
    data_plot$x_min = 0
    data_plot$x_mid = 0
    data_plot$x_max = 0
    data_plot$y_min = 0
    data_plot$y_mid = 0
    data_plot$y_max = 0
    if(lm$env[trial_nr] == 'Environment 1'){
      data_plot$x_min = -5100
      data_plot$x_mid = 0
      data_plot$x_max = 5100
      data_plot$y_min = -5100
      data_plot$y_max = 5100
    } else if(lm$env[trial_nr] == 'Environment 2'){
      data_plot$x_min = 23500
      data_plot$x_mid = 30000
      data_plot$x_max = 36500
      data_plot$y_min = -6500
      data_plot$y_max = 6500
    } else if(lm$env[trial_nr] == 'Environment 3'){
      data_plot$x_min = 54900
      data_plot$x_mid = 60000
      data_plot$x_max = 65100
      data_plot$y_min = -5100
      data_plot$y_max = 5100
    }
    
    # Flag missing YAW data
    yaw_index = !is.na(data_plot$angle_by_yaw)
    data_plot$yaw_present = 'Yes'
    data_plot$yaw_present[!yaw_index] = 'No'
    # When yaw is missing, set it to 0
    data_plot$angle_by_yaw = as.numeric(data_plot$angle_by_yaw)
    data_plot$angle_by_yaw[!yaw_index] = 0
    
    if(only_final_frame){
      
      # Give output to user
      cat('Plotting trial', str_pad(as.character(trial_nr), 2, pad = '0'), '...\n')
      
      p = ggplot(data = data_plot[nrow(data_plot), ]) +
        theme_bw() +
        scale_x_continuous(limits = c(min(data_plot$x_min) - 1000,
                                      max(data_plot$x_max) + 1000)) +
        scale_y_continuous(limits = c(min(data_plot$y_min) - 1000,
                                      max(data_plot$y_max) + 1000)) +
        coord_fixed() +
        # transition_time(t) +
        # shadow_mark(past = TRUE, exclude_layer = c(1,3:17), color = 'blue') +
        theme(legend.position = 'none',
              panel.grid = element_blank(),
              panel.background = element_rect(fill = 'transparent'),
              axis.ticks = element_line(size = NA),
              axis.line = element_line(size = NA),
              axis.title = element_blank(),
              axis.text = element_blank()) +
        # Layer 1: Arena
        geom_circle(aes(x0 = x_mid, y0 = y_mid, r = x_max- x_mid),
                    fill = 'green',
                    color = 'black',
                    size = 3) +
        # Layer 2: Movement path
        # geom_point(data = data_plot[3:nrow(data_plot),],
        #            aes(x = x,
        #                y = y),
        #            size = 2,
        #            color = 'blue') +
        geom_path(data = data_plot[3:nrow(data_plot),],
                  aes(x = x,
                      y = y),
                  size = 1,
                  color = 'black',
                  linetype = 'solid') +
        # Layer 3: Start location (Third frame of Player)
        geom_point(data = data_plot[10, ],
                  aes(x = x,
                      y = y),
                  shape = 1,
                  stroke = 2,
                  size = 5) +
        # Layer 5: Drop Location
        # geom_point(aes(x = drop_x,
        #                y = drop_y),
        #            size = 4,
        #            shape = 21,
        #            stroke = 2,
        #            color = 'white',
        #            fill = 'red') +
      geom_point(aes(x = drop_x,
                     y = drop_y),
                 size = 6,
                 shape = 4,
                 stroke = 2,
                 color = 'black') +
        # Layer 4: Object location
        geom_point(aes(x = object_x,
                       y = object_y),
                   shape = 4,
                   size = 6,
                   stroke = 2,
                   alpha = 1,
                   color = 'red') +
        # Layer 6: Landmark location
        # geom_point(aes(x = landmark_x,
        #                y = landmark_y),
        #            size = 7,
        #            shape = 24,
        #            color = 'red',
        #            fill = 'white') +
        annotation_custom(grob = cone,
                          xmin = data_plot$landmark_x[nrow(data_plot)] - 1000,
                          xmax = data_plot$landmark_x[nrow(data_plot)] + 1000,
                          ymin = data_plot$landmark_y[nrow(data_plot)] - 1000,
                          ymax = data_plot$landmark_y[nrow(data_plot)] + 1000) +
        # Layer 7: Connection between drop and object location
        geom_segment(aes(x = drop_x,
                         y = drop_y,
                         xend = object_x,
                         yend = object_y),
                     linetype = 'solid',
                     alpha = 1,
                     size = 1,
                     color = 'red')
      if(include_information == TRUE){
        p = p +
          # Layer 8: Time
          geom_label(aes(x = x_max,
                         y = y_max + 100,
                         label=as.character(round(t, 2))),
                     hjust = 1,
                     vjust = 0,
                     size = 5) +
          # Layer 9: Distance
          geom_label(aes(label = distance,
                         x = x_min,
                         y = y_max + 100),
                     size = 5,
                     hjust = 0,
                     vjust = 0) +
          # Layer 10: Headline for time
          geom_text(aes(label = headline_time,
                        x = x_max,
                        y = y_max + 700),
                    size = 5,
                    hjust = 1,
                    vjust = 0) +
          # Layer 11: Headline for distance
          geom_text(aes(label = headline_distance,
                        x = x_min,
                        y = y_max + 700),
                    size = 5,
                    hjust = 0,
                    vjust = 0) +
          # Layer 12: Headline for environment
          geom_text(aes(label = 'Environment',
                        x = x_mid,
                        y = y_max + 700),
                    size = 5,
                    hjust = 0.5,
                    vjust = 0) +
          # Layer 13: Environment
          geom_label(aes(label = env,
                         x = x_mid,
                         y = y_max + 100),
                     size = 5,
                     hjust = 0.5,
                     vjust = 0) +
          # Layer 14; Flag for missing YAW data
          geom_label(aes(label = yaw_present,
                         x = x_min,
                         y = y_min - 700),
                     size = 5,
                     hjust = 0,
                     vjust = 1) +
          # Layer 15: Headline for YAW information
          geom_text(aes(label = 'YAW information',
                        x = x_min,
                        y = y_min - 100),
                    size = 5,
                    hjust = 0,
                    vjust = 1) +
          # Layer 16: Headline for trial
          geom_text(aes(label = 'Trial',
                        x = x_max,
                        y = y_min - 100),
                    size = 5,
                    hjust = 1,
                    vjust = 1) +
          # Layer 17: Label for trial
          geom_label(aes(label = str_pad(trial, width = 2, pad = '0'),
                         x = x_max,
                         y = y_min - 700),
                     size = 5,
                     hjust = 1,
                     vjust = 1)
      }
      
      # Save final frame
      file = file.path(base_path,
                       'derivatives',
                       'preprocessing',
                       'logfile',
                       sub_id,
                       ses_id,
                       paste(sub_id, '_',
                             ses_id, '_',
                             'task-nav', '_',
                             'plot-trial', str_pad(as.character(trial_nr), 2, pad = '0'),
                             '.pdf', sep = ''))
      ggsave(filename = file,
             plot = p,
             width = 6,
             height = 6,
             units = 'in')
      
      
    } else{
      
      # Give output to user
      cat('Rendering trial', str_pad(as.character(trial_nr), 2, pad = '0'), '...\n')
      
      # Animate movement through environment for each trial
      anim = ggplot(data = data_plot) +
        theme_bw() +
        scale_x_continuous(limits = c(min(data_plot$x_min) - 1000,
                                      max(data_plot$x_max) + 1000)) +
        scale_y_continuous(limits = c(min(data_plot$y_min) - 1000,
                                      max(data_plot$y_max) + 1000)) +
        coord_fixed() +
        transition_time(t) +
        shadow_mark(past = TRUE, exclude_layer = c(1,3:17), color = 'blue') +
        theme(legend.position = 'none',
              panel.grid = element_blank(),
              panel.background = element_rect(fill = 'transparent'),
              axis.ticks = element_line(size = NA),
              axis.line = element_line(size = NA),
              axis.title = element_blank(),
              axis.text = element_blank()) + 
        # Layer 1: Arena
        geom_circle(aes(x0 = x_mid, y0 = y_mid, r = x_max- x_mid),
                    fill = 'green',
                    color = 'black',
                    size = 3) +
        # Layer 2: Movement path
        geom_point(aes(x = x,
                       y = y),
                   size = 2,
                   color = 'blue') +
        # Layer 3: Player (incl viewing direction)
        geom_text(aes(label='V',
                      x = x,
                      y = y,
                      angle = angle_by_yaw + 90),
                  size = 10) +
        # Layer 4: Object location
        geom_point(aes(x = object_x,
                       y = object_y),
                   shape = 4,
                   size = 10,
                   alpha = 0.8,
                   color = 'red') +
        # Layer 5: Drop Location
        geom_point(aes(x = drop_x,
                       y = drop_y,
                       size = drop),
                   shape = 21,
                   stroke = 2,
                   color = 'white',
                   fill = 'red') +
        # Layer 6: Landmark location
        # geom_point(aes(x = landmark_x,
        #                y = landmark_y),
        #            size = 10,
        #            shape = 24,
        #            color = 'red',
        #            fill = 'white') +
        annotation_custom(grob = cone,
                          xmin = data_plot$landmark_x[nrow(data_plot)] - 750,
                          xmax = data_plot$landmark_x[nrow(data_plot)] + 750,
                          ymin = data_plot$landmark_y[nrow(data_plot)] - 750,
                          ymax = data_plot$landmark_y[nrow(data_plot)] + 750) +
        # Layer 7: Connection between drop and object location
        geom_segment(aes(x = drop_x,
                         y = drop_y,
                         xend = object_x,
                         yend = object_y,
                         alpha = connect),
                     linetype = 'dashed',
                     size = 1)
      if(include_information == TRUE){
        anim = anim +
          # Layer 8: Time
          geom_label(aes(x = x_max,
                         y = y_max + 100,
                         label=as.character(round(t, 2))),
                     hjust = 1,
                     vjust = 0,
                     size = 5) +
          # Layer 9: Distance
          geom_label(aes(label = distance,
                         x = x_min,
                         y = y_max + 100),
                     size = 5,
                     hjust = 0,
                     vjust = 0) +
          # Layer 10: Headline for time
          geom_text(aes(label = headline_time,
                        x = x_max,
                        y = y_max + 700),
                    size = 5,
                    hjust = 1,
                    vjust = 0) +
          # Layer 11: Headline for distance
          geom_text(aes(label = headline_distance,
                        x = x_min,
                        y = y_max + 700),
                    size = 5,
                    hjust = 0,
                    vjust = 0) +
          # Layer 12: Headline for environment
          geom_text(aes(label = 'Environment',
                        x = x_mid,
                        y = y_max + 700),
                    size = 5,
                    hjust = 0.5,
                    vjust = 0) +
          # Layer 13: Environment
          geom_label(aes(label = env,
                         x = x_mid,
                         y = y_max + 100),
                     size = 5,
                     hjust = 0.5,
                     vjust = 0) +
          # Layer 14; Flag for missing YAW data
          geom_label(aes(label = yaw_present,
                         x = x_min,
                         y = y_min - 700),
                     size = 5,
                     hjust = 0,
                     vjust = 1) +
          # Layer 15: Headline for YAW information
          geom_text(aes(label = 'YAW information',
                        x = x_min,
                        y = y_min - 100),
                    size = 5,
                    hjust = 0,
                    vjust = 1) +
          # Layer 16: Headline for trial
          geom_text(aes(label = 'Trial',
                        x = x_max,
                        y = y_min - 100),
                    size = 5,
                    hjust = 1,
                    vjust = 1) +
          # Layer 17: Label for trial
          geom_label(aes(label = str_pad(trial, width = 2, pad = '0'),
                         x = x_max,
                         y = y_min - 700),
                     size = 5,
                     hjust = 1,
                     vjust = 1)
      }
      
      # Set render parameters
      fps = 10
      end_pause = 50
      
      # Render animation
      anim = animate(anim,
                     height = 6,
                     width = 6,
                     units = 'in',
                     res = 200,
                     nframes = nrow(data_plot) + end_pause,
                     #duration = (data_plot$t[nrow(data_plot)] - data_plot$t[1]) + (end_pause/fps),
                     fps = fps,
                     rewind = FALSE,
                     #renderer = gifski_renderer(loop = TRUE),
                     renderer = av_renderer(),
                     detail = 1,
                     end_pause = end_pause)
      
      # Save animation to file
      file = file.path(base_path,
                       'derivatives',
                       'preprocessing',
                       'logfile',
                       sub_id,
                       ses_id,
                       paste(sub_id, '_',
                             ses_id, '_',
                             'task-nav', '_',
                             'anim-trial', str_pad(as.character(trial_nr), 2, pad = '0'),
                             '.mp4', sep = ''))
      #'.gif', sep = ''))
      anim_save(filename = file)
    }
    
  }
  
}


# Create options to pass to script
option_list = list(
  make_option(c('--sub_id'),
              type='character',
              help='ID of participant (e.g. "sub-younger001")',
              metavar = 'SUB_ID'),
  make_option(c('--ses_id'),
              type='character',
              help='ID of session (e.g. "ses-1")',
              metavar = 'TESTING'),
  make_option(c('--only_final_frame'),
              type='logical',
              help = 'Bool if only .pdf of finished trial should be plotted',
              metavar = 'ONLY_FINAL_FRAME',
              default = TRUE),
  make_option(c('--only_feedback_phase'),
              type='logical',
              help = 'Bool if only trials of the feedback phase should be plotted/rendered',
              metavar = 'ONLY_FEEDBACK_PHASE',
              default = TRUE),
  make_option(c('--include_information'),
              type='logical',
              help = 'Bool if detailed text information about trial should be included in render/plot',
              metavar = 'INCLUDE_INFORMATION',
              default = FALSE))


# provide options in list to be callable by script
opt_parser = OptionParser(option_list = option_list)
opt = parse_args(opt_parser)

# Call curve fitting function
PlotPath(sub_id = opt$sub_id,
         ses_id = opt$ses_id,
         only_final_frame = opt$only_final_frame,
         only_feedback_phase = opt$only_feedback_phase,
         include_information = opt$include_information)

# PlotPath.R --sub_id 'sub-younger001' --ses_id 'ses-1' --only_final_frame 'FALSE' --only_feedback_phase 'TRUE' --include_information 'FALSE'


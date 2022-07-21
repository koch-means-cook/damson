
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


# Function to convert logfile to eventfile
CreateRawEventfile = function(sub_id,
                              ses_id,
                              tr_tolerance,
                              max_angle_diff_for_fwd,
                              min_angle_diff_for_bwd,
                              min_turn_speed_per_s,
                              n_dir_bins,
                              binshift){

  # sub_id = 'sub-older065'
  # ses_id = 'ses-2'
  # tr_tolerance = 0.1
  # max_angle_diff_for_fwd = 20
  # min_angle_diff_for_bwd = 160
  # min_turn_speed_per_s = 5
  # n_dir_bins = 6
  # binshift = 0

  # Get base path
  base_path = file.path(here::here(), fsep = .Platform$file.sep)
  
  # Get logfile path
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
  
  # Get seqinfo path
  seq_info_path = file.path(base_path,
                            'bids',
                            'task-nav_bold.json',
                            fsep = .Platform$file.sep)
  
  
  
  # Load pre-written functions
  source_path = file.path(base_path, 'code', 'preprocessing', 'logfile',
                          'utils', fsep = .Platform$file.sep)
  source_files = list.files(source_path, pattern = "[.][rR]$",
                            full.names = TRUE, recursive = TRUE)
  invisible(lapply(source_files, function(x) source(x)))
  
  
  # ===
  # Loading and preparing logfile
  # ===
  
  # Give message to user
  cat('Loading and preparing logfile...\n')
  
  # Load logfile lines
  alldata = readLines(logfile_path)
  
  # Location data
  location = alldata[grep('Location', alldata)]
  location = data.table(t(matrix(unlist(strsplit(location, "\\|")), nrow = 9)))
  # Get timestamp, type, x, y
  location = select(location, c(V2, V3, V5, V7))
  colnames(location) = c('t', 'type', 'x', 'y')
  location$t = as.numeric(location$t)
  location$x = as.numeric(location$x)
  location$y = as.numeric(location$y)
  
  # Add YAW information to location where it is available
  location$yaw = NA
  yaw = alldata[grep('YawUnit', alldata)]
  yaw = data.table(t(matrix(unlist(strsplit(yaw, "\\|")), nrow = 11)))
  # Get timestamp, x, y, yaw
  yaw = select(yaw, c(V2, V9))
  colnames(yaw) = c('t', 'yaw')
  yaw$t = as.numeric(yaw$t)
  yaw$yaw = as.numeric(yaw$yaw)
  # Add YAW to location data where timestamps match
  location$yaw[location$t %in% yaw$t] = yaw$yaw
  
  # Reposition data
  reposition = alldata[grep('Reposition', alldata)]
  reposition = data.table(t(matrix(unlist(strsplit(reposition, "\\|")), nrow = 11)))
  # Get timestamp, type, x, y, yaw
  reposition = select(reposition, c(V2, V3, V5, V7, V11))
  colnames(reposition) = c('t', 'type', 'x', 'y', 'yaw')
  reposition$t = as.numeric(reposition$t)
  reposition$x = as.numeric(reposition$x)
  reposition$y = as.numeric(reposition$y)
  reposition$yaw = as.numeric(reposition$yaw)
  
  # Fuse reposition and location data and sort after timestamp
  data = rbind(location, reposition)
  data = data[order(t)]
  
  
  # ===
  # Adjusting for scanner drift
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
  # If there were fluctuations in pulse logging, drift adjustment will be median
  # of other drift adjustments since TR timings for thesecases will be 
  # calculated rather than read from the logfile, but are still oriented at 
  # UNREAL time stamps, which cause the drift)
  adjustment = adjustment[sub == sub_id & ses == ses_id]
  adjustment = adjustment$adj
  # Adjust time of logs for Unreal drift
  data$t = round(data$t * adjustment, 2)
  
  
  # ===
  # Add TRs
  # ===
  
  data$tr = 0
  pulses = alldata[grep('Scanner Pulse', alldata)]
  pulses = data.table(t(matrix(unlist(strsplit(pulses, "\\|")), nrow = 3)))
  pulses = dplyr::select(pulses, c(V2))
  colnames(pulses) = 't'
  pulses$t = as.numeric(pulses$t)
  # Remove duplicates in timestamps (e.g. first scanner pulses are logged twice)
  pulses = pulses[!duplicated(pulses)]
  # Adjust pulse timing for Unreal drift
  pulses$t = round(pulses$t * adjustment, 2)
  # Get TR from sequence file
  rep_time = jsonlite::fromJSON(seq_info_path)
  rep_time = rep_time$RepetitionTime
  # Mark TR number for location logs
  for(t_tr_count in seq(length(pulses$t))){
    t_tr = pulses$t[t_tr_count]
    data[data.table::between(t,
                             lower = t_tr,
                             upper = t_tr + rep_time + tr_tolerance)]$tr = t_tr_count
  }
  
  # Set tr of logs during no TR was collected to NA
  data[tr == 0]$tr = NA
  
  # Add TRs adjusted for hemodynamic lag
  data$tr_adj = data$tr + 2
  
  # Set time of first scanner pulse to new t = 0
  t_first_pulse = pulses$t[1]
  data$t = data$t - t_first_pulse
  
  # Exclude data before first TR
  data = data[t >= 0]
  
  
  # ===
  # Calculate movement from logfiles
  # ===
  
  # Give message to user
  cat('Calculating movement from logs...\n')
  
  # Calculate direction angle by yaw (transform unreal YAW into degrees)
  # YAWs range from -32768 to 32768, range = 65536 (2^16)
  data$angle_by_yaw = (data$yaw/65536) * 360
  # Transform scale from (-180|180) to (0|360)
  data[yaw < 0]$angle_by_yaw = data[angle_by_yaw < 0]$angle_by_yaw + 360
  # Round angles
  data$angle_by_yaw = round(data$angle_by_yaw, 2)
  
  
  # Prepare data for function apply (get previous entries in same line)
  data$prev_x = shift(data$x, 1)
  data$prev_y = shift(data$y, 1)
  data$prev_t = shift(data$t, 1)
  
  # Movement speed (by consecutive location)
  data = data.table(ddply(data,
                          names(data),
                          function(x) DirectionSpeed(curr_x = x$x,
                                                     curr_y = x$y,
                                                     curr_t = x$t,
                                                     prev_x = x$prev_x,
                                                     prev_y = x$prev_y,
                                                     prev_t = x$prev_t)))
  # Rename new column
  data = plyr::rename(data, c('V1' = 'speed'))
  # Erase speed value in case participant was repositioned
  data[type == 'Reposition']$speed = NA
  
  
  # Angle of movement (by consecutive location)
  data = data.table(ddply(data,
                          names(data),
                          function(x) DirectionAngle(curr_x = x$x,
                                                     curr_y = x$y,
                                                     prev_x = x$prev_x,
                                                     prev_y = x$prev_y)))
  data = plyr::rename(data, c('V1' = 'angle_by_loc'))
  # Erase angle by location in case participant was relocated (movement not made
  # by participant)
  data[type == 'Reposition']$angle_by_loc = NA
  
  
  # Add previous angle
  # by location
  data$prev_angle_by_loc = shift(data$angle_by_loc)
  # by yaw
  data$prev_angle_by_yaw = shift(data$angle_by_yaw)
  
  # Speed of angular movement
  # by consecutive location
  data = data.table(ddply(data,
                          names(data),
                          function(x) TurningSpeed(curr_angle = x$angle_by_loc,
                                                   curr_t = x$t,
                                                   prev_angle = x$prev_angle_by_loc,
                                                   prev_t = x$prev_t)$speed))
  data = plyr::rename(data, c('V1' = 'turn_speed_by_loc'))
  # by yaw
  data = data.table(ddply(data,
                          names(data),
                          function(x) TurningSpeed(curr_angle = x$angle_by_yaw,
                                                   curr_t = x$t,
                                                   prev_angle = x$prev_angle_by_yaw,
                                                   prev_t = x$prev_t)$speed))
  data = plyr::rename(data, c('V1' = 'turn_speed_by_yaw'))
  # Erase turn speed during Repositioning since it could be misleading
  data[type == 'Reposition']$turn_speed_by_yaw = NA
  
  
  # Direction of angular movement
  # by consecutive location
  data = data.table(ddply(data,
                          names(data),
                          function(x) TurningSpeed(curr_angle = x$angle_by_loc,
                                                   curr_t = x$t,
                                                   prev_angle = x$prev_angle_by_loc,
                                                   prev_t = x$prev_t)$direction))
  data = plyr::rename(data, c('V1' = 'turn_dir_by_loc'))
  # by yaw
  data = data.table(ddply(data,
                          names(data),
                          function(x) TurningSpeed(curr_angle = x$angle_by_yaw,
                                                   curr_t = x$t,
                                                   prev_angle = x$prev_angle_by_yaw,
                                                   prev_t = x$prev_t)$direction))
  data = plyr::rename(data, c('V1' = 'turn_dir_by_yaw'))
  # Erase turn direction during Repositioning since it could be misleading
  data[type == 'Reposition']$turn_dir_by_yaw = NA
  
  
  # Delete rows added for ddply
  data = select(data, -contains('prev'))
  
  
  # Add difference between angle by loc and angle by yaw to spot backwards 
  # walking
  data = data.table(ddply(data,
                          names(data),
                          function(x) AngleDiff(angle_1 = x$angle_by_loc,
                                                angle_2 = x$angle_by_yaw)))
  data = plyr::rename(data, c('V1' = 'angle_diff'))
  
  # Get bin of angle
  # (by location)
  data = data.table(ddply(data,
                          names(data),
                          function(x) ClassifyAngle(angle = x$angle_by_loc,
                                                    numberSubclasses = n_dir_bins,
                                                    binShift = binshift)))
  data = plyr::rename(data, c('V1' = 'bin_by_loc'))
  # by yaw
  data = data.table(ddply(data,
                          names(data),
                          function(x) ClassifyAngle(angle = x$angle_by_yaw,
                                                    numberSubclasses = n_dir_bins,
                                                    binShift = binshift)))
  data = plyr::rename(data, c('V1' = 'bin_by_yaw'))
  
  
  # ===
  # Flag events in logfile
  # ===
  
  # Give message to user
  cat('Flagging events...\n')
  
  # Add column for walking (reposition does not count as walking)
  data$walking = NA
  data[type == 'Location' & speed == 0]$walking = 0
  data[type == 'Location' & speed != 0]$walking = 1
  # Add column for walking forward
  data$walking_fwd = NA
  data[walking == 0]$walking_fwd = 0
  data[angle_diff > max_angle_diff_for_fwd]$walking_fwd = 0
  data[angle_diff <= max_angle_diff_for_fwd]$walking_fwd = 1
  # Add column for walking backward
  data$walking_bwd = NA
  data[walking == 0]$walking_bwd = 0
  data[angle_diff <= min_angle_diff_for_bwd]$walking_bwd = 0
  data[angle_diff > min_angle_diff_for_bwd]$walking_bwd = 1
  
  # Add column for turning by location (reposition does not count as turning)
  data$turning_by_loc = NA
  # For location logs we can only tell turning during walking (since angle is inferred by consecutive locations)
  data[type == 'Location' & speed != 0 & turn_speed_by_loc < min_turn_speed_per_s]$turning_by_loc = 0
  data[type == 'Location' & turn_speed_by_loc >= min_turn_speed_per_s]$turning_by_loc = 1
  # Add column for turning right by location
  data$turning_right_by_loc = NA
  data[turning_by_loc == TRUE & turn_dir_by_loc == 'right']$turning_right_by_loc = 1
  data[turning_by_loc == TRUE & turn_dir_by_loc == 'left']$turning_right_by_loc = 0
  # Turning left by location
  data$turning_left_by_loc = NA
  data[turning_by_loc == TRUE & turn_dir_by_loc == 'left']$turning_left_by_loc = 1
  data[turning_by_loc == TRUE & turn_dir_by_loc == 'right']$turning_left_by_loc = 0
  
  # Same for YAW derived angle data
  data$turning_by_yaw = NA
  data[type == 'Location' & turn_speed_by_yaw >= min_turn_speed_per_s]$turning_by_yaw = 1
  data[type == 'Location' & turn_speed_by_yaw < min_turn_speed_per_s]$turning_by_yaw = 0
  # Turning right
  data$turning_right_by_yaw = NA
  data[turning_by_yaw == TRUE & turn_dir_by_yaw == 'right']$turning_right_by_yaw = 1
  data[turning_by_yaw == TRUE & turn_dir_by_yaw == 'left']$turning_right_by_yaw = 0
  # Turning left
  data$turning_left_by_yaw = NA
  data[turning_by_yaw == TRUE & turn_dir_by_yaw == 'left']$turning_left_by_yaw = 1
  data[turning_by_yaw == TRUE & turn_dir_by_yaw == 'right']$turning_left_by_yaw = 0
  
  
  # ===
  # Save raw eventfile to derivatives
  # ===
  
  # Give message to user
  cat('Saving raw eventfile...\n')
  
  # Raw event file folder
  file = file.path(base_path,
                   'derivatives',
                   'preprocessing',
                   'logfile',
                   sub_id,
                   ses_id,
                   fsep = .Platform$file.sep)
  # If it does not exist, create directory
  if(!file.exists(file)){
    dir.create(file, recursive = TRUE)
  }
  # Get full file name
  file = file.path(file,
                   paste(sub_id,
                         ses_id,
                         'task-nav',
                         'events-raw.tsv',
                         sep = '_'),
                   fsep = .Platform$file.sep)
  # Save file
  write.table(data,
              file = file,
              sep = '\t',
              quote = FALSE,
              row.names = FALSE,
              col.names = TRUE,
              na = 'n/a')
  
  
  # Give message to user
  cat('...done!\n')
  
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
  make_option(c('--tr_tolerance'),
              type='numeric',
              default = 0.1,
              help = 'time in seconds added to tr if there is no immediate consecutive TR, will include additional logs to the last TR before pause',
              metavar = 'TR_TOLERANCE'),
  make_option(c('--max_angle_diff_for_fwd'),
              type='numeric',
              default = 20,
              help = 'Largest difference allowed between location-derived walking angle and YAW-derived walking angle (in degrees) while still counted as forward walking',
              metavar = 'MAX_DIFFERENCE_ALLOWED'),
  make_option(c('--min_angle_diff_for_bwd'),
              type='numeric',
              default = 160,
              help = 'Minimum difference between location-derived walking angle and YAW-derived walking angle (in degrees) required to flag backwards walking',
              metavar = 'MIN_DIFFERENCE_REQUIRED'),
  make_option(c('--min_turn_speed_per_s'),
              type='numeric',
              default = 5,
              help = 'Minimum of turn speed required to flag turning (in degrees per second)',
              metavar = 'MIN_TURN_SPEED'),
  make_option(c('--n_dir_bins'),
              type='numeric',
              default = 6,
              help = 'Number of directional bins (required to be even)',
              metavar = 'NUMBER_OF_BINS'),
  make_option(c('--binshift'),
              type='numeric',
              default = 0,
              help = 'Rotation of bin-boundaries in degrees (e.g. binshift = 30 -> bin1 [30,90] instead of [0,60])',
              metavar = 'BINSHIFT'))


# provide options in list to be callable by script
opt_parser = OptionParser(option_list = option_list)
opt = parse_args(opt_parser)

# Call function with arguments provided by user
CreateRawEventfile(sub_id = opt$sub_id,
                   ses_id = opt$ses_id,
                   tr_tolerance = opt$tr_tolerance,
                   max_angle_diff_for_fwd = opt$max_angle_diff_for_fwd,
                   min_angle_diff_for_bwd = opt$min_angle_diff_for_bwd,
                   min_turn_speed_per_s = opt$min_turn_speed_per_s,
                   n_dir_bins = opt$n_dir_bins, 
                   binshift = opt$binshift)

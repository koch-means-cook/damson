
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


# Script will create a tsv with the optimal drift adjustments for each 
# participant. If specified, a identity mapping can be created which will not
# adjust for any Unreal drift (adjustment = 1).



GetDriftAdjustment = function(min_adj,
                              max_adj,
                              steps,
                              identity){
  
  # Defaults for testing
  # min_adj = 1
  # max_adj = 1.0005
  # steps = 5000
  # identity = FALSE
  
  
  # Get base path
  base_path = file.path(here::here(), fsep = .Platform$file.sep)
  
  # Load pre-written functions
  source_path = file.path(base_path, 'code', 'preprocessing', 'logfile',
                          'utils', fsep = .Platform$file.sep)
  source_files = list.files(source_path, pattern = "[.][rR]$",
                            full.names = TRUE, recursive = TRUE)
  invisible(lapply(source_files, function(x) source(x)))
  
  
  # Load participants .tsv
  participants_dir = file.path(base_path, 'bids', 'participants.tsv',
                               fsep = .Platform$file.sep)
  participants = read.table(participants_dir, header = TRUE,
                            check.names = FALSE,
                            na.strings = 'n/a',
                            sep = '\t')
  participants = data.table(participants)
  
  # ===
  # Form list of participants
  # ===
  
  sub_list = list.dirs(file.path(base_path, 'bids', fsep = .Platform$file.sep),
                       full.names = FALSE,
                       recursive = FALSE)
  sub_list = sub_list[grep('sub-', sub_list)]
  
  # ===
  # Get optimal adjustment values for each subject ans session
  # ===
  
  # If specified, create file that wont adjust for Unreal drift
  if(identity){
    
    # Give message to user
    cat('Skipping optimal adjustment...\n')
    
    # Create file without adjustment to Unreal drift
    adjustment = data.table()
    adjustment$sub_id = rep(sub_list, each = 2)
    adjustment$ses_id = paste('ses-',
                              rep(c(1,2), times = length(sub_list)),
                              sep = '')
    # No adjustment means 1 since: Unreal_Time * Adjustment = Real_Time
    adjustment$adj = 1
    adjustment$rmse = adjustment$max_t_diff = NA
    
    
    # If optimal adjustment should be found
  } else{
    
    # Give message to user
    cat('Finding optimal adjustment for...\n')
    
    # Set template for appending
    adjustment = data.frame(matrix(0, 0, 5))
    colnames(adjustment) = c('adj', 'rmse', 'max_t_diff', 'sub_id', 'ses_id')
    
    # Loop over all participants and sessions
    for(sub_count in seq(length(sub_list))){
      sub_id = sub_list[sub_count]
      
      # Give message to user
      cat(paste('\t', sub_id, '...', '\n', sep = ''))
      
      # See if pulse fluctuations were found in any session of participant
      pulse_fluc = c(participants[participant_id == sub_id]$`pulse_fluc_ses-1`,
                     participants[participant_id == sub_id]$`pulse_fluc_ses-2`)
      
      for(ses_count in seq(2)){
        ses_id = paste('ses-', ses_count, sep = '')
        
        # Skip finding drift adjustment is pulse fluctuations were found 
        # (because if that happend the TR timings are calculated instead of
        # being read from the logfile)
        if(pulse_fluc[ses_count]){
          temp = data.frame(matrix(NA, 1, 5))
          colnames(temp) = c('adj', 'rmse', 'max_t_diff', 'sub_id', 'ses_id')
        } else{
          # Otherwise, get optimal drift adjustment
          temp = DriftAdjustment(sub_id = sub_id,
                                 ses_id = ses_id,
                                 min_adj = min_adj,
                                 max_adj = max_adj,
                                 steps = steps,
                                 only_minimum = TRUE)
        }
        
        # Add column for participant and session
        temp$sub_id = sub_id
        temp$ses_id = ses_id
        
        # Fuse individual values to data frame
        adjustment = rbind(adjustment, temp)
        
      }
    }
    
    # Convert to data table
    adjustment = data.table(adjustment)
  }
  
  # Sort columns
  setcolorder(adjustment, c('sub_id', 'ses_id', 'adj', 'rmse', 'max_t_diff'))
  
  # ===
  # Fill NAs with median drift adjustment (since adjustments are not normally 
  # distributed)
  # ===
  adjustment[is.na(adjustment$adj)]$adj = median(adjustment$adj, na.rm = TRUE)
  
  # ===
  # Save output as .tsv-file
  # ===
  
  # Give message to user
  cat('Saving output...\n')
  
  adjustment = data.table(adjustment)
  file = file.path(base_path, 'derivatives', 'preprocessing', 'logfile',
                   fsep = .Platform$file.sep)
  # Create output folder if not already existing
  if(!file.exists(file)){
    dir.create(file, recursive = TRUE)
  }
  # Save output to .tsv
  file = file.path(file, 'drift_adjustment.tsv', fsep = .Platform$file.sep)
  write.table(adjustment,
              file = file,
              sep = '\t',
              quote = FALSE,
              row.names = FALSE,
              col.names = TRUE)
  
  # Give message to user
  cat('...done!\n')
  
}

# Create options to pass to script
option_list = list(
  make_option(c('--min_adj'),
              type='numeric',
              default = 1,
              help='Minimum value to use when searching for optimal drift adjustment',
              metavar = 'MIN_ADJ'),
  make_option(c('--max_adj'),
              type='numeric',
              default = 1.0005,
              help='Maximum value to use when searching for optimal drift adjustment',
              metavar = 'MAX_ADJ'),
  make_option(c('--steps'),
              type='numeric',
              default = 5000,
              help = 'Number of steps between min_adj and max_adj to search for optimal adjustment',
              metavar = 'STEPS'),
  make_option(c('--identity'),
              type='logical',
              default = FALSE,
              help = 'Logical if identity mapping between Unreal time and scanner time should be used (i.e. no adjustment for Unreal drift). If TRUE no adjustment will be made.',
              metavar = 'IDENTITY'))


# provide options in list to be callable by script
opt_parser = OptionParser(option_list = option_list)
opt = parse_args(opt_parser)

# Call function with arguments provided by user
GetDriftAdjustment(min_adj = opt$min_adj,
                   max_adj = opt$max_adj,
                   steps = opt$steps,
                   identity = opt$identity)


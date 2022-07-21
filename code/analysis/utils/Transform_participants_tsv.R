# This function transforms the participants.tsv into a format more suitable to
# use for analysis. This format allows multiple rows for the same participant
# unlike the participants.tsv file.

library(data.table)

Transform_participants_tsv = function(raw_df){
  
  # Transform data to data table
  data = setDT(raw_df)
  
  # If column names '-' got replaces by a '.', put it back to '-'
  cols = colnames(data)
  cols = gsub('\\.', '-', cols)
  
  # Rename intervention column to session plan to avoid conflict once 
  # 'intervention_ses-1' and 'intervention_ses-2' get parsed into long format
  cols[cols == 'intervention'] = 'session_plan'
  
  colnames(data) = cols
  
  ## Session data
  # Set base that does not vary with different sessions
  data_base = dplyr::select(data, -contains('ses-'))
  
  # Select only data related to each session
  data_ses_1 = dplyr::select(data, contains('ses-1'))
  data_ses_2 = dplyr::select(data, contains('ses-2'))
  
  # Delete session information from colnames so they match for both sessions
  colnames(data_ses_1) = str_remove(colnames(data_ses_1), '_ses-1')
  colnames(data_ses_2) = str_remove(colnames(data_ses_2), '_ses-2')
  
  # Add base to session specific data so they can be appended
  data_ses_1 = cbind(data_base, data_ses_1)
  data_ses_2 = cbind(data_base, data_ses_2)
  
  # Add session column
  data_ses_1$ses = 1
  data_ses_2$ses = 2
  
  # Append session specific data
  data = rbind(data_ses_1, data_ses_2)
  
  
  ## Sequence data
  # Set base that does not vary with different sequences
  data_base = dplyr::select(data, -contains(c('_rest_', '_nav_')))
  
  # Select only data related to each sequence
  data_rest = dplyr::select(data, contains('_rest_'))
  data_nav = dplyr::select(data, contains('_nav_'))
  
  # Delete sequence information from colnames so they match for both sequences
  colnames(data_rest) = str_remove(colnames(data_rest), '_rest')
  colnames(data_nav) = str_remove(colnames(data_nav), '_nav')
  
  # Add base to sequence specific data so they can be appended
  data_rest = cbind(data_base, data_rest)
  data_nav = cbind(data_base, data_nav)
  
  # Add sequence column
  data_rest$sequence = 'rest'
  data_nav$sequence = 'nav'
  
  # Append sequence specific data
  data = rbind(data_nav, data_rest)
  
  
  # Return transformed data
  return(data)
}
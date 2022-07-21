library(data.table)
library(ggplot2)
library(lemon)

# Function to plot confusion function in different ways (individual, as points, 
# or as mean curves)
PlotConf = function(data,
                    plot_type,
                    age_split = FALSE,
                    intervention_split = FALSE,
                    show_chance = TRUE,
                    within_session = FALSE,
                    perm = FALSE){

  # data = data_plot
  # plot_type = 'mean_curves'
  # age_split = FALSE
  # intervention_split = FALSE
  # show_chance = TRUE
  # within_session = TRUE
  # perm = FALSE
  
  data = data.table(data)
  
  # If requested, split up intervention to single administrations and delete buffer
  if(within_session){
    if('buffer' %in% colnames(data)){
      data[, buffer := NULL]
    }
    data$manipulation = data$intervention
    data$manipulation[data$intervention == 'AB' & data$session == 1] = 'A'
    data$manipulation[data$intervention == 'AB' & data$session == 2] = 'B'
    data$manipulation[data$intervention == 'BA' & data$session == 1] = 'B'
    data$manipulation[data$intervention == 'BA' & data$session == 2] = 'A'
  }
  
  # # If there is only one manipulation (e.g. only placebo) split by session
  # if(length(unique(data$manipulation)) < 2){
  #   data$manipulation = data$session
  # }
  
  # Average over irrelevant columns
  if(perm){
    cols = c('i_perm',
             'participant_id',
             'mask_index',
             'variable')
  } else{
    cols = c('participant_id',
             'mask_index',
             'variable')
  }
  
  
  if(age_split){
    cols = c(cols, 'group')
  }
  if(within_session){
    cols = c(cols, 'manipulation')
  }
  if(intervention_split){
    cols = c(cols, 'intervention')
  }
  
  # Average over irrelevant columns
  data$value = as.numeric(data$value)
  data = data %>%
    group_by_at(cols) %>%
    dplyr::summarise(value = mean(value))
  
  # Get number of bins (for axis scaling)
  n_bins = length(unique(data$variable))
  
  
  if(perm){
    data$participant_id = paste(data$participant_id, data$i_perm, sep = '_')
    data = data[, !'i_perm']
  }
  
  if(plot_type == 'individual'){
    p = ggplot(data, aes(x = variable,
                         y = value,
                         color = mask_index,
                         group = participant_id)) +
      geom_line(alpha=1) +
      geom_point(alpha=0.5, color = 'black') +
      scale_color_viridis(option='D', discrete = TRUE) +
      labs(y = '% correct', x = 'Divergence from target direction') +
      facet_grid(participant_id ~ mask_index)
    if(within_session){
      p = p + facet_grid(participant_id + manipulation ~ mask_index)
    }
  }
  
  if(plot_type == 'single_points'){
    p = ggplot(data, aes(x = variable,
                         y = value,
                         color = mask_index,
                         fill = mask_index)) +
      geom_jitter(alpha=1,
                  height = 0,
                  width = 0.2,
                  size = 0.5,
                  color = 'black') +
      geom_boxplot(outlier.shape = NA,
                   color = 'black',
                   alpha = 0.5) +
      stat_summary(fun = mean, geom = 'point', 'shape' = 5, size = 2, stroke = 1,
                   color = 'black') +
      stat_summary(fun = mean, geom = 'point', 'shape' = 18, size = 2,
                   color = 'white') +
      scale_color_viridis(option='D', discrete = TRUE) +
      scale_fill_viridis(option='D', discrete = TRUE) +
      labs(y = '% correct', x = 'Divergence from target direction') +
      facet_grid(. ~ mask_index)
  }
  
  if(plot_type == 'mean_curves'){
    p = ggplot(data, aes(x = variable,
                         y = value,
                         color = mask_index,
                         group = participant_id)) +
      geom_line(alpha = 0.3, size = 0.5) +
      stat_summary(fun = 'mean', geom = 'line',
                   size = 1, alpha = 1, color = 'black', linetype = 'solid',
                   mapping = aes(group = mask_index)) +
      stat_summary(fun = 'mean', geom = 'point',
                   size = 2, alpha = 1, shape = 16,
                   mapping = aes(group = mask_index)) +
      stat_summary(fun = 'mean', geom = 'point',
                   size = 2, alpha = 1, shape = 1, color = 'black',
                   mapping = aes(group = mask_index)) +
      scale_color_viridis(option='D', discrete = TRUE) +
      labs(y = '% correct', x = 'Divergence from target direction') +
      facet_grid(. ~ mask_index)
  }
  
  # Split plots according to input
  if(plot_type != 'individual'){
    if(age_split & !intervention_split & !within_session){
      p = p + facet_grid(group ~ mask_index)
    } else if(!age_split & intervention_split & !within_session){
      p = p + facet_grid(intervention ~ mask_index)
    } else if(age_split & intervention_split & !within_session){
      p = p + facet_grid(intervention ~ mask_index + group)  
    } else if(!age_split & !intervention_split & within_session){
      p = p + facet_grid(manipulation ~ mask_index)  
    } else if(age_split & !intervention_split & within_session){
      p = p + facet_grid(manipulation ~ mask_index + group)
    } else if(!age_split & intervention_split & within_session){
      p = p + facet_grid(intervention + manipulation ~ mask_index)
    } else if(age_split & intervention_split & within_session){
      p = p + facet_grid(intervention + manipulation ~ mask_index + group)
    }  
  }
  
  # Adjust display of strips and coordinate system when splitting plots
  p = p + 
    theme_bw() +
    theme(panel.border=element_blank(), axis.line=element_line()) +
    coord_capped_cart(left='both', bottom='both', expand=TRUE) +
    theme(legend.position = 'none',
          strip.background = element_rect(color = 'transparent',
                                          fill = 'transparent'),
          strip.text = element_text(face = 'bold', size = 6),
          axis.text.x = element_text(size = 6, angle = 300, hjust = 0))
  
  # Add x-val strategy to plot title
  # p = p + labs(title = paste('X-Val: ', unique(data$x_val_split))) +
  #   theme(plot.title = element_text(hjust = 0.5, face = 'bold', size = 10))
    
  return(p)
}

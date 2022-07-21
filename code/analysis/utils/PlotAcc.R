library(ggplot2)
library(data.table)

# Function to load classification accuracy
PlotAcc = function(data,
                   custom_color_map = c(),
                   roi_vec = c(),
                   label = FALSE,
                   age_split = FALSE,
                   intervention_split = FALSE,
                   within_session = FALSE){
  
  # If list of ROIs is given, restrict data to ROIs
  if(length(roi_vec) != 0){
    data = data %>%
      filter(mask_index %in% roi_vec)
  }
  
  # If requested, split up intervention to single administrations
  if(within_session){
    data$manipulation = 0
    data$manipulation = data$intervention
    data$manipulation[data$intervention == 'AB' & data$session == 1] = 'A'
    data$manipulation[data$intervention == 'AB' & data$session == 2] = 'B'
    data$manipulation[data$intervention == 'BA' & data$session == 1] = 'B'
    data$manipulation[data$intervention == 'BA' & data$session == 2] = 'A'
  }
  
  # Reduce label size based on splits
  label_size = c(age_split, intervention_split, within_session)
  label_size = 4 - sum(label_size)
  
  n_bins = unique(data$n_bins)
  p = ggplot(data,
             aes(x = mask_index,
                 y = clf_acc,
                 fill = mask_index,
                 color = mask_index)) +
    theme_bw() +
    theme(panel.border=element_blank(), axis.line=element_line()) +
    geom_violin(draw_quantiles = c(0.25, 0.5, 0.75),
                color = 'black',
                alpha = 0.5) +
    geom_jitter(size = 0.5, height = 0, width = 0.2, color = 'black', alpha = 0.5) +
    geom_hline(yintercept = 1/n_bins, linetype = 'solid', color = 'black') +
    stat_summary(fun = 'mean', geom = 'point',
                 size = 2, alpha = 1, shape = 18) +
    stat_summary(fun = 'mean', geom = 'point',
                 size = 2, alpha = 1, shape = 5, stroke = 1.5, color = 'black') +
    coord_capped_flip(left='both', bottom='both', expand=TRUE) +
    
    theme(legend.position = 'none',
          strip.background = element_rect(color = 'transparent', fill = 'transparent'),
          strip.text = element_text(face = 'bold', size = 15))
  
  if(label){
    p = p + 
      stat_summary(fun = 'mean', geom = 'label', size = label_size, alpha = 1,
                   color = 'black', mapping = aes(label = round(..y.., 3)),
                   position = position_nudge(x = 0.4), fill = 'white')
  }
  
  # Color ROIs
  if(length(custom_color_map) == 0){
    p = p + 
      scale_fill_viridis(option = 'D', discrete = TRUE) +
      scale_color_viridis(option = 'D', discrete = TRUE)
  } else if(length(custom_color_map) < length(unique(data$mask_index))){
    stop('More ROIs in data than specified in color map')
  } else if(length(custom_color_map == length(unique(data$mask_index)))){
    p = p + 
      scale_fill_manual(values = custom_color_map) +
      scale_color_manual(values = custom_color_map)
  }
  
  # Add x-val strategy to plot title
  p = p + labs(title = paste('X-Val: ', unique(data$x_val_split))) +
    theme(plot.title = element_text(hjust = 0.5, face = 'bold', size = 10))
    
  
  # Add splits to data
  if(age_split & !intervention_split & !within_session){
    p = p + facet_wrap(~group)  
  } else if(!age_split & intervention_split & !within_session){
    p = p + facet_wrap(~intervention)  
  } else if(age_split & intervention_split & !within_session){
    p = p + facet_grid(group ~ intervention)  
  } else if(!age_split & !intervention_split & within_session){
    p = p + facet_wrap(~manipulation)  
  } else if(age_split & !intervention_split & within_session){
    p = p + facet_grid(group ~ manipulation)
  } else if(!age_split & intervention_split & within_session){
    p = p + facet_wrap(~intervention + manipulation)  
  } else if(age_split & intervention_split & within_session){
    p = p + facet_grid(group ~ intervention + manipulation)  
  }
  
  return(p)
}
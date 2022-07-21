library(ggplot2)
library(data.table)
library(plyr)

# Function to load classification accuracy
PlotPerm = function(data_perm,
                    data_real,
                    custom_color_map = c(),
                    roi_vec = c(),
                    label = FALSE,
                    n_bins = 6,
                    age_split = FALSE,
                    intervention_split = FALSE,
                    within_session = FALSE){
  
  data_perm = data.table(data_perm)
  data_real = data.table(data_real)
  
  # If list of ROIs is given, restrict data to ROIs
  if(length(roi_vec) != 0){
    data_perm = data_perm %>%
      filter(mask_index %in% roi_vec)
    data_real = data_real %>%
      filter(mask_index %in% roi_vec)
  }
  
  # Reduce label size based on splits
  label_size = c(age_split, intervention_split, within_session)
  label_size = 4 - sum(label_size)
  
  # Plot permutation
  p = ggplot(data = data_perm, aes(x = mask_index,
                                   y = clf_acc,
                                   fill = mask_index,
                                   color = mask_index,
                                   label = round(clf_acc, 3))) +
    theme_bw() +
    theme(panel.border=element_blank(), axis.line=element_line()) +
    geom_violin(draw_quantiles = c(0.25, 0.5, 0.75), color = 'black', fill = 'white') +
    geom_jitter(height = 0, width = 0.2, color = 'black', size = 0.2, alpha = 0.2) +
    geom_point(data = data_real, shape = 18, size = 4) +
    geom_point(data = data_real, shape = 5, stroke = 1.5, size = 4, color = 'black') +
    geom_hline(yintercept = 1/n_bins, linetype = 'dashed', color = 'red', size = 1) +
    theme(legend.position = 'none',
          strip.background = element_rect(color = 'transparent', fill = 'transparent'),
          strip.text = element_text(face = 'bold', size = 15)) +
    coord_capped_flip(left='both', bottom='both', expand=TRUE)
  
  if(label){
    p = p + 
      geom_label(data = data_real, color = 'black', fill = 'white',
                 size = label_size, position = position_nudge(x = 0.4))
  }
  
  # Color ROIs
  if(length(custom_color_map) == 0){
    p = p + 
      scale_fill_viridis(option = 'D', discrete = TRUE) +
      scale_color_viridis(option = 'D', discrete = TRUE)
  } else if(length(custom_color_map) < length(unique(data_real$mask_index))){
    stop('More ROIs in data than specified in color map')
  } else if(length(custom_color_map == length(unique(data_real$mask_index)))){
    p = p + 
      scale_fill_manual(values = custom_color_map) +
      scale_color_manual(values = custom_color_map)
  }
  
  # Add x-val strategy to plot title
  p = p + labs(title = paste('X-Val: ', unique(data_real$x_val_split))) +
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
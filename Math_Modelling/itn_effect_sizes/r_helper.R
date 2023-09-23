## --------------------------- r_helper.R ---------------------------

###------------------------------------------------------------- Convenient helper for plotting
library(ggplot2)
library(ggthemes)
library(cowplot)
library(scales)

###------------------------------------------------------------- From Ben Toh on DHS adjustments

###------------------------------------------------------------- For plotting
th <- theme_bw(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        strip.background = element_blank(),
        strip.text = element_text(size = 12),
        axis.text = element_text(size = 12),
        panel.background = element_blank())

f_getCustomTheme <- function(fontscl = 1) {
  customTheme <- theme(
    strip.text = element_text(size = 12 * fontscl, face = "bold"),
    plot.title = element_text(size = 14 * fontscl, vjust = -1, hjust = 0, color = 'black'),
    plot.subtitle = element_text(size = 12 * fontscl, color = 'black'),
    plot.caption = element_text(size = 9 * fontscl, color = 'black'),
    legend.title = element_text(size = 12 * fontscl, color = 'black'),
    legend.text = element_text(size = 12 * fontscl, color = 'black'),
    axis.title = element_text(size = 12 * fontscl, color = 'black'),
    axis.text = element_text(size = 12 * fontscl, color = 'black'),
    axis.ticks = element_line(size = rel(0.43)),
    axis.line = element_line(size = 0.25, linetype = 1),
    panel.grid.minor = element_blank(),
    strip.background = element_blank(),
    panel.border = element_rect(size = rel(0.43)),
    plot.margin = unit(c(0.5, 0.5, 0.5, 0.5), "cm")
  )
  return(customTheme)
}


#Wrapper function to save png and pdf at same call
f_save_plot <- function(pplot, plot_name, plot_dir, width = 14, height = 8, units = 'in', device_format = c('pdf', 'png')) {
  if ('png' %in% device_format) {
    ggsave(paste0(plot_name, ".png"), plot = pplot, path = plot_dir,
           width = width, height = height, units = units, device = "png")
  }
  if ('pdf' %in% device_format) {
    if (!dir.exists(file.path(plot_dir, "pdf"))) { dir.create(file.path(plot_dir, "pdf")) }
    ggsave(paste0(plot_name, ".pdf"), plot = pplot, path = file.path(plot_dir, "pdf"),
           width = width, height = height, units = units, device = "pdf", useDingbats = FALSE)
  }
}

## Wrapper function for plot_grid to combine a shared legend
plot_combine <- function(plist, ncol = 1, legend_position = 'right', rel_dims = 1, leg_dim = 0.25, labels = c('', '')) {
  plegend <- get_legend(plist[[1]])

  for (i in c(1:length(plist))) {
    plist[[i]] <- plist[[i]] + theme(legend.position = 'None')
  }

  if (sum(lengths(rel_dims)) == 1)rel_dims <- rep(rel_dims, length(plist))
  pplot <- cowplot::plot_grid(plotlist = plist, ncol = ncol, labels = labels, rel_widths = rel_dims)
  if (tolower(legend_position) == 'right')pplot <- plot_grid(pplot, plegend, ncol = 2, rel_widths = c(1, leg_dim))
  if (tolower(legend_position) == 'left')pplot <- plot_grid(plegend, pplot, ncol = 1, rel_heights = c(leg_dim, 1))
  if (tolower(legend_position) == 'bottom')pplot <- plot_grid(pplot, plegend, ncol = 1, rel_heights = c(1, leg_dim))
  if (tolower(legend_position) == 'top')pplot <- plot_grid(plegend, pplot, ncol = 1, rel_heights = c(leg_dim, 1))
  if (tolower(legend_position) == 'none')pplot <- pplot
  return(pplot)
}



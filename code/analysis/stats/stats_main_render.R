library(rmarkdown)
library(here)

render_path = file.path(here::here(), 'code', 'analysis', 'stats', 'stats_main.Rmd',
 fsep = .Platform$file.sep)

 rmarkdown::render(render_path, 'html_document')

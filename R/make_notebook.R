library("rmarkdown")
setwd("notebook")
render("notebook.Rmd", output_format = "html_document")
render("notebook.Rmd", output_format = "md_document")

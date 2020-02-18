`�``{r, results ="asis"}
fig_files <- dir(pattern = "txt$") 
paste0("* ", fig_files, " ![]](", fig_files, ")\n")
`�``

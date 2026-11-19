# Install the packages used by analysis.R and the tests.
pkgs <- c("survival", "ggplot2", "patchwork", "knitr", "scales", "testthat")
missing <- setdiff(pkgs, rownames(installed.packages()))
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")

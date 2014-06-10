library("dplyr",  warn.conflicts = FALSE)
options(stringsAsFactors = FALSE)

source("logs/initialize_logger.R")
logger <- create.logger(logfile = "logs/03_make_model_data.log", level = log4r:::INFO)
info(logger, "Merging scores into looking data")

merging <- list(output_file = "data/merged.RData")

looks <- read.csv("data/binned_looks.csv")
scores <- read.csv("data/scores.csv")

merged <- inner_join(looks, scores)
save(merged, file = merging$output_file)

# Headcount
trial_summary <- merged %>%
  select(Subject, Trials) %>%
  unique() %>%
  summarise(Subjects = n_distinct(Subject), Trials = sum(Trials))

merging$n_subjects <- trial_summary[["Subjects"]]
merging$n_trials <- trial_summary[["Trials"]]

log_list(merging)

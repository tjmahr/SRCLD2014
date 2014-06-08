library(plyr)
library(dplyr)
library(ggplot2)
source("logs/initialize_logger.R")
info(logger, "Cleaning eyetracking data")

# Constants for cleaning
gaze_info <- list(
  input_file = "data/trials_01_raw.RData",
  missing_data_cutoff = .5,
  min_n_trials = 24)
output_file <- "data/trials_02_trimmed.RData"

load(gaze_info$input_file)
long_trials <- group_by(long_trials, Subject, DateTime, TrialNo)

# How many trials have more than 50% missing data?
prop_na_summary <- long_trials %>%
  summarise(PropNA = sum(is.na(GazeByImageAOI)) / length(GazeByImageAOI))

p1 <- qplot(prop_na_summary$PropNA) +
  labs(x = "proportion mistracked data", y = "number of trials")
ggsave("plots/cleaning/propna_raw.png", p1)

headcount <- function(df) {
  df_summary <- df %>% count(c("Subject", "DateTime")) %>%
    summarise(n_subjects = n_distinct(Subject),
              n_blocks = n_distinct(DateTime),
              n_trials = sum(freq)) %>%
    as.list()
  df_summary$avg_prop_na <- round(mean(df$PropNA, na.rm = TRUE), 4)
  df_summary
}
headcount_raw <- headcount(prop_na_summary)

# Filter trials with more than 50% missing data
trimmed <- prop_na_summary %>%
  filter(PropNA >= gaze_info$missing_data_cutoff) %>%
  anti_join(long_trials, .)

trimmed_prop_na <- trimmed %>%
  summarise(PropNA = sum(is.na(GazeByImageAOI)) / length(GazeByImageAOI))
headcount_dropped_trials <- headcount(trimmed_prop_na)
trials_per_subject <- count(trimmed_prop_na, "Subject")

# Plot trials per subject
p2 <- qplot(trials_per_subject$freq) +
  geom_vline(x = gaze_info$min_n_trials, color = "red", linetype = "dashed") +
  labs(title = sprintf("Exclude subjects with fewer than %s usable trials",
                       gaze_info$min_n_trials),
       x = "Number of usable trials",
       y = "Number of subjects")
ggsave("plots/cleaning/dropped_subjects.png", p2)

# Exclude subjects with fewer than [24] trials
to_drop <- trials_per_subject %>% filter(freq < gaze_info$min_n_trials)
dropped_subjects <- structure(as.list(to_drop$freq), names = to_drop$Subject)
trimmed <- anti_join(trimmed, to_drop)
save(trimmed, file = output_file)

# Final headcount
trimmed_prop_na2 <- trimmed %>%
  summarise(PropNA = sum(is.na(GazeByImageAOI)) / length(GazeByImageAOI))

# Avg trials per block
trials_per_block <- trimmed %>%
  group_by(Subject, DateTime) %>%
  summarise(Trials = n_distinct(TrialNo))
mean_trials <- mean(trials_per_block$Trials)

headcount_dropped_subjects <- headcount(trimmed_prop_na2)
headcount_dropped_subjects$avg_trials_per_block = round(mean_trials)

# Logging
gaze_info <- list(
  gaze_info,
  raw = headcount_raw,
  after_dropping_trials = headcount_dropped_trials,
  after_dropping_subjects = headcount_dropped_subjects,
  output_file = output_file)
log_list(gaze_info)

trials_per_dropped_subject <- dropped_subjects
log_list(trials_per_dropped_subject)

library("plyr")
library("dplyr")
library("ggplot2")
source("logs/initialize_logger.R")
info(logger, "Cleaning eyetracking data")

compute_prop_na <- function(xs) mean(is.na(xs))

headcount <- function(df) {
  df_summary <- df %>% count(c("Subject", "DateTime")) %>%
    summarise(n_subjects = n_distinct(Subject),
              n_blocks = n_distinct(DateTime),
              n_trials = sum(freq)) %>% as.list()
  df_summary$avg_prop_na <- round(mean(df$PropNA, na.rm = TRUE), 4)
  df_summary
}

# Constants for cleaning
clean_gaze_info <- list(
  input_file = "data/trials_01_raw.RData",
  missing_data_cutoff = .5,
  min_n_trials = 24,
  output_file = "data/trials_02_trimmed.RData")
log_list(clean_gaze_info)

load(clean_gaze_info$input_file)
long_trials <- group_by(long_trials, Subject, DateTime, TrialNo)


# How many trials have more than 50% missing data?
prop_na_summary <- long_trials %>%
  summarise(PropNA = compute_prop_na(GazeByImageAOI))

p1 <- qplot(prop_na_summary$PropNA) +
  labs(x = "proportion mistracked data", y = "number of trials")
ggsave("plots/cleaning/propna_raw.png", p1)

headcount_raw <- headcount(prop_na_summary)
log_list(headcount_raw)


# Filter trials with more than 50% missing data
trimmed <- prop_na_summary %>%
  filter(PropNA >= clean_gaze_info$missing_data_cutoff) %>%
  anti_join(long_trials, .)
trimmed_prop_na <- summarise(trimmed, PropNA = compute_prop_na(GazeByImageAOI))
headcount_dropped_trials <- headcount(trimmed_prop_na)
log_list(headcount_dropped_trials)


# Plot trials per subject
trials_per_subject <- count(trimmed_prop_na, "Subject")
p2 <- qplot(trials_per_subject$freq) +
  geom_vline(x = clean_gaze_info$min_n_trials, color = "red", linetype = "dashed") +
  labs(title = sprintf("Exclude subjects with fewer than %s usable trials",
                       clean_gaze_info$min_n_trials),
       x = "Number of usable trials",
       y = "Number of subjects")
ggsave("plots/cleaning/dropped_subjects.png", p2)


# Exclude subjects with fewer than [24] trials
to_drop <- filter(trials_per_subject, freq < clean_gaze_info$min_n_trials)
trimmed <- anti_join(trimmed, to_drop)
save(trimmed, file = clean_gaze_info$output_file)

too_few_trials <- structure(as.list(to_drop$freq), names = to_drop$Subject)
log_list(too_few_trials)
too_few_trials <- data.frame(num_trials = unlist(too_few_trials))
write.csv(too_few_trials, "logs/too_few_trials.csv")

# Avg trials per block
trials_per_block <- trimmed %>%
  group_by(Subject, DateTime) %>%
  summarise(Trials = n_distinct(TrialNo))
mean_trials <- list(mean_trials_per_block = mean(trials_per_block$Trials))
log_list(mean_trials)


# Final headcount
trimmed_prop_na2 <- summarise(trimmed, PropNA = compute_prop_na(GazeByImageAOI))
headcount_dropped_subjects <- headcount(trimmed_prop_na2)
log_list(headcount_dropped_subjects)

headcounts <- rbind(
  raw = as.data.frame(headcount_raw),
  dropping_trials = as.data.frame(headcount_dropped_trials),
  dropping_subjects = as.data.frame(headcount_dropped_subjects))

write.csv(headcounts, file = "logs/headcounts.csv")

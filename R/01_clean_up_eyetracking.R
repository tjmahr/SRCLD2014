
load("data/trials_01_raw.RData")
# Filter trials with more than 50% missing data
trimmed <- long_trials %>%
  group_by(Subject, DateTime, TrialNo) %>%
  summarise(PropNA = sum(is.na(GazeByImageAOI)) / length(GazeByImageAOI),
            Trials = n_distinct(TrialNo)) %>%
  filter(.5 < PropNA) %>%
  anti_join(long_trials, .)

trimmed_percent_na <- trimmed %>%
  group_by(Subject) %>%
  summarise(PropNA = sum(is.na(GazeByImageAOI)) / length(GazeByImageAOI),
            Trials = n_distinct(TrialNo))

n_before <- n_distinct(trimmed$Subject)

qplot(data = trimmed_percent_na, x = PropNA)

p <- qplot(data = trimmed_percent_na, x = Trials) +
  geom_vline(x = 24, color = "red", linetype = "dashed") +
  labs(title = "Excluded subjects with fewer than 24 usable trials"m
       y = "Number of subjects")
ggsave("plots/dropped_subjects.png", p)

# Exclude subjects with fewer than 24 trials
trimmed <- trimmed_percent_na %>% filter(Trials < 24) %>% anti_join(trimmed, .)
n_after <- n_distinct(trimmed$Subject)

trials_per_block <- trimmed %>% group_by(Subject, DateTime) %>%
  summarise(Trials = n_distinct(TrialNo))

trials_per_subject <- trials_per_block %>% summarise(Trials = sum(Trials))
summary(trials_per_subject$Trials)

save(trimmed, file = "data/trimmed_trials.RData")

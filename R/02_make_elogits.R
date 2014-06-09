library("lookr")
library("dplyr",  warn.conflicts = FALSE)
library("ggplot2")
library("gtools")
source("logs/initialize_logger.R")
options(stringsAsFactors = FALSE)
load("data/trials_02_trimmed.RData")
info(logger, "Computing empirical logits")

binning <- list(
  width = 3,
  na_location = "tail",
  output_file = "data/binned_looks.csv")

plot_looks <- function(looks) {
  ggplot(looks, aes(Time, inv.logit(elogit))) +
    stat_summary(fun.data = mean_se, geom = "pointrange", size = 1) +
    labs(title = "Raw data (points with SE range)",
         y = "Proportion looking to target")
}


# Looks by time by subject
looks <- AggregateLooks(trimmed, Subject + Time ~ GazeByImageAOI)
binning$n_frames_dropped <-n_distinct(looks$Time) %% 3

binned <- group_by(looks, "Subject") %>%
  mutate(Bin = AssignBins(Time, binning$width, binning$na_location)) %>%
  group_by("Subject", "Bin") %.%
  summarise(
    Time = min(Time),
    ToTarget = sum(Target),
    ToDistractors = sum(Others),
    Proportion = ToTarget / (ToTarget + ToDistractors),
    Trials = (ToTarget + ToDistractors + sum(NAs) + sum(Elsewhere)) / binning$width,
    elogit = empirical_logit(ToTarget, ToDistractors),
    elogit_weights = empirical_logit_weight(ToTarget, ToDistractors)) %>%
  na.omit


# Include quadratic and linear times
times <- orthogonal_time(binned$Time, 2)
binned <- left_join(binned, times)
write.csv(binned, binning$output_file, row.names = FALSE)

# Headcount
trial_summary <- ungroup(binned) %>%
  select(Subject, Trials) %>%
  unique %>%
  summarise(Subjects = n_distinct(Subject), Trials = sum(Trials))

binning$n_subjects <- trial_summary[["Subjects"]]
binning$n_trials <- trial_summary[["Trials"]]
log_list(binning)

# Subject level plots
p <- ggplot(binned, aes(x = Time, y = Proportion)) +
  geom_point() + facet_wrap("Subject") +
  stat_smooth(method = "lm", formula = y ~ poly(x, 2), se = FALSE)
ggsave("plots/binning/subject_facets.png", p, width = 12, height = 12)

p2 <- plot_looks(binned)
ggsave("plots/binning/raw_data.png", p2)


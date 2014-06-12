library("dplyr",  warn.conflicts = FALSE)
library("lme4")
library("ggplot2")
options(stringsAsFactors = FALSE)

source("logs/initialize_logger.R")
logger <- create.logger(logfile = "logs/03_make_model_data.log", level = log4r:::INFO)
info(logger, "Merging scores into looking data")

plot_model <- function(model) {
  ggplot(fortify(model), aes(Time, elogit)) +
    stat_summary(fun.data = mean_se, geom = "pointrange", size = 1) +
    stat_summary(aes(y=.fitted), fun.y = mean, geom = "line", size = 1) +
    labs(title = "Raw data (points with SE range) and model fit (lines)")
}

scores <- read.csv("data/scores.csv", row.names = 1)
looks <- read.csv("data/binned_looks.csv")

# Filter out subjects with exclusion criteria that would affect eyetracking
eyetracking_reasons <- c("Exclude", "Cimplant", "LateTalker",
                         "TestedAfter2013Jan15", "TooFewTrials")
looks <- read.csv("logs/exclusions.csv") %>%
  filter(Reason %in% eyetracking_reasons) %>% anti_join(looks, .)

# Third-order time fixed effects. Second-order random effects.
m_f3_r2 <- lmer(
  elogit ~ 1 + ot1 + ot2 + ot3 + (1 + ot1 + ot2 | Subject),
  control = lmerControl(optimizer = "bobyqa"),
  weights = 1 / elogit_weights, REML = FALSE, data = looks)
capture.output(summary(m_f3_r2), file = "logs/m_f3_rs_model_summary.txt")

# Include model fits with participant scores
model_fits <- coef(m_f3_r2)$Subject
model_fits$Subject <- row.names(model_fits)
names(model_fits)[1:4] <- c("Intercept", "Linear", "Quadratic", "Cubic")
merged <- filter(scores, !is.na(EVT_GSV_T1)) %>% inner_join(., model_fits)
save(merged, file = "data/merged.RData")

# Log a headcount
merging <- looks %>% select(Subject, Trials) %>% unique %>%
  summarise(gca_trials = sum(Trials), gca_subjects = n_distinct(Subject)) %>%
  as.list

scored <- merged %>% select(Subject) %>%
  summarise(scores_n_subjects = n_distinct(Subject)) %>% as.list

merging <- c(merging, scored)
log_list(merging)

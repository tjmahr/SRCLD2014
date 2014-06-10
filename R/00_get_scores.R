# Combine participant info from several different sources
library("stringr")
library("plyr")
library("dplyr", warn.conflicts = FALSE)
options(stringsAsFactors = FALSE)

source("logs/initialize_logger.R")
logger <- create.logger(logfile = "logs/00_get_scores.log", level = log4r:::INFO)
info(logger, "Loading scores")

# Filtering constants
score_info <- list(
  minimum_lena_hours = 12,
  output_file = "data/scores.csv")

source("//l2t.cla.umn.edu/tier2/DataAnalysis/RScripts/GetSiteInfo.r")
is_not_one <- function(x) is.na(x) | x != 1
is_not_zero <- function(x) is.na(x) | x != 0

# Timepoint 2: Get any timepoint2 vocab scores
info_t2 <- GetSiteInfo(sheet = "TimePoint2") %>%
  select(Subject = Participant_ID,
         Age_T2 = AgeAtvA_3.4,
         EVT_Raw_T2 = EVT_raw_time3.4,
         EVT_Stnd_T2 = EVT_standard_time3.4,
         EVT_GSV_T2 = EVT_GSV,
         PPVT_Raw_T2 = PPVT_raw_time3.4,
         PPVT_Stnd_T2 = PPVT_standard_time3.4,
         PPVT_GSV_T2 = PPVT_GSV) %>%
  mutate(Subject = str_trim(Subject),
         Age_T2 = str_extract(Age_T2, "^\\d\\d")) %>%
  mutate_each(funs(suppressWarnings(as.numeric(.))), -Subject) %>%
  na.omit()

# Timepoint 1: Child-level variables and vocab scores
info_t1 <- GetSiteInfo() %>%
  select(Subject = Participant_ID,
         Exclude, Cimplant, LateTalker, TestedAfter2013Jan15, AAE,
         Female = female,
         Age = AgeAtvA_1.2,
         EVT_Raw_T1 = EVT_raw_time1.2,
         EVT_Stnd_T1 = EVT_standard_time1.2,
         EVT_GSV_T1 = EVT_GSV,
         PPVT_Raw_T1 = PPVT_raw_time1.2,
         PPVT_Stnd_T1 = PPVT_standard_time1.2,
         PPVT_GSV_T1 = PPVT_GSV,
         Site, Cohort) %>%
  mutate_each(funs(suppressWarnings(as.numeric(.))), -Subject, -Site)
score_info$n_raw <- n_distinct(info_t1$Subject)

# Record excluded subjects
to_exclude <- info_t1 %>%
  select(Subject, Exclude, Cimplant, LateTalker, TestedAfter2013Jan15) %>%
  to_exclusion_rows() %>%
  filter(!is.na(Value))

tested_ok <- filter(to_exclude, Reason == "TestedAfter2013Jan15" & Value == 1)
others_ok <- filter(to_exclude, Reason != "TestedAfter2013Jan15" & Value == 0)
to_exclude <- anti_join(to_exclude, rbind(tested_ok, others_ok))

# Apply subject exclusions
info_t1 <- info_t1 %>% anti_join(., to_exclude)
score_info$n_subjects_included <- n_distinct(info_t1$Subject)

# Get SES values
imputed_ses <- read.csv("//l2t.cla.umn.edu/tier2/ParticipantInfo/SurveyData/ImputedData/imputed_data_20140606.csv")
names(imputed_ses) <- c("Subject", "Medu", "Income")
score_info$imputed_ses_used <- TRUE
imputed_ses$Subject <- substr(imputed_ses$Subject, 1, 4)

# Get word counts from the CDI
cdi_umn <- read.xlsx(umn_info_path, sheetName = "CDI", startRow = 4) %>%
  select(Subject = participant_ID, CDI = Words_Prod)

cdi_uw <- read.xlsx(uw_info_path, sheetName = "CDI", startRow = 4) %>%
  select(Subject = participant_ID, CDI = Words_Prod)

# Merge and tidy
cdi <- rbind(cdi_uw, cdi_umn) %>%
  mutate(CDI = suppressWarnings(as.numeric(CDI)),
         Subject = str_trim(Subject)) %>% na.omit()


# Get adult word counts
lenas_t1 <- read.csv("//l2t.cla.umn.edu/tier2/DataAnalysis/LENA/timepoint1_awc.csv")
lenas_t2 <- read.csv("//l2t.cla.umn.edu/tier2/DataAnalysis/LENA/timepoint2_awc.csv")

new_lenas_in_t2 <- anti_join(lenas_t2, lenas_t1, by = "Subject")
lenas_t1 <- rbind(lenas_t1, new_lenas_in_t2)

score_info$used_lena_from_t2 <- new_lenas_in_t2[["Subject"]]

# Merge merge merge
info <- info_t1 %>%
  left_join(., info_t2) %>%
  left_join(., cdi) %>%
  left_join(., lenas_t1) %>%
  left_join(., imputed_ses)

# Require at least [[12]] LENA hours
no_hours <-  filter(info, is.na(Hours)) %>%
  select(Subject) %>%
  mutate(Reason = "NoLena", Value = 1)

too_few_hours <-  filter(info, Hours < score_info$minimum_lena_hours) %>%
  select(Subject, Value = Hours) %>%
  mutate(Reason = "TooFewHours")

# Save exclusions
exclusions <- rbind.fill(to_exclude, too_few_hours, no_hours) %>%
  arrange(Subject, Reason) %>% unique()
write.csv(exclusions, "logs/exc_scores.csv", row.names = FALSE)

info <- info %>% anti_join(., exclusions) %>% arrange(Subject)
write.csv(info, score_info$output_file)

score_info$n_lenas_okay <- n_distinct(info$Subject)
log_list(score_info)

write.csv(count(info, c("Cohort", "AAE", "Female")), "logs/keeper_counts.csv")

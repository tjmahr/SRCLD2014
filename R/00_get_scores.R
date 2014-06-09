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
  select(Subject = Participant_ID, EVT_Raw_T2 = EVT_raw_time3.4,
         EVT_GSV_T2 = EVT_GSV, PPVT_GSV_T2 = PPVT_GSV) %>%
  mutate(Subject = str_trim(Subject)) %>%
  na.omit


# Timepoint 1: Little more cleaning required
info_t1 <- GetSiteInfo() %>% select(
  Subject = Participant_ID,
  Exclude, Cimplant, LateTalker, TestedAfter2013Jan15, AAE,
  Female = female,
  Age = AgeAtvA_1.2,
  EVT_GSV_T1 = EVT_GSV,
  PPVT_GSV_T1 = PPVT_GSV,
  EVT_Raw_T1 = EVT_raw_time1.2,
  PPVT_Raw_T1 = PPVT_raw_time1.2,
  Site, Cohort)
score_info$n_raw <- n_distinct(info_t1$Subject)

# Make sure numeric columns are numeric
num_names <- c("Age", "EVT_Raw_T1", "EVT_GSV_T1",
               "PPVT_Raw_T1", "PPVT_GSV_T1", "Cohort")
info_t1[num_names] <- suppressWarnings(colwise(as.numeric)(info_t1[num_names]))


# Count exclusions
exclude_counts <- count(info_t1, c("Exclude", "Cimplant", "LateTalker", "TestedAfter2013Jan15"))
write.csv(exclude_counts, "logs/exclude_counts.csv")

# Record excluded subjects
excluded_IDs <- info_t1 %>%
  filter(Exclude == 1 | Cimplant == 1 | LateTalker == 1 | TestedAfter2013Jan15 == 0)
excluded_IDs <- excluded_IDs[["Subject"]]

# Apply subject exclusions
info_t1 <- info_t1 %>% filter(
  is_not_one(Exclude),
  is_not_one(Cimplant),
  is_not_one(LateTalker),
  is_not_zero(TestedAfter2013Jan15))
score_info$n_subjects_included <- n_distinct(info_t1$Subject)


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
write.csv(new_lenas_in_t2, "logs/lenas_used_from_t2.csv", row.names = FALSE)

score_info$used_lena_from_t2 <- new_lenas_in_t2[["Subject"]]

# Merge merge merge
info <- info_t1 %>%
  left_join(., info_t2) %>%
  left_join(., cdi) %>%
  left_join(., lenas_t1)


# Require at least [[15]] LENA hours
no_hours <- info %>%
  filter(is.na(Hours))
no_hours <- no_hours[["Subject"]]

too_few_hours <- info %>%
  filter(Hours < score_info$minimum_lena_hours)
write.csv(too_few_hours, "logs/too_few_hours.csv")
too_few_hours <- too_few_hours[["Subject"]]

info <- info %>%
  filter(score_info$minimum_lena_hours <= Hours) %>%
  mutate(AWC_C = WordsPerHour - mean(WordsPerHour, na.rm = TRUE))
write.csv(info, score_info$output_file, row.names = FALSE)

score_info$n_lenas_okay <- n_distinct(info$Subject)

log_list(excluded_IDs)
log_list(no_hours)
log_list(too_few_hours)
log_list(score_info)

write.csv(count(info, c("Cohort", "AAE", "Female")), "logs/keeper_counts.csv")

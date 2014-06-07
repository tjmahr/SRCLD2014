# Combine participant info from several different sources
library(stringr)
library(plyr)
library(dplyr, warn.conflicts = FALSE)
options(stringsAsFactors = FALSE)

source("//l2t.cla.umn.edu/tier2/DataAnalysis/RScripts/GetSiteInfo.r")
is_not_one <- function(x) is.na(x) | x != 1

info_t1 <- GetSiteInfo()
info_t2 <- GetSiteInfo(sheet = "TimePoint2")

info_t2 <- info_t2 %>% 
  select(Subject = Participant_ID, EVT_Raw_T2 = EVT_raw_time3.4, 
         EVT_GSV_T2 = EVT_GSV, PPVT_GSV_T2 = PPVT_GSV) %>% 
  mutate(Subject = str_trim(Subject)) %>% 
  na.omit

# Apply subject exclusions
exclude_counts <- count(info_t1, c("Exclude", "Cimplant", "LateTalker", 
                                   "TestedAfter2013Jan15"))

info_t1 <- filter(info_t1, is_not_one(Exclude), is_not_one(Cimplant), 
               is_not_one(LateTalker), TestedAfter2013Jan15 == 1)

message("Counts of keepers")
count(info_t1, c("Cohort", "AAE", "female"))

# Rename columns
aliases <- c(
  Participant_ID = "Subject",
  AAE = "AAE",
  female = "Female",
  householdIncome = "Income_Raw",
  medu = "MEdu_Raw",
  AgeAtvA_1.2 = "Age",
  MinPairs_time1.2 = "MinPairs",
  EVT_GSV = "EVT_GSV_T1",
  PPVT_GSV = "PPVT_GSV_T1",
  EVT_raw_time1.2 = "EVT_Raw_T1",
  EVT_standard_time1.2 = "EVT_Stnd_T1",
  PPVT_raw_time1.2 = "PPVT_Raw_T1",
  PPVT_standard_time1.2 = "PPVT_Stnd_T1",
  fruitstroop_time1.2 = "FruitStroop",
  Site = "Site",
  Cohort = "Cohort")
info_t1 <- rename(info_t1, replace = aliases) 
info_t1 <- info_t1[aliases]

# Make sure numeric columns are numeric
num_names <- c("Age", "MinPairs", "EVT_Raw_T1", "EVT_Stnd_T1", "EVT_GSV_T1", 
               "PPVT_Raw_T1", "PPVT_Stnd_T1", "PPVT_GSV_T1", "FruitStroop", 
               "Cohort")
info_t1[num_names] <- suppressWarnings(colwise(as.numeric)(info_t1[num_names]))

# Handle SES
info_t1 <- info_t1 %>% mutate(
  MEdu = as.rank.education(MEdu_Raw),
  Income = as.rank.income(Income_Raw)) %>% 
  select(-MEdu_Raw, -Income_Raw)

# Get word counts from the CDI
cdi_umn <- read.xlsx(umn_info_path, sheetName = "CDI", startRow = 4) %>% 
  select(Subject = participant_ID, CDI = Words_Prod)

cdi_uw <- read.xlsx(uw_info_path, sheetName = "CDI", startRow = 4) %>% 
  select(Subject = participant_ID, CDI = Words_Prod)

# Merge and tidy
cdi <- rbind(cdi_uw, cdi_umn) %>% 
  mutate(CDI = suppressWarnings(as.numeric(CDI)),
         Subject = str_trim(Subject)) %>% 
  na.omit

# Get adult word counts
lenas_t1 <- read.csv("//l2t.cla.umn.edu/tier2/DataAnalysis/LENA/timepoint1_awc.csv")
lenas_t2 <- read.csv("//l2t.cla.umn.edu/tier2/DataAnalysis/LENA/timepoint2_awc.csv")

new_lenas_in_t2 <- anti_join(lenas_t2, lenas_t1, by = "Subject")
lenas_t1 <- rbind(lenas_t1, new_lenas_in_t2)

write.csv(new_lenas_in_t2, "data/lenas_used_from_t2.csv", row.names = FALSE)

info <- info_t1 %>%
  left_join(., info_t2) %>% 
  left_join(., cdi) %>% 
  left_join(., lenas_t1)

write.csv(info, "data/scores.csv", row.names = FALSE)

message("Excluding kids with less than 15 LENA hours")

words <- info %>% filter(15 <= Hours) %>%
  select(Subject:Age, contains("GSV"), contains("EVT"), WordsPerHour) %>%
  mutate(AWC_C = WordsPerHour - mean(WordsPerHour, na.rm = TRUE))

write.csv(words, "data/just_word_scores.csv", row.names = FALSE)

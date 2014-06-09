library("plyr")
library("dplyr")
library("lookr")
source("//cifs/l2t/Scripts/LWL_Shared.R", chdir = TRUE)

source("logs/initialize_logger.R")
logger <- create.logger(logfile = "logs/00_get_eyetracking.log", level = log4r:::INFO)
info(logger, "Loading raw eye-tracking data")

# Set package options
lwl_opts$set(timeslice_start = 250, timeslice_end = 1750)
build_info <- list(lwl_opts = lwl_opts$get())

# Load the cached eye-tracking data
rwl1 <- TaskCache(task_dir = "//cifs/l2t/DataAnalysis/RealWordListening/TimePoint1/",
                  cache_dir = "//cifs/l2t/DataAnalysis/RealWordListening/TimePoint1/CompiledData/cache/")
trials <- LoadCache(rwl1)
trials <- TimeSlice(trials)

# Convert to a long data-frame
long_trials <- MeltLooks(trials) %>% tbl_df %>%
  select(-CarrierOnset, -TargetEnd, -Task,
         -Condition, -Audio, -WordGroup, -Subject) %>%
  rename(c(Subj = "Subject"))

# Find subjects with duplicated blocks
block_summary <- long_trials %>%
  group_by(Subject, DateTime) %>%
  summarise(n_blocks = n_distinct(Basename))

too_many <- block_summary %>%
  filter(n_blocks != 1) %>%
  select(Subject)

# Number duplicated blocks and filter to those with a value greater than 1
droppable_blocks <- long_trials %>% inner_join(too_many) %>%
  group_by(Subject, DateTime, Basename) %>%
  summarise() %>%
  mutate(BlockCount = seq_len(n())) %>%
  filter(1 < BlockCount) %>%
  select(Basename)

# Exclude duplicates
long_trials <- long_trials %>% anti_join(droppable_blocks)

# Confirm no duplicated blocks
block_summary <- long_trials %>%
  group_by(Subject, DateTime) %>%
  summarise(n_blocks = n_distinct(Basename),
            n_trials = n_distinct(TrialNo))
no_duplicates <- block_summary %>% filter(n_blocks != 1) %>% nrow(.) == 0

build_info$duplicated_block <- droppable_blocks$Basename
build_info$duplicates_removed <- no_duplicates

# Count the amount of data loaded
counts <- block_summary %>% ungroup %>%
  summarise(num_subjects = n_distinct(Subject),
            num_blocks = sum(n_blocks),
            num_trials = sum(n_trials)) %>% as.list

output_file <- "data/trials_01_raw.RData"
save(long_trials, file = output_file)

build_info <- c(build_info, counts, output_file = output_file)
log_list(build_info)

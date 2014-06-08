.PHONY: refresh_foreign

data/trials_02_trimmed.RData: R/01_clean_up_eyetracking.R data/trials_01_raw.RData
	Rscript R/01_clean_up_eyetracking.R

data/trials_01_raw.RData: R/00_get_eyetracking.R
	Rscript R/00_get_eyetracking.R

R/01_clean_up_eyetracking.R: logs/initialize_logger.R
R/00_get_eyetracking.R: logs/initialize_logger.R

refresh_foreign:
	touch R/00_get_eyetracking.R
	touch R/00_get_scores.R

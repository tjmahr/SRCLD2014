.PHONY: refresh_foreign

data/scores.csv: R/00_get_scores.R
	Rscript $<

data/trials_02_trimmed.RData: R/01_clean_up_eyetracking.R data/trials_01_raw.RData
	Rscript $<

data/trials_01_raw.RData: R/00_get_eyetracking.R
	Rscript $<

# Refresh all R scripts if logger utility is updated
R/*.R: logs/initialize_logger.R
	touch $@

refresh_foreign:
	touch R/00_get_eyetracking.R
	touch R/00_get_scores.R

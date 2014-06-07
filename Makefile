.PHONY: refresh

data/trials_01_raw.RData: R/00_get_eyetracking.R
	Rscript R/00_get_eyetracking.R
	
R/00_get_eyetracking.R: logs/initialize_logger.R

refresh: 
	touch R/00_get_eyetracking.R
	touch R/00_get_scores.R
.PHONY: refresh_foreign

notebook/notebook.html notebook/notebook.md: R/make_notebook.R data/scored.RData notebook/notebook.Rmd
	Rscript $<

data/scored.RData: R/04_make_poster_data.R data/merged.RData
	Rscript $<

data/merged.RData: R/03_make_model_data.R data/binned_looks.csv data/scores.csv logs/exclusions.csv
	Rscript $<

data/binned_looks.csv: R/02_make_elogits.R data/trials_02_trimmed.RData
	Rscript $<

data/trials_02_trimmed.RData logs/exc_eyetracking.csv: R/01_clean_up_eyetracking.R data/trials_01_raw.RData
	Rscript $<

data/trials_01_raw.RData: R/00_get_eyetracking.R
	Rscript $<

data/scores.csv logs/exc_scores.csv: R/00_get_scores.R
	Rscript $<

# Refresh all R scripts if logger utility is updated
R/*.R: logs/initialize_logger.R
	touch $@

logs/exclusions.csv: logs/exc_scores.csv logs/exc_eyetracking.csv
	Rscript -e "library(dplyr); options(stringsAsFactors = FALSE); \
		rbind(read.csv('logs/exc_scores.csv'), read.csv('logs/exc_eyetracking.csv')) %>% \
		arrange(Subject) %>%  write.csv(., 'logs/exclusions.csv')"

refresh_foreign:
	touch R/00_get_eyetracking.R
	touch R/00_get_scores.R

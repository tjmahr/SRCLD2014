library("log4r", warn.conflicts = FALSE)
library("reshape2")


log_list <- function(xs) {
  # Modify list so its first element is its name
  xs2 <- unlist(list(`Logged List` = deparse(substitute(xs)), xs))
  messages <- sprintf("%s: %s", names(xs2), xs2)
  info(logger, messages)
}

new_exclusions <- function() {
  data.frame(Subject = character(0), Reason = character(0),
             Value = numeric(0), stringsAsFactors = FALSE)
}

to_exclusion_rows <- function(df) {
  melt(df, id.vars = "Subject", variable.name = "Reason", value.name = "Value")
}

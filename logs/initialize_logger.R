library("log4r", warn.conflicts = FALSE)

log_list <- function(xs) {
  # Modify list so its first element is its name
  xs2 <- unlist(list(`Logged List` = deparse(substitute(xs)), xs))
  messages <- sprintf("%s: %s", names(xs2), xs2)
  info(logger, messages)
}

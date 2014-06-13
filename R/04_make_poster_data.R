
library("plyr")
library("dplyr")
library("gtools")

# Mean-center and divide a variable by a constant
mc <- function(xs, y = 1) (xs - mean(xs)) / y

scale_medu <- function(xs, reference = "Below") {
  xs <- ifelse(xs < 5, "Below", ifelse(xs == 5, "College", "Above"))
  levels <- unique(c(reference, c("Below", "College", "Above")))
  factor(xs, levels = levels)
}

load("data/merged.RData")
scores <- merged %>%
  select(Subject, Age, Female, EVT_Raw_T1, EVT_GSV_T1, EVT_Stnd_T1, Intercept,
         Linear, WordsPerHour, CTCPerHour, Meaningful, Age, Income, Medu) %>%
  unique() %>% filter(!is.na(EVT_GSV_T1), !is.na(WordsPerHour), !is.na(Medu)) %>%
  mutate(Accuracy = inv.logit(Intercept) * 100,
         WordsPerHour2 = mc(WordsPerHour),
         CTCPerHour2 = mc(CTCPerHour),
         Meaningful2 = mc(Meaningful),
         Linear2 = mc(Linear),
         EVT2 = mc(EVT_GSV_T1),
         Accuracy2 = mc(Accuracy),
         Age2 = mc(Age),
         MeduC = scale_medu(Medu),
         MeduC2 = scale_medu(Medu, "College"),
         MeduD = ifelse(Medu < 5, -.5, .5))
save(scores, file = "data/scored.RData")

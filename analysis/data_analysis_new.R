# ---
# title: "data_analysis"
# author: "Jakob Weickmann"
# date: "2020/11/25"
# output: html_document
# ---
  
# analyzing speech segmentation task

# Package names
packages <- c("outliers","ggplot2",
              "ggrepel", "ggtext",
              "lme4", "lmerTest", "emmeans",
              "fitdistrplus", "gamlss.dist", 
              "data.table", "shiny", "plotly", 
              "grid", "dplyr")

# Install packages not yet installed
installed_packages <- packages %in% rownames(installed.packages())
if (any(installed_packages == FALSE)) {
  install.packages(packages[!installed_packages])
}

# Packages loading
invisible(lapply(packages, library, character.only = TRUE))

# -----------------------------
# IMPORT DATA FROM CSV FILES 
# -----------------------------

# cwd <- dirname(rstudioapi::getSourceEditorContext()$path)
cwd <- getwd()
data_dir <- paste(cwd, "/data_reconstruction/output/", sep='')
dataRaw <- fread(paste(data_dir,'recoveredData_2021_01_29.csv',sep=''))

# ----------------------------------
# DATA PREPROCESSING
# ----------------------------------

# set factor variables as factors
factors <- c("WordID", "Word", "Block", "Participant", "Language", "Familiarity")
setDT(dataRaw)[, (factors) := lapply(.SD, as.factor), .SDcols = factors]

# select only those participants who have contributed to at least three trials with more than 1 sec looking time each
data <- as.data.frame(dataRaw)
participantsList <- data %>% 
  filter(Block == 'testing', totalFixationDuration_Intervals_FromEdfInSecs >= 1) %>%
  group_by(Participant, Familiarity) %>%
  count() %>%
  filter(n >= 3) %>% 
  ungroup(Familiarity) %>% 
  select(Participant)     
filter <- participantsList %>% 
  duplicated()

validParticipants <- t(participantsList[filter,])

validData <- data[data$Participant %in% validParticipants, ]

dataTesting <- validData %>% 
  filter(Block == 'testing', totalFixationDuration_Intervals_FromEdfInSecs >= 1)


# calculate group means
meansDT <- dataTesting[,.(meanFixationPercent = mean(FixationPercent), 
                          sdFixationPercent = sd(FixationPercent), 
                          meanLookingTime = mean(absoluteLookingTime), 
                          sdLookingTime = sd(absoluteLookingTime)), 
                       by = .(WordID, familiarizationWords)]

meansDT <- dataTesting %>%
  group_by(Participant, Familiarity) %>%
  summarize(meanFixationDuration = mean(totalFixationDuration_Intervals_FromEdfInSecs),
            meanFixationPercent = mean(fixationPercent_Intervals_FromEdf))


# RANDOM EFFECTS HIERARCHICAL MODEL WITH PARTICIPANTS AS RANDOM EFFECT
model_A <- lmer(meanFixationDuration ~ Familiarity + (1 | Participant), meansDT)
summary(model_A)

model_B <- lmer(meanFixationPercent  ~ Familiarity + (1 | Participant), meansDT)
summary(model_B)
fixef(model_A,)
ranef(model_A)
confint(model_A)


# GENERATE DIFFERENCES BETWEEN NOVEL AND FAMILIAR 
# as a proxy for speech development
differencesDT <- meansDT %>% 
  pivot_wider(names_from = Familiarity, values_from = c(meanFixationDuration, meanFixationPercent)) %>%
  summarize(meanAbsDurationDifference = abs(meanFixationDuration_novel - meanFixationDuration_familiar), 
            meanDurationDifference = meanFixationDuration_novel - meanFixationDuration_familiar)     


differencesDT %>%
  ggplot(aes(x = reorder(Participant, meanDurationDifference), y = meanDurationDifference)) + 
  geom_bar(stat = 'identity', alpha = 0.5, fill = 'red') +
  labs(title = 'Difference in mean fixation time \n(novel - familiar words)', 
       subtitle = 'in seconds') +
  xlab('Participant ID') + 
  ylab('Difference in mean fixation duration (s)')

differencesDT %>%
  ggplot(aes(x = reorder(Participant, meanAbsDurationDifference), y = meanAbsDurationDifference)) + 
  geom_bar(stat = 'identity', alpha = 0.5, fill = 'red') +
  labs(title = 'Absolute values of difference in \nmean fixation time (novel - familiar words)', 
       subtitle = 'in seconds') +
  xlab('Participant ID') + 
  ylab('Absolute difference in mean fixation duration (s)')

differencesDT %>%
  ggplot(aes(x = reorder(Participant, meanPercentDifference), y = meanPercentDifference)) + 
  geom_point(stat = 'identity', alpha = 0.5, color = 'blue') +
  xlab('Participant ID') + 
  ylab('Absolute difference of mean fixation percent')

cor(differencesDT[,2:3])

# generate mean data se
ggplot(meansDT, aes(x = Familiarity, y = meanFixationDuration, color = Participant)) +
  geom_line(aes(group=Participant), alpha = 0.5) + 
  xlab("") + 
  labs(title = "Differences in mean fixation duration between \nfamiliar and novel stimuli per participant",
       subtitle = paste("n =", as.character(length(unique(meansDT$Participant))))) +
  ylab("Fixation Duration in Seconds") + 
  theme(axis.ticks.x = element_blank(), 
        axis.line.x = element_blank(), 
        axis.line.y = element_blank(),
        legend.position = "none", 
        strip.background = element_blank(), 
        strip.text.x = element_text(color = "grey40")) + 
  geom_point()

ggplot(meansDT, aes(x = Familiarity, y = meanFixationPercent, color = Participant)) +
  geom_line(aes(group=Participant), alpha = 0.5) + 
  xlab("") + 
  labs(title = "Differences in mean fixation percentage between \nfamiliar and novel stimuli per participant",
       subtitle = paste("n =", as.character(length(unique(meansDT$Participant))))) +
  ylab("Fixation Percentage") + 
  theme(axis.ticks.x = element_blank(), 
        axis.line.x = element_blank(), 
        axis.line.y = element_blank(),
        legend.position = "none", 
        strip.background = element_blank(), 
        strip.text.x = element_text(color = "grey40")) + 
  geom_point()


# -------------------------------------
# PLOTS
# -------------------------------------

p1 <- ggplot(dataTesting, aes(familiarizationWords, absoluteLookingTime, color = WordID)) +
  geom_point(position = position_jitter(width = .3, seed = 137), alpha = 0.5) + 
  geom_vline(xintercept = mean_FixationPercent, linetype = 3) +
  geom_boxplot(aes(fill = WordID), alpha = 0.5) + 
  theme_classic()

layout(boxmode = "group", (ggplotly(p1)))


p2 <- ggplot(dataTesting, aes(x = familiarizationWords, y = absoluteLookingTime, fill = WordID)) +
  geom_boxplot(aes(fill = WordID), alpha = 0.5) + 
  xlab("") + 
  ylab("Absolute Looking Time (s)") + 
  theme_classic()

layout(boxmode = "group", (ggplotly(p2)))

p3 <- ggplot(dataTesting, aes(x = familiarizationWords, y = FixationPercent, fill = WordID)) +
  geom_boxplot(aes(fill = WordID), alpha = 0.5) + 
  xlab("") + 
  ylab("Fixation Percent") + 
  theme_classic()

layout(boxmode = "group", (ggplotly(p3)))

p4 <- ggplot(dataTesting, aes(FixationPercent, fill = familiarizationWords, group = familiarizationWords)) +
  geom_density(position = position_jitter(width = .3, seed = 137), alpha = 0.3) + 
  facet_grid(~ WordID) + 
  theme_classic()

ggplotly(p4)

p5 <- ggplot(dataTesting, aes(absoluteLookingTime, fill = familiarizationWords, group = familiarizationWords)) +
  geom_density(position = position_jitter(width = .3, seed = 137), alpha = 0.3) + 
  facet_grid(~ WordID) + 
  theme_classic()

ggplotly(p5)

p6 <- ggplot(dataTesting, aes(absoluteLookingTime, fill = familiarizationWords, group = familiarizationWords)) +
  geom_density(position = position_jitter(width = .3, seed = 137), alpha = 0.3) + 
  facet_grid(~ WordID) + 
  theme_classic()

ggplotly(p6)

p7 <- ggplot(dataTesting, aes(absoluteLookingTime, FixationPercent, color = WordID)) +
  geom_point(position = position_jitter(width = .3, seed = 137), alpha = 0.5) + 
  stat_smooth(alpha = 0.3, se = FALSE) +
  theme_classic()

ggplotly(p7)


p7 <- ggplot(dataTesting, aes(familiarizationWords, absoluteLookingTime, fill = familiarizationWords)) +
  geom_violin(alpha = 0.5) + 
  geom_point(alpha = 0.3, position = position_jitter(width = 0.2)) + 
  # stat_smooth(alpha = 0.3, se = FALSE) +
  facet_wrap(~ WordID) + 
  theme_classic() + 
  xlab("") + 
  ylab("Absolute Looking Time (s)") + 
  theme(axis.ticks.x = element_blank(), 
        axis.line.x = element_blank(), 
        legend.position = "none", 
        strip.background = element_blank(), 
        strip.text.x = element_text(color = "grey40")) + 
  labs(title = "Looking Time in s compared between Familiarization Groups")

ggplotly(p7)


p8 <- ggplot(dataTesting, aes(familiarizationWords, FixationPercent, fill = familiarizationWords)) +
  geom_violin(alpha = 0.5) + 
  geom_point(alpha = 0.3, position = position_jitter(width = 0.2)) + 
  # stat_smooth(alpha = 0.3, se = FALSE) +
  facet_wrap(~ WordID) + 
  theme_classic() + 
  xlab("") + 
  ylab("Fixation Percent") + 
  theme(axis.ticks.x = element_blank(), 
        axis.line.x = element_blank(), 
        legend.position = "none", 
        strip.background = element_blank(), 
        strip.text.x = element_text(color = "grey40")) + 
  labs(title = "Fixation Percent compared between Familiarization Groups")

ggplotly(p8)

p9 <- ggplot(dataTesting, aes(participant, fill = removed)) + 
  geom_bar(alpha = 0.4, position = 'fill') + 
  xlab("Participant ID") + 
  ylab("Percentage of valid trials") + 
  labs(title = 'Participants to remove due to too many invalid trials') + 
  geom_hline(yintercept = 0.20, color = 'grey30', linetype = 'dotted')

ggplotly(p9)

p10 <- ggplot(dataTesting, aes(participant, fill = removed)) + 
  geom_bar(alpha = 0.4, position = 'stack') + 
  xlab("Participant ID") + 
  ylab("Number of trials") + 
  labs(title = 'Participants to remove due to too many invalid trials') + 
  geom_hline(yintercept = 2.5, color = 'grey30', linetype = 'dotted')

ggplotly(p10)


p11 <- ggplot(dataTesting, aes(participant, fill = removed)) + 
  geom_bar(alpha = 0.4, position = 'stack') + 
  xlab("Participant ID") + 
  ylab("Number of trials") +
  geom_hline(yintercept = 2.5, color = 'grey30', linetype = 'dotted')

ggplotly(p11)




# grouped fix percent
ggplot(dataTesting, aes(x = Familiarity, y = fixationPercent_Intervals_FromEdf, fill = Language)) +
  geom_boxplot(alpha = 0.5) + 
  xlab("") + 
  ylab("Fixation Percent") + 
  theme_classic()

# grouped looking time
dataTesting %>% filter(Language == 'German') %>%
  ggplot(aes(x = Familiarity, y = totalFixationDuration_Intervals_FromEdfInSecs, fill = Language)) +
  geom_boxplot(alpha = 0.5) + 
  xlab("") + 
  ylab("Absolute Looking Time") + 
  theme_classic()





# grouped line graph
ggplot(dataTesting, aes(Familiarity, fixationPercent_Intervals_FromEdf, fill=Familiarity)) +
  geom_violin(alpha = 0.5) + 
  geom_boxplot(alpha = 1, width = 0.2, fill = 'grey95') +
  xlab("") +
  ggtitle("Fixation Percent by Familiarity") +
  ylab("Fixation Percent") + 
  theme(axis.ticks.x = element_blank(), 
        axis.line.x = element_blank(), 
        axis.line.y = element_blank(),
        legend.position = "none", 
        strip.background = element_blank(), 
        strip.text.x = element_text(color = "grey40")) + 
  stat_summary(geom="text", fun=quantile,
               aes(label=sprintf("%1.1f", ..y..)),
               position=position_nudge(x=0.28), size=3.5)

ggplot(dataTesting, aes(Familiarity, totalFixationDuration_Intervals_FromEdfInSecs, fill=Familiarity)) +
  geom_violin(alpha = 0.5) + 
  geom_boxplot(alpha = 1, width = 0.2, fill = 'grey95') +
  xlab("") + 
  ggtitle("Fixation Duration by Familiarity") +
  ylab("Fixation Duration in Seconds") + 
  theme(axis.ticks.x = element_blank(), 
        axis.line.x = element_blank(), 
        axis.line.y = element_blank(),
        legend.position = "none", 
        strip.background = element_blank(), 
        strip.text.x = element_text(color = "grey40")) + 
  stat_summary(geom="text", fun=quantile,
               aes(label=sprintf("%1.1f", ..y..)),
               position=position_nudge(x=0.28), size=3.5)


# generate mean data se
ggplot(meansDT, aes(x = Familiarity, y = meanFixationDuration, color = Participant)) +
  geom_line(aes(group=Participant), alpha = 0.5) + 
  xlab("") + 
  ggtitle("Difference in fixation duration between \nfamiliar and novel stimuli per participant") +
  ylab("Fixation Duration in Seconds") + 
  theme(axis.ticks.x = element_blank(), 
        axis.line.x = element_blank(), 
        axis.line.y = element_blank(),
        legend.position = "none", 
        strip.background = element_blank(), 
        strip.text.x = element_text(color = "grey40")) + 
  geom_point()

ggplot(meansDT, aes(x = Familiarity, y = meanFixationPercent, color = Participant)) +
  geom_line(aes(group=Participant), alpha = 0.5) + 
  xlab("") + 
  ggtitle("Difference in fixation percentage between \nfamiliar and novel stimuli per participant") +
  ylab("Fixation Percentage") + 
  theme(axis.ticks.x = element_blank(), 
        axis.line.x = element_blank(), 
        axis.line.y = element_blank(),
        legend.position = "none", 
        strip.background = element_blank(), 
        strip.text.x = element_text(color = "grey40")) + 
  geom_point()




# +
#   annotate("text", label = paste('N = ', length(unique(dataTesting$participant))), x = 0.7, y = 20) +
#   labs(title = "Fixation Percent by Familiarity") +
#   annotate(geom="text", x = 1.5, y = 60, label='PROOF ONLY', color='white', angle=45, fontface='bold', size=20, alpha=0.6)

ggplotly(p12)

p13 <- ggplot(dataTesting, aes(familiarity, absoluteLookingTime)) +
  geom_violin(aes(fill = familiarity), alpha = 0.5) + 
  geom_boxplot(alpha = 1, width = 0.2, fill = 'grey95') +
  xlab("") + 
  ylab("Cumulative Fixation Time") + 
  theme(axis.ticks.x = element_blank(), 
        axis.line.x = element_blank(), 
        axis.line.y = element_blank(),
        legend.position = "none", 
        strip.background = element_blank(), 
        strip.text.x = element_text(color = "grey40")) + 
  stat_summary(geom="text", fun=quantile,
               aes(label=sprintf("%1.1f", ..y..)),
               position=position_nudge(x=0.28), size=3.5) +
  annotate("text", label = paste('N = ', length(unique(dataTesting$participant))), x = 0.7, y = 20) + 
  labs(title = "Cumulative Fixation Time by Familiarity") + 
  annotate(geom="text", x = 1.5, y = 15, label='PROOF ONLY', color='white', angle=45, fontface='bold', size=15, alpha=0.6)


p14 <- ggplot(dataTesting, aes(familiarity, absoluteLookingTime)) +
  geom_violin(aes(fill = familiarity), alpha = 0.5) + 
  geom_boxplot(alpha = 1, width = 0.2, fill = 'grey95') +
  xlab("") + 
  ylab("Cumulative Fixation Time") + 
  theme(axis.ticks.x = element_blank(), 
        axis.line.x = element_blank(), 
        axis.line.y = element_blank(),
        legend.position = "none", 
        strip.background = element_blank(), 
        strip.text.x = element_text(color = "grey40")) + 
  stat_summary(geom="text", fun=quantile,
               aes(label=sprintf("%1.1f", ..y..)),
               position=position_nudge(x=0.28), size=3.5) +
  annotate("text", label = paste('N = ', length(unique(dataTesting$participant))), x = 0.7, y = 20) + 
  facet_grid(~ familiarizationWords) + 
  labs(title = "Cumulative Fixation Time by Familiarity between \nFamiliarization and Test Word") +
  annotate(geom="text", x = 1.5, y = 15, label='PROOF ONLY', color='white', angle=45, fontface='bold', size=15, alpha=0.6)

ggplot(dataTesting, aes(familiarity, FixationPercent)) +
  geom_violin(aes(fill = familiarity), alpha = 0.5) + 
  geom_boxplot(alpha = 1, width = 0.2, fill = 'grey95') +
  xlab("") + 
  ylab("Cumulative Fixation Time") + 
  theme(axis.ticks.x = element_blank(), 
        axis.line.x = element_blank(), 
        axis.line.y = element_blank(),
        legend.position = "none", 
        strip.background = element_blank(), 
        strip.text.x = element_text(color = "grey40")) + 
  stat_summary(geom="text", fun=quantile,
               aes(label=sprintf("%1.1f", ..y..)),
               position=position_nudge(x=0.28), size=3.5) +
  annotate("text", label = paste('N = ', length(unique(dataTesting$participant))), x = 0.7, y = 20) + 
  facet_grid(~ familiarizationWords) + 
  labs(title = "Fixation Percent Time by Familiarity between \nFamiliarization and Test Word") +
  annotate(geom="text", x = 1.5, y = 60, label='PROOF ONLY', color='white', angle=45, fontface='bold', size=15, alpha=0.6)
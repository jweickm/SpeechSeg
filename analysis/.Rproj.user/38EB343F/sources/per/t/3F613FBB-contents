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
data_dir <- paste(cwd, "/data", sep='')
folders <- list.files(data_dir)
filePaths <- array(dim = length(folders))
filePaths_indices <- array(data = TRUE, dim = c(1,length(folders)))

for (participant in folders){
  sub_dir <- paste(data_dir, '/', participant, sep='')
  subfolders <- list.files(sub_dir)
  
  if (subfolders == paste(participant, '_speech', sep='')){
    ending <- '_speech'
  } else if (subfolders == paste(participant, '_language', sep='')){
    ending <- '_language'
  } else {
    warning('No speech/language sub-directory for this participant found. Please make sure that all folders are named consistently.')
  }
  
  sub_data_dir <- paste(data_dir, '/', participant, '/', paste(participant, ending, sep=''), sep='')
  
  fileNames <- list.files(sub_data_dir, "\\.csv$", full.names = TRUE)
  if (length(fileNames) > 0) {
    filePaths[as.double(participant)] <- fileNames
  } else {
    filePaths_indices[as.double(participant)] <- FALSE
  }
}

listData <- as.list(filePaths_indices)
columnNames <- c("Trial", "WordID", "Word", "Block", "TrialOnset", "AttentionGrabberDuration", "StimulusDuration", "FixationPercent")
for (i in 1:length(folders)) {
  if (filePaths_indices[i]) {
    listData[i] <- list(fread(filePaths[i]))
  } else {
    listData[i] <- list(data.frame(matrix(ncol = 8, nrow = 16, dimnames=list(NULL, columnNames))))
    }
}

dataRaw <- rbindlist(listData, idcol = "participant", fill = TRUE)

# ----------------------------------
# DATA PREPROCESSING
# ----------------------------------

# unify variable names for 'Word'
dataRaw[dataRaw$Word == 'F']$Word <- 'Felsen'
dataRaw[dataRaw$Word == 'P']$Word <- 'Pinsel'
dataRaw[dataRaw$Word == 'K']$Word <- 'Kurbel'
dataRaw[dataRaw$Word == 'B']$Word <- 'Balken'

# set factor variables as factors
factors <- c("WordID", "Word", "Block", "participant")
setDT(dataRaw)[, (factors) := lapply(.SD, as.factor), .SDcols = factors]

levels(dataRaw$WordID)[levels(dataRaw$WordID) == "1"] <- "Balken"
levels(dataRaw$WordID)[levels(dataRaw$WordID) == "2"] <- "Felsen"
levels(dataRaw$WordID)[levels(dataRaw$WordID) == "3"] <- "Kurbel"
levels(dataRaw$WordID)[levels(dataRaw$WordID) == "4"] <- "Pinsel"

# reorder factor WordID
dataRaw$WordID <- factor(dataRaw$WordID, levels = c("Balken", "Kurbel", "Felsen", "Pinsel"))

# calculate absoluteLookingTime
dataRaw$absoluteLookingTime <- dataRaw$StimulusDuration * (dataRaw$FixationPercent/100)

dataRaw$removed <- !complete.cases(dataRaw)
dataRaw[dataRaw$Block == 'familiarization' | dataRaw$absoluteLookingTime <= 0.5]$removed <- TRUE


# select only the complete cases
dataComplete <- dataRaw[complete.cases(dataRaw)]
participants <- unique(dataComplete$participant)

# add variable for familiarization group
dataComplete$familGroup  <- as.factor(array()) # preallocate

for (n in participants) {
  familiarizationList <- paste(dataComplete[Block == 'familiarization' & participant == n]$Word, collapse = ", ")
  dataComplete[participant == n]$familGroup <- familiarizationList
}

# then add a new column with combined levels
dataComplete$familiarizationWords <- dataComplete$familGroup
levels(dataComplete$familiarizationWords) <- c("Balken/Kurbel", "Felsen/Pinsel", "Felsen/Pinsel", "Balken/Kurbel")

# calculate absoluteLookingTime
dataComplete$absoluteLookingTime <- dataComplete$StimulusDuration * (dataComplete$FixationPercent/100)

# --------------------------------------------------------

# select only the data from the testing block
dataTesting <- dataComplete[dataComplete$Block == 'testing'] 

# exclude participants with more than 2 invalid testing trials 
participantsToExclude <- dataTesting[removed == TRUE, .N, by = .(participant)][N > 2]$participant
dataTestingTrimmed <- dataTesting[removed == FALSE]
dataTestingTrimmed <- dataTestingTrimmed[!is.element(dataTestingTrimmed$participant, participantsToExclude)]

# exclude trials with less than .5 s of screen fixation time
# number of trials to be excluded
excludePercent <- 1 - nrow(dataTestingTrimmed)/nrow(dataTesting)

mean_FixationPercent = mean(dataTestingTrimmed$FixationPercent)


# calculate group means

meansDT <- dataTesting[,.(meanFixationPercent = mean(FixationPercent), 
                          sdFixationPercent = sd(FixationPercent), 
                          meanLookingTime = mean(absoluteLookingTime), 
                          sdLookingTime = sd(absoluteLookingTime)), 
                       by = .(WordID, familiarizationWords)]

# accrue WordID as congruent/incongruent
dataTestingTrimmed$familiarity <- as.factor('novel')
for (n in 1:nrow(dataTestingTrimmed)) {
  if (grepl(dataTestingTrimmed[n]$WordID, dataTestingTrimmed[n]$familiarizationWords, fixed = TRUE)) {
    dataTestingTrimmed[n]$familiarity <- as.factor('familiar')
  } 
}


# =====================================
# IMPORTING AND ANALYZING EDF DATA
# ====================================

# using subject 14 as an example
rawData_sbj14 <- fread('C:\\Users\\jakob\\OneDrive-Univie\\University\\StudAss\\MindTheBody\\SpeechSegmentation\\014_speech_sample_report.csv')
str(rawData_sbj14)



# -------------------------------------
# PLOTS
# -------------------------------------

p1 <- ggplot(dataTestingTrimmed, aes(familiarizationWords, absoluteLookingTime, color = WordID)) +
  geom_point(position = position_jitter(width = .3, seed = 137), alpha = 0.5) + 
  geom_vline(xintercept = mean_FixationPercent, linetype = 3) +
  geom_boxplot(aes(fill = WordID), alpha = 0.5) + 
  theme_classic()

layout(boxmode = "group", (ggplotly(p1)))


p2 <- ggplot(dataTestingTrimmed, aes(x = familiarizationWords, y = absoluteLookingTime, fill = WordID)) +
  geom_boxplot(aes(fill = WordID), alpha = 0.5) + 
  xlab("") + 
  ylab("Absolute Looking Time (s)") + 
  theme_classic()

layout(boxmode = "group", (ggplotly(p2)))

p3 <- ggplot(dataTestingTrimmed, aes(x = familiarizationWords, y = FixationPercent, fill = WordID)) +
  geom_boxplot(aes(fill = WordID), alpha = 0.5) + 
  xlab("") + 
  ylab("Fixation Percent") + 
  theme_classic()

layout(boxmode = "group", (ggplotly(p3)))

p4 <- ggplot(dataTestingTrimmed, aes(FixationPercent, fill = familiarizationWords, group = familiarizationWords)) +
  geom_density(position = position_jitter(width = .3, seed = 137), alpha = 0.3) + 
  facet_grid(~ WordID) + 
  theme_classic()

ggplotly(p4)

p5 <- ggplot(dataTestingTrimmed, aes(absoluteLookingTime, fill = familiarizationWords, group = familiarizationWords)) +
  geom_density(position = position_jitter(width = .3, seed = 137), alpha = 0.3) + 
  facet_grid(~ WordID) + 
  theme_classic()

ggplotly(p5)

p6 <- ggplot(dataTestingTrimmed, aes(absoluteLookingTime, fill = familiarizationWords, group = familiarizationWords)) +
  geom_density(position = position_jitter(width = .3, seed = 137), alpha = 0.3) + 
  facet_grid(~ WordID) + 
  theme_classic()

ggplotly(p6)

p7 <- ggplot(dataTestingTrimmed, aes(absoluteLookingTime, FixationPercent, color = WordID)) +
  geom_point(position = position_jitter(width = .3, seed = 137), alpha = 0.5) + 
  stat_smooth(alpha = 0.3, se = FALSE) +
  theme_classic()

ggplotly(p7)


p7 <- ggplot(dataTestingTrimmed, aes(familiarizationWords, absoluteLookingTime, fill = familiarizationWords)) +
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


p8 <- ggplot(dataTestingTrimmed, aes(familiarizationWords, FixationPercent, fill = familiarizationWords)) +
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


p11 <- ggplot(dataTestingTrimmed, aes(participant, fill = removed)) + 
  geom_bar(alpha = 0.4, position = 'stack') + 
  xlab("Participant ID") + 
  ylab("Number of trials") +
  geom_hline(yintercept = 2.5, color = 'grey30', linetype = 'dotted')

ggplotly(p11)

# grouped fix percent
ggplot(dataTestingTrimmed, aes(x = familiarizationWords, y = FixationPercent, fill = congruency)) +
  geom_boxplot(alpha = 0.5) + 
  xlab("") + 
  ylab("Fixation Percent") + 
  theme_classic()

# grouped looking time
ggplot(dataTestingTrimmed, aes(x = familiarizationWords, y = absoluteLookingTime, fill = congruency)) +
  geom_boxplot(alpha = 0.5) + 
  xlab("") + 
  ylab("Absolute Looking Time") + 
  theme_classic()

# grouped line graph
p12 <- ggplot(dataTestingTrimmed, aes(familiarity, FixationPercent)) +
  geom_violin(aes(fill = congruency), alpha = 0.5) + 
  geom_boxplot(alpha = 1, width = 0.2, fill = 'grey95') +
  xlab("") + 
  ylab("Fixation Percent") + 
  theme(axis.ticks.x = element_blank(), 
        axis.line.x = element_blank(), 
        axis.line.y = element_blank(),
        legend.position = "none", 
        strip.background = element_blank(), 
        strip.text.x = element_text(color = "grey40")) + 
  stat_summary(geom="text", fun=quantile,
               aes(label=sprintf("%1.1f", ..y..)),
               position=position_nudge(x=0.28), size=3.5) +
  annotate("text", label = paste('N = ', length(unique(dataTestingTrimmed$participant))), x = 0.7, y = 20) + 
  labs(title = "Fixation Percent by Familiarity") + 
  annotate(geom="text", x = 1.5, y = 60, label='PROOF ONLY', color='white', angle=45, fontface='bold', size=20, alpha=0.6)

ggplotly(p12)

p13 <- ggplot(dataTestingTrimmed, aes(familiarity, absoluteLookingTime)) +
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
  annotate("text", label = paste('N = ', length(unique(dataTestingTrimmed$participant))), x = 0.7, y = 20) + 
  labs(title = "Cumulative Fixation Time by Familiarity") + 
  annotate(geom="text", x = 1.5, y = 15, label='PROOF ONLY', color='white', angle=45, fontface='bold', size=15, alpha=0.6)


p14 <- ggplot(dataTestingTrimmed, aes(familiarity, absoluteLookingTime)) +
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
  annotate("text", label = paste('N = ', length(unique(dataTestingTrimmed$participant))), x = 0.7, y = 20) + 
  facet_grid(~ familiarizationWords) + 
  labs(title = "Cumulative Fixation Time by Familiarity between \nFamiliarization and Test Word") +
  annotate(geom="text", x = 1.5, y = 15, label='PROOF ONLY', color='white', angle=45, fontface='bold', size=15, alpha=0.6)

ggplot(dataTestingTrimmed, aes(familiarity, FixationPercent)) +
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
  annotate("text", label = paste('N = ', length(unique(dataTestingTrimmed$participant))), x = 0.7, y = 20) + 
  facet_grid(~ familiarizationWords) + 
  labs(title = "Fixation Percent Time by Familiarity between \nFamiliarization and Test Word") +
  annotate(geom="text", x = 1.5, y = 60, label='PROOF ONLY', color='white', angle=45, fontface='bold', size=15, alpha=0.6)
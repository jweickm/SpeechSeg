lapply(c("dplyr", "data.table"), library, character.only = TRUE)

rawData_sbj14 <- fread('C:\\Users\\jakob\\OneDrive-Univie\\University\\StudAss\\MindTheBody\\SpeechSegmentation\\014_speech_sample_report.csv')

str(rawData_sbj14)

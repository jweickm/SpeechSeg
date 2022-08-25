Speech Segmentation Meeting Summary

## EDF File analysis

In our meeting on Friday we investigated possible approaches on how to reconstruct the fixation percentage of each trial in the speech segmentation paradigm using a combination of the data in the .edf file and the .csv Matlab output. 

### The CSV File
The .csv file contains information about each trial, like the duration of the attention grabber, the duration of the stimulus or fixation percentage. However, timings were recorded using the `GetSecs()` function of PsychToolbox, which appears to return unreliable durations in a certain part of the script (where we are looping over the function). It is unclear whether this issue affects all timings/durations in the .csv file or only the fixation percentage. 

In order to reconstruct the fixation percentage using the .edf file, we need to rely only on one column in the .csv: `attention_grabber_duration`, of which we hope that it is reliable in its timings. 

### The EDF Files
There are two different types of .edf file:  
1. fixation report  
2. sample report  

#### Fixation Report
The fixation report contains a summary of all fixations that the eyelink recorded. One row for each fixation. They are of varying duration and we have information like the fixation location of the eye, the start and end times of each fixation as well as the trial ID. 

In this fixation report, saccades are excluded from the durations, meaning that there is a time gap of a few milliseconds (~20 ms) between two fixations. This means, that simply summing the durations of all fixations in one trial does not result in the trial duration. 

**Is there an export option to include saccades and/or blinks in the fixation report?**

#### Sample Report
The sample report contains the raw data of the eyelink. Recording with 500 Hz results in a new row every 2 ms. There are different columns to indicate additional information, e.g. whether the eye is blinking, currently moving and so on. There are also columns containing the timestamp, the fixation position of the eye and the trial id. 

### Process
A new trial in eyelink is started every time, the loop in the Matlab script finishes and changes into the next trial. The first trial of the .edf files can be ignored as this was initiated during the initial setup of the eyelink. 

After the start of the trial, the attention grabber starts playing until the child fixates on the screen and at least 0.5 seconds have passed. The exact duration of this interval is recorded in the .csv file. From then onwards, the stimulus will play until either it has reached its full duration or the child looks away from the screen continuously for at least 2 seconds. 

Then, the Matlab script will save the data and wait for 1 whole second before returning to the beginning of the trial loop and initiating the next trial. Therefore, the last at east 1000 ms of each trial recorded in the .edf has to be waiting time, that is not actually part of the trial. 

If we decide to trust on the two timestamps from the .edf: `attention_grabber_duration` and `stimulus_duration` then we can deduce, which rows of the sample report belong to which part of the trial. 

#### To Do's
1. Find all rows that lie between the beginning of the stimulus presentation (`beginning = time_stamp_at_trial_start + attention_grabber_duration`) and the end of the stimulus presentation (`end = beginning + stimulus_duration`).  
2. Find the rows that are fixations on the screen:  
	- consider x and y position  
	- consider saccades  
	- consider blinks  
	- consider missing data  
3. Calculate the duration of those rows (*2.*) and divide by the total duration of the `stimulus_presentation`.  
4. Check for consistency of time measurement using the last column of the .edf file and the durations in the .csv file. 


#### To-Dos for the Script.m:
- [ ] implement variable in the beginning where one selects German or Austrian Stimuli  
- [ ] also save the variable to the mat file, when reading in the audio files  
- [ ] add _German and _Austrian to the end of the filenames  
- [ ] add new column in export: familiar or novel  

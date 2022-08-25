% This scripts recovers crucial data from the speech segmentation paradigm
% (mostly fixation percent and fixation duration)
% Written by Jakob Weickmann

% Load stimuli language list
if exist('participantsLanguageMonica.csv', 'file')
    languageList = readtable('participantsLanguageMonica.csv');
    save('languageList')
elseif exist('languageList.mat', 'file')
    load('languageList.mat');
else
    warning('Please provide language information about the participants');
    return
end

familiarityCategories = {'novel', 'familiar'};

% Set the subjectData directory
subjectDataDir = dir('./subjectData/*.csv');

% set the names of the columns that pertain to saccades
saccadeColumns = {'NEXT_SAC_DURATION', 'NEXT_SAC_END_X', 'NEXT_SAC_END_Y',...
    'NEXT_SAC_END_TIME', 'NEXT_SAC_START_TIME', 'NEXT_SAC_START_X', 'NEXT_SAC_START_Y'};

% define regex to find the subject ID number
sbjID_expression = '([0-9]+)';

% search the IDs from the source folder
subjectIDs = zeros(length(subjectDataDir), 1);
for subject = 1:length(subjectDataDir)
    match = regexp(subjectDataDir(subject).name, sbjID_expression, 'match');
    subjectIDs(subject, 1) = str2double(match);
end

% count the number of files in the `subjectData` folder for each
% participant
sort(subjectIDs);
fileNumberPerSubject = [unique(subjectIDs), ...
    histc(subjectIDs, unique(subjectIDs))];

subjectIDs = unique(subjectIDs)';
disp(['Participants found: ', sprintf('%02d ', subjectIDs)]);

% check if every participant has 2 files, abort if not the case and report
% the faulty IDs
notPairedIndex = find(fileNumberPerSubject(:,2) ~= 2);
notPaired = fileNumberPerSubject(fileNumberPerSubject(:,2) ~= 2, 1);
if notPaired
    warning('There are not two files for each participant!');
    fprintf('ID | n \n---|---\n');
    fprintf('%02d | %d\n',fileNumberPerSubject(notPairedIndex, :)');
    warning('Please check the `subjectData` folder!');
    subjectIDs = setdiff(subjectIDs, notPaired); % remove the notPaired IDs
else
    disp('Great! There are two files for each participant.');
end

csvOutput = table;

%% IMPORT THE DATA
for subject = 1:length(subjectIDs)
    % Import the participant's files
    fixReportDataDir = dir(sprintf('./subjectData/fix_report_*%02d.csv', subjectIDs(subject)));
    csvDataDir = dir(sprintf('./subjectData/subject_*%02d.csv', subjectIDs(subject)));
    
    fixReportData = readtable([fixReportDataDir.folder, filesep, fixReportDataDir.name]);
    csvData = readtable([csvDataDir.folder, filesep, csvDataDir.name]);
    
    if size(fixReportData, 1) < 1
        continue
    end
    
    % preprocess the data
    % remove "SYNCTIME" row if it exists and shift Trial ID accordingly
    synctimeRows = fixReportData.CURRENT_FIX_MSG_TEXT_1 == "SYNCTIME";
    if  find(synctimeRows)
        fixReportData = fixReportData(synctimeRows == false, :); % pick all rows without SYNCTIME
    end
    firstTrialIndex = fixReportData.TRIAL_INDEX(1);
    if firstTrialIndex > 1
        shift = firstTrialIndex - 1;
        fixReportData{:,'TRIAL_INDEX'} = fixReportData{:,'TRIAL_INDEX'} - shift; % shift the TRIAL ID to the correct value
    end
    
    % get the number of trials including the familiarization phase
    trialVector = unique(fixReportData{:,'TRIAL_INDEX'})';
    nTrials = 16;
    
    % convert the Columns that pertain to the Saccades from string to double
    edfData = fixReportData;

    for column = 1:length(saccadeColumns)
        edfData.(saccadeColumns{column}) = str2double(fixReportData.(saccadeColumns{column}));
    end

    % Preallocate the output variables
    totalFixationDurationSaccades = zeros(nTrials,1);
    totalFixationDurationIntervals = zeros(nTrials, 1);
    fixationPercentSaccades = zeros(nTrials, 1);
    fixationPercentIntervals = zeros(nTrials, 1);
    trialDuration = zeros(nTrials, 1);

    % calculate the fixation percent for each trial in the data
    for trial = trialVector
        % get the current trial's durations and convert them into milliseconds
        currentAttentionGrabberDuration = csvData{trial,'AttentionGrabberDuration'} .*1000;
        currentStimulusDuration = csvData{trial,'StimulusDuration'} .*1000;
        currentTrialDuration = currentAttentionGrabberDuration + currentStimulusDuration;

        % get the edf data regarding the current trial
        currentEDF = edfData(edfData.TRIAL_INDEX == trial,:);

        % find the last fixation row that starts before the of end the attention grabber
        if find(currentEDF.CURRENT_FIX_START < currentAttentionGrabberDuration & currentEDF.CURRENT_FIX_END > currentAttentionGrabberDuration)
            AttentionGrabberEndRow = find(currentEDF.CURRENT_FIX_START < currentAttentionGrabberDuration & currentEDF.CURRENT_FIX_END > currentAttentionGrabberDuration);
            startsInFixation = true;
        else % or if it does not exist: find the first fixation after the end of the attention grabber
            AttentionGrabberEndRow = find(currentEDF.CURRENT_FIX_START >= currentAttentionGrabberDuration, 1, 'first');
            startsInFixation = false;
        end

        % find row that covers the end of the stimulus presentation
        if find(currentEDF.CURRENT_FIX_START < currentTrialDuration & currentEDF.CURRENT_FIX_END > currentTrialDuration)
            StimulusEndRow = find(currentEDF.CURRENT_FIX_START < currentTrialDuration & currentEDF.CURRENT_FIX_END > currentTrialDuration);
            endsInFixation = true;
        else % or if it does not exist: find the last valid fixation before the end of the stimulus
            StimulusEndRow = find(currentEDF.CURRENT_FIX_END <= currentTrialDuration, 1, 'last');
            endsInFixation = false;
        end

        %% Choose only the rows that pertain to the stimulus time window
        stimulusWindow = currentEDF(AttentionGrabberEndRow:StimulusEndRow,:);
        if size(stimulusWindow,1) > 0
            if startsInFixation
                stimulusWindow.CURRENT_FIX_DURATION(1) = stimulusWindow.CURRENT_FIX_END(1) - currentAttentionGrabberDuration;
            % else
                % note, no adjustment for saccades necessary here as we count from
                % the first valid fixation and the information is always about the
                % saccade that follows
            end

            if endsInFixation 
                % adjust the duration of the last fixation by substracting the
                % overlap over the end of the trial duration
               stimulusWindow.CURRENT_FIX_DURATION(end) = ...
                   stimulusWindow.CURRENT_FIX_DURATION(end) - stimulusWindow.CURRENT_FIX_END(end) + currentTrialDuration;

               % and do not add the NEXT_SACCADE from that row
               stimulusWindow.NEXT_SAC_DURATION(end) = 0;

            else % if it ends during a saccade, blink, etc. 
                % adjust the duration of the last saccade by substracting the
                % overlap over the end of the trial duration
               stimulusWindow.NEXT_SAC_DURATION(end) = ...
                   stimulusWindow.NEXT_SAC_DURATION(end) - stimulusWindow.NEXT_SAC_END_TIME(end) + currentTrialDuration;
            end  

            % get all rows where the fixation was on the screen
            validFixations = stimulusWindow(...
                (0 <= stimulusWindow.CURRENT_FIX_X) & (stimulusWindow.CURRENT_FIX_X <= 1920) & ...
                (0 <= stimulusWindow.CURRENT_FIX_Y) & (stimulusWindow.CURRENT_FIX_Y <= 1080)...
                ,:);

            % Calculate the duration of all valid fixations
            totalFixationDuration = sum(validFixations.CURRENT_FIX_DURATION);        
        end
        %% A
        % intervals longer than 500 ms were coded as a ‘look away’ from the
        % screen and discarded from total looking time. 
        % Looking time data intervals of **less than 500** ms were imputed 
        % as looks, as long as the child was looking at the screen before 
        % as well as after the interval
        % calculate the time intervals between all valid fixations
        
        % 1st mark all rows that precede an interfixation interval that lies
        % between two valid fixations
        validIntervals = [validFixations.CURRENT_FIX_INDEX zeros(length(validFixations.CURRENT_FIX_INDEX), 1)];
        if size(validIntervals,1) > 1
            for j = 1:size(validIntervals, 1)-1
                if (validIntervals(j+1,1) == validIntervals(j,1) + 1)
                    validIntervals(j, 2) = validFixations(j+1,:).CURRENT_FIX_START - validFixations(j,:).CURRENT_FIX_END;
                end
            end
        end
       
        % the second row of validInterals contains the duration of time
        % duration between two valid fixations, select only those that are
        % SHORTER THAN 500 ms
        totalTimeDataIntervals = sum(validIntervals(validIntervals(:,2) < 500, 2));
        
        % sum all fixations and time intervals that are shorter than 500 ms and 
        % are preceded and followed by a fixation on screen
        totalFixationDurationIntervals(trial) = totalFixationDuration + totalTimeDataIntervals;
        % calculate the fixation percent
        fixationPercentIntervals(trial) = totalFixationDurationIntervals(trial) ./ currentTrialDuration;
        
        %% B
        % get a vector of all saccades that were on the screen -> validSaccades
        validSaccades = (...
            (0 <= validFixations.NEXT_SAC_START_X) & (validFixations.NEXT_SAC_START_X <= 1920) & ...
            (0 <= validFixations.NEXT_SAC_START_Y) & (validFixations.NEXT_SAC_START_Y <= 1080) & ...
            (0 <= validFixations.NEXT_SAC_END_X)   & (validFixations.NEXT_SAC_END_X <= 1920)   & ...
            (0 <= validFixations.NEXT_SAC_END_Y)   & (validFixations.NEXT_SAC_END_Y <= 1080)...
            );
        totalSaccadeDuration = sum(validFixations.NEXT_SAC_DURATION(validSaccades), 'omitnan');
        
        % sum all fixations and saccades that are within the screen
        totalFixationDurationSaccades(trial) = totalFixationDuration + totalSaccadeDuration;
        % calculate the fixation percent
        fixationPercentSaccades(trial) = totalFixationDurationSaccades(trial) ./ currentTrialDuration;
       
        %% save the trial duration
        trialDuration(trial) = currentTrialDuration;
    end

    % Generate the table output
    trialDurationFromEdfInSecs = trialDuration ./1000;
    totalFixationDuration_Saccades_FromEdfInSecs = totalFixationDurationSaccades ./1000;
    fixationPercent_Saccades_FromEdf = fixationPercentSaccades .* 100;
    
    totalFixationDuration_Intervals_FromEdfInSecs = totalFixationDurationIntervals ./1000;
    fixationPercent_Intervals_FromEdf = fixationPercentIntervals .* 100;
    
    % add column for familiar vs novel stimuli
    familiarWords = csvData.WordID(1:2);
    wordIsFamiliar = ismember(csvData.WordID, familiarWords);
    Familiarity = familiarityCategories(1 + wordIsFamiliar)';
    
    % add subject ID column and language column
    ID_language = repmat(languageList(subjectIDs(subject),:), nTrials, 1);
    
    currentCsvOutput = addvars(csvData, Familiarity, trialDurationFromEdfInSecs, totalFixationDuration_Saccades_FromEdfInSecs, fixationPercent_Saccades_FromEdf, totalFixationDuration_Intervals_FromEdfInSecs, fixationPercent_Intervals_FromEdf);
    currentCsvOutput = [ID_language, currentCsvOutput];
    
    csvOutput = [csvOutput; currentCsvOutput]; % add new rows to the output table
end

% generate output file
writetable(csvOutput, sprintf('./output/recoveredData_%s.csv', datetime('today', 'Format', 'yyyy_MM_dd')));
fprintf('Output file `recoveredData_%s.csv` successfully created in `./output`\n', datetime('today', 'Format', 'yyyy_MM_dd'));







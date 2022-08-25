%----------------------------------------------------------------------
%                       HOW 2 EXECUTE
%
% 1. Start Labchart, (open preset "iBEAT"). Apply LabChart/Fast Response Output
% Settings according to FAST_RESPONSE_SETTINGS.txt
% 
% 1.1 Test the Threshold: (a) plug output of powerlab (analog 1) to input 3 (this only tests fast response output) or (b) run
% ecgTest.m (this tests arduino & fast response output)
%
% 2. Make sure arduino & eye tracker are connected
% 
% 3. Select Experiment Screen as Main Display, set SCREEN_NAME='presentation'
% 
% 4.set DUMMY_MODE = false, TRACKING_ACTIVE = true, DEBUG = false,
% MAX_TRIAL_TIME = 20, NUM_TRIALS = 80
% 
% 5. run the experiment. to escape, press the 'Esc' key while a
% stimulus is presented
%
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% Configuration for Debugging: DEBUG = true, DUMMY_MODE = false,
% TRACKING_ACTIVE = <true|false>, MAX_TRIAL_TIME = 4, NUM_TRIALS = 4
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
%
%----------------------------------------------------------------------



%----------------------------------------------------------------------
%                          CLEAR
%----------------------------------------------------------------------

% clear workspace & close screens/clear textures
clear
close all
Screen('CloseAll'); 
sca();


%----------------------------------------------------------------------
%                          IMPORT FUNCTIONS
%----------------------------------------------------------------------
addpath("functions");
addpath(".." + filesep + "UTILS");

%----------------------------------------------------------------------
%                        GLOBAL SETTINGS
%----------------------------------------------------------------------

% set debug mode
DEBUG = false;
TRACKING_ACTIVE = true;    % Eye Tracking?
DUMMY_MODE = false;         % EyeLink Dummy Mode?
BACKGROUND_COLOR = [216/255 216/255 216/255];

SCREEN_NAME = 'presentation';       % options: 'side', 'main', 'presentation'


%----------------------------------------------------------------------
%                        Initialize Trial Data
%----------------------------------------------------------------------

% set constants
NUM_TRIALS = 80;         % must be a multiple of 4 
MAX_TRIAL_TIME = 20;
MIN_TRIAL_TIME = 5;
MAX_LOOKAWAY_TIME = 3;
MAX_CONSECUTIVE_ABORTED_TRIALS = 5;

try
    % get subject code from command line and make filename for data output
    if(DEBUG)
        subjectCode = "TEST";
    else
        subjectCode = getSubjectCode();
    end
    filename = getFileName("subjectData", subjectCode);

    % generate per trial data (images, left/right, iti...)
    trialData = makeTrialData(NUM_TRIALS, subjectCode);

catch e
    showErrorMsg("Trial Data could not be set up. Terminating.", e);
    clear;
end

try
    % get attention grabber assets
    attentionGrabberImage = imread("media" + filesep + "monkey.jpg");
catch e
    showErrorMsg("Attention Grabber Img could not be loaded. Terminating.", e);
    clear;
end






%----------------------------------------------------------------------
%                        Set up PTB Screen
%----------------------------------------------------------------------
try
    % Uncomment next line if screen sync problems appear
    Screen('Preference', 'SkipSyncTests', 1);
    
    % default settings for setting up Psychtoolbox
    PsychDefaultSetup(2);

    % Get the screen number  (if errors occur, set screen number manually (main screen: 1, side screen: 2, presentation screen: 3))
    try
        screenNumber = getScreenNumber(SCREEN_NAME);
    catch
        showErrorMsg("ScreenNumber could not be retrieved. Terminating.", e);
        return;
    end


    % Open an on screen window
    [window, windowRect] = PsychImaging('OpenWindow', screenNumber, BACKGROUND_COLOR);

    % Get the dims of the on screen window
    [screenWidth, screenHeight] = Screen('WindowSize', window);

    % Query the frame duration (inter frame interval; framerate = 1/ifi)
    ifi = Screen('GetFlipInterval', window);

    % Get the centre coordinate of the window
    [xCenter, yCenter] = RectCenter(windowRect);

    % Set up alpha-blending for smooth (anti-aliased) lines
    Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

catch e
    showErrorMsg("PTB and Screen could not be set up. Terminating.", e);
    sca();
    clear;
    return;
end

%----------------------------------------------------------------------
%                        Set up PTB Audio
%----------------------------------------------------------------------
InitializePsychSound;
ptbAudioDevice = [];
ptbNumChannels = 2;
audioSamplerate = 44100;
try
    audioHandle = PsychPortAudio('Open', ptbAudioDevice, [], 0, audioSamplerate, ptbNumChannels);
catch
    disp("Audio Device could not be set up on " + audioSamplerate + "hz. Usingh default samplerate now.");
    psychlasterror('reset');
    audioHandle = PsychPortAudio('Open', ptbAudioDevice, [], 0, [], ptbNumChannels);
end



%----------------------------------------------------------------------
%                        Load Sounds
%----------------------------------------------------------------------
try
    audMonkey = ptbLoadWav("media" + filesep + "monkey_wiggle2.wav");
    audBip1 = ptbLoadWav("media" + filesep + "bip1.wav");
    audBop1 = ptbLoadWav("media" + filesep + "bop1.wav");
    audBip2 = ptbLoadWav("media" + filesep + "bip2.wav");
    audBop2 = ptbLoadWav("media" + filesep + "bop2.wav");
catch e
    showErrorMsg("Sounds could not be loaded. Terminating.", e);
    sca();
    return;
end



%----------------------------------------------------------------------
%                        Set up Keyboard Queue
%----------------------------------------------------------------------
try
    escapeKeyIdx = KbName('escape');
    pauseKeyIdx = KbName('p');
    calibrateKeyIdx = KbName('c');
    attentionKeyIdx = KbName('a');
    continueKeyIdx = KbName('c');
    quitKeyIdx = KbName('q');
    KbQueueCreate();
    KbQueueStart();
catch e
    showErrorMsg("Keyboard queue could not be set up. Terminating.", e);
    sca();
    return;
end



%----------------------------------------------------------------------
%                        Set up Arduino
%----------------------------------------------------------------------
try
    ard = arduino();
    pinNumber = 'A0';   % analog input pin on arduino that is connected to powerlab
    lastECGStatus = "OFF";  
catch e
    showErrorMsg("Arduino could not be set up. Terminating.", e);
    sca();
    return;
end



%----------------------------------------------------------------------
%                        Set up Eyelink
%----------------------------------------------------------------------
if(TRACKING_ACTIVE)
    el=EyelinkInitDefaults(window);
    if ~EyelinkInit(DUMMY_MODE, 1)
        fprintf('Eyelink Init aborted.\n');
        return;
    end
    % make sure that we get gaze data from the Eyelink
    Eyelink('command', 'link_sample_data = LEFT,RIGHT,GAZE,AREA,FIXATION,SACCADE,BLINK,MESSAGE');
    % set edf file output params
    Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
    Eyelink('command', 'file_sample_data = RIGHT,LEFT,GAZE,GAZERES,AREA,HREF,VELOCITY');
    % Eyelink('command', 'calibration_type = H3');
    % Calibrate the eye tracker
    EyelinkDoTrackerSetup(el);
    % do a final check of calibration using driftcorrection
    EyelinkDoDriftCorrection(el);
    eye_used = -1;
end



%----------------------------------------------------------------------
%                        Run Trials
%----------------------------------------------------------------------

numConsecutiveAbortedTrials = 0;
endExperiment = false;

% initialize vars for storing delta times between ecg events in asynchronous
% runs
dtOn = [];      % deltaTimes of ON events
dtOff = [];     % deltaTimes of OFF events
avgDtOn = 0;
avgDtOff = 0;
lastEventTime = 0;

try
    for trialIndex = 1:length(trialData) 
        
        % if maximum number of aborted trials has been reached, ask
        % experimenter if experiment should be aborted
        quitExperiment = false;
        if numConsecutiveAbortedTrials >= MAX_CONSECUTIVE_ABORTED_TRIALS 
           text = 'Maximum number of consecutive aborted Trials reached.\nPress C to continue or Q to quit.';
           flipText(text, window, BACKGROUND_COLOR);
           disp(text);
           decisionMade = false;
           while ~decisionMade
               [~,pressedTiVec] = KbQueueCheck();
               if pressedTiVec(continueKeyIdx) 
                   decisionMade = true;
                   quitExperiment = false;
               elseif pressedTiVec(quitKeyIdx) 
                   decisionMade = true;
                   quitExperiment = true;
               end
           end
           % reset counter
           numConsecutiveAbortedTrials = 0;
        end
        if quitExperiment
            endExperiment = true;
            break;
        end
        
        % initialize csv for per-frame data
        csvColumns = ["trialIndex", "timestamp", "gaze_x", "gaze_y", "ecgState", "stimulusState"];
        csv = initCSV(csvColumns);
        
        if DEBUG
            disp(trialData(trialIndex));
        end
        
        % Show Attention Grabber 
        Screen('FillRect', window, BACKGROUND_COLOR);
        textureMonkey = Screen('MakeTexture', window, attentionGrabberImage);
        Screen('DrawTexture', window, textureMonkey, [], [], 0);
        Screen('Flip', window);
        ptbPlayAudio(audioHandle, audMonkey);
        Screen('DrawTexture', window, textureMonkey, [], [], -30);
        Screen('Flip', window);
        WaitSecs(.5);
        Screen('DrawTexture', window, textureMonkey, [], [], 30);
        Screen('Flip', window);
        WaitSecs(.5);
        Screen('DrawTexture', window, textureMonkey, [], [], 0);
        Screen('Flip', window);
        ptbPlayAudio(audioHandle, audMonkey);
        WaitSecs(.5);
        
        if DEBUG
           KbPressWait();
        end


        % get and process current trial data object
        currentTrialData = trialData(trialIndex);
        imageRest = imread(currentTrialData.picRest);
        [heightRest, widthRest, ~] = size(imageRest);
        imageBounce = imread(currentTrialData.picBounce);
        [heightBounce, widthBounce, ~] = size(imageBounce);
        textureRest = Screen('MakeTexture', window, imageRest);
        textureBounce = Screen('MakeTexture', window, imageBounce);  
        if(currentTrialData.lr)
            imgXPosition = 0;
        else
            imgXPosition = xCenter;
        end

        % init fixation vars
        fixationActive = false;
        lookAwayTime = 0.;          % measures time while subject is looking away
        lookAwayStartTime = clock();     % the timestamp when looking away started
        totalFixationTime = 0.;

        trialStartTime = clock();
        
        % run trial
        if(currentTrialData.synchronous)

            % - - - - - - -
            % synchronous trial 
            % - - - - - - -
            
            startTime = GetSecs();
            lastEventTime = startTime;
            
            % reset keyboard events
            KbQueueFlush();
            KbEventFlush();
            
            % reset delta times
            dtOn = [];
            dtOff = [];
            avgDtOn = 0;
            avgDtOff = 0;         
            
            % initialize eyelink edf recording
            if(TRACKING_ACTIVE)  
                edfFileName = char("trial" + string(trialIndex) + ".edf");
                %Eyelink('OpenFile', edfFileName);

                edfFileError = Eyelink('OpenFile', edfFileName);
                if(edfFileError)
                    error("EDF File couldn't be created on the Eyelink Host");
                    return;
                end

                Eyelink('StartRecording');
                Eyelink('Message', 'SYNCTIME'); % mark zero-plot time in data file
            end
            
            % - - - - - - -
            % show stimulus
            % - - - - - - -   
            %wait until ecg state is OFF (prevent jitter at first beat)
            while getECGStatus(ard, pinNumber) == "ON"
                WaitSecs(1/200)
            end
            
            % trial goes on as long as it is shorter than the max time and
            % either the subject is fixated or the time is smaller than the
            % trial minimum
            while(((GetSecs() - startTime < MAX_TRIAL_TIME)...             % Trials take 20s at max...
                        && (lookAwayTime <= MAX_LOOKAWAY_TIME))...         % Subjects may look away for max 3 seconds...
                   || (GetSecs() - startTime <= MIN_TRIAL_TIME))           % ...but anyway, trials last at least 5 seconds

                frameStart = GetSecs();

                if(TRACKING_ACTIVE)
                    error=Eyelink('CheckRecording');
                    if(error~=0)
                        break;
                    end
                end
                
                % - - - - - - -
                % get Ecg status, show image and play sound
                % - - - - - -  -
                stimulusRect = [imgXPosition 0 imgXPosition+screenWidth/2 screenHeight];
                currentECGStatus = getECGStatus(ard, pinNumber);
                statusChanged = (currentECGStatus ~= lastECGStatus);
                lastECGStatus = currentECGStatus;
                
                %calc delta times for event
                if(statusChanged)
                    dt = GetSecs() - lastEventTime;
                    if(currentECGStatus == "OFF")
                        dtOff = [dtOff, dt];
                    else
                        dtOn = [dtOn, dt];
                    end
                    lastEventTime = GetSecs();
                end
                
                % draw / play
                if(currentECGStatus == "OFF")
                    Screen('FillRect', window, BACKGROUND_COLOR);
                    Screen('DrawTexture', window, textureRest, [0 0 widthRest heightRest],...
                        stimulusRect, 0);
                    Screen('Flip', window);
                    if(statusChanged)
                        if(currentTrialData.audNumber == '1')
                            ptbPlayAudio(audioHandle, audBop1);
                        else
                            ptbPlayAudio(audioHandle, audBop2);
                        end
                    end
                else
                    Screen('FillRect', window, BACKGROUND_COLOR);
                    Screen('DrawTexture', window, textureBounce, [0 0 widthBounce heightBounce],...
                        stimulusRect, 0);
                    Screen('Flip', window);
                    if(statusChanged)
                        if(currentTrialData.audNumber == '1')
                            ptbPlayAudio(audioHandle, audBip1);
                        else
                            ptbPlayAudio(audioHandle, audBip2);
                        end
                    end
                end
                
                % get fine timestamp
                timestamp_millis = string(datestr(clock(), 'YYYY/mm/dd HH:MM:SS:FFF'));
                
                % - - - - - - -
                % get eyelink data
                % - - - - - -  -
                gaze_x = 0;
                gaze_y = 0;
                if(TRACKING_ACTIVE)
                    [eye_used, fixationActive, lookAwayTime, lookAwayStartTime, gaze_x, gaze_y] =...
                        processEyelinkSample(el, eye_used, fixationActive, lookAwayTime, stimulusRect, lookAwayStartTime, DEBUG);
                end
                
                % - - - - - - -
                % write per frame data to csv
                % - - - - - -  -
                csvRow = [trialIndex timestamp_millis gaze_x gaze_y currentECGStatus currentECGStatus];
                csv = appendToCSV(csv, csvRow);
                
                 % - - - - - - -
                % check for escape and pause key
                % press'p' to end pause, 'c' to recalibrate the eye tracker or 'a' to play an attention getter video
                % - - - - - -  -
                endTrial = false;
                [~,pressedTiVec] = KbQueueCheck();
                if(pressedTiVec(escapeKeyIdx))
                    disp("Esc pressed");
                    endExperiment = true;
                    break;
                elseif (pressedTiVec(pauseKeyIdx))
                    disp("'p' pressed (pause) [press'p' to end pause, 'c' to recalibrate the eye tracker or 'a' to play an attention getter video]");
                    paused = true;
                    while(paused)
                        [~,pressedTiVec] = KbQueueCheck();
                        if (pressedTiVec(pauseKeyIdx))
                            paused = false;
                        elseif (pressedTiVec(attentionKeyIdx))
                            playAttentionGetterVideo(window, windowRect);
                            paused = false;
                        elseif (TRACKING_ACTIVE && pressedTiVec(calibrateKeyIdx))
                            % Calibrate the eye tracker
                            EyelinkDoTrackerSetup(el);
                            % do a final check of calibration using driftcorrection
                            EyelinkDoDriftCorrection(el);
                            paused = false;
                        end
                    end
                    endTrial = true;
                end
                if endTrial
                    break;
                end
                
                
                % wait; sending new frames to the screen can be done after IFI has passed,
                % therefore wait for the difference between ifi and the time that has passed while presenting
                % the current frame
                frameEnd = GetSecs();
                frameDuration = frameEnd - frameStart;
                ifiRemainder = ifi - frameDuration;
                if(ifiRemainder < 0)
                    ifiRemainder = 0;
                end
                WaitSecs(ifiRemainder);  
                
            end
            
            % finilize edf recording and receive file
            if(TRACKING_ACTIVE)
                Eyelink('Stoprecording');
                closeError = Eyelink('CloseFile');
                edfLocalPath = char("subjectData" + filesep + string(currentTrialData.subject));
                receiveError = Eyelink('ReceiveFile', edfFileName, edfLocalPath, 1);
            end
            
            % calculate average delta time
            avgDtOn = mean(dtOn);
            avgDtOff = mean(dtOff);

            % sanity checks
            if (avgDtOn < .3)          
                avgDtOn = .3;
            end
            if (avgDtOff < .05)        
                avgDtOff = .05;
            end
            
            
            % calculate total trial time
            trialEndTime = clock();
            trialTime = etime(trialEndTime, trialStartTime);
            
            if(lookAwayTime >= MAX_LOOKAWAY_TIME)
                numConsecutiveAbortedTrials = numConsecutiveAbortedTrials + 1;
            else
                numConsecutiveAbortedTrials = 0;
            end
            
            if DEBUG
                disp('Trial Over. Trial Time:');
                disp(trialTime);
            end
            

            % wait for key press
            if ~endExperiment && DEBUG
                KbPressWait();
            end

            
            
        else
            
            % - - - - - - -
            % asynchronous trial
            % - - - - - - -

            
            % reset keyboard events
            KbQueueFlush();
            KbEventFlush();
                      
            % make delta times faster or slower (+/- 10%)
            slower = currentTrialData.slowfast;
            if(slower)
                avgDtOnModified = avgDtOn * 1.1;
                avgDtOffModified = avgDtOff * 1.1;
            else
                avgDtOnModified = avgDtOn * 0.9;
                avgDtOffModified = avgDtOff * 0.9;
            end
            
            
            startTime = GetSecs();
            currentState = "OFF";
            
            % initialize eyelink edf recording
            if(TRACKING_ACTIVE)  
                edfFileName = char("trial" + string(trialIndex) + ".edf");
                %Eyelink('OpenFile', edfFileName);

                edfFileError = Eyelink('OpenFile', edfFileName);
                if(edfFileError)
                    error("EDF File couldn't be created on the Eyelink Host");
                    return;
                end

                Eyelink('StartRecording');
                Eyelink('Message', 'SYNCTIME'); % mark zero-plot time in data file
            end
            
            % - - - - - - -
            % show stimulus
            % - - - - - -  -
            timeLastStateChange = GetSecs();
            % init delta time
            dt = 0;
            
            % trial goes on as long as it is shorter than the max time and
            % either the subject is fixated or the time is smaller than the
            % trial minimum
            while(((GetSecs() - startTime < MAX_TRIAL_TIME)...             % Trials take 20s at max...
                        && (lookAwayTime <= MAX_LOOKAWAY_TIME))...         % Subjects may look away for max 3 seconds...
                   || (GetSecs() - startTime <= MIN_TRIAL_TIME))           % ...but anyway, trials last at least 5 seconds
                
                if(TRACKING_ACTIVE)
                    error=Eyelink('CheckRecording');
                    if(error~=0)
                        break;
                    end
                end      
    
                
                % update display state, if current dt has passed
                updateState = GetSecs() >= timeLastStateChange + dt; 
                if(updateState)
                    % get delta time
                    if(currentState == "OFF")
                        dt = avgDtOffModified;
                    else
                        dt = avgDtOnModified;
                    end 
                    timeLastStateChange = GetSecs();
                    
                    % update fake ecg state
                    if(currentState == "OFF")
                        currentState = "ON";
                    else 
                        currentState = "OFF";
                    end  
                    
                    % - - - - - - -
                    % show image and play sound
                    % - - - - - -  -
                    stimulusRect = [imgXPosition 0 imgXPosition+screenWidth/2 screenHeight];
                    if(currentState == "OFF")
                        Screen('FillRect', window, BACKGROUND_COLOR);
                        Screen('DrawTexture', window, textureRest, [0 0 widthRest heightRest],...
                            stimulusRect, 0);
                        Screen('Flip', window);
                        if(currentTrialData.audNumber == '1')
                            ptbPlayAudio(audioHandle, audBop1);
                        else
                            ptbPlayAudio(audioHandle, audBop2);
                        end
                    else
                        Screen('FillRect', window, BACKGROUND_COLOR);
                        Screen('DrawTexture', window, textureBounce, [0 0 widthBounce heightBounce],...
                            stimulusRect, 0);
                        Screen('Flip', window);
                        if(currentTrialData.audNumber == '1')
                            ptbPlayAudio(audioHandle, audBip1);
                        else
                            ptbPlayAudio(audioHandle, audBip2);
                        end
                    end

                    
                end
                
                % - - - - - - -
                % get 'real' ecg data and timestamp
                % - - - - - -  -
                ecgStatus = getECGStatus(ard, pinNumber);
                timestamp_millis = string(datestr(clock(), 'YYYY/mm/dd HH:MM:SS:FFF'));
                
                % - - - - - - -
                % get eyelink data
                % - - - - - -  -
                gaze_x = 0;
                gaze_y = 0;
                if(TRACKING_ACTIVE)
                    [eye_used, fixationActive, lookAwayTime, lookAwayStartTime, gaze_x, gaze_y] =...
                        processEyelinkSample(el, eye_used, fixationActive, lookAwayTime, stimulusRect, lookAwayStartTime, DEBUG);
                end               
            
                
                % - - - - - - -
                % write per frame data to csv
                % - - - - - -  -
                csvRow = [trialIndex timestamp_millis gaze_x gaze_y ecgStatus currentState];
                csv = appendToCSV(csv, csvRow);
                
                
                 % - - - - - - -
                % check for escape and pause key
                % press'p' to end pause, 'c' to recalibrate the eye tracker or 'a' to play an attention getter video
                % - - - - - -  -
                endTrial = false;
                [~,pressedTiVec] = KbQueueCheck();
                if(pressedTiVec(escapeKeyIdx))
                    disp("Esc pressed");
                    endExperiment = true;
                    break;
                elseif (pressedTiVec(pauseKeyIdx))
                    disp("'p' pressed (pause) [press'p' to end pause, 'c' to recalibrate the eye tracker or 'a' to play an attention getter video]");
                    paused = true;
                    while(paused)
                        [~,pressedTiVec] = KbQueueCheck();
                        if (pressedTiVec(pauseKeyIdx))
                            paused = false;
                        elseif (pressedTiVec(attentionKeyIdx))
                            playAttentionGetterVideo(window, windowRect);
                            
                            paused = false;
                        elseif (TRACKING_ACTIVE && pressedTiVec(calibrateKeyIdx))
                            % Calibrate the eye tracker
                            EyelinkDoTrackerSetup(el);
                            % do a final check of calibration using driftcorrection
                            EyelinkDoDriftCorrection(el);
                            paused = false;
                        end
                    end
                    endTrial = true;
                end
                if endTrial
                    break;
                end
                
            end
            
            % finilize edf recording and receive file
            if(TRACKING_ACTIVE)
                Eyelink('Stoprecording');
                closeError = Eyelink('CloseFile');
                edfLocalPath = char("subjectData" + filesep + string(currentTrialData.subject));
                receiveError = Eyelink('ReceiveFile', edfFileName, edfLocalPath, 1);
            end
            
            
            % calculate total trial time
            trialEndTime = clock();
            trialTime = etime(trialEndTime, trialStartTime);
            
            if(lookAwayTime >= MAX_LOOKAWAY_TIME)
                numConsecutiveAbortedTrials = numConsecutiveAbortedTrials + 1;
            else
                numConsecutiveAbortedTrials = 0;
            end
            
            if DEBUG
                disp('Trial Over. Trial Time:');
                disp(trialTime);
            end
            
            
            % wait for key press
            if ~endExperiment && DEBUG
                KbPressWait();
            end

        end
  
        
        % write trial data to csv
        currentTrialData.stimulusRect = stimulusRect;
        currentTrialData.trialIndex = trialIndex;
        currentTrialData.startTime = datestr(trialStartTime);
        currentTrialData.endTime = datestr(trialEndTime);
        writeTrialDataToCSV(currentTrialData);

        % write per-frame data to csv
        csvDir = "subjectData" + filesep() + string(currentTrialData.subject);
        csvFilename = "frameData_" + string(trialIndex) + ".csv";
        writeStringToFile(csv, csvDir, csvFilename);
            
        
        % terminate experiment if needed
        if(endExperiment)
            break;
        end
        
        % Wait (inter-trial interval)
        Screen('FillRect', window, BACKGROUND_COLOR); 
        Screen('Flip', window);
        iti = currentTrialData.ITI / 1000; % convert ms to s
        WaitSecs(iti);        


    end
    
    
catch e
    showErrorMsg("An unexpected error has occured while running the trials. Terminating.", e)
end



%----------------------------------------------------------------------
%                       Terminate
%----------------------------------------------------------------------
if(TRACKING_ACTIVE)
    Eyelink('StopRecording');
end

% close screen
sca();
Screen('CloseAll'); % this also deletes textures etc.
Screen('Close'); 
% clean queue
KbQueueRelease();
KbReleaseWait();
%destroy audio device
PsychPortAudio('Close', audioHandle);

clear;

% main(screenNumber, SkipTests, Fullscreen)
% General Information
%       Between subjects design (i.e. two participant groups)
%       4 target words (e.g. Balken, Kurbel, Pinsel, Felsen) divided 
%           between the two participant groups
%       For the familiarization phase, four sentence passages are created 
%           which contain each of the four target words. Every participant 
%           group listens to only two of these passages.
%       Every participant group is familiarized with two of the words (e.g. 
%           Balken and Pinsel) and the remaining two (e.g. Kurbel and 
%           Felsen) serve as unfamiliar words at the test phase.
% written by Jakob Weickmann, MA BSc
% 1.10.2020
% Github:
% https://github.com/wunderwald/MindTheBody/tree/Jakob/SpeechSegmentation

%% ===================================================
%               INITIALIZATION AND DEFAULTS
% ==========================================================

% Adjust path for lab pc
% cd('C:\[...]\SpeechSegmentation');

% Clear everything
close all;
clear mem;
sca;
clc;

disp('Initializing script...');

origin_folder = cd;
addpath 'Scripts';
addpath("..\UTILS");

AssertOpenGL;
PsychDefaultSetup(2);

Fullscreen = 1;
SkipTests = 1;
useExcel = 1;
useManualLists = 0;

% -----------------------------------------------
% For EyeLink
TRACKING_ACTIVE = false;     % Eye Tracking?
DUMMY_MODE = false;         % EyeLink Dummy Mode?
DEBUG = false;

if TRACKING_ACTIVE    
    screenNumber = getScreenNumber('presentation'); % options: 'side', 'main', 'presentation'
else
    % screenNumber = getScreenNumber('side');
    screenNumber = 0;
end

%% ===================================================
%                   EXPERIMENTAL DESIGN
% ==========================================================

% WORDS
words = {1, 2, 3, 4; "B", "F", "K", "P"};
[B, F, K, P] = matsplit(words, 1);

nFamTrials = 4; % number of trials in familiarization block
nTestTrials = 12; % number of trials in testing block
nBlocks = 3; % number of experimental blocks 
nTexts = 4; % number of different text passages

MIN_TRIAL_TIME = 3;
MAX_LOOKAWAY_TIME = 2; % in seconds

% Durations in seconds
durations = 1.000; % inter-trial interval

% Background Colour when opening window
bgc = 216;

audioReadStartTime = GetSecs();
%% ===================================================
%                   DATA IMPORT
% ==========================================================
% Read WAV file from filesystem:
% if no preloaded stimuli already exist in ./Stimuli
if ~exist('./Stimuli/sounds.mat', 'file')
    soundFiles = soundImport_('./Audio/');
else
    disp('sounds.mat found');
    textprogressbar('Loading sounds:        ');
    load('./Stimuli/sounds.mat', 'soundFiles');
    try
        textprogressbar(100);
    catch
        textprogressbar('Loading sounds:        ');
        textprogressbar(100);
    end
    textprogressbar('done');
end


duration = GetSecs() - audioReadStartTime;
fprintf('It took %.2f seconds to load the sounds.\n', duration);

%% ===================================================
%                 ATTENTION GRABBER SETUP
% ==========================================================
attentionGrabberFiles = cell(3,3);
AGSounds = ["baby", "bell", "bird"];
for i = 1:3
    [y, attentionGrabberFiles{i,2}] = psychwavread(strcat('./AttentionGetter/', AGSounds(i),'.aiff'));
    numchannels = size(y,2); 
        if numchannels < 2
            y = [y, y];
        end
    attentionGrabberFiles{i,1} = y'; 
end
[attentionGrabberFiles{1,3}, ~, alpha]= imread('./AttentionGetter/wheel.png'); 
attentionGrabberFiles{1,3}(:,:,4) = alpha;

%% ===================================================
%                       SCREEN SETUP
% ==========================================================

% Fullscreen
if Fullscreen
    screenRect = [];
else
    screenRect = [10 10 710 710];
end

% Here we call some default settings for setting up Psychtoolbox
PsychDefaultSetup(2);
rng('shuffle');

% disable syn tests when coding/debugging but not when running ex periments!!
if SkipTests
    Screen('Preference', 'SkipSyncTests', 1);
else
    Screen('Preference', 'SkipSyncTests', 0);
end

% Checking Psychtoolbox: Break and issue an eror message if installed
% Psychtoolbox is not based on OpenGL or Screen() is not working properly.
AssertOpenGL;

% Get black and white index of the system.
% white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);

%% ===================================================
%               PARTICIPANT'S DETAILS DIALOG
% ==========================================================
if useExcel == 1
    [subjectCode, group, order, testListCode] = participantDetails_('Pseudorandom stimuli');
    setupInfo = [group, order, nTestTrials, nBlocks, useManualLists, testListCode];
else
    [subjectCode, group, order] = participantDetails_();
    setupInfo = [group, order, nTestTrials, nBlocks, useManualLists];
end

%% ===================================================
%                        TRIAL MATRIX
% ==========================================================
[TrialMat, famMatrix] = generateTrialMat(setupInfo, words);

trialDuration = zeros(4,nFamTrials + nTestTrials);
fixationMatrix = zeros(2, nFamTrials + nTestTrials);

%% ---------------------------------------------------
%                              KEYS
% ----------------------------------------------------------

% provide a consistent mapping of keyCodes to key names on all operating systems.
KbName('UnifyKeyNames');

% keyCodes: [Space, Return, Escape, G, H, X, P]
abortExpKey = 'Escape';
attentionGrabberKey = 'G';
pauseKey = 'P';
abortBlockKey = 'X';
keyCodes = [KbName('Space'), KbName('Return'), KbName(abortExpKey), ...
    KbName(attentionGrabberKey), KbName(attentionGrabberKey) + 1, ...
    KbName(abortBlockKey), KbName(pauseKey), KbName('V'), KbName('C')];

%% ---------------------------------------------------
%                         AUDIO PLAYBACK
% ----------------------------------------------------------

% Perform basic initialization of the sound driver:
disp('Initializing PsychSound: ');
InitializePsychSound;

% can specify audio device here
device = [];

% Open the  audio device, with default mode [] (==Only playback),
% and a required latencyclass of zero 0 == no low-latency mode, as well as
% a frequency of freq and nrchannels sound channels.
% This returns a handle to the audio device:
disp('Trying to open audio device...');
try
    % Try with the 'freq'uency we wanted:
    pahandle = PsychPortAudio('Open', device, [], 0, soundFiles(1).list.freq, 2);
    agaudiohandle = PsychPortAudio('Open', device, [], 0, attentionGrabberFiles{1,2}, 2);
catch
    % Failed. Retry with default frequency as suggested by device:
    fprintf('\nCould not open device at wanted playback frequency of %i Hz. Will retry with device default frequency.\n', freq);
    fprintf('Sound may sound a bit out of tune, ...\n\n');
    psychlasterror('reset');
    pahandle = PsychPortAudio('Open', device, [], 0, [], 2);
    agaudiohandle = PsychPortAudio('Open', device, [], 0, [], 2);
end

%% ===================================================
%                     OPEN ON-SCREEN WINDOW
% ==========================================================

disp('Opening on-screen window...');

% using Screen
bgColour_RGB = bgc * ones(1,3); % convert to RGB
BGC_Psychimaging = bgColour_RGB ./255;
% [window, windowRect] = Screen('OpenWindow', screenNumber, bgColour_RGB, screenRect);
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, BGC_Psychimaging, screenRect);

stimulusRect = windowRect;

% Retreive the maximum priority number
topPriorityLevel = MaxPriority(window);

% set priority level for accurate timing
Priority(topPriorityLevel);

ifi = Screen('GetFlipInterval', window);

% Set up alpha-blending for smooth (anti-aliased) lines
Screen('BlendFunction',window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

HideCursor(screenNumber);
%----------------------------------------------------------------------
%                        Set up Eyelink
%----------------------------------------------------------------------
if(TRACKING_ACTIVE)
    el = EyelinkInitDefaults(window);
    if ~EyelinkInit(DUMMY_MODE, 1)
        fprintf('Eyelink Init aborted.\n');
        return;
    end
    % !! The following Part is copied from VideoDemo.m provided by Eyelink
    % people  !!
    
    % set calibration/validation/drift-check(or drift-correct) background and target colors. It is important that this background colour is
    % similar to that of the stimuli to prevent large luminance-based pupil size changes (which can cause a drift in the eye movement data)
    disp("CALIB START");
    
    el.backgroundcolour = [115/255 115/255 115/255];
    
    % Configure animated calibration target path and properties
    el.calTargetType = 'video';
    calMovieName = ('media/calibVid.mov');
    
    el.calAnimationTargetFilename = [pwd '/' calMovieName];
    el.targetbeep = 0;
    el.feedbackbeep = 0;
    el.calAnimationResetOnTargetMove = true; % false by default, set to true to rewind/replay video from start every time target moves
    
    % You must call this function to apply the changes made to the el structure above
    EyelinkUpdateDefaults(el);    

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
    
    disp("CALIB DONE");
end

RestrictKeysForKbCheck(keyCodes);

%% ===================================================
%                 OPEN CHECKERBOARD
% ==========================================================

movie_dir = dir('./Video/*.avi');
absolutePathToMovie = strcat(origin_folder, '/Video/', movie_dir(1).name);

% Load movie
moviePtr = Screen('OpenMovie', window, absolutePathToMovie);
space_string = 'Press SPACE to start with the familiarization phase.';
instructions_string = ['Press SPACE to continue.\n',...
    'Press [P] to pause the script\nPress [X] to skip an attention grabber or a trial\nPress ESCAPE to abort and save the data'];
DrawFormattedText(window, ['Familiarization phase upcoming. ', instructions_string], 'left'); 
Screen('Flip', window);
disp(space_string);
KbWait();

%% ===================================================
%                 EXPERIMENTAL LOOP 
% ==========================================================
wheelTex = Screen('MakeTexture', window, attentionGrabberFiles{1,3});

angleSpeed = round(360*ifi*0.2); % degrees per iteration
wheelSpeed = ifi; % time between two frames

% initialize eyelink edf recording
if(TRACKING_ACTIVE)  
    edfFileName = char("s_" + string(subjectCode) + ".edf");
    edfFileError = Eyelink('OpenFile', edfFileName);
    if(edfFileError)
        error("EDF File couldn't be created on the Eyelink Host");
        return;
    end
    % Eyelink('StartRecording');
    Eyelink('Message', 'SYNCTIME'); % mark zero-plot time in data file
end

%% ----------------------------------------------------
%                 FAMILIARIZATION PHASE
% -----------------------------------------------------------
try
    for famIndex = famMatrix
        % EyeLink Initialization
        % init fixation vars
        fixationActive = false;
        lookAwayTime = 0.;               % measures time while subject is looking away
        lookAwayStartTime = clock();     % the timestamp when looking away started
        totalFixationTime = 0.;

        % run trial
        trialStartTime = GetSecs();
        lastEventTime = trialStartTime; 
        playingStimulusAudio = 0; 
        playingAGAudio.Active = 0;
        lastPlayed = trialStartTime - 2;

        agCounter = 0; 

        % get initial eyelink data
        % - - - - - -  -
        gaze_x = 0;
        gaze_y = 0;
        if(TRACKING_ACTIVE)
            Eyelink('StartRecording');
            [eye_used, fixationActive, lookAwayTime, lookAwayStartTime, gaze_x, gaze_y] =...
                processEyelinkSample_speechseg(el, eye_used, fixationActive, lookAwayTime, stimulusRect, lookAwayStartTime, DEBUG);
        end  


        % Show Attention Grabber 
        AGsoundID = randi(3);
        while ((fixationActive == false) || ... % play attention grabber while child is not looking at screen
                (GetSecs()-trialStartTime < 0.50))% but play at least for 0.5 seconds


            [skipTrial, terminate] = reactToKeyPresses_(pahandle, keyCodes);
            if skipTrial
                WaitSecs(0.1);
                break;
            elseif terminate
                exit_routine_(subjectCode, origin_folder, TrialMat, famMatrix, trialDuration)
                return
            end

            if angleSpeed*agCounter >= 360 
                agCounter = 0; % reset loop
            end

            playingAGAudio = PsychPortAudio('GetStatus', agaudiohandle);
            if ((~playingAGAudio.Active) && (GetSecs() - lastPlayed > 3.00))
                PsychPortAudio('FillBuffer', agaudiohandle, attentionGrabberFiles{AGsoundID, 1});
                PsychPortAudio('Start', agaudiohandle, 1);
                lastPlayed = GetSecs();
            end

            if agCounter == 0
                Screen('DrawTexture', window, wheelTex, [], [], 0);
                Screen('Flip', window);

            else 
                Screen('DrawTexture', window, wheelTex, [], [], (angleSpeed*agCounter));
                Screen('Flip', window);
            end

            agCounter = agCounter + 1; 

            % - - - - - - -
            % get eyelink data
            % - - - - - -  -

            gaze_x = 0;
            gaze_y = 0;
            if(TRACKING_ACTIVE)
                [eye_used, fixationActive, lookAwayTime, lookAwayStartTime, gaze_x, gaze_y] =...
                    processEyelinkSample_speechseg(el, eye_used, fixationActive, lookAwayTime, stimulusRect, lookAwayStartTime, DEBUG);
            end
        end   

        % ======================
        % Start Stimuli
        % ======================

        startTime = GetSecs();
        frameEndTime = GetSecs();
        previousFixation = true;

        % Open the  audio device 
        pahandle = PsychPortAudio('Open', device, [], 0, soundFiles(famIndex{2}).familiarization.freq, 2); 

        % End AG sounds
        if playingAGAudio.Active 
            PsychPortAudio('Stop', agaudiohandle);
        end

        % Fill Audio Buffer with text passage according to Trial Matrix 
        PsychPortAudio('FillBuffer', pahandle, soundFiles(famIndex{2}).familiarization.y_); 
        PsychPortAudio('Start', pahandle, 1, [], [], [] ,1); % play once and activate 'resume' 

        Screen('Flip', window); % initial flip 
        if Fullscreen 
            movieRect = [0, 0, windowRect(3), windowRect(4)]; % Fullscreen 
        else 
            movieRect = [100, 100, windowRect(3)-100, windowRect(4)-100]; 
        end 

        [droppedframes] = Screen('PlayMovie', moviePtr, 0.2, 1, 0); 

        totalLookAwayTime = 0;
        lastLookAwayTime = -1;

        while true

            [skipTrial, terminate] = reactToKeyPresses_(pahandle, keyCodes);
            if skipTrial
                WaitSecs(0.1);
                break;
            elseif terminate
                exit_routine_(subjectCode, origin_folder, TrialMat, famMatrix, trialDuration)
                return
            end

            % present stimuli...

            playingStimulusAudio =  PsychPortAudio('GetStatus', pahandle);
            playingAGAudio = PsychPortAudio('GetStatus', agaudiohandle);

            % when the audio finished playing end the loop
            if playingStimulusAudio.ElapsedOutSamples >= size(soundFiles(famIndex{2}).familiarization.y_, 2)
                break;
            end

            if playingStimulusAudio.Active == 0 % after playing an attention grabber
                % start the audio again
                PsychPortAudio('Start', pahandle, 1, [], [], [] ,1); % play once and activate 'resume'
            end

            % Wait for next movie frame, retrieve texture handle to it
            tex = Screen('GetMovieImage', window, moviePtr);

            % Draw the new texture immediately to screen:
            if Fullscreen
                Screen('DrawTexture', window, tex, [], movieRect);
            else
                Screen('DrawTexture', window, tex, []);
            end

            % Update display:
            Screen('Flip', window);

            % Release texture:
            Screen('Close', tex);

            % - - - - - - -
            % get eyelink data
            % - - - - - -  -

            gaze_x = 0;
            gaze_y = 0;
            if(TRACKING_ACTIVE)
                [eye_used, fixationActive, lookAwayTime, lookAwayStartTime, gaze_x, gaze_y] =...
                    processEyelinkSample(el, eye_used, fixationActive, lookAwayTime, stimulusRect, lookAwayStartTime, DEBUG);
                
                if lookAwayTime == -1 && lastLookAwayTime >= 0 
                    totalLookAwayTime = totalLookAwayTime + lastLookAwayTime;
                end 
                
                if ((fixationActive)) %&& (fixationActive == previousFixation))
                    fixationMatrix(1, famIndex{1}) = fixationMatrix(1, famIndex{1}) + (GetSecs() - frameEndTime); % plus runtime
                elseif ((~fixationActive)) %&& (fixationActive == previousFixation))
                    fixationMatrix(2, famIndex{1}) = fixationMatrix(2, famIndex{1}) + (GetSecs() - frameEndTime); % plus runtime
                end
                previousFixation = fixationActive;
                lastLookAwayTime = lookAwayTime;
                
            end
            frameEndTime = GetSecs();
        end
        
        if lookAwayTime ~= -1 
            totalLookAwayTime = totalLookAwayTime + lastLookAwayTime;
        end

        % save the trial duration
        trialDuration(1, famIndex{1}) = trialStartTime;
        trialDuration(2, famIndex{1}) = startTime - trialStartTime;
        trialDuration(3, famIndex{1}) = GetSecs() - startTime;
        trialDuration(4, famIndex{1}) = 100 * (fixationMatrix(1, famIndex{1}) / ...
            (fixationMatrix(2, famIndex{1}) + fixationMatrix(1, famIndex{1})));
        trialDuration(5, famIndex{1}) = totalLookAwayTime;
        trialDuration(6, famIndex{1}) = fixationMatrix(1, famIndex{1});
        trialDuration(7, famIndex{1}) = fixationMatrix(2, famIndex{1});
        
        
        if playingAGAudio.Active 
            PsychPortAudio('Stop', agaudiohandle);
        end
        PsychPortAudio('Close', pahandle);

        if(TRACKING_ACTIVE)                       
            Eyelink('Stoprecording');
        end

        % Stop checkerboard playback:
        Screen('PlayMovie', moviePtr, 0, 1, 0);

        % Update display:
        Screen('Flip', window);
        WaitSecs(durations(1));
    end

catch e
    showErrorMsg("An unexpected error has occured during the familiarization phase. Moving on...", e)
end

DrawFormattedText(window, ['Test phase upcoming. ', instructions_string], 'left'); 
Screen('Flip', window);
disp('Press SPACE to continue with the test phase.');
KbWait();

%% ----------------------------------------------------
%                      TEST PHASE
% -----------------------------------------------------------
try
    for trialIndex = TrialMat

        % EyeLink Initialization
        % init fixation vars
        fixationActive = false;
        lookAwayTime = 0.;               % measures time while subject is looking away
        lookAwayStartTime = clock();     % the timestamp when looking away started
        totalFixationTime = 0.;

        % run trial
        trialStartTime = GetSecs();
        lastEventTime = trialStartTime;
        playingStimulusAudio = 0;

        agCounter = 0;

        % get initial eyelink data
        % - - - - - -  -
        gaze_x = 0;
        gaze_y = 0;
        if(TRACKING_ACTIVE)
            Eyelink('StartRecording');
            [eye_used, fixationActive, lookAwayTime, lookAwayStartTime, gaze_x, gaze_y] =...
                processEyelinkSample_speechseg(el, eye_used, fixationActive, lookAwayTime, stimulusRect, lookAwayStartTime, DEBUG);
        end

        % Show Attention Grabber 
        AGsoundID = randi(3);
        while ((fixationActive == false) || ... % play attention grabber while child is not looking at screen
                (GetSecs()-trialStartTime < 0.50))% but play at least for 0.5 seconds

            [skipTrial, terminate] = reactToKeyPresses_(pahandle, keyCodes);
            if skipTrial
                WaitSecs(0.1);
                break;
            elseif terminate
                exit_routine_(subjectCode, origin_folder, TrialMat, famMatrix, trialDuration)
                return
            end

            if angleSpeed*agCounter >= 360 
                agCounter = 0; % reset loop
            end

            playingAGAudio = PsychPortAudio('GetStatus', agaudiohandle);
            if ((~playingAGAudio.Active) && (GetSecs() - lastPlayed > 3.00)) % if last time played is longer than 3 secs ago
                PsychPortAudio('FillBuffer', agaudiohandle, attentionGrabberFiles{AGsoundID, 1});
                PsychPortAudio('Start', agaudiohandle, 1);
                lastPlayed = GetSecs();
            end

            if agCounter == 0
                Screen('DrawTexture', window, wheelTex, [], [], 0);
                Screen('Flip', window);

            else 
                Screen('DrawTexture', window, wheelTex, [], [], (angleSpeed*agCounter));
                Screen('Flip', window);
            end

            agCounter = agCounter + 1; 

            % - - - - - - -
            % get eyelink data
            % - - - - - -  -
            gaze_x = 0;
            gaze_y = 0;
            if(TRACKING_ACTIVE)
                [eye_used, fixationActive, lookAwayTime, lookAwayStartTime, gaze_x, gaze_y] =...
                    processEyelinkSample_speechseg(el, eye_used, fixationActive, lookAwayTime, stimulusRect, lookAwayStartTime, DEBUG);
            end
        end  

        % ======================
        % Start Stimuli
        % ======================

        startTime = GetSecs();
        frameEndTime = GetSecs();
        previousFixation = true;

        % End AG sounds
        if playingAGAudio.Active 
            PsychPortAudio('Stop', agaudiohandle);
        end

        % Open the audio device
        pahandle = PsychPortAudio('Open', device, [], 0, soundFiles(trialIndex{2}).list.freq, 2);

        % Fill Audio Buffer with text passage according to Trial Matrix
        PsychPortAudio('FillBuffer', pahandle, soundFiles(trialIndex{2}).list.y_);
        PsychPortAudio('Start', pahandle, 1, [], [], [] ,1); % play once and activate 'resume'

        Screen('Flip', window); % initial flip
        if Fullscreen
            movieRect = [0, 0, windowRect(3), windowRect(4)]; % Fullscreen
        else 
            movieRect = [100, 100, windowRect(3)-100, windowRect(4)-100];
        end

        [droppedframes] = Screen('PlayMovie', moviePtr, 0.2, 1, 0);
        
        totalLookAwayTime = 0;
        lastLookAwayTime = -1;
        
        while ((lookAwayTime <= MAX_LOOKAWAY_TIME) ||... % play the trial while child is fixated
                (GetSecs()-startTime < 3.000)) % but play at least for 3 seconds
            [skipTrial, terminate] = reactToKeyPresses_(pahandle, keyCodes);
            if skipTrial
                WaitSecs(0.1);
                break;
            elseif terminate
                exit_routine_(subjectCode, origin_folder, TrialMat, famMatrix, trialDuration)
                return
            end

            % present stimuli...
            playingStimulusAudio =  PsychPortAudio('GetStatus', pahandle);
            playingAGAudio = PsychPortAudio('GetStatus', agaudiohandle);

            % when the audio finished playing end the loop
            if playingStimulusAudio.ElapsedOutSamples >= size(soundFiles(trialIndex{2}).list.y_, 2)
                break;
            end

            if playingStimulusAudio.Active == 0 % after playing an attention grabber
                % start the audio again
                PsychPortAudio('Start', pahandle, 1, [], [], [] ,1); % play once and activate 'resume'
            end

            % Wait for next movie frame, retrieve texture handle to it
            tex = Screen('GetMovieImage', window, moviePtr);

            % Draw the new texture immediately to screen:
            if Fullscreen
                Screen('DrawTexture', window, tex, [], movieRect);
            else
                Screen('DrawTexture', window, tex, []);
            end

            % Update display:
            Screen('Flip', window);

            % Release texture:
            Screen('Close', tex);    

            % - - - - - - -
            % get eyelink data
            % - - - - - -  -
            gaze_x = 0;
            gaze_y = 0;
            if(TRACKING_ACTIVE)
                [eye_used, fixationActive, lookAwayTime, lookAwayStartTime, gaze_x, gaze_y] =...
                    processEyelinkSample(el, eye_used, fixationActive, lookAwayTime, stimulusRect, lookAwayStartTime, DEBUG);
                
                if lookAwayTime == -1 && lastLookAwayTime >= 0 
                    totalLookAwayTime = totalLookAwayTime + lastLookAwayTime;
                end                    
                
                if (fixationActive) % && (fixationActive == previousFixation)
                    fixationMatrix(1, trialIndex{1} + length(famMatrix)) = fixationMatrix(1, trialIndex{1} + length(famMatrix)) + (GetSecs() - frameEndTime); % plus runtime
                elseif (~fixationActive) % && (fixationActive == previousFixation)
                    fixationMatrix(2, trialIndex{1} + length(famMatrix)) = fixationMatrix(2, trialIndex{1} + length(famMatrix)) + (GetSecs() - frameEndTime); % plus runtime
                end
                previousFixation = fixationActive;
                lastLookAwayTime = lookAwayTime;
            end
            frameEndTime = GetSecs();
        end

        if lookAwayTime ~= -1 
            totalLookAwayTime = totalLookAwayTime + lastLookAwayTime;
        end
        
        % save the trial duration
        trialDuration(1, trialIndex{1}+length(famMatrix)) = trialStartTime;
        trialDuration(2, trialIndex{1}+length(famMatrix)) = startTime - trialStartTime; % AG duration
        trialDuration(3, trialIndex{1}+length(famMatrix)) = GetSecs() - startTime; % stimulus duration
        trialDuration(4, trialIndex{1}+length(famMatrix)) = 100 * (fixationMatrix(1, trialIndex{1} + length(famMatrix)) / ...
            (fixationMatrix(2, trialIndex{1} + length(famMatrix)) + fixationMatrix(1, trialIndex{1} + length(famMatrix))));
        trialDuration(5, trialIndex{1}+length(famMatrix)) = totalLookAwayTime; % totalLookAwayTime
        trialDuration(6, trialIndex{1}+length(famMatrix)) = fixationMatrix(1, trialIndex{1} + length(famMatrix));
        trialDuration(7, trialIndex{1}+length(famMatrix)) = fixationMatrix(2, trialIndex{1} + length(famMatrix));
        
        if playingAGAudio.Active 
            PsychPortAudio('Stop', agaudiohandle);
        end

        PsychPortAudio('Close', pahandle);

        % Stop checkerboard playback:
        Screen('PlayMovie', moviePtr, 0, 1, 0);

        % Update display:
        Screen('Flip', window);
        WaitSecs(durations(1));
    end

catch e
    showErrorMsg("An unexpected error has occured during the test phase. Terminating...", e)
end

% finilize edf recording and receive file
if(TRACKING_ACTIVE)
    Eyelink('Stoprecording');
    closeError = Eyelink('CloseFile');
    edfLocalPath = char("Output" + filesep + string(subjectCode));
    receiveError = Eyelink('ReceiveFile', edfFileName, edfLocalPath, 1);
end

%% Close up shop
% Close Movie
exit_routine_(subjectCode, origin_folder, TrialMat, famMatrix, trialDuration);
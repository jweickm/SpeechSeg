function [eye_used, fixationActive, lookAwayTime, lookAwayStartTime, x, y] =... 
    processEyelinkSample(el, eye_used, fixationActive, lookAwayTime, stimulusRect, lookAwayStartTime, DEBUG)
    
    x=-1;
    y=-1;

    if Eyelink( 'NewFloatSampleAvailable') > 0
        % get the sample in the form of an event structure
        evt = Eyelink( 'NewestFloatSample');
        
        if eye_used ~= -1 % do we know which eye is used yet?
            % if we do, get current gaze position from sample
            x = evt.gx(eye_used+1); % +1 as we're accessing MATLAB array
            y = evt.gy(eye_used+1);
            
            % do we have valid data and is the pupil visible?
            if x~=el.MISSING_DATA && y~=el.MISSING_DATA && evt.pa(eye_used+1)>0
                % if data is valid, check if it is inside the
                % current image
                isFixated = isGazeInStimulusRect(x, y, stimulusRect);
                fixationActive = isFixated;
                if(isFixated)
                    if DEBUG
                        disp('fixated')
                    end
                    lookAwayTime = -1;
                else
                    if lookAwayTime <= -1
                        lookAwayStartTime = clock();
                    end
                    lookAwayTime = etime(clock(), lookAwayStartTime);
                    if DEBUG
                        disp(['not fixated, lookAwayTime = ' num2str(lookAwayTime)]);
                    end
                end
            else
                % If pupil is invisible, treat it like "not fixated"
                if lookAwayTime <= -1
                        lookAwayStartTime = clock();
                end
                lookAwayTime = etime(clock(), lookAwayStartTime);
                if DEBUG
                    disp(['not fixated (pupil invisible), lookAwayTime = ' num2str(lookAwayTime)]);
                end
            end
        else % if we don't, first find eye that's being tracked
            eye_used = Eyelink('EyeAvailable'); % get eye that's tracked
            if eye_used == el.BINOCULAR  % if both eyes are tracked
                eye_used = el.LEFT_EYE; % use left eye
            end
        end
    end 
end

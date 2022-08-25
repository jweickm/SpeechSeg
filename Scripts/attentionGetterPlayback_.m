% Written by Jakob Weickmann
% Attention Getter plays until one presses a key again (NOT 'G'!)

function[droppedframes] = attentionGetterPlayback_(moviePtr, windowPtr, windowRect, secs, Fullscreen)
    
    Screen('Flip', windowPtr); % initial flip
    
    if Fullscreen
        % movieRect = [0, 0, windowRect(3), windowRect(4)]; % Fullscreen
        movieRect = [100, 100, windowRect(3)-100, windowRect(4)-100];
    else 
        movieRect = [100, 100, windowRect(3)-100, windowRect(4)-100];
    end

    [droppedframes] = Screen('PlayMovie', moviePtr, 0.5, 1, 0);
        while GetSecs <= (secs + 0.5) || ~KbCheck() % attention getter has to run for at least 500 ms

            % Wait for next movie frame, retrieve texture handle to it
            tex = Screen('GetMovieImage', windowPtr, moviePtr);

            % Valid texture returned? A negative value means end of movie reached:
            if tex<=0
                % We're done, break out of loop:
                break;
            end 
            
            % Draw the new texture immediately to screen:
            if Fullscreen
                Screen('DrawTexture', windowPtr, tex, [], movieRect);
            else
                Screen('DrawTexture', windowPtr, tex, []);
            end

            % Update display:
            Screen('Flip', windowPtr);

            % Release texture:
            Screen('Close', tex);
        end
        
    % Stop playback:
    Screen('PlayMovie', moviePtr, 0);
    
    % Update display:
    Screen('Flip', windowPtr);
return
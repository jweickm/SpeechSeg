% Written by Jakob Weickmann

function[droppedframes] = videoPlayback(moviePtr, windowPtr, windowRect)
    
    Screen('Flip', windowPtr); % initial flip
    movieRect = [0, 0, windowRect(3), windowRect(4)]; % Fullscreen

    [droppedframes] = Screen('PlayMovie', moviePtr, 0.5, 1, 0);
    while true

        % Wait for next movie frame, retrieve texture handle to it
        tex = Screen('GetMovieImage', windowPtr, moviePtr);

        % Valid texture returned? A negative value means end of movie reached:
        if tex <= 0
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
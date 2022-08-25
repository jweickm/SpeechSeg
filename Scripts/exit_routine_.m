% Written by Jakob Weickmann
function[] = exit_routine_(subjectCode, origin_folder, TrialMat, famMatrix, trialDuration)
    ListenChar();
    Screen('CloseAll');
    
   % Save Data
    disp('Saving output data to ./Output/...');
    
    
    TrialMatConcat = [famMatrix, TrialMat;...
        repmat("familiarization", 1,length(famMatrix)),...
        repmat("testing", 1, length(TrialMat))];
    TrialMatConcat(1,length(famMatrix)+1:end) = str2double(TrialMatConcat(1,length(famMatrix)+1:end)) + length(famMatrix);
    
    U = table(TrialMatConcat(1,:)', TrialMatConcat(2,:)', TrialMatConcat(3,:)', TrialMatConcat(4,:)', ...
        'VariableNames', {'Trial', 'WordID', 'Word', 'Block'});
    U.Properties.Description = strcat('Output Data for Subject', sprintf(' %02s', num2str(subjectCode)));
    U = addvars(U, trialDuration(1,:)', trialDuration(2,:)', trialDuration(3,:)', trialDuration(4,:)', trialDuration(5,:)', trialDuration(6,:)', trialDuration(7,:)', 'NewVariableNames', {'TrialOnset', 'AttentionGrabberDuration', 'StimulusDuration', 'FixationPercent', 'TotalLookAwayTime', 'FixMatrixOnDur', 'FixMatrixOffDur'});
    
    disp('Please wait...');
    subjectString = strcat('Subject_', sprintf('%02s', num2str(subjectCode))); % to pad the subjectCode with zeroes if necessary 
    save(strcat('./Output/', subjectString, '.mat'),  'TrialMat', 'famMatrix'); 
    % this saves all the above variables to a file called Subject_.mat
    % and to a CSV file
    if exist(strcat('./Output/', subjectString, '.csv'), 'file')
        delete(strcat('./Output/', subjectString, '.csv'));
    end
    writetable(U, strcat('./Output/', subjectString, '.csv'));
    disp('Saved successfully.');
    
   % Close up shop
    sca;
    clear Screen;
    ShowCursor();
    RestrictKeysForKbCheck([]);
    disp('End of Experiment. Please stop recording.')
    cd(origin_folder);
return
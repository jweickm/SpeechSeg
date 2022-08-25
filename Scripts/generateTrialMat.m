% Written by Jakob Weickmann

function [TrialMat, famMatrix] = generateTrialMat(setupInfo, words)

if length(setupInfo) == 5
    [group, order, nTestTrials, nBlocks, useManualLists] = matsplit(setupInfo);
else 
    [group, order, nTestTrials, nBlocks, useManualLists, testListCode] = matsplit(setupInfo);
end
[B, F, K, P] = matsplit(words, 1);
%% ===================================================
%                        TRIAL MATRIX
% ==========================================================
if useManualLists == 1
    
    % This imports the manually created trial lists from Monica and removes
    % everything but the first letter of each stimulus
    [~, excelP3, ~] = xlsread("Pseudorandom stimuli", "List TEST phase");
    stimuliLists = cell(4,12);
    for listNumber = 1:4
        stimuliLists(listNumber,:) = excelP3(2:end,listNumber+1);
        for element = 1:numel(stimuliLists(listNumber,:))
            stimuliLists(listNumber,element) = {stimuliLists{listNumber,element}(1)};
        end
    end

    TrialMat        = cell(3, nTestTrials); % preallocate
    TrialMat(1,:)   = num2cell([1:nTestTrials]);
    TrialMat(3,:)   = upper(stimuliLists(testListCode,:));
    for position = 1:length(TrialMat(2,:))
        if TrialMat{3,position} == "B"
            TrialMat{2,position} = 1;
        elseif TrialMat{3,position} == "F"
            TrialMat{2,position} = 2;
        elseif TrialMat{3,position} == "K"
            TrialMat{2,position} = 3;
        elseif TrialMat{3,position} == "P"
            TrialMat{2,position} = 4;
        end
    end

else
    % create a pseudorandom trial matrix from which to select on each trial
    while true
        orderRandomTrue = 1;
        prevTrialWord = "";

        % create TrialMat
        TrialMat = cell(3, nTestTrials);
        TrialMat(1,:)    = num2cell(randperm(nTestTrials));
        TrialMat(2:3,:)  = repmat(words, 1, nBlocks);
        TrialMat(:,1:4)  = sortrows(TrialMat(:,1:4)', 1)';
        TrialMat(:,5:8)  = sortrows(TrialMat(:,5:8)', 1)';
        TrialMat(:,9:12) = sortrows(TrialMat(:,9:end)', 1)';
        TrialMat(1,:)    = num2cell(1:nTestTrials);
        
        % Check whether trials of a certain word are played consecutively
        for trialWord = TrialMat
            if trialWord{3} == prevTrialWord
                orderRandomTrue = 0;
                break;
            else
                prevTrialWord = trialWord{3};
            end
        end
        
        % Check whether the order of trials within a block is repeated in the next block
        if all([TrialMat{2,1:4}] == [TrialMat{2,5:8}]) || all([TrialMat{2,5:8}] == [TrialMat{2,9:12}])
            orderRandomTrue = 0;
        end
        
        % Check whether the same stimulus appears more than 2 times in the same location within list
        for block_position = 1:4
            [~, ~, ic] = unique([TrialMat{2,block_position:4:end}]);
            if max(accumarray(ic,1)) > 2
                orderRandomTrue = 0;
                break;
            end
        end
        
        if orderRandomTrue == 1
            disp('TrialMat successfully created.');
            break;
        end
    end
end

% GROUP AND ORDER
% -------------------------------------------
if group == 1
    famMatrix = [{1,2,3,4}; repmat([B, K], 1,2)];
elseif group == 2
    famMatrix = [{1,2,3,4}; repmat([P, F], 1,2)];
end

if order == 2
    famMatrix(2:3,:) = flip(famMatrix(2:3,:)')';
end
 
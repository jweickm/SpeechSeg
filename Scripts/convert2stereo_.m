% Written by Jakob Weickmann

function [sounds] = convert2stereo_(sounds)

% Make sure we have always 2 channels stereo output.
% Why? Because some low-end and embedded soundcards
% only support 2 channels, not 1 channel, and we want
% to be robust in our experiment.
    textprogressbar('Converting to stereo:  ');
    for i = 1:length(sounds)
        if size(sounds(i).familiarization.y',1) < 2 % if it is not stereo
            sounds(i).familiarization.y = [sounds(i).familiarization.y, sounds(i).familiarization.y]; % make it stereo
        end
        if size(sounds(i).list.y',1) < 2 % if it is not stereo
            sounds(i).list.y = [sounds(i).list.y, sounds(i).list.y]; % make it stereo
        end
        textprogressbar(i * 100/length(sounds));
    end
    textprogressbar('done');
return
    
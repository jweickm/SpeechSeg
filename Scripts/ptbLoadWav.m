  
% mostly copied from: https://raw.githubusercontent.com/Psychtoolbox-3/Psychtoolbox-3/beta/Psychtoolbox/PsychDemos/BasicSoundOutputDemo.m

function wavedata = ptbLoadWav(path)
    try
        [y, ~] = psychwavread(path);
        wavedata = y';
        numchannels = size(wavedata,1); 
        if numchannels < 2
            wavedata = [wavedata; wavedata];
        end
    catch
        error("The file " + string(path) + "could not be loaded");
    end
end
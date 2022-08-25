function isFixated = isGazeInStimulusRect(x, y, stimulusRect)
    isFixated = x >= stimulusRect(1) & x <= stimulusRect(3) & y >= stimulusRect(2) & y <= stimulusRect(4);
end


% Written by Jakob Weickmann

function [soundFiles] = soundImport_(location)

    textprogressbar('Importing sound files: '); % initialize textprogressbar
    
    
    % Audio Files (FAM)
    audio_fam_dir = dir(strcat(location,'*fam.wav'));
    
    % Audio Files (LIST)
    audio_list_dir = dir(strcat(location,'*list.wav'));
    
    if length(audio_fam_dir) == length(audio_list_dir)
        nAudio = zeros(length(audio_fam_dir),1);
    else
        print('Number of Audio Files in Familiarization Condition and List condition are not the same!');
    end
    
    % preallocate soundFiles struct
    soundFiles = struct('name', nAudio, 'familiarization', struct('name', nAudio, 'y', nAudio, 'freq', nAudio, 'y_', nAudio), 'list', struct('name', nAudio, 'y', nAudio, 'freq', nAudio, 'y_', nAudio));
    
    % read wavedata
    for i = 1:length(nAudio)
        [soundFiles(i).familiarization.y, soundFiles(i).familiarization.freq] = psychwavread(strcat(audio_fam_dir(i).folder,  '/', audio_fam_dir(i).name));
        [soundFiles(i).list.y, soundFiles(i).list.freq]                       = psychwavread(strcat(audio_list_dir(i).folder, '/', audio_list_dir(i).name));
        soundFiles(i).name = audio_fam_dir(i).name(1:regexp(audio_fam_dir(i).name, '_')-1); % get the file names
        soundFiles(i).list.name = soundFiles(i).name;
        soundFiles(i).familiarization.name = soundFiles(i).name;
        textprogressbar(i * 100/length(nAudio));
    end
    
    textprogressbar('done');
    
    % convert to stereo
    soundFiles = convert2stereo_(soundFiles);
    
    % flip wavedata matrix to work with PsychSound
    textprogressbar('Flipping Sound Matrix: ');
    for s = 1:length(soundFiles)
        soundFiles(s).familiarization.y_ = soundFiles(s).familiarization.y';
        soundFiles(s).list.y_            = soundFiles(s).list.y';
        textprogressbar(s * 100/length(soundFiles));
    end
    textprogressbar('done');
    
    % Save audio stimuli in mat file
    textprogressbar('Saving sounds to .mat: ');
    %save('./Stimuli/sounds.mat', 'soundFiles');
    textprogressbar(100);
    textprogressbar('done');
return
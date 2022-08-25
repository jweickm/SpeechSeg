% Written by Jakob Weickmann

function [subjectCode, group, order, testListCode] = participantDetails_(filename)

if nargin < 1
    filename = 0;
end

prompt1 = 'Please enter the participant ID (integer):\n';
subjectCode = [];
prompt2 = 'Please enter the participant''s group number:\n  [1]: "BK" \n  [2]: "PF"\n';
group = 0;
prompt3 = 'Please select the stimulus order:\n  [1]: %s (normal) \n  [2]: %s (reversed)\n';
junban = ["BKBK", "PFPF"; "KBKB", "FPFP"];
yes = ["y", "Y", "yes", "Yes", "YES", "absolutely"];

while true
    try subjectCode = input(prompt1);
        subjectString = strcat('./Output/Subject_', sprintf('%02s', num2str(subjectCode)), '.mat'); % to pad the subjectCode with zeroes if necessary
        if exist(subjectString, 'file')
            fprintf(repmat('\b',1, 1 + length(num2str(subjectCode))));
            fprintf('Subject %02d already exists.\n\n', subjectCode);
            if ~ismember(input('Do you really want to continue? (Y/N)\n', 's'), yes)
                subjectCode = [];
                continue;
            end
            fprintf(repmat('\b',1, 40));
        else
            fprintf(repmat('\b',1, 1 + length(num2str(subjectCode))));
        end

        if filename == 0
            % ask for participant group
            while true
                try group = input(prompt2);
                    if group == 1 || group == 2
                        fprintf(repmat('\b',1, 1 + length(num2str(group))));
                        break;
                    else
                        disp('Input must be 1 or 2.');
                        group = 0;
                        continue;
                    end                        
                catch
                    warning('Input must be 1 or 2.');
                end
            end

            % ask for order for counterbalancing
            while true
                try order = input(sprintf(prompt3, junban(1,group), junban(2,group)));
                    if order == 1 || order  == 2
                        fprintf(repmat('\b',1, 1 + length(num2str(order))));
                        break;   
                    else
                        disp('Input must be [1] or [2].');
                        order = 0;
                        continue;
                    end
                catch
                    warning('Input must be [1] or [2].');
                end
            end

            fprintf('\n----------------------------');            
            fprintf(['\nParticipant ID: %11d\n'...
                       'Group number: %13d\n'...
                       'FamList: %18s\n'], subjectCode, group, junban(order,group));

        elseif exist('Pseudorandom stimuli.csv', 'file')
            disp('Looking up from CSV file...');

            % SUBJECT CODE
            csvTable = readtable([filename, '.csv']);
            famListCode = csvTable{subjectCode, 3};
            if rem(famListCode,2) == 1 % if famListCode is odd
                order = 1;
            else 
                order = 2;
            end
            if famListCode <= 2
                group = 1;
            else
                group = 2;
            end

            testListCode = csvTable{subjectCode, 4};

            fprintf('\n----------------------------');            
            fprintf(['\nParticipant ID: %11d\n'...
                       'FamList: %18s\n'], subjectCode, junban(order,group));


        elseif exist('Pseudorandom stimuli.xlsx', 'file')
                disp('Looking up from Excel file...');
                % look up order from excel file


            % SUBJECT CODE
            [excelP1, ~, ~] = xlsread(filename, "Overall");
            famListCode = excelP1(subjectCode, 3);
            if rem(famListCode,2) == 1 % if famListCode is odd
                order = 1;
            else 
                order = 2;
            end
            if famListCode <= 2
                group = 1;
            else
                group = 2;
            end

            testListCode = excelP1(subjectCode, 4);

            fprintf('\n----------------------------');            
            fprintf(['\nParticipant ID: %11d\n'...
                       'FamList: %18s\n'], subjectCode, junban(order,group));

        else 
            disp('Specified file was not found.');
            filename = 0;
            continue;
        end

        if ismember(input('Is that correct? (Y/N)\n', 's'), yes)
            fprintf(repmat('\b',1, 25));
            disp('============================');
            break;
        else
            subjectCode = [];
            group = 0;
            order = 0;
            filename = 1;
            fprintf('\b\b');
            disp('----------------------------');
            continue;
        end
    catch
        warning('ID must be an integer.');
    end
end

return
clear
time_ = 15
accuracy_ = 90
trial_ = 9

load zd67
time = 0
accuracy = 0
trial = 0

save zd67 accuracy time trial






% rmmatvar('test.mat', 'a');
% whos('-file', 'test.mat');
% 

function rmmatvar(matfile, varname)
% Load in data as a structure, where every field corresponds to a variable
% Then remove the field corresponding to the variable
tmp = rmfield(load(matfile), varname);
% Resave, '-struct' flag tells MATLAB to store the fields as distinct variables
save(matfile, '-struct', 'tmp');
end


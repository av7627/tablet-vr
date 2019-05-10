%graph trials over time. For one day

a = load('savefile.mat');
List = a.zd54Table{1:end,'zd54List1'}{1,1};

filename = List{1,:} % the first one

fid = fopen(filename,'rt');
data=textscan(fid, '%f %s',...
    'headerlines', 5,...
    'delimiter',',',...
    'TreatAsEmpty','NA',...
    'EmptyValue', NaN);
fclose(fid);

time = data{1:end};

plot(1:length(time),time/60,'o')
title(['Trials Over time'])
xlabel('trial Number')
ylabel('time (min)')
%graph error rate over time. For one day

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

time = data{1};

secondRow = data{2};
for i = 1:length(data{1})
   erList(i,:) = str2num(secondRow{i}(end-7:end));
    
end


plot(time/60,erList*100)
title(['Error Rate over Time'])
xlabel('time (min)')
ylabel('error rate(%)')
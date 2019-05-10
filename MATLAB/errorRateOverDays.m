a = load('savefile.mat');
List = a.zd54Table{1:end,'zd54List1'}{1};


for i = 1:numel(List)
    
    filename = List{i,:};
    
    fid = fopen(filename,'rt');
    data=textscan(fid, '%f %s',...
        'headerlines', 5,...
        'delimiter',',',...
        'TreatAsEmpty','NA',...
        'EmptyValue', NaN);
    fclose(fid);
    
    %get trial number
    try
        lastLine = cell2mat(data{2}(end,1));
        errorRate(i) = str2num(lastLine(end-7:end));
        
    catch
        %errorRate(i) = NaN;
        %delete(filename)
    end
    
    
end



graph =    bar(1:length(errorRate),errorRate*100);
graph.FaceColor = 'flat';
title(['Error Rate over sessions'])
xlabel('days')
ylabel('ErrorRate (%)')


dates = a.zd54Table{1:end,'zd54List2'}{1}';
sessionNumber = 1;
color = rand(1,3);
for i =1 : length(dates)
    current = num2str(dates(i));
    current = str2num(current(2:3));
    try
        next = num2str(dates(i+1));
        next = str2num(next(2:3));
    catch
    end
    sessionList(i) = sessionNumber;
    
    graph.CData(i,:) = color;
    
    if current~=next %next is different day
        
        sessionNumber = 1;
        color = rand(1,3);
        
    else
        sessionNumber = sessionNumber +1;
    end
    
    
    
end




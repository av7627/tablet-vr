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
            lastLine = data{2}{end,1};
            NumberTrials(i) = str2num(lastLine(8:10));
        catch
            NumberTrials(i) = NaN;
            delete(filename)
        end
        
      
        
end
    
graph1 =    bar(1:length(NumberTrials),NumberTrials);
      
      graph1.FaceColor = 'flat';
    title(['Trials Per Day'])
    xlabel('days')
    ylabel('number of trials')


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
    
    graph1.CData(i,:) = color;
    
    if current~=next %next is different day
        
        sessionNumber = 1;
        color = rand(1,3);
        
    else
        sessionNumber = sessionNumber +1;
    end
    
    
    
end


zd54List = {a.zd54Table{1:end,'zd54List1'}{1},a.zd54Table{1:end,'zd54List2'}{1},NumberTrials',sessionList'};%file,date,trialNum,sessionNum
zd54Table = array2table(zd54List);
save('savefile.mat', 'zd54Table');










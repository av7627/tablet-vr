clear; clc;

Foldername = 'C:\Users\anilv\Downloads\VR_TrialBased\VR_TrialBased';

names = ['zd48','zd54'];

listing = dir(Foldername);%alphabatised with both names

numzd54 = 0;
 for i = 1:numel(listing) %this loop makes a list of mousenames, file paths, and dates created
  fn =  strcat(Foldername,'\',listing(i).name); %full file name



  last = fn(1:end-9); %time stamp truncated (date is left still)
  
  if  str2double(last(end)) ~= sqrt(-1) && ~isnan(str2double(last(end)))
      files{i-numzd54,:} = fn;
      dates{i-numzd54,:} = last(end-9:end);
      MouseNames{i-numzd54,:} = listing(i).name(1:4);
  else
      numzd54 = numzd54 +1;
      continue
  end
  
  
 end

 Filelist = [MouseNames,files ,dates];

 
 
 %sperate names
 
 numzd54 = 0;
for i = 1:numel(files)
    
    if strcmp(Filelist{i,1},'zd48')
        zd48List{i-numzd54,:} = [Filelist{i,2}];
    else
        numzd54 = numzd54 + 1;
    end
end


numzd48 = 0;
for i = 1:numel(files)
    
    if strcmp(Filelist{i,1},'zd54')
        zd54List{i-numzd48,:} = [Filelist{i,2}];
    else
        numzd48 = numzd48 + 1;
    end
end
    Rangezd48 = [1:numzd48];
    Rangezd54 = [numzd48+1:numzd48+numzd54];
    


[datesZD48_sorted, datesZD48_order] = sort(dates(Rangezd48)); %sort dates inorder to sort zd48List 
zd48List = {zd48List(datesZD48_order,:),transpose(datesZD48_sorted)};

[datesZD54_sorted, datesZD54_order] = sort(dates(Rangezd54)); 
zd54List = {zd54List(datesZD54_order,:),transpose(datesZD54_sorted)}; %sorted file paths based off date








zd54Table = array2table(zd54List);
save('savefile.mat', 'zd54Table');


%  plotTrialsPerDay(zd48List,'zd48')
%  plotTrialsPerDay(zd54List,'zd54')

%% get the trial numbers for the two session per day and then plot them
% function plotTrialsPerDay(List,name)
% 
% 
%     for i = 1:numel(List)
%         
%         filename = List{i,:};
%         
%         fid = fopen(filename,'rt');
%         data=textscan(fid, '%f %s',...
%             'headerlines', 5,...
%             'delimiter',',',...
%             'TreatAsEmpty','NA',...
%             'EmptyValue', NaN);
%         fclose(fid);
%         
%         %get trial number
%         try
%             lastLine = data{2}{end,1};
%             NumberTrials(i) = str2num(lastLine(8:10));
%         catch
%             NumberTrials(i) = NaN;
%             delete(filename)
%         end
%         
%         
%     end
%    
% %     bar(1:length(NumberTrials),NumberTrials)
% %     title([name,': Trials Per Day'])
% %     xlabel('days')
% %     ylabel('number of trials')
% end

zd48List = zd48List(datesZD48_order,:);

[datesZD54_sorted, datesZD54_order] = sort(dates(Rangezd54)); 
zd54List = zd54List(datesZD54_order,:); %sorted file paths based off date

 plotTrialsPerDay(zd48List)
 %plotTrialsPerDay(zd54List)

%% get the trial numbers for the two session per day and then plot them
function plotTrialsPerDay(List)


    for i = 1:numel(List)
        
        filename = List{i,:}
        
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
            NumberTrials(i) = str2num(lastLine(8:10))
        catch
            NumberTrials(i) = NaN
            %delete(filename)
        end
        
        
    end
    
    plot(1:length(NumberTrials),NumberTrials)
end




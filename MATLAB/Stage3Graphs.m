clear; clc;
close all
Foldername = 'C:\Users\anilv\Downloads\VR_TrialBased (1)\VR_TrialBased';

names = ['db_c';'zd43';'zd48';'zd50';'zd54';'zd67'];

listing = dir(Foldername);%alphabatised with names

a = 0;
 for i = 1:numel(listing) %this loop makes a list of mousenames, file paths, and dates created
  fn =  strcat(Foldername,'\',listing(i).name); %full file name



  last = fn(1:end-4); %time stamp truncated (date is left still)
  
  if  str2double(last(end)) ~= sqrt(-1) && ~isnan(str2double(last(end)))
      files{i-a,:} = fn;
      dates{i-a,:} = last(end-14:end);
      MouseNames{i-a,:} = listing(i).name(1:4);
  else
      a = a + 1;
      continue
  end
  
  
 end

  Filelist = [MouseNames,files ,dates];

 
 
 %sperate names
 for i =1:numel(names(:,1))
    Split{i} = strcmp(Filelist(:,1),names(i,:));
    Split{i}=Filelist(Split{i},:); 
 end
 
 
 

for i =1:numel(names(:,1))
    dates = Split{i}(:,3);
    [Split_sorted{i}, dates_sorted{i}] = sort(dates);
    A = Split{i}(:,2);
    Split{i}=[A(dates_sorted{i},:),Split_sorted{i}];
    %
    
end

subplot(2,1,1)
A = Split{3};
plotTrialsPerDay(A,'r')
plotTrialsPerDay(Split{5},'b')
hold on
legend('mouse1','mouse2')
%xlabel('Sessions')
ylabel('Number of Trials')
hold off
 xticks([1:1:15])
  a = get(gca,'XTickLabel');
    set(gca,'XTickLabel',a,'FontName','Times','fontsize',15)
 %title('Trials Per Session','FontSize',25)
 
 subplot(2,1,2)
%figure(2)
AccuracryOverTime(A,'r')
AccuracryOverTime(Split{5},'b')

xlabel('Sessions')
ylabel('Accuracy (%)')
xticks([1:1:15])
 a = get(gca,'XTickLabel');
    set(gca,'XTickLabel',a,'FontName','Times','fontsize',15)
  %  title('Accuracy Per Session','FontSize',25)

plot([0 15],[50 50],'--k')
legend('mouse1','mouse2')

figure(3)
IntervalBetweenTrials(Split{5})
hold on
ylabel('trials')
xlabel('time (min)')
   
caxis([1 numel(Split{5})/2])
%H.Ticks = 1:5:numel(Split{5})/2
H = colorbar;
H.Label.String = 'Sessions Number'
set(H,'ytick',1:5:numel(Split{5})/2);
xlim([1 20])

function plotTrialsPerDay(List,color)


    for i = 1:15%numel(List)/2
        
        filename = List{i,1};
        
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
            %delete(filename)
        end
        
        
    end
   
    plot(1:length(NumberTrials),NumberTrials,'color',color)
    hold on
   
    
    
end

function AccuracryOverTime(List,color)
for i = 1:15%numel(List)/2
    
    filename = List{i,1};
    
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

plot(1:length(errorRate),100-errorRate*100,'color',color)
hold on



end

function IntervalBetweenTrials(List)
for i = 1:15%numel(List)/2
   
    filename = List{i,1};
    
    fid = fopen(filename,'rt');
    data=textscan(fid, '%f %s',...
        'headerlines', 5,...
        'delimiter',',',...
        'TreatAsEmpty','NA',...
        'EmptyValue', NaN);
    fclose(fid);
    time = data{1}/60;
    
    color = cool(15);
    
    color = color(i,:);
   
    plot(time,1:length(time),'color',color)
    colormap(cool(15));
    
    hold on
    
    
end



end




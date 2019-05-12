%plot rotation of wheel over time 


%make a folder with figures that show the path taken by the
%user for each trial

data = xlsread('C:\Users\anilv\Documents\VR_TimeBased\test_gain9_session1_VR_TimeBased_2019-05-10_1616.csv');
XYdata = [data(:,3),data(:,8:12)];
RotationData = [data(:,1),data(:,15)]

rows = 1;
while true %take out any rows containing NaNs
    if rows == length(XYdata)+1
        break
    elseif sum(isnan(XYdata(rows,:))) ~= 0%contains nan
        XYdata(rows,:) = [];
    else
        rows= rows+1;
    end
end

realXYList = zeros(length(XYdata),2); %make list of actual XY position. Choose movie or hardware mode position as needed
for entries = 1:length(XYdata)
    if XYdata(entries,end) == 0 %if moviespeed is zero take coords from hardware columns
        realXYList(entries,1:2) = XYdata(entries,end-2:end-1);
    else%if moviespeed is not zero take coords from moviemode columns
        realXYList(entries,1:2) = XYdata(entries,2:3);
    end
end
realXYList = [XYdata(:,1), realXYList];%append trial numbers to array


numTrials = realXYList(end,1); %get max number of trials from file
for trials = 1:numTrials
    newMatrix{trials} = realXYList(realXYList(:,1) == trials,:);
end%separate based on trial

folder = fullfile(getenv('USERPROFILE'), 'Documents');
session = sprintf('trialRotationFigures');
session = [session(1:end-8),'-',session(end-7:end-6),'-',session(end-5:end-4),'_',session(end-3:end)];
filename_plots = fullfile(folder, sprintf('%s', session));
mkdir(filename_plots)%make new folder for this session



for trials = 1:numTrials
    list = newMatrix{trials};
    y = list(:,3);
    x = list(:,2);
    
    
    plot(list(1:length(x(y<-33)),2),y(y<-33),'b.')%plot xy data as points before decision point
    
    hold on
    plot(list(length(x(y<-33))+1:end,2),y(y>-33),'r.')%plot xy data as points
    
    %make outline of the 3rd branch
    plot([457,457],[-158,-28],'k')%left line
    plot([477,477],[-158,-28],'k')%right line
    plot([457,431],[-28,10],'k')%leftwall
    plot([477,503],[-28,10],'k')%rightwall
    plot([467,452],[-28,10],'k')%left inner wall
    plot([467,482],[-28,10],'k')%right inner wall
    
    %show where where the stimulus is on graph
    %plot(
    
    
    
    
    
    
    hold off
    title(sprintf('trial %i',trials))
    xlim([430 504])
    ylim([-100 5])
    
    yticks([-100 -50 0])
    yticklabels([0 50 100])
    %
    xticks([431 467 503])
    xticklabels([-36 0 36])
    
    session = sprintf(['trial_%i'],trials);
    file = fullfile(filename_plots, sprintf('%s.png', session));
    saveas(gcf,file)
end



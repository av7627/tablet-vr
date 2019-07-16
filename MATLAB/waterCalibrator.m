varargin = {'monitors,{192.168.0.100;0;192.168.0.103;-90;192.168.0.104;90},hardware,2,com,com4'};
varargin = varargin{:};%convert from cell array to string
varargin= varargin(~isspace(varargin));%get rid of spaces
varargin = strsplit(varargin,',');%split on commas
keys = varargin(1:2:end);
values = varargin(2:2:end);

k = find(strcmpi(keys, 'hardware'), 1);
obj.hardware = str2num(values{k}); %hardware on/off = 0/2


k = find(strcmpi(keys, 'com'), 1);
if isempty(k)
    obj.com = [];
else
    obj.com = values{k};
end


obj.treadmill = ArduinoTreadmill(obj.com);

obj.treadmill.reward(2);%1sec

RewardRate = input('water amount (grams): '); %ml/sec. Because valve open for 1 sec
trials = input('expected number of trials: ');
time = 0.8 / RewardRate;

timePerTrial = time/trials

delete(obj.treadmill);


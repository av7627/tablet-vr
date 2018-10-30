%Notes: 
%make sure onstep works new change to choose distance


% LinearMaze - Controller for a linear maze using custom behavioral apparatus.
% 
% Movement is initiated by a subject running on a treadmill. Multiple monitors
% are placed around the field of view of the subject to create an immersive
% virtual environment. These monitors consist of tablets synchronized with
% the controller via WiFi, using UDP packets.
% Actuators such as pinch valves for reward or punishment can also be controlled here.
% Synchronization with data acquisition systems can be accomplished using
% methods start, stop, and reset.
% Constant forward speed can also be produced in the absence of a treadmill
% by changing the property speed.
% Behavioral data is saved locally every step and exported to a mat file at
% the end of the recording session.
% 
% LinearMaze methods:
%   blank  - Show blank for a given duration.
%   delete - Release all resources.
%   log    - Create a log entry using the same syntax as sprintf.
%   pause  - Show blank and disable behavior for a given duration.
%   print  - Print on screen and create a log entry using the same syntax as sprintf.
%   reset  - Reset trial, position, rotation, frame count and encoder steps.
%   start  - Send high pulse to trigger-out and enable behavior.
%   stop   - Send low pulse to trigger-out and disable behavior.
% 
% LinearMaze properties:
%   gain   - Forward speed factor in closed-loop when the rotary encoder produces movement.
%   speed  - Forward speed in open-loop.
% 
% Please note that these classes are in early stages and are provided "as is"
% and "with all faults". You should test throughly for proper execution and
% proper data output before running any behavioral experiments.
%
% Tested on MATLAB 2018a.
% 
% See also CircularMaze, TableTop, TwoChoice.

% 2017-12-13. Leonardo Molina.
% 2018-05-25. Leonardo Molina.
%2018-05-26+. Anil Verman.

classdef LinearMaze < handle
    %%
    
    properties
        % properties of the class
        
        % intertrialBehavior - Whether to permit behavior during an intertrial.
        intertrialBehavior = true;
        
        % intertrial - Duration (s) of an intertrial when last node is reached.
        intertrialDuration = 2;
        
        % logOnChange - Create a log entry with every change in position or rotation.
        logOnChange = false;
        
        % logOnFrame - Create a log entry with every trigger-input.
        logOnFrame = false;
        
        % logOnUpdate - Create a log entry at the frequency of the behavior controller.
        logOnUpdate = true;
		
        % rewardDuration - Duration (s) the reward valve remains open after a trigger.
        rewardDuration =0.040;
        
        % rewardTone - Frequency and duration of the tone during a reward.

        rewardTone = [1000, 0.5];
        
        %errorTone - played when mouse makes a mistake
        errorTone = [2000, 1];


        

        % tapeTrigger - Whether to initiate a new trial when photosensor
        % detects a tape strip in the belt.
        tapeTrigger = false;
        
        % treadmill - Arduino controlled apparatus.
        treadmill
        
%         comPortName = 'com5';
%         com = 'com'
%         so = [com,comPortName];
%inputs = ['com', 'COM4', 'monitors', {'127.0.0.1', 0, '192.168.1.100', 90}]
    end
    
    properties (SetAccess = private)
        
        % filename - Name of the log file. - time based
        filename
        
        
        stopDuringBlank; %this makes sure that obj is disabled and blank is not turned of during intertrial, if stop(obj) is called
        
        %name of log file - trial based
        filename_trial
        
        % scene - Name of an existing scene.
        scene = 'linearMaze_v2';
		
        % vertices - Vertices of the maze (x1, y1; x2, y2 ... in cm).
        %vertices = [0,-100   0,-42   -35,-10 ; 255,-100    255,-30     240,-2  ;  467,-95   467,-33   446,-1];%of three branches. go left at first
        vertices = [0,-100   0,-42   -35,-10 ; 255,-100    255,-30     240,-2  ;  467,-95   467,-33   446,-1];
        straightDist;
        vectorPosition;% = [0, -100];%starting position to be updated if hardware on
        %branch number - tells what branch to move camera  to
        %branchNum = 1
        
        %obj.branchArray = [[xleft, xmiddle,xright, z]] this is for walls. the
        %vertices of where branch splits or turns
        branchArray = [-5, 0, 5, -40
                   244 ,255, 266, -24 
                   459,466,475,-28];
        
        % resetNode - When resetNode is reached, re-start.
        resetNode = 3;
        
        %choiceArray - each index is a trial. 1=left,2=right
        choiceArray = [];
        
        %accuracyArray - each index is the accuracy over last ten trials,
        %index is trial number
        accuracyArray = [];
        
        %averageCorrectChoice - a running average of correct choice at each
        %trial
        averageCorrectChoice = [];
        
        %averageGratingSide - the current ratio of left vs right.
        %0=left,1=right
        averageGratingSide = [];
        
        
        yRotation = 90; %for rotating the camera for steering
        x_yRotation = 0;
        z_yRotation = 1;
        
        currentBranch %variable that holds the number of the current branch
    end
    
    properties (Dependent)
        
        % gain - Forward speed factor in closed-loop when the rotary encoder produces movement.
        gain
        
        % speed - Forward speed in open-loop.
        speed
        
        
    end
    
    properties (Access = private)
        
        
        % addresses - IP addresses listed under monitors.
        addresses
        
        % blankId - Process id for scheduling blank periods.
        blankId
        
        % className - Name of this class.
        className
        
        % enabled - Whether to allow treadmill to cause movement.
        enabled = false;
        
        % fid - Log file identifier.
        fid
        
        %log file trial based
        fid_trial
        
        mGain = 1;
        
        mSpeed = 0;
        
        lickCount = 0;  
        
        steeringPushfactor = 20;
        
        %this is used in MouseGraph to get the average grating side
        %0=left,1=right.Index is trial number.
        gratingSideArray = [];
        
        %% UI hadles
        % figureHandle - UI handle to control figure.
        figureHandle
       
        newGUI_figurehandle;
        
        choosebranch_h;
        
        tempMovieMode_h;
        
        %movieDirection;
        movieDirection_h;
        
        choiceDistance_h
        
        gratingSide_h;
        
        % textBox - Textbox GUI.
        textBox_h
        
        textBox_speed_h
        
        textBox_stimRotation_h %handle to textbox
        stimRot = 90 %variable holding current grating rotation. 90deg here is 0deg in unity.
        
        steeringLength %variable for length of straightaway inactive
        
        stimSize_h %which stimulus size to show. default: thick
        stimSize_string = 'Thick' %variable changed by stimSize_h handle. default: thick
        %%
        % nodes - Nodes object for controlling behavior.
        nodes
        
        %this is to check check where the stimulus actually went, because
        %random cant be checked in the csv file
        ActualSide;
        
        % offsets - Monitor rotation offset listed under monitors.
        offsets
        
        % pauseId - Process id for scheduling pauses.
        pauseId
        
        % scheduler - Scheduler object for non-blocking pauses.
        scheduler
        
        % sender - Network communication object.
        sender
        
        % startTime - Reference to time at start.
        startTime
        
        % tapeControl - Control when to trigger a trial based on tape crossings.
        tapeControl = [0 1]
        
        
        
        % trial - Trial number.
        trial = 1
        
        % update - Last string logged during an update operation.
        update = ''
        
        
        com 
        
        csvDataTable  %holds info from csv preset
        
%         %these all hold the value of where the x coordinate of the branch
%         %walls to the left or right side
%         left_leftwall %left branch
%         left_rightwall
%         right_leftwall %right branch
%         right_rightwall
        csvFileName = 'LinearMaze_presets\'; %the preset file to set variables automatically
        
        
        
        hardware = 0;%0:no hardware,  2:steeringOnly--------------------------------------------------------------------------
        
    end
    
    properties (Constant)
        
        % fps - Frames per seconds for time integration; should match VR game.
        fps = 50
        
        % programVersion - Version of this class.
        programVersion = '20180525';
        
        
        
       
        
    end
    %%
    methods
        %% initialize function: LinearMaze('com', 'com5','monitors', {'192.168.0.111',0, '192.168.0.109',90,'192.168.0.110',-90,});
        function obj = LinearMaze(app,varargin)
            %   Controller for a liner-maze.
             %  offset1, ip2, offset2, ...}, ...)
            %   Provide the serial port name of the treadmill (rotary encoder, pinch valve,
            %   photo-sensor, and lick-sensors assumed connected to an Arduino microcontroller
            %   running a matching firmware).
            %LinearMaze(monitors,{192.168.0.111;0;192.168.0.109;90;192.168.0.110;-90},hardware,0/2);
            %   Provide IP address of each monitor tablet and rotation offset for each camera.
            
            %monitors,{10.255.33.234;0;169.234.24.24;90},hardware,0,com,com5
            
            obj.newGUI_figurehandle = app; %this is the handle for the app. to set values from CSV
            
            
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
           
%             if obj.hardware == 0 %no hardware
%                 obj.com = [];
%                 obj.mSpeed = 25;
%             elseif obj.hardware == 2%hardware on
%                 obj.com = 'com5';
%             end
%             
            




            
            k = find(strcmpi(keys, 'monitors'), 1);
            if isempty(k)
                monitors = '{127.0.0.1;0}';
            else
                monitors = values{k};
            end
            monitors(1) = []; %get rid of first curly bracket
            monitors(end) = []; %get rid of last curly bracket
            monitors = strsplit(monitors,';'); %split on semicolon
            
            
            
            % Initialize network.
            i = 2;
            for nums = 1:length(monitors)/2 %do this for a number of times = to how many monitors connected
                obj.offsets(i/2) = str2num(monitors{i}); %append the offset number to obj.offsets
                i = i + 2;
            end
            obj.addresses = monitors(1:2:end); %disp(obj.addresses)
            obj.sender = UDPSender(32000);
            
            %get mouse name for log files
            mouseName = obj.newGUI_figurehandle.EnterMouseNameEditField.Value;
            
 
            % Create a log file. Time based
            folder = fullfile(getenv('USERPROFILE'), 'Documents', 'VR_TimeBased');
            session = sprintf([mouseName,'_VR_TimeBased%s'], datestr(now, 'yyyymmddHHMMSS'));
            obj.filename = fullfile(folder, sprintf('%s.csv', session));
            obj.fid = Files.open(obj.filename, 'a');
            
            % Create a log file. Trial based
            folder = fullfile(getenv('USERPROFILE'), 'Documents', 'VR_TrialBased');
            session = sprintf([mouseName,'_VR_TrialBased%s'], datestr(now, 'yyyymmddHHMMSS'));
            obj.filename_trial = fullfile(folder, sprintf('%s.csv', session));
            obj.fid_trial = Files.open(obj.filename_trial, 'a');
            
            % Remember version and session names. for time based log
            obj.startTime = tic;
            obj.className = mfilename('class');
            obj.print('maze-version,%s-%s', obj.className, LinearMaze.programVersion);
            obj.print('nodes-version,%s', Nodes.programVersion);
            obj.print('treadmill-version,%s', ArduinoTreadmill.programVersion);
            obj.print('filename,%s', obj.filename);
            
            %this one is for trial based log file
            obj.print_trial('maze-version,%s-%s', obj.className, LinearMaze.programVersion);
            obj.print_trial('nodes-version,%s', Nodes.programVersion);
            obj.print_trial('treadmill-version,%s', ArduinoTreadmill.programVersion);
            obj.print_trial('filename,%s', obj.filename_trial);
            
            %print categories in log file
            obj.log('logType,trial,frame,EncoderStep,distanceFromStart ,yaw,x_movie,z_movie,x_hardware,z_hardware, speed_movie,speed_hardware, branchNum');% obj.treadmill.frame,obj.treadmill.step,obj.nodes.distance,obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2)
            obj.log_trial('trialNum, correct/incorrect, stimSide, sideChosen, stim spatialFreq, stim orientation, branchNum, hardware on/off, distanceBeginSteering');% obj.treadmill.frame,obj.treadmill.step,obj.nodes.distance,obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2)
            
            
            % Show blank.
            obj.sender.send('enable,Blank,1;', obj.addresses);
            
            % Load an existing scene.
            obj.sender.send(sprintf('scene,%s;', obj.scene), obj.addresses);
            
            % Initialize treadmill controller.
            if isempty(obj.com)
                obj.treadmill = TreadmillInterface();
                obj.print('treadmill-version,%s', TreadmillInterface.programVersion);
            else
                obj.treadmill = ArduinoTreadmill(obj.com);
                obj.treadmill.bridge.register('ConnectionChanged', @obj.onBridge);
            end
            obj.treadmill.register('Frame', @obj.onFrame);
            obj.treadmill.register('Step', @obj.onStep);
            obj.treadmill.register('Tape', @obj.onTape);
            obj.treadmill.register('touchPad', @obj.touchPad);
                       
%     Listen for incoming data:
%       bridge.register('DataReceived', @fcn)
%       function fcn(data)
%           fprintf('Pin: %i. State: %i. Count: %i.\n', data.Pin, data.State, data.Count);
%       end
            %set up listener for sparkfun touch pad:
%            
             %obj.treadmill.bridge.register(3,@obj.touchPad); %touchPad(obj) is the callback function for the touchPad
%             disp('face')
            
            % Release resources when the figure is closed.
%             obj.figureHandle = figure('Name', mfilename('Class'), 'MenuBar', 'none', 'NumberTitle', 'off','Position', [100, 100, 100, 100],'DeleteFcn', @(~, ~)obj.delete());
%             h(1) = uicontrol('Style', 'PushButton', 'String', 'Stop',  'Callback', @(~, ~)obj.stop());
%             h(2) = uicontrol('Style', 'PushButton', 'String', 'Start', 'Callback', @(~, ~)obj.start());
%             h(3) = uicontrol('Style', 'PushButton', 'String', 'Reset', 'Callback', @(~, ~)obj.reset());
%             
%             h(4) = uicontrol('Style', 'PushButton', 'String', 'Log text above', 'Callback', @(~, ~)obj.onLogButton());
%             h(4) = uicontrol('Style', 'PushButton', 'String', 'choose Branch (1-number)', 'Callback', @(~, ~)obj.chooseBranch());
%             h(5) = uicontrol('Style', 'Edit');
%             
%             h(6) = uicontrol('Style', 'popup',...
%                'String', {'branch1', 'branch2','branch3'},...
%                'Callback', @(~,~)obj.chooseBranch());
%                          
%             h(7) = uicontrol('Style', 'PushButton', 'String', 'SetSpeed above (default:25)', 'Callback', @(~, ~)obj.textSpeed());
%             %h(4) = uicontrol('Style', 'PushButton', 'String', 'choose Branch (1-number)', 'Callback', @(~, ~)obj.chooseBranch());
%             h(8) = uicontrol('Style', 'Edit');
%                          
%             h(9) = uicontrol('Style', 'popup',...
%                'String', {'(DoesntWork)steering on', '(DoesntWork)tempMovieMode'},...
%                'Callback', @(~,~)obj.tempMovie()); %broken dont use. may take out 
%        
%             h(10) = uicontrol('Style', 'popup',...
%                'String', {'MovieMode: random', 'MovieMode: left','MovieMode: right'},'Callback', @(~,~)obj.ManualDirection()); 
%             h(11) = uicontrol('Style', 'popup',...
%                'String', {'steeringoff:4/4', 'steeringoff:3/4','steeringoff:2/4','steeringoff:1/4'},'Callback', @(~,~)obj.tempMovie()); 
% 
% %             h(12) = uicontrol('Style', 'popup',...
% %                'String', {'GratingRandom', 'GratingLeft','GratingRight','GratingOff'},'Callback',@(~, ~)obj.ManualGratingSide()); 
% %            
% %             h(13) = uicontrol('Style', 'PushButton', 'String', 'Set Rotation above (default:0 deg)', 'Callback', @(~, ~)obj.textRotation());
% %             %h(4) = uicontrol('Style', 'PushButton', 'String', 'choose Branch (1-number)', 'Callback', @(~, ~)obj.chooseBranch());
% %             h(14) = uicontrol('Style', 'Edit');
%            
% %             h(15) = uicontrol('Style', 'popup',...
% %                'String', {'Grating:Thick', 'Grating:Thin'},'Callback', @(~, ~)obj.stimThickness()); 
%            
%             p = get(h(1), 'Position');
%             %set(h, 'Position', [p(1:2), 4 * p(3), p(4)]);
%             %set(h(8:14), 'Position', [300+p(1),p(2), 4 * p(3), p(4)]);
%             align(h, 'Left', 'Fixed', 0.5 * p(1));
%             %align(h(8:14), 'Right', 'Fixed', 0.5 * p(1));
%             
%             obj.textBox_h = h(5);
%             obj.choosebranch_h = h(6);
% %             obj.textBox_speed_h = h(8);
%             obj.tempMovieMode_h = h(9);
%             obj.movieDirection_h = h(10);
%             obj.choiceDistance_h = h(11);
%             
%             %obj.gratingSide_h = h(12);
%             %obj.textBox_stimRotation_h = h(14);
%             %obj.stimSize_h = h(15);
%             
%             set(obj.figureHandle, 'Position', [obj.figureHandle.Position(1), obj.figureHandle.Position(2), 4 * p(3) + 2 * p(1), 2 * numel(h) * p(4)])
%             
            
            
%             if obj.hardware == 2 (I put this function in onUpdate)
%                 obj.scheduler.repeat(@obj.steeringPush, 1 / obj.fps);%if hardware then use steeringPush (maybe combine this with onUpdate)
%             end

            obj.straightDist = obj.vertices(:, 4)- obj.vertices(:,2 );

            % Initialize nodes.
            obj.nodes = Nodes();
            obj.nodes.register('Change', @(position, distance, yaw, rotation)obj.onChange(position, distance, yaw));
            obj.nodes.register('Lap', @(lap)obj.onLap);
            obj.nodes.register('Node', @obj.onNode);

            
            obj.csvFileName = [obj.csvFileName,obj.newGUI_figurehandle.EnterPresetFileNameEditField.Value,'.csv'];%add filename of preset file to file path
            obj.csvDataTable = readtable(obj.csvFileName, 'Format', '%f%f%f%f%f%f%f%f%f%f%f'); %read from preset csv file
            
           
            
            
            
            
            obj.updateFromCSV(); %update variables with csv file values
            set(findall(obj.newGUI_figurehandle.UIFigure, '-property', 'enable'), 'enable', 'on'); %this turns the startup info buttons off
            set(obj.newGUI_figurehandle.EnterStartupInfoEditField,'Enable','off');
            set(obj.newGUI_figurehandle.SendButton,'Enable','off');
            set(obj.newGUI_figurehandle.EnterPresetFileNameEditField,'Enable','off');
            set(obj.newGUI_figurehandle.EnterMouseNameEditField,'Enable','off');
            if obj.hardware == 0
                set(obj.newGUI_figurehandle.SteeringOnOffDropDown,'Enable','off'); %this can only be used if hardware is connected
            end
            
            %obj.newGUI_figurehandle.debugEditField.Value = 'ready'; %this changes the debug log on the gui to say ready to start

            
            obj.currentBranch = obj.csvDataTable.BranchNum(1); %set the first branch num
            
            %obj.nodes.vertices = obj.vertices(obj.currentBranch,:); %first update from csv then set the nodal path
            if obj.hardware == 0  %if not using steering 
                %obj.setNodes_movieMode(); %set path for right or left. movie mode only
                obj.vectorPosition = [nan,nan];
                obj.setNodes_movieMode(); %set a nodal path even with hardware on  
            else
                obj.vectorPosition = obj.vertices(obj.currentBranch,1:2);%first update from csv set vector Position for steering wheel
            end
            
            obj.scheduler = Scheduler();
            obj.scheduler.repeat(@obj.onUpdate, 1 / obj.fps);
            
            
            obj.setStimulus();%put the stimulus in place with correct rotation

        end
        
        %% these functions are for the GUI
        
%         function RecieveAppHandle(obj,appHandle) %this happens in start
%                                                   up script

%             obj.newGUI_figurehandle = appHandle; %this is the handle for the app. to set values from CSV
%             %obj.newGUI_figurehandle.debugEditField.Value
%             
%             obj.updateFromCSV(); %update variables with csv file values
%         end
        
        function updateFromCSV(obj)
            currentValues = obj.csvDataTable{obj.trial,:}; %Trial	BranchNum	stim(on/off)	Spatial Freq (stim)	orientation (stim)	Reward Side	side (movie mode)	steering type (movie/wheel)	speed	distance from split turn on steering ([1,2,3,4]/4)	logText
       
            %set(obj.choosebranch_h, 'Value', currentValues(2)) %change branchNum
            %obj.chooseBranch() 
            obj.newGUI_figurehandle.BranchNumberDropDown.Value = obj.newGUI_figurehandle.BranchNumberDropDown.Items{currentValues(2)};
             
            %set(obj.gratingSide_h, 'Value', currentValues(3)) %change stim side
            obj.newGUI_figurehandle.GratingSideEditField.Value = currentValues(3);
            %this changes the gui from the value from CSV file
           
            
            %set(obj.stimSize_h, 'Value', currentValues(4)) %change stim thickness (spatial frequency)
            %obj.stimThickness() %switched to new GUI
            obj.newGUI_figurehandle.SpatialFrequencyDropDown.Value = obj.newGUI_figurehandle.SpatialFrequencyDropDown.Items{currentValues(4)};
            
        
            %set(obj.textBox_stimRotation_h, 'String', currentValues(5))
            %change stim orientation % switched to new GUI
            %obj.textRotation()
            obj.newGUI_figurehandle.EnterRotationEditField.Value = currentValues(5);
            
            %set(obj.movieDirection_h, 'Value', currentValues(6)) %change moviemode direction
            obj.newGUI_figurehandle.MovieModeSideEditField.Value =  currentValues(6);%obj.newGUI_figurehandle.MovieModeSideDropDown.Items{currentValues(6)};
            
            %set(obj.textBox_speed_h, 'String', currentValues(8)) %change stim orientation
            %obj.textSpeed() 
            obj.newGUI_figurehandle.EnterSpeedEditField.Value = currentValues(8);
            
            %set(obj.choiceDistance_h, 'Value', currentValues(9)) %change distance from split turn on steering ([1, 2, 3, 4]/4)
            obj.newGUI_figurehandle.SteeringLengthDropDown.Value = obj.newGUI_figurehandle.SteeringLengthDropDown.Items{currentValues(9)};    
            
            
        end
       
        
        
        function chooseBranch(obj,branchNum)
            % This function overwrites the csvfile data table when a manual input is entered
            obj.csvDataTable{obj.trial:end,2} = branchNum; %obj.choosebranch_h.Value; %index is the 2nd column. overwrite branchNum data with this branchNum
            %obj.csvDataTable
        end
        
        function ManualGratingSide(obj,sideNum)
            
             obj.csvDataTable{obj.trial+1:end,3} = sideNum;%obj.gratingSide_h.Value; %index is the 3th column.

        end
        
        function stimThickness(obj,value)
            % This function overwrites csvdatatable with manual input for Next trial's preset stim spatial freq

            obj.csvDataTable{obj.trial+1:end,4} = value; %obj.stimSize_h.Value; %index is the 4nd column.
        end
        
        
        
        function textRotation(obj,rotation)
           % This function overwrites csvdatatable with manual input for Next trial's preset stim orientation

            obj.csvDataTable{obj.trial+1:end,5} = rotation; %str2double(obj.textBox_stimRotation_h.String); %index is the 5th column.

        end
        
        function ManualDirection(obj,sideNum)
                obj.csvDataTable{obj.trial+1:end,6} = sideNum; %obj.movieDirection_h.Value;%index is the 6nd column.
    
        end
        
        function textSpeed(obj,speed)
           % This function overwrites csvdatatable with manual input for Next trials' preset speed
            %obj.csvDataTable
            obj.csvDataTable{obj.trial:end,8} = speed;%str2double(obj.textBox_speed_h.String);%index is the 8nd column.
            
            %obj.csvDataTable
        end
        
        function ManualChoiceDistance(obj,length)
             obj.csvDataTable{obj.trial+1:end,9} = length;%obj.choiceDistance_h.Value; %index is the 9nd column.
        end
        
        
        function reset(obj)
            % LinearMaze.reset()
            % Reset position, rotation, frame count and encoder steps.
            
            branchNum = find(strcmp(obj.newGUI_figurehandle.BranchNumberDropDown.Items,obj.newGUI_figurehandle.BranchNumberDropDown.Value));
            %obj.trial = 1;
            if obj.hardware == 0
                obj.nodes.vertices = obj.vertices(branchNum,:);
            elseif obj.hardware == 2
                obj.yRotation = 90; %reset rotation on new trial
                obj.z_yRotation = 1;
                obj.x_yRotation = 0;
                obj.sender.send(sprintf('rotation,Main Camera,0,%.2f,0;', obj.yRotation-90), obj.addresses);
                obj.vectorPosition(1:2) = obj.vertices(1:2);
            end
            
            % Frame counts and steps are reset to zero.
            obj.treadmill.frame = 0;
            obj.treadmill.step = 0;
            obj.print('note,reset');
        end
       
        function start(obj)
            % LinearMaze.start()
            % Send high pulse to trigger-out and enable behavior.
            
            obj.stopDuringBlank = false;
            % Load an existing scene.
            obj.sender.send(sprintf('scene,%s;', obj.scene), obj.addresses);
            
            % Hide user menu.
            obj.sender.send('enable,Menu,0;', obj.addresses);
            
            % Hide blank and enable external devices and behavior.
            obj.sender.send('enable,Blank,0;', obj.addresses);
            
            % Send a high pulse to trigger-out.
            obj.treadmill.trigger = true;
            obj.enabled = true;
            obj.print('note,start');
        end
        
        function stop(obj)
            % LinearMaze.stop()
            % Send low pulse to trigger-out and disable behavior.
            
            % Show blank and disable external devices and behavior.
            obj.stopDuringBlank = true;
            obj.enabled = false;
            obj.treadmill.trigger = false;
            obj.sender.send('enable,Blank,1;', obj.addresses);
            %obj.sender.send('enable,Mouse,1;', obj.addresses); %this is how
            %to turn off and on (0 or 1 respectively) objects in Main 
            
            obj.print('note,stop');
            drawnow;
        end
        
        function onButton(obj)
            % LinearMaze.onLogButton()
            % Log user text.
            
            if ~isempty(obj.newGUI_figurehandle.LogTextEditField.Value)      %obj.textBox_h.String)
                obj.print('note,%s', obj.newGUI_figurehandle.LogTextEditField.Value);%obj.textBox_h.String);
                obj.newGUI_figurehandle.LogTextEditField.Value = '';%obj.textBox_h.String = '';
            end
        end
        
        function ManualReward(obj)
           %send pulse to water pump
           
           obj.treadmill.reward(obj.rewardDuration);
           obj.log('note,reward');
          
        end
        
        function delete(obj)
            % LinearMaze.delete()
            % Release all resources.
            
            obj.treadmill.trigger = false;
            delete(obj.treadmill);
            delete(obj.scheduler);
            delete(obj.nodes);
            delete(obj.sender);
            obj.log('note,delete');
            fclose(obj.fid); %close timeBased log file
            fclose(obj.fid_trial); %close trialBased log file
            LinearMaze.export(obj.filename);
            LinearMaze.export(obj.filename_trial);
            
            
            
%             if ishandle(obj.figureHandle)             %i think this is
%                                                         for the old gui
%                 set(obj.figureHandle, 'DeleteFcn', []);
%                 delete(obj.figureHandle);
%             end
            
        end
        
        function MouseGraph(obj)
            %add another number to y-axis
            %add marker to right/left indicating right/wrong
            %this function gets called in newTrial()
            handle_mouseChoice = obj.newGUI_figurehandle.MouseChoiceGraph; %handle to mouseChoiceGraph on GUI
            handle_choiceAccuracy = obj.newGUI_figurehandle.ChoiceAccuracyGraph;%handle to ChoiceAccuracyGraph on GUI
            
            lastTrial = obj.trial - 1; %this is because we care about plotting the previous trial
            
            if lastTrial < 10 %first ten trials
                ylim(handle_mouseChoice,[0 ,lastTrial]); %increase limit of mouseChoiceGraph trial # by 1
                set(handle_mouseChoice,'ytick',[1:lastTrial]);%add trial number to graph
                
            else
                %start taking the lowest trial out of yaxis and adding to
                %top of yaxis
                ylim(handle_mouseChoice,[lastTrial-9 ,lastTrial]);
                set(handle_mouseChoice,'ytick',[lastTrial-9:lastTrial]);
                
            end
            %-----------------This is for choiceAccuracyGraph
            xlim(handle_choiceAccuracy,[0 ,lastTrial]);%increase limit of ChoiceAccuracyGraph trial # by 1
            set(handle_choiceAccuracy,'xtick',[1:2:lastTrial]);%add trial number to graph
            %array for the last ten trials
            if lastTrial > 10
                lastTenAccuracy = obj.choiceArray(end-9:end,2); %try getting the accuracy for last 10 trials if trials>10 
            else
                lastTenAccuracy = obj.choiceArray(:,2); %get all the accuracy info 
            end
            obj.accuracyArray(lastTrial) = sum(lastTenAccuracy)/length(lastTenAccuracy)*100; %the percent accurate over last ten trials
            plot(handle_choiceAccuracy,1:lastTrial, obj.accuracyArray,'-m','LineWidth',2);%plot the accuracy over last ten trials
            %--------------------
            
            
            %calculate the ratio for averageGratingSide
            obj.averageGratingSide(lastTrial) = sum(obj.gratingSideArray(1:lastTrial))/lastTrial;% * 2 + 2; %find average side of grating, convert 0-1 ratio to 2-4 ratio. append to list
            changeratio = obj.averageGratingSide .*2 +2;%stretch by factor of 2, push to the right 2. So it fits in the plot 
            
            obj.averageCorrectChoice(lastTrial) = sum(obj.choiceArray(:,1))/length(obj.choiceArray(:,2)); %list of average correct choice at each trial
            
            if obj.choiceArray(lastTrial,2) == 1 %correct
                plot(handle_mouseChoice, obj.choiceArray(lastTrial,1),lastTrial,'o','color',[0 .5 0],'LineWidth',1);%plot black circle for correct
            else %incorrect
                plot(handle_mouseChoice, obj.choiceArray(lastTrial,1),lastTrial,'xr','LineWidth',1);%plot red x for incorrect
            end
            
            plot(handle_mouseChoice,obj.averageCorrectChoice,1:lastTrial,'k','LineWidth',2);  %plot list of average correct choice at each trial 
            plot(handle_mouseChoice,changeratio,1:lastTrial,'b','LineWidth',2);  %plot average side line
                                    
                
        end
        
        %%
        function setStimulus(obj)
            
            
            %initially turn off all stimulus. turn off thin
            obj.sender.send('enable,Branch1LeftGratingThin,0;', obj.addresses);
            obj.sender.send('enable,Branch1RightGratingThin,0;', obj.addresses);
            obj.sender.send('enable,Branch2LeftGratingThin,0;', obj.addresses);
            obj.sender.send('enable,Branch2RightGratingThin,0;', obj.addresses);
            obj.sender.send('enable,Branch3LeftGratingThin,0;', obj.addresses);
            obj.sender.send('enable,Branch3RightGratingThin,0;', obj.addresses);
            %turn off thick
            obj.sender.send('enable,Branch1LeftGratingThick,0;', obj.addresses);
            obj.sender.send('enable,Branch1RightGratingThick,0;', obj.addresses);
            obj.sender.send('enable,Branch2LeftGratingThick,0;', obj.addresses);
            obj.sender.send('enable,Branch2RightGratingThick,0;', obj.addresses);
            obj.sender.send('enable,Branch3LeftGratingThick,0;', obj.addresses);
            obj.sender.send('enable,Branch3RightGratingThick,0;', obj.addresses);
            %turn off all gray cylinders
            obj.sender.send('enable,Branch1LeftGray,0;', obj.addresses);
            obj.sender.send('enable,Branch1RightGray,0;', obj.addresses);
            obj.sender.send('enable,Branch2LeftGray,0;', obj.addresses);
            obj.sender.send('enable,Branch2RightGray,0;', obj.addresses);
            obj.sender.send('enable,Branch3LeftGray,0;', obj.addresses);
            obj.sender.send('enable,Branch3RightGray,0;', obj.addresses);
            
            
%             if obj.stimSize_h.Value == 1 %thick            
%                 obj.stimSize_string = 'Thick';
%             else %thin
%                 obj.stimSize_string = 'Thin';
%             end
            obj.stimSize_string = obj.newGUI_figurehandle.SpatialFrequencyDropDown.Value; %get spatial freq from APP
            obj.stimRot = obj.newGUI_figurehandle.EnterRotationEditField.Value+90;% get rotation from APP %str2double(obj.textBox_stimRotation_h.String)+90;
             
            %set rotation of current branches stimuli
            obj.sender.send(sprintf(strcat('rotation,Branch', num2str(obj.currentBranch) ,'RightGrating',obj.stimSize_string,',%.2f,-50,90;'), obj.stimRot),obj.addresses)
            obj.sender.send(sprintf(strcat('rotation,Branch', num2str(obj.currentBranch) ,'LeftGrating',obj.stimSize_string,',%.2f,50,90;'), obj.stimRot),obj.addresses)
            
             
             
             
            %set the stimulus
            %side = obj.gratingSide_h.Value;
            preset = obj.csvDataTable{obj.trial,3};%find(strcmp(obj.newGUI_figurehandle.MovieModeSideDropDown.Items,obj.newGUI_figurehandle.MovieModeSideDropDown.Value)); %obj.movieDirection_h.Value;   
                
            rando = rand();
            
            %obj.ActualSide = preset; %this is to see if the side chosen was correct or not for the reward
            if preset < rando %left
                obj.sender.send(strcat('enable,Branch', num2str(obj.currentBranch) ,'LeftGrating', obj.stimSize_string ,',1;'), obj.addresses);
                obj.sender.send(strcat('enable,Branch', num2str(obj.currentBranch) ,'RightGray,1;'), obj.addresses);
                obj.ActualSide = 2;%left.%this is to see if the side chosen was correct or not for the reward
                obj.gratingSideArray(obj.trial) = 0;
            else%if side == 3%right
                obj.sender.send(strcat('enable,Branch', num2str(obj.currentBranch) ,'RightGrating',obj.stimSize_string,',1;'), obj.addresses);
                obj.sender.send(strcat('enable,Branch', num2str(obj.currentBranch) ,'LeftGray,1;'), obj.addresses);
                obj.ActualSide = 3;%this is to see if the side chosen was correct or not for the reward
                obj.gratingSideArray(obj.trial) = 1;
            end
            
            %disp(obj.gratingSideArray)
        end
        
        function setNodes_movieMode(obj)
            %set path left or right for movie mode camera
            
            %this is the value of the preset between 0 and 1
            preset = obj.csvDataTable{obj.trial,6};%find(strcmp(obj.newGUI_figurehandle.MovieModeSideDropDown.Items,obj.newGUI_figurehandle.MovieModeSideDropDown.Value)); %obj.movieDirection_h.Value;   
                
            rando = rand();
            
            obj.nodes.vertices = obj.vertices(obj.currentBranch,:);
                if obj.currentBranch == 1
  
                    if preset < rando 
                        obj.nodes.vertices(end-1) = -35; %left
                    else                                  
                       obj.nodes.vertices(end-1) = 35;%right
                    end
                    
                elseif obj.currentBranch == 2
                    
                    
                    if preset < rando  %go left
                        obj.nodes.vertices(end-1) = 240;%left
                    else
                       obj.nodes.vertices(end-1) = 270;%right
                    end
                elseif obj.currentBranch == 3
                    
                    
                    if preset < rando 
                        obj.nodes.vertices(end-1) = 446;%left
                    else
                       obj.nodes.vertices(end-1) = 488;%right
                    end
                end
    
%                 if rand == 1
%                     rand = randi([2 3]); %round(rand)+2%2 or 3
%                 end
%                 
%                 obj.nodes.vertices = obj.vertices(obj.currentBranch,:);
%                 if obj.currentBranch == 1
%   
%                     if rand == 2 %go left
%                         obj.nodes.vertices(end-1) = -35;
%                     elseif rand ==3 %go right
%                        obj.nodes.vertices(end-1) = 35;
%                     end
%                     
%                 elseif obj.currentBranch == 2
%                     
%                     
%                     if rand == 2 %go left
%                         obj.nodes.vertices(end-1) = 240;
%                     elseif rand ==3%go right
%                        obj.nodes.vertices(end-1) = 270;
%                     end
%                 elseif obj.currentBranch == 3
%                     
%                     
%                     if rand == 2 %go left
%                         obj.nodes.vertices(end-1) = 446;
%                     elseif rand ==3 %go right
%                        obj.nodes.vertices(end-1) = 488;
%                     end
%                 end
        end
        
        
        function touchPad(obj,data)             
            %this will display on the gui a lick count and log it on time
            %based log file
            
            %fprintf('Pin: %i. State: %i. Count: %i.\n', data.Pin, data.State, data.Count); 
            if data.Count == 0
                return %this function gets called once at the beginning of the script so return
                
            elseif obj.lickCount ~= data.Count %make sure this can only be entered once per lick
                obj.lickCount = data.Count;
                %disp('start')
                
                obj.newGUI_figurehandle.LickCountNumber.Text = num2str(data.Count); %update GUI
                
                %log the Lick
                obj.log('note,start of lick');
                
            else
                %make a note in the timebased log file that this is the end
                %of the lick
                %disp('end')
                obj.log('note,end of lick');
                
            end
            
        end
        
        
        
        
        
        function blank(obj, duration)
            % LinearMaze.pause(duration)
            % Show blank for a given duration.
            
           
            %Objects.delete(obj.blankId); %this gave me a problem on the
            %basement pc
            if duration == 0 && ~obj.stopDuringBlank
                obj.sender.send('enable,Blank,0;', obj.addresses);
                obj.enabled = true;
            elseif duration > 0
                obj.enabled = false;
                obj.sender.send('enable,Blank,1;', obj.addresses);
                %obj.blankId = %this also gave me a problem on pc
                obj.scheduler.delay({@obj.blank, 0}, duration);
            end
        end
        
        function set.gain(obj, gain)
            obj.mGain = gain;
            obj.print('gain,%.2f', gain);
        end
        
        function gain = get.gain(obj)
            gain = obj.mGain;
        end
        
        function set.speed(obj, speed)
            obj.print('speed,%.2f', speed);f

            obj.mSpeed = speed;
        end
        
        function speed = get.speed(obj)
            %if ~isempty(obj.textBox_speed_h.String) %obj.newGUI_figurehandle.EnterSpeedEditField.Value
                 if obj.hardware == 0%movie
                    obj.mSpeed = obj.csvDataTable{obj.trial,8};%obj.newGUI_figurehandle.EnterSpeedEditField.Value; %str2double(obj.textBox_speed_h.String);
                    %obj.mSpeed = obj.csvDataTable{obj.trial,8};
                 %else%steering - gets handled in onupdate
                 %   obj.steeringPushfactor = str2double(obj.textBox_speed.String);
                 end
                 
                %obj.textBox_speed.String = '';
            %end
            speed = obj.mSpeed;
        end
        
        
        
%         function MovieModeDirection(obj)
%             yo =find(strcmp(obj.newGUI_figurehandle.SteeringOnOffDropDown.Items,obj.newGUI_figurehandle.SteeringOnOffDropDown.Value));
%             if yo == 1
%                 obj.hardware = 2;
%             else
%                 obj.hardware = 0;
%             end
%             
%         end
  
        function log(obj, format, varargin)
            % LinearMaze.log(format, arg1, arg2, ...)
            % Create a log entry using the same syntax as sprintf.
            
            fprintf(obj.fid, '%.2f,%s\n', toc(obj.startTime), sprintf(format, varargin{:}));
            
        end
        
        function pause(obj, duration)
            % LinearMaze.pause(duration)
            % Show blank and disable behavior for a given duration.
            
            Objects.delete(obj.pauseId);
            if duration == 0
                obj.enabled = true;
                obj.sender.send('enable,Blank,0;', obj.addresses);
            elseif duration > 0
                obj.enabled = false;
                obj.sender.send('enable,Blank,1;', obj.addresses);
                obj.pauseId = obj.scheduler.delay({@obj.pause, 0}, duration);
            end
        end
        
        function print(obj, format, varargin)
            % LinearMaze.print(format, arg1, arg2, ...)
            % Print on screen and create a log entry using the same syntax as sprintf.
            
            fprintf('[%.1f] %s\n', toc(obj.startTime), sprintf(format, varargin{:}));
            obj.log(format, varargin{:});
        end
        
        function print_trial(obj, format, varargin)
            % LinearMaze.print(format, arg1, arg2, ...)
            % Print on screen and create a log entry using the same syntax as sprintf.
            
            fprintf('[%.1f] %s\n', toc(obj.startTime), sprintf(format, varargin{:}));
            obj.log_trial(format, varargin{:});
        end
        
        function log_trial(obj, format, varargin)
            % LinearMaze.log(format, arg1, arg2, ...)
            % Create a log entry using the same syntax as sprintf.
            
            fprintf(obj.fid_trial, '%.2f,%s\n', toc(obj.startTime), sprintf(format, varargin{:}));
            
        end
    end
   
    methods (Access = private)
        %%
        function newTrial(obj)
            % LinearMaze.newTrial()
            % Send a reward pulse, play a tone, log data, pause.
            yo =find(strcmp(obj.newGUI_figurehandle.SteeringOnOffDropDown.Items,obj.newGUI_figurehandle.SteeringOnOffDropDown.Value));
            if yo == 1 && ~isempty(obj.com)
                obj.hardware = 2;
            elseif ~isempty(obj.com)
                obj.hardware = 0;
            end
            
            correctness = 1;
            if obj.hardware == 2
                if obj.vectorPosition(1)<obj.branchArray(obj.currentBranch,2)
                    sidechosen = 'left';
                    obj.choiceArray(obj.trial,1) = 2; %the mouse went left
                else
                    sidechosen = 'right';
                    obj.choiceArray(obj.trial,1) = 4;%the mouse went right
                end
                
                if obj.vectorPosition(1)<obj.branchArray(obj.currentBranch,2) && obj.ActualSide == 2    %left
                    %correct
                    %obj.newGUI_figurehandle.ChoiceEditField.Value = 'correct left';
                    obj.intertrialDuration = 1;
                    
                    %Tools.tone(obj.rewardTone(1), obj.rewardTone(2));% This makes a reward tone
                    obj.treadmill.reward(obj.rewardDuration);
                    
                    obj.log('note,reward');
                    
                    obj.choiceArray(obj.trial,2) = 1; %correct side chosen
                    
                    
                elseif obj.vectorPosition(1)> obj.branchArray(obj.currentBranch,2) && obj.ActualSide == 3  %right
                    %correct
                    %obj.newGUI_figurehandle.ChoiceEditField.Value = 'correct right';
                    obj.intertrialDuration = 1;
                    
                    %Tools.tone(obj.rewardTone(1), obj.rewardTone(2)); %This makes a reward tone
                    
                    obj.treadmill.reward(obj.rewardDuration);
                    
                    obj.log('note,reward');
                    
                    obj.choiceArray(obj.trial,2) = 1; %correct side chosen
                else
                    %incorrect
                    
                    %Tools.tone(obj.errorTone(1), obj.errorTone(2)); %This makes a error tone
                   
                    
                    %obj.newGUI_figurehandle.ChoiceEditField.Value = 'incorrect';
                    obj.intertrialDuration = 3;
                    correctness = 0;
                    
                    obj.choiceArray(obj.trial,2) = 0; %incorrect side chosen
                end
            else%hardware off
                if obj.nodes.yaw < 0
                    sidechosen = 'left';
                    obj.choiceArray(obj.trial,1) = 2;%the mouse went left
                else
                    sidechosen = 'right';
                    obj.choiceArray(obj.trial,1) = 4;%the mouse went right
                end
                
                if obj.nodes.yaw < 0 && obj.ActualSide == 2          %left
                    %correct
                    
                    %obj.newGUI_figurehandle.ChoiceEditField.Value = 'correct left';
                    obj.intertrialDuration = 1;
                    obj.treadmill.reward(obj.rewardDuration);
                    %Tools.tone(obj.rewardTone(1), obj.rewardTone(2)); %This makes a reward tone
                    obj.log('note,reward');
                    obj.choiceArray(obj.trial,2) = 1; %correct side chosen
                    
                elseif obj.nodes.yaw > 0 && obj.ActualSide == 3    %right
                    %correct
                    %obj.newGUI_figurehandle.ChoiceEditField.Value = 'correct right';
                    obj.intertrialDuration = 1;
                    obj.treadmill.reward(obj.rewardDuration);
                    %Tools.tone(obj.rewardTone(1), obj.rewardTone(2));% This makes a reward tone
                    obj.log('note,reward');
                    obj.choiceArray(obj.trial,2) = 1; %correct side chosen
                else
                    %incorrect
                    %Tools.tone(obj.errorTone(1), obj.errorTone(2)); %This makes a error tone
                   
                    
                    %obj.newGUI_figurehandle.ChoiceEditField.Value = 'incorrect';
                    obj.intertrialDuration = 3;
                    correctness = 0;
                    
                    obj.choiceArray(obj.trial,2) = 0; %incorrect side chosen
                end
            end
            
            %log last trial
            obj.log('data,%i,%i,%i,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f, %i,%i,%i', obj.trial,obj.treadmill.frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2),obj.vectorPosition(1),obj.vectorPosition(2),obj.speed,obj.steeringPushfactor ,obj.currentBranch);
            obj.log_trial('%i,%i,%i,%s,%s,%.2f,%i,%i,%i', obj.trial,correctness,obj.ActualSide,sidechosen,obj.stimSize_string,obj.stimRot-90,obj.currentBranch,obj.hardware,obj.steeringLength); 
            
            %obj.print('trial,%i', obj.trial); %print trial in command window and log in file

            obj.trial = obj.trial + 1; %increment the trial number
            
            try  %this makes a black screen whenever the end of the preset csv file has been reached                
                obj.currentBranch = obj.csvDataTable{obj.trial,2};%find(strcmp(obj.newGUI_figurehandle.BranchNumberDropDown.Items,obj.newGUI_figurehandle.BranchNumberDropDown.Value));
            catch
                obj.stop() 
                %obj.newGUI_figurehandle.debugEditField.Value = 'end of preset csv file reached';
            end
            
            
            
            obj.newGUI_figurehandle.trialNumberLabel.Text = num2str(obj.trial); %change trial number in GUI
            
            obj.MouseGraph(); %update the mouseGraph in GUI

            
            %try  %this makes a black screen whenever the end of the preset csv file has been reached                
                obj.steeringLength = obj.csvDataTable{obj.trial,9};%find(strcmp(obj.newGUI_figurehandle.SteeringLengthDropDown.Items,obj.newGUI_figurehandle.SteeringLengthDropDown.Value));
            %catch
%                 obj.stop() 
%                 obj.newGUI_figurehandle.debugEditField.Value = 'end of preset csv file reached';
%             end
            
            
            obj.updateFromCSV() %update input values from csv file
            obj.setStimulus(); %put the stimulus in place with correct rotation

            
            %if movie mode, and random then switch the final node randomly
            %left or right
            if obj.hardware == 0  %if not using steering 
                obj.setNodes_movieMode(); %set path left or right for movie mode camera

            else%obj.hardware == 2
                
                obj.vectorPosition = obj.vertices(obj.currentBranch,1:2);
                obj.yRotation = 90; %reset rotation on new trial
                obj.z_yRotation = 1;
                obj.x_yRotation = 0;
                
                %obj.sender.send(sprintf('rotation,Main Camera,0,%.2f,0;', obj.yRotation-90), obj.addresses);
                obj.sender.send(Tools.compose([sprintf(...
                'position,Main Camera,%.2f,1,%.2f;', obj.vectorPosition(1), obj.vectorPosition(2)), ...
                'rotation,Main Camera,0,%.2f,0;'], obj.yRotation-90 + obj.offsets), ...
                obj.addresses);
            end
            
            %Disable movement and show blank screen for the given duration.
            if obj.intertrialBehavior
                obj.blank(obj.intertrialDuration);
            else
                obj.pause(obj.intertrialDuration);
            end
            
            
        end
        %%
        function onBridge(obj, connected)
            if connected
                obj.print('note,Arduino connected.');
            else
                obj.print('note,Arduino disconnected.');
            end
        end
        
        function onChange(obj, position, distance, yaw)
            % LinearMaze.onChange(position, distance, yaw)
            % Update monitors with any change in position and rotation.
            % Create an entry in the log file if logOnChange == true.
            
            obj.sender.send(Tools.compose([sprintf(...
                'position,Main Camera,%.2f,1,%.2f;', position(1), position(2)), ...
                'rotation,Main Camera,0,%.2f,0;'], yaw + obj.offsets), ...
                obj.addresses);
            
            if obj.logOnChange
                obj.log('data,%i%i,%i,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f, %i,%i,%i',obj.trial, obj.treadmill.frame, obj.treadmill.step, distance, yaw, position(1), position(2),obj.vectorPosition(1),obj.vectorPosition(2),obj.speed,obj.steeringPushfactor ,obj.currentBranch);
            end
        end
        
        function onFrame(obj, frame)
            % LinearMaze.onFrame(frame)
            % The trigger input changed from low to high.
            % Create an entry in the log file if logOnFrame == true.
            
            % Log changes including frame count and rotary encoder changes.
            
            
            if obj.logOnFrame
                obj.log('data,%i%i,%i,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f, %i,%i,%i',obj.trial, frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2),obj.vectorPosition(1),obj.vectorPosition(2),obj.speed,obj.steeringPushfactor ,obj.currentBranch);
            end
            
            % Change the name to reflect frame number.
            set(obj.figureHandle, 'Name', sprintf('%s - Frame: %i', mfilename('Class'), frame));
        end
        
        function onLap(obj)
            % LinearMaze.onLap()
            % Ran thru all nodes, disable motion during the intertrial.
            
            obj.newTrial();
        end

        function onTape(obj, forward)
            % LinearMaze.onTape(state)
            % Treadmill's photosensor detected a reflective tape in the belt.
            
            if obj.enabled && obj.tapeTrigger
                if forward
                    obj.tapeControl(1) = obj.tapeControl(1) + 1;
                else
                    obj.tapeControl(1) = obj.tapeControl(1) - 1;
                end
                if obj.tapeControl(1) == obj.tapeControl(2)
                    obj.tapeControl(2) = obj.tapeControl(2) + 1;
                    obj.newTrial();
                end
            end
        end
        
        function onNode(obj, node)
            % LinearMaze.onNode(node)
            % Reached a reset node.
            
            if ~obj.tapeTrigger && ismember(node, obj.resetNode)
                %obj.nodes.vertices = obj.vertices;
                obj.newTrial();
            end
        end
        
        function onStep(obj, step)
            % LinearMaze.onStep(step)
            % The rotary encoder changed, update behavior if enabled
            % Create an entry in the log file otherwise.
            
            %if obj.enabled && obj.speed == 0 && ~obj.nodes.rotating
                % Rotary encoder changes position unless open-loop speed is different than 0.
                %obj.nodes.push(step * obj.gain);
            %end
            
            
            %steeringWheel        if current posit  is greater than the
            %                    starting posit plus 1/4 2/4 3/4 4/4 of the
            %                    distance from start to split
            
            
            if obj.enabled && obj.hardware==2  %&& obj.vectorPosition(2) > (5-obj.steeringLength)/4 * obj.straightDist(obj.currentBranch) + obj.vertices(obj.currentBranch,2)
               %disp('o')
                obj.yRotation = obj.yRotation + step * obj.gain; %the yRotation is updated each time this function is called
                
                if obj.yRotation > 180
                    obj.yRotation = 180;
                elseif obj.yRotation < 0
                    obj.yRotation = 0;
                end
                
%                 obj.x_yRotation = cosd(obj.yRotation);%This is done in onupdate now
%                 obj.z_yRotation = sind(obj.yRotation);
          
%                 obj.sender.send(sprintf('position,Main Camera,%.2f,1,%.2f;', obj.vectorPosition(1), obj.vectorPosition(1,2), ...
%                 'rotation,Main Camera,0,%.2f,0;',obj.yRotation))
                
                
%                  obj.sender.send(sprintf(...
%                     'rotation,Main Camera,0,%.2f,0;', obj.yRotation-90 + obj.offsets), ...
%                  obj.addresses);

            end
        end
                
                
       
        
%         function steeringPush(obj) (I put this function in onUpdate
%             
%             if obj.enabled %if game not 'stop' or 'pause'
%                 
%                 obj.sender.send(sprintf(...
%                 'position,Main Camera,%.2f,1,%.2f;', obj.vectorPosition(1), obj.vectorPosition(1,2)), ...
%                 obj.addresses);
%             
%                 obj.vectorPosition(1,1) = obj.vectorPosition(1,1) - obj.x_yRotation;
%                 obj.vectorPosition(1,2) = obj.vectorPosition(1,2) + obj.z_yRotation;
%                 
%                 if obj.vectorPosition(1,2) > obj.vertices(end) %get to reset node: then reset camera position
%                     obj.vectorPosition(1:2) = obj.vertices(1:2); 
%                     obj.newTrial();
%                 end
%             end
%         end

        
       
        %%
        function onUpdate(obj)
            % LinearMaze.onUpdate()
            % Create an entry in the log file if logOnUpdate == true.
             %tic
                
                if obj.hardware == 0 && obj.enabled%obj.speed ~= 0 && obj.enabled && ~obj.nodes.rotating
                    % Open-loop updates position when open-loop speed is different 0.
                    obj.nodes.push(obj.speed / obj.nodes.fps);
                elseif obj.enabled  %hardware on, obj enabled
                     
                    
                
%                     if ~isempty(obj.textBox_speed_h.String)
%                         obj.steeringPushfactor = obj.csvDataTable{obj.trial,8} * .05;%str2double(obj.textBox_speed_h.String)*.05;%steering factor based off speed textbox and random 0.05 number
%                     else
%                         obj.steeringPushfactor = 1.25; %= 25*.05. This is the default push factor if nothing is put in the text box
%                     end
                    obj.steeringPushfactor = obj.newGUI_figurehandle.EnterSpeedEditField.Value * .05;
                    
                    obj.vectorPosition(1) = obj.vectorPosition(1) - (cosd(obj.yRotation)*obj.steeringPushfactor);
                    obj.vectorPosition(2) = obj.vectorPosition(2) + (sind(obj.yRotation)*obj.steeringPushfactor);
                    
                    x_coord = obj.vectorPosition(1);
                    y_coord = obj.vectorPosition(2);
                    
                
                    %----------------------------------------------------------------------------
                    
                             %this ifelse is the walls
                    if y_coord < obj.branchArray(obj.currentBranch,4)%-28 %on straight path
                        %bound x by [457, 475]
                        if x_coord < obj.branchArray(obj.currentBranch,1) %457 too far left
                            obj.vectorPosition(1) = obj.branchArray(obj.currentBranch,1);
                        elseif x_coord > obj.branchArray(obj.currentBranch,3) %475 %too far right
                            obj.vectorPosition(1) = obj.branchArray(obj.currentBranch,3);
                        end
                        
                            
                    else%if obj.vectorPosition(2) >= obj.branchArray(obj.currentBranch,4)%-28
                        %bound x by function of z
                        if x_coord <= obj.branchArray(obj.currentBranch,2)%466 %left path
                            if x_coord < obj.left_leftwall(y_coord,obj.currentBranch) %too far left
                                obj.vectorPosition(1) = obj.left_leftwall(y_coord,obj.currentBranch);%function of z
                            elseif x_coord > obj.left_rightwall(y_coord,obj.currentBranch) %too far right
                                obj.vectorPosition(1) = obj.left_rightwall(y_coord,obj.currentBranch); %function of z
                            end
                        else%if x_coord > obj.branchArray(obj.currentBranch,2)%466 %right path
                            if x_coord < obj.right_leftwall(y_coord,obj.currentBranch) %too far left
                                obj.vectorPosition(1) = obj.right_leftwall(y_coord,obj.currentBranch);%function of z
                            elseif x_coord > obj.right_rightwall(y_coord,obj.currentBranch) %too far right
                                obj.vectorPosition(1) = obj.right_rightwall(y_coord,obj.currentBranch); %function of z
                            end
                        end
                    end
                    
%                     obj.sender.send(sprintf(...
%                     'position,Main Camera,%.2f,1,%.2f;', obj.vectorPosition(1), obj.vectorPosition(2)), ...
%                     obj.addresses);
                
                obj.sender.send(Tools.compose([sprintf(...
                'position,Main Camera,%.2f,1,%.2f;', obj.vectorPosition(1), obj.vectorPosition(2)), ...
                'rotation,Main Camera,0,%.2f,0;'], obj.yRotation-90 + obj.offsets), ...
                obj.addresses);
                    %---------------------------------------------------------------------------------
%                     obj.sender.send(sprintf(...
%                     'position,Main Camera,%.2f,1,%.2f;', obj.vectorPosition(1), obj.vectorPosition(2)), ...
%                     obj.addresses);
                         %obj.vectorPosition
%             obj.vertices(obj.choosebranch_h.Value,end)
                     if y_coord > obj.vertices(obj.currentBranch,end) %get to reset node: then reset camera position

                            obj.newTrial();
                     end  
                     
                 end
        
            if obj.logOnUpdate
                str = sprintf('data,%i,%i,%i,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f, %i,%i,%i', obj.trial,obj.treadmill.frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2),obj.vectorPosition(1),obj.vectorPosition(2),obj.speed,obj.steeringPushfactor ,obj.currentBranch);
                if ~strcmp(str, obj.update)
                    obj.update = str;
                    obj.log(str);
                end
                
            end
             %linear = toc%av = 0.001
%             disp([linear,obj.enabled])%monitors,{192.168.0.11;0},hardware,0
        end
        
        
        
        
    end
    %% Walls and export log file
    methods (Static)
        
        
%         function stimThickness_GUIDE(value)
%             % This function overwrites csvdatatable with manual input for Next trial's preset stim spatial freq
% 
%             %obj.csvDataTable{obj.trial+1:end,4} = value; %index is the 4nd column.
%             LinearMaze.stimThickness(value)
%         end
%         
        function x = left_leftwall(z,branch)
            %left side of left branch
           if branch == 3 %branch 3
            x = z/(-1.75)  +  443;
            %x = (z-728)*(-0.61);
           elseif branch == 2 %branch 2 
            x = (z-318.5)/(-1.4);
          
           else%if branch == 1 %branch 1
            x = (z + 44.776)/(-.96);
           end
        end
        
        function x = left_rightwall(z,branch)
            %right side of left branch
            
           if branch == 3 %branch 3
            x = z/(-1.75) + 450;
           elseif branch == 2 %branch 2 
            x = (z-1335)/(-5.33);
          
           else%if branch == 1 %branch 1
            
            x = (z+40)/(-1.3);
           end
        end
        
        function x = right_leftwall(z, branch)
            %left side of right branch
            
           if branch == 3 %branch 3
            x = z/1.65 + 484.5;
           elseif branch == 2 %branch 2 
            x = (z+1383)/5.3;
            
           else%if branch == 1 %branch1
            x = (z+40)/1.6;
           end
        end
        
       
        function x = right_rightwall(z, branch)
            %right side of right branch
            
           if branch == 3 %branch 3
            x = z/1.6 + 492;
           elseif branch == 2 %branch 2 
            x = (z+423)/1.5;
           
           elseif branch == 1 %branch 1
            x = (z+45.33)/1.1;
           end
        end
        
        function export(filename)
            % LinearMaze.export(filename)
            % Convert log file to a mat file.
            
            header = {'time (s)', 'frame', 'encoder-step', 'unfolded-distance (cm)', 'y-rotation (degrees)', 'x-position (cm)', 'z-position (cm)'};
            data = str2double(CSV.parse(CSV.load(filename), [-1 1:6], 'data'));
            [folder, filename] = fileparts(filename);
            save(fullfile(folder, sprintf('%s.mat', filename)), 'header', 'data');
        end
        
       
    end
end

%#ok<*NASGU>
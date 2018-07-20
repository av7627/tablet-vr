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
classdef LinearMaze < handle
    %%
    properties
        % properties of the class
        
        % intertrialBehavior - Whether to permit behavior during an intertrial.
        intertrialBehavior = false;
        
        % intertrial - Duration (s) of an intertrial when last node is reached.
        intertrialDuration = 0;
        
        % logOnChange - Create a log entry with every change in position or rotation.
        logOnChange = false;
        
        % logOnFrame - Create a log entry with every trigger-input.
        logOnFrame = true;
        
        % logOnUpdate - Create a log entry at the frequency of the behavior controller.
        logOnUpdate = true;
		
        % rewardDuration - Duration (s) the reward valve remains open after a trigger.
        rewardDuration = 0.040;
        
        % rewardTone - Frequency and duration of the tone during a reward.

        rewardTone = [2000, 0.5];
        


        

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
        
        % filename - Name of the log file.
        filename
        
        % scene - Name of an existing scene.
        scene = 'linearMaze';
		
        % vertices - Vertices of the maze (x1, y1; x2, y2 ... in cm).
        %vertices = [0,-100   0,-42   -35,-10 ; 255,-100    255,-30     240,-2  ;  467,-95   467,-33   446,-1];%of three branches. go left at first
        vertices = [0,-100   0,-42   -35,-10 ; 255,-100    255,-30     240,-2  ;  467,-95   467,-33   446,-1];
        straightDist;
        vectorPosition;% = [0, -100];%starting position to be updated if hardware on
        %branch number - tells what branch to move camera  to
        %branchNum = 1
        
        %obj.branchArray = [[xleft, xmiddle,xright, z]] this is for walls. the
        %vertices of where branch splits or turns
        branchArray = [1 2 3 4
                      1 2 3 4
                   457,466,475,-28];
        
        % resetNode - When resetNode is reached, re-start.
        resetNode = 3;
        
        yRotation = 90; %for rotating the camera for steering
        x_yRotation = 0;
        z_yRotation = 1;
        
        
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
        
        mGain = 5;
        
        mSpeed = 0;
        
         
        steeringPushfactor = 20;
        
        
        %% UI hadles
        % figureHandle - UI handle to control figure.
        figureHandle
       
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
        
        stimSize_h %which stimulus size to show. default: thick
        stimSize_string = 'Thick' %variable changed by stimSize_h handle. default: thick
        %%
        % nodes - Nodes object for controlling behavior.
        nodes
        
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
        
        csvDataTable %holds info from csv preset
        
%         %these all hold the value of where the x coordinate of the branch
%         %walls to the left or right side
%         left_leftwall %left branch
%         left_rightwall
%         right_leftwall %right branch
%         right_rightwall

        
        
    end
    
    properties (Constant)
        
        % fps - Frames per seconds for time integration; should match VR game.
        fps = 50
        
        % programVersion - Version of this class.
        programVersion = '20180525';
        
        
        hardware =2;%0:no hardware,  2:steeringOnly--------------------------------------------------------------------------
        
        csvFileName = 'C:\Users\anilv\Documents\GandhiLab\Github\tablet-vr\MATLAB\LinearMaze_presets\testPresets.csv'; %the preset file to set variables automatically
        
        
    end
    %%
    methods
        %% initialize function: LinearMaze('com', 'com5','monitors', {'192.168.0.111',0, '192.168.0.109',90,'192.168.0.110',-90,});
        function obj = LinearMaze(varargin)
            %   Controller for a liner-maze.
             %  offset1, ip2, offset2, ...}, ...)
            %   Provide the serial port name of the treadmill (rotary encoder, pinch valve,
            %   photo-sensor, and lick-sensors assumed connected to an Arduino microcontroller
            %   running a matching firmware).
            %LinearMaze('com', 'com5','monitors', {'192.168.0.111',0, '192.168.0.109',90,'192.168.0.110',-90,});
            %   Provide IP address of each monitor tablet and rotation offset for each camera.
            %commandwindow
            %varargin
            
            %obj.hardware = hardware
            
            
            keys = varargin(1:2:end);
            values = varargin(2:2:end);
            k = find(strcmpi(keys, 'com'), 1);
%              if isempty(k)
%                  obj.com = [];
%              else
%                 obj.com = 'com5'; %values{k};
%              end
           
            if obj.hardware == 0 %no hardware
                obj.com = [];
                obj.mSpeed = 25;
            elseif obj.hardware == 2%hardware on
                obj.com = 'com5';
            end
            
            
                
            
            k = find(strcmpi(keys, 'monitors'), 1);
            if isempty(k)
                monitors = {'127.0.0.1', 0};
            else
                monitors = values{k};
            end
            
            % Initialize network.
            obj.addresses = monitors(1:2:end);
            obj.offsets = [monitors{2:2:end}];
            obj.sender = UDPSender(32000);
            
            % Create a log file.
            folder = fullfile(getenv('USERPROFILE'), 'Documents', 'VR');
            session = sprintf('VR%s', datestr(now, 'yyyymmddHHMMSS'));
            obj.filename = fullfile(folder, sprintf('%s.csv', session));
            obj.fid = Files.open(obj.filename, 'a');
            
            % Remember version and session names.
            obj.startTime = tic;
            obj.className = mfilename('class');
            obj.print('maze-version,%s-%s', obj.className, LinearMaze.programVersion);
            obj.print('nodes-version,%s', Nodes.programVersion);
            obj.print('treadmill-version,%s', ArduinoTreadmill.programVersion);
            obj.print('filename,%s', obj.filename);
            
            % Show blank.
            obj.sender.send('enable,Blank,1;', obj.addresses);
            
            % Load an existing scene.
            obj.sender.send(sprintf('scene,%s;', obj.scene), obj.addresses);
            
            % Initialize treadmill controller.
            if isempty(obj.com)
                obj.treadmill = TreadmillInterface();
                obj.print('treadmill-version,%s', TreadmillInterface.programVersion);
            else
                obj.treadmill = ArduinoTreadmill('com5');
                obj.treadmill.bridge.register('ConnectionChanged', @obj.onBridge);
            end
            obj.treadmill.register('Frame', @obj.onFrame);
            obj.treadmill.register('Step', @obj.onStep);
            obj.treadmill.register('Tape', @obj.onTape);
            
            
            
            % Release resources when the figure is closed.
            obj.figureHandle = figure('Name', mfilename('Class'), 'MenuBar', 'none', 'NumberTitle', 'off','Position', [100, 100, 100, 100],'DeleteFcn', @(~, ~)obj.delete());
            h(1) = uicontrol('Style', 'PushButton', 'String', 'Stop',  'Callback', @(~, ~)obj.stop());
            h(2) = uicontrol('Style', 'PushButton', 'String', 'Start', 'Callback', @(~, ~)obj.start());
            h(3) = uicontrol('Style', 'PushButton', 'String', 'Reset', 'Callback', @(~, ~)obj.reset());
            
            h(4) = uicontrol('Style', 'PushButton', 'String', 'Log text above', 'Callback', @(~, ~)obj.onLogButton());
            %h(4) = uicontrol('Style', 'PushButton', 'String', 'choose Branch (1-number)', 'Callback', @(~, ~)obj.chooseBranch());
            h(5) = uicontrol('Style', 'Edit');
            
            h(6) = uicontrol('Style', 'popup',...
               'String', {'branch1', 'branch2','branch3'},...
               'Callback', @(~,~)obj.chooseBranch());
                         
            h(7) = uicontrol('Style', 'PushButton', 'String', 'SetSpeed above (default:25)', 'Callback', @(~, ~)obj.textSpeed());
            %h(4) = uicontrol('Style', 'PushButton', 'String', 'choose Branch (1-number)', 'Callback', @(~, ~)obj.chooseBranch());
            h(8) = uicontrol('Style', 'Edit');
                         
            h(9) = uicontrol('Style', 'popup',...
               'String', {'(DoesntWork)steering on', '(DoesntWork)tempMovieMode'},...
               'Callback', @(~,~)obj.tempMovie()); %broken dont use. may take out 
       
            h(10) = uicontrol('Style', 'popup',...
               'String', {'MovieMode: random', 'MovieMode: left','MovieMode: right'},'Callback', @(~,~)obj.ManualDirection()); 
            h(11) = uicontrol('Style', 'popup',...
               'String', {'steeringoff:4/4', 'steeringoff:3/4','steeringoff:2/4','steeringoff:1/4'},'Callback', @(~,~)obj.tempMovie()); 

            h(12) = uicontrol('Style', 'popup',...
               'String', {'GratingRandom', 'GratingLeft','GratingRight','GratingOff'},'Callback',@(~, ~)obj.ManualGratingSide()); 
           
            h(13) = uicontrol('Style', 'PushButton', 'String', 'Set Rotation above (default:0 deg)', 'Callback', @(~, ~)obj.textRotation());
            %h(4) = uicontrol('Style', 'PushButton', 'String', 'choose Branch (1-number)', 'Callback', @(~, ~)obj.chooseBranch());
            h(14) = uicontrol('Style', 'Edit');
           
            h(15) = uicontrol('Style', 'popup',...
               'String', {'Grating:Thick', 'Grating:Thin'},'Callback', @(~, ~)obj.stimThickness()); 
           
            p = get(h(1), 'Position');
            set(h, 'Position', [p(1:2), 4 * p(3), p(4)]);
            %set(h(8:14), 'Position', [300+p(1),p(2), 4 * p(3), p(4)]);
            align(h, 'Left', 'Fixed', 0.5 * p(1));
            %align(h(8:14), 'Right', 'Fixed', 0.5 * p(1));
            
            obj.textBox_h = h(5);
            obj.choosebranch_h = h(6);
            obj.textBox_speed_h = h(8);
            obj.tempMovieMode_h = h(9);
            obj.movieDirection_h = h(10);
            obj.choiceDistance_h = h(11);
            obj.straightDist = obj.vertices(:, 4)- obj.vertices(:,2 );
            obj.gratingSide_h = h(12);
            obj.textBox_stimRotation_h = h(14);
            obj.stimSize_h = h(15);
            
            set(obj.figureHandle, 'Position', [obj.figureHandle.Position(1), obj.figureHandle.Position(2), 4 * p(3) + 2 * p(1), 2 * numel(h) * p(4)])
            
            
            
%             if obj.hardware == 2 (I put this function in onUpdate)
%                 obj.scheduler.repeat(@obj.steeringPush, 1 / obj.fps);%if hardware then use steeringPush (maybe combine this with onUpdate)
%             end

            % Initialize nodes.
            obj.nodes = Nodes();
            obj.nodes.register('Change', @(position, distance, yaw, rotation)obj.onChange(position, distance, yaw));
            obj.nodes.register('Lap', @(lap)obj.onLap);
            obj.nodes.register('Node', @obj.onNode);

            obj.csvDataTable = readtable(obj.csvFileName, 'Format', '%f%f%f%f%f%f%f%f%f%f%f'); %read from preset csv file
            obj.updateFromCSV(); %update variables with csv file values
            
            obj.nodes.vertices = obj.vertices(obj.choosebranch_h.Value,:); %first update from csv then set the nodal path
            
            obj.vectorPosition = obj.vertices(obj.choosebranch_h.Value,1:2);%first update from csv set vector Position for steering wheel
            
            obj.scheduler = Scheduler();
            obj.scheduler.repeat(@obj.onUpdate, 1 / obj.fps);
            
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
        end
        
        %% these functions are for the GUI
        
        function updateFromCSV(obj)
            currentValues = obj.csvDataTable{obj.trial,:}; %Trial	BranchNum	stim(on/off)	Spacial Freq (stim)	orientation (stim)	Reward Side	side (movie mode)	steering type (movie/wheel)	speed	distance from split turn on steering ([1,2,3,4]/4)	logText
       
            set(obj.choosebranch_h, 'Value', currentValues(2)) %change branchNum
            %obj.chooseBranch() 
            
            set(obj.gratingSide_h, 'Value', currentValues(3)) %change stim side
           
            
            set(obj.stimSize_h, 'Value', currentValues(4)) %change stim thickness (spatial frequency)
            %obj.stimThickness() 
           
            set(obj.textBox_stimRotation_h, 'String', currentValues(5)) %change stim orientation
            %obj.textRotation()
            
            set(obj.movieDirection_h, 'Value', currentValues(6)) %change moviemode direction
            
            
            set(obj.textBox_speed_h, 'String', currentValues(8)) %change stim orientation
            %obj.textSpeed() 
            
            set(obj.choiceDistance_h, 'Value', currentValues(9)) %change distance from split turn on steering ([1, 2, 3, 4]/4)
            
        end
       
        function chooseBranch(obj)
            % This function overwrites the csvfile data table when a manual input is entered
            obj.csvDataTable{obj.trial+1:end,2} = obj.choosebranch_h.Value; %index is the 2nd column. overwrite branchNum data with this branchNum

        end
        
        function ManualGratingSide(obj)
             obj.csvDataTable{obj.trial+1:end,3} = obj.gratingSide_h.Value; %index is the 3th column.

        end
        
        function stimThickness(obj)
            % This function overwrites csvdatatable with manual input for Next trial's preset stim spatial freq

            obj.csvDataTable{obj.trial+1:end,4} = obj.stimSize_h.Value; %index is the 4nd column.
        end
        
        function textRotation(obj)
           % This function overwrites csvdatatable with manual input for Next trial's preset stim orientation

            obj.csvDataTable{obj.trial+1:end,5} = str2double(obj.textBox_stimRotation_h.String); %index is the 5th column.

        end
        
        function ManualDirection(obj)
                obj.csvDataTable{obj.trial+1:end,6} = obj.movieDirection_h.Value;%index is the 6nd column.
    
        end
        
        function textSpeed(obj)
           % This function overwrites csvdatatable with manual input for Next trials' preset speed
            %obj.csvDataTable
            obj.csvDataTable{obj.trial:end,8} = str2double(obj.textBox_speed_h.String);%index is the 8nd column.
            
            %obj.csvDataTable
        end
        
        function ManualChoiceDistance(obj)
             obj.csvDataTable{obj.trial+1:end,9} = obj.choiceDistance_h.Value; %index is the 9nd column.
        end
        
        
        function reset(obj)
            % LinearMaze.reset()
            % Reset trial, position, rotation, frame count and encoder steps.
            
            obj.trial = 1;
            if obj.hardware == 0
                obj.nodes.vertices = obj.vertices(obj.choosebranch_h.Value,:);
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
            obj.enabled = false;
            obj.treadmill.trigger = false;
            obj.sender.send('enable,Blank,1;', obj.addresses);
            %obj.sender.send('enable,Mouse,1;', obj.addresses); %this is how
            %to turn off and on (0 or 1 respectively) objects in Main 
            
            obj.print('note,stop');
        end
        
        %%
        function blank(obj, duration)
            % LinearMaze.pause(duration)
            % Show blank for a given duration.
            
            %duration = 0; %hardcode blank to be zero
            
            Objects.delete(obj.blankId);
            if duration == 0
                obj.sender.send('enable,Blank,0;', obj.addresses);
            elseif duration > 0
                obj.sender.send('enable,Blank,1;', obj.addresses);
                obj.blankId = obj.scheduler.delay({@obj.blank, 0}, duration);
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
            if ~isempty(obj.textBox_speed_h.String)
                 if obj.hardware == 0%movie
                    obj.mSpeed = str2double(obj.textBox_speed_h.String);
                    %obj.mSpeed = obj.csvDataTable{obj.trial,8};
                 %else%steering - gets handled in onupdate
                 %   obj.steeringPushfactor = str2double(obj.textBox_speed.String);
                 end
                 
                %obj.textBox_speed.String = '';
            end
            speed = obj.mSpeed;
        end
        
        
        
%         function MovieModeDirection(obj)
% %             if obj.movieDirection_h.Value == 1 %random
% %                 obj.movieDirection = 0;
% %             elseif obj.movieDirection_h.Value == 2 %left 
% %                 obj.movieDirection = 1;
% %             else
% %                 obj.movieDirection = 2;%right
% %             end
%             
%         end
        
        
        
        function delete(obj)
            % LinearMaze.delete()
            % Release all resources.
            
            obj.treadmill.trigger = false;
            delete(obj.treadmill);
            delete(obj.scheduler);
            delete(obj.nodes);
            delete(obj.sender);
            obj.log('note,delete');
            fclose(obj.fid);
            LinearMaze.export(obj.filename);
            if ishandle(obj.figureHandle)
                set(obj.figureHandle, 'DeleteFcn', []);
                delete(obj.figureHandle);
            end
        end
        
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
        
%         function tempMovie(obj)
%            % if ~isempty(obj.com)
%                 if obj.tempMovieMode.Value == 1
%                     obj.enabled = true;
% %                     obj.hardware = 2;
% %                     obj.mSpeed = 0;
% %                     
%                  obj.treadmill = ArduinoTreadmill('com5');
%                  obj.treadmill.bridge.register('ConnectionChanged', @obj.onBridge);
%            
%                 else
%                     obj.enabled = false;
% %                     obj.hardware = 0;
% %                     obj.mSpeed = 25;
% %                     
%                  obj.treadmill = TreadmillInterface();
% %                 
%                 end
%         end
           % end
        
                    
        
        function print(obj, format, varargin)
            % LinearMaze.print(format, arg1, arg2, ...)
            % Print on screen and create a log entry using the same syntax as sprintf.
            
            fprintf('[%.1f] %s\n', toc(obj.startTime), sprintf(format, varargin{:}));
            obj.log(format, varargin{:});
        end
        
        
    end
   
    methods (Access = private)
        %%
        function newTrial(obj)
            % LinearMaze.newTrial()
            % Send a reward pulse, play a tone, log data, pause.
            
            %this is how to change and update a popupmenu in GUI:
%             set(obj.choosebranch_h, 'Value', 2)
%             obj.chooseBranch()

            obj.trial = obj.trial + 1;
            
            obj.updateFromCSV() %update input values from csv file


            
            %if movie mode, and random then switch the final node randomly
            %left or right
            if obj.hardware == 0  %if not using steering 
                rand = obj.movieDirection_h.Value;
                if rand == 1
                    rand = randi([2 3]); %round(rand)+2%2 or 3
                end
                obj.nodes.vertices = obj.vertices(obj.choosebranch_h.Value,:);
                if obj.choosebranch_h.Value == 1
  
                    if rand == 2 %go left
                        obj.nodes.vertices(end-1) = -35;
                    elseif rand ==3 %go right
                       obj.nodes.vertices(end-1) = 35;
                    end
                    
                elseif obj.choosebranch_h.Value == 2
                    
                    
                    if rand == 2 %go left
                        obj.nodes.vertices(end-1) = 240;
                    elseif rand ==3%go right
                       obj.nodes.vertices(end-1) = 270;
                    end
                elseif obj.choosebranch_h.Value == 3
                    
                    
                    if rand == 2 %go left
                        obj.nodes.vertices(end-1) = 446;
                    elseif rand ==3 %go right
                       obj.nodes.vertices(end-1) = 488;
                    end
                end
                    
            
            
            elseif obj.hardware == 2
                
                obj.vectorPosition = obj.vertices(obj.choosebranch_h.Value,1:2);
                obj.yRotation = 90; %reset rotation on new trial
                obj.z_yRotation = 1;
                obj.x_yRotation = 0;
                
                %obj.sender.send(sprintf('rotation,Main Camera,0,%.2f,0;', obj.yRotation-90), obj.addresses);
                obj.sender.send(Tools.compose([sprintf(...
                'position,Main Camera,%.2f,1,%.2f;', obj.vectorPosition(1), obj.vectorPosition(2)), ...
                'rotation,Main Camera,0,%.2f,0;'], obj.yRotation-90 + obj.offsets), ...
                obj.addresses);
            end
            
            
            
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
            
            
            if obj.stimSize_h.Value == 1 %thick
                obj.stimSize_string = 'Thick';
            else %thin
                obj.stimSize_string = 'Thin';
            end
            
            obj.stimRot = str2double(obj.textBox_stimRotation_h.String)+90;
             %set rotation of current branches stimuli
             obj.sender.send(sprintf(strcat('rotation,Branch', num2str(obj.choosebranch_h.Value) ,'RightGrating',obj.stimSize_string,',%.2f,-50,90;'), obj.stimRot),obj.addresses);
             obj.sender.send(sprintf(strcat('rotation,Branch', num2str(obj.choosebranch_h.Value) ,'LeftGrating',obj.stimSize_string,',%.2f,50,90;'), obj.stimRot),obj.addresses);
             
            %set the stimulus
            side = obj.gratingSide_h.Value;
            if side == 1 %random
                side = randi([2 3]);
            end
            
            if side == 2 %left
                obj.sender.send(strcat('enable,Branch', num2str(obj.choosebranch_h.Value) ,'LeftGrating', obj.stimSize_string ,',1;'), obj.addresses);
                obj.sender.send(strcat('enable,Branch', num2str(obj.choosebranch_h.Value) ,'RightGray,1;'), obj.addresses);
            elseif side == 3%right
                obj.sender.send(strcat('enable,Branch', num2str(obj.choosebranch_h.Value) ,'RightGrating',obj.stimSize_string,',1;'), obj.addresses);
                obj.sender.send(strcat('enable,Branch', num2str(obj.choosebranch_h.Value) ,'LeftGray,1;'), obj.addresses);
            
            end
            
             
            
                
            
            obj.treadmill.reward(obj.rewardDuration);
            %Tools.tone(obj.rewardTone(1), obj.rewardTone(2)); This makes a reward tone
            
            % Disable movement and show blank screen for the given duration.
            if obj.intertrialBehavior
                obj.blank(obj.intertrialDuration);
            else
                obj.pause(obj.intertrialDuration);
            end
            obj.log('data,%i,%i,%.2f,%.2f,%.2f,%.2f', obj.treadmill.frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2));
            
            obj.print('trial,%i', obj.trial);
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
                obj.log('data,%i,%i,%.2f,%.2f,%.2f,%.2f', obj.treadmill.frame, obj.treadmill.step, distance, yaw, position(1), position(2));
            end
        end
        
        function onFrame(obj, frame)
            % LinearMaze.onFrame(frame)
            % The trigger input changed from low to high.
            % Create an entry in the log file if logOnFrame == true.
            
            % Log changes including frame count and rotary encoder changes.
            if obj.logOnFrame
                obj.log('data,%i,%i,%.2f,%.2f,%.2f,%.2f', frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2));
            end
            
            % Change the name to reflect frame number.
            set(obj.figureHandle, 'Name', sprintf('%s - Frame: %i', mfilename('Class'), frame));
        end
        
        function onLap(obj)
            % LinearMaze.onLap()
            % Ran thru all nodes, disable motion during the intertrial.
            
            obj.newTrial();
        end
        
        function onLogButton(obj)
            % LinearMaze.onLogButton()
            % Log user text.
            
            if ~isempty(obj.textBox_h.String)
                obj.print('note,%s', obj.textBox_h.String);
                obj.textBox_h.String = '';
            end
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
                obj.nodes.vertices = obj.vertices;
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
            if obj.enabled && obj.vectorPosition(2) > (5-obj.choiceDistance_h.Value)/4 * obj.straightDist(obj.choosebranch_h.Value) + obj.vertices(obj.choosebranch_h.Value,2)
               %disp('o')
                obj.yRotation = obj.yRotation + step * obj.gain; %the yRotation is updated each time this function is called
                
                if obj.yRotation >= 180
                    obj.yRotation = 180;
                elseif obj.yRotation <= 0
                    obj.yRotation = 0;
                end
                
                obj.x_yRotation = cosd(obj.yRotation);
                obj.z_yRotation = sind(obj.yRotation);
          
%                 obj.sender.send(sprintf('position,Main Camera,%.2f,1,%.2f;', obj.vectorPosition(1), obj.vectorPosition(1,2), ...
%                 'rotation,Main Camera,0,%.2f,0;',obj.yRotation))
                
                %obj.sender.send(sprintf('rotation,Main Camera,0,%.2f,0;', obj.yRotation-90), obj.addresses);
                obj.sender.send(Tools.compose([sprintf(...
                'position,Main Camera,%.2f,1,%.2f;', obj.vectorPosition(1), obj.vectorPosition(2)), ...
                'rotation,Main Camera,0,%.2f,0;'], obj.yRotation-90 + obj.offsets), ...
                obj.addresses);
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
            
            
                
                if obj.speed ~= 0 && obj.enabled && ~obj.nodes.rotating
                    % Open-loop updates position when open-loop speed is different 0.
                    obj.nodes.push(obj.speed / obj.nodes.fps);
                elseif obj.hardware == 2 && obj.enabled %hardware on, obj enabled
                     
                    obj.sender.send(sprintf(...
                    'position,Main Camera,%.2f,1,%.2f;', obj.vectorPosition(1), obj.vectorPosition(2)), ...
                    obj.addresses);
                
                    if ~isempty(obj.textBox_speed_h.String)
                        obj.steeringPushfactor = obj.csvDataTable{obj.trial,8} * .05;%str2double(obj.textBox_speed_h.String)*.05;%steering factor based off speed textbox and random 0.05 number
                    else
                        obj.steeringPushfactor = 1.25; %= 25*.05. This is the default push factor if nothing is put in the text box
                    end
                    
                    obj.vectorPosition(1) = obj.vectorPosition(1) - (obj.x_yRotation*obj.steeringPushfactor);
                    obj.vectorPosition(2) = obj.vectorPosition(2) + (obj.z_yRotation*obj.steeringPushfactor);
                
                    
                    %not tested on hardware. only works on branch 3
                    %----------------------------------------------------------------------------
                    
                             
                    if obj.vectorPosition(2)< obj.branchArray(obj.choosebranch_h.Value,4)%-28 %on straight path
                        %bound x by [457, 475]
                        if obj.vectorPosition(1) < obj.branchArray(obj.choosebranch_h.Value,1) %457 too far left
                            obj.vectorPosition(1) = 457;
                        elseif obj.vectorPosition(1) > obj.branchArray(obj.choosebranch_h.Value,3) %475 %too far right
                            obj.vectorPosition(1) = 475;
                        end
                        
                            
                    elseif obj.vectorPosition(2) > obj.branchArray(obj.choosebranch_h.Value,4)%-28
                        %bound x by function of z
                        if obj.vectorPosition(1) < obj.branchArray(obj.choosebranch_h.Value,2)%466 %left path
                            if obj.vectorPosition(1) < obj.left_leftwall(obj.vectorPosition(2),obj.choosebranch_h.Value) %too far left
                                obj.vectorPosition(1) = obj.left_leftwall(obj.vectorPosition(2),obj.choosebranch_h.Value);%function of z
                            elseif obj.vectorPosition(1) > obj.left_rightwall(obj.vectorPosition(2),obj.choosebranch_h.Value) %too far right
                                obj.vectorPosition(1) = obj.left_rightwall(obj.vectorPosition(2),obj.choosebranch_h.Value); %function of z
                            end
                        elseif obj.vectorPosition(1) > obj.branchArray(obj.choosebranch_h.Value,2)%466 %right path
                            if obj.vectorPosition(1) < obj.right_leftwall(obj.vectorPosition(2),obj.choosebranch_h.Value) %too far left
                                obj.vectorPosition(1) = obj.right_leftwall(obj.vectorPosition(2),obj.choosebranch_h.Value);%function of z
                            elseif obj.vectorPosition(1) > obj.right_rightwall(obj.vectorPosition(2),obj.choosebranch_h.Value) %too far right
                                obj.vectorPosition(1) = obj.right_rightwall(obj.vectorPosition(2),obj.choosebranch_h.Value); %function of z
                            end
                        end
                    end
                    %---------------------------------------------------------------------------------
                        
                 end
                
             %obj.vectorPosition
%             obj.vertices(obj.choosebranch_h.Value,end)
             if obj.vectorPosition(2) > obj.vertices(obj.choosebranch_h.Value,end) %get to reset node: then reset camera position
                    %obj.vectorPosition(1:2) = obj.vertices(1:2); 
                    obj.newTrial();
             end  
             
%             obj.treadmill.frame
%             obj.treadmill.step
%             %obj.nodes.distance
%             obj.nodes.yaw
%             obj.nodes.position(1)
%             obj.nodes.position(2)
            
            if obj.logOnUpdate
                str = sprintf('data,%i,%i,%.2f,%.2f,%.2f,%.2f', obj.treadmill.frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2));
                if ~strcmp(str, obj.update)
                    obj.update = str;
                    obj.log(str);
                end
                
            end
            
        end
        
        
        
        
    end
    %% Walls and export log file
    methods (Static)
        function x = left_leftwall(z,branch)
            %left side of left branch
           if branch == 3 %branch 3
            x = z/(-1.75)  +  441;
           elseif branch == 2 %branch 2 
                
           elseif branch == 1 %branch 3
                
           end
        end
        
        function x = left_rightwall(z,branch)
            %right side of left branch
            
           if branch == 3 %branch 3
            x = z/(-1.75) + 450;
           elseif branch == 2 %branch 2 
                
           elseif branch == 1 %branch 3
                
           end
        end
        
        function x = right_leftwall(z, branch)
            %left side of right branch
            
           if branch == 3 %branch 3
            x = z/1.647 + 483;
           elseif branch == 2 %branch 2 
                
           elseif branch == 1 %branch 3
                
           end
        end
        
        function x = right_rightwall(z, branch)
            %right side of right branch
            
           if branch == 3 %branch 3
            x = z/1.556 + 493;
           elseif branch == 2 %branch 2 
                
           elseif branch == 1 %branch 3
                
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
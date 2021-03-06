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

    %% monitors,{192.168.0.100;0;192.168.0.103;-90;192.168.0.104;90},hardware,2,com,com4, stage,stage3

    
    properties
        % properties of the class
        trialNumberFactor = 0; %this factor is incremented whenever the end of the preset file is reached
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
        rewardDuration =0.1*3/4;%15;
        
        airpuffDuration = 0.05;
        
        % rewardTone - Frequency and duration of the tone during a reward.

        rewardTone = [1000, 0.5];
        
        %errorTone - played when mouse makes a mistake
        errorTone = [2000, 1];

        startTone = [500, .3];
        
         pauseInput = [500, .7];
        % tapeTrigger - Whether to initiate a new trial when photosensor
        % detects a tape strip in the belt.
        tapeTrigger = false;
        
        % treadmill - Arduino controlled apparatus.
        treadmill
        
        timeout = 30; %seconds until the stage3 trial is auto timedout
        
        stage3BlockArray = [];
    end
    
    properties (SetAccess = private)
        
        % filename - Name of the log file. - time based
        filename
        
        
        stopDuringBlank; %this makes sure that obj is disabled and blank is not turned of during intertrial, if stop(obj) is called
        
        %name of log file - trial based
        filename_trial
        
        % scene - Name of an existing scene.
        scene = 'linearMaze_v3';
		
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
                   457.5,467,477,-28];
        
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
        
        mGain =7; %1 - 90deg for stage 2
        
        mSpeed = 5;
        
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
        
        
        rewardInterval = 20 %for stage1. this is the interval for rewards to be dispensed
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
        
        mouseName
        
        
        
        stage
        
        stage2GainInterval = 10;
        
        stage3Record =0;%first number is number of trials, second number is number of errors 
        
        Stage3RecordList
        
        dateCreated
        
        stage3Array = [1,1, 35,155];%[errorYet(0no/1yes) , stim side(0left/1right) , incorrectSide, correctSide ]
        
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
        
        function obj = LinearMaze(app,varargin)
            %   Controller for a liner-maze.
             %  offset1, ip2, offset2, ...}, ...)
            %   Provide the serial port name of the treadmill (rotary encoder, pinch valve,
            %   photo-sensor, and lick-sensors assumed connected to an Arduino microcontroller
            %   running a matching firmware).
            %
            %   Provide IP address of each monitor tablet and rotation offset for each camera.
            
            %monitors,{192.168.0.100;0},hardware,2,com,com4, stage,stage3
            %monitors,{192.168.0.100;0;192.168.0.103;-90;192.168.0.104;90},hardware,2,com,com4, stage,stage3
            
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
            obj.mouseName = [obj.newGUI_figurehandle.EnterMouseNameEditField.Value,'_gain',num2str(obj.mGain), '_session',num2str(obj.newGUI_figurehandle.SessionNumberDropDown.Value)];
            
            k = find(strcmpi(keys, 'stage'), 1);
            try
                obj.stage = values{k};
            catch
                obj.stage = nan;
            end
 
            % Create a log file. Time based
            obj.dateCreated = datestr(now, 'yyyymmddHHMM');
            folder = fullfile(getenv('USERPROFILE'), 'Documents', 'VR_TimeBased');
            session = sprintf([obj.mouseName,'_VR_TimeBased_%s_%s'], obj.stage, obj.dateCreated);
            session = [session(1:end-8),'-',session(end-7:end-6),'-',session(end-5:end-4),'_',session(end-3:end)];
            obj.filename = fullfile(folder, sprintf('%s.csv', session));
            obj.fid = Files.open(obj.filename, 'a');
            
            % Create a log file. Trial based
            folder = fullfile(getenv('USERPROFILE'), 'Documents', 'VR_TrialBased');
            session = sprintf([obj.mouseName,'_VR_TrialBased_%s'], obj.dateCreated);
            session = [session(1:end-8),'-',session(end-7:end-6),'-',session(end-5:end-4),'_',session(end-3:end)];
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
            %obj.treadmill.register('Frame', @obj.onFrame);
            
            k = find(strcmpi(keys, 'stage'), 1);
            try
                obj.stage = values{k};
            catch
                obj.stage = nan;
            end
            switch obj.stage
                case 'stage1'
                case 'stage2'
                    obj.treadmill.register('Step', @obj.stage2);
                case 'stage3'
                    obj.treadmill.register('Step', @obj.stage3);
                    
                    obj.sender.send(Tools.compose([sprintf(...
                        'position,Main Camera,%.2f,6,%.2f;', 467, -30), ...
                        'rotation,Main Camera,0,%.2f,0;'], obj.yRotation-90 + obj.offsets), ...
                        obj.addresses);
                otherwise
                    obj.treadmill.register('Step', @obj.onStep);
            end
            %obj.treadmill.register('Tape', @obj.onTape);
            obj.treadmill.register('touchPad', @obj.touchPad);
            
            obj.treadmill.register('laserPin', @obj.laserPin);
                       

            obj.straightDist = obj.vertices(:, 4)- obj.vertices(:,2 );

            % Initialize nodes.
            obj.nodes = Nodes();
            %obj.nodes.register('Change', @(position, distance, yaw, rotation)obj.onChange(position, distance, yaw));
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
                obj.vectorPosition = obj.vertices(obj.currentBranch,1:2);%first update from csv set vector Position for steering wheel
            else
                obj.vectorPosition = obj.vertices(obj.currentBranch,1:2);%first update from csv set vector Position for steering wheel
            end

            obj.setNodes_movieMode(); %set a nodal path even with hardware on  
            obj.scheduler = Scheduler();
            
            obj.setStimulus();%put the stimulus in place with correct rotation
            
            
            
            switch obj.stage
                case 'stage1'
                    obj.sender.send('enable,Blank,1;', obj.addresses);
                    obj.scheduler.repeat(@obj.stage1,1 / obj.fps);
                    
                case 'stage2'
                    obj.sender.send('enable,Blank,1;', obj.addresses);
                case 'stage3'
                    
                    obj.scheduler.repeat(@obj.stage3Timer,1);
                    
                    obj.sender.send('enable,CombinedMesh-MeshBaker-MeshBaker-mesh,0;', obj.addresses);
                    
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
                    obj.sender.send('enable,Branch3RightGratingThick,1;', obj.addresses);
                    %turn off all gray cylinders
                    obj.sender.send('enable,Branch1LeftGray,0;', obj.addresses);
                    obj.sender.send('enable,Branch1RightGray,0;', obj.addresses);
                    obj.sender.send('enable,Branch2LeftGray,0;', obj.addresses);
                    obj.sender.send('enable,Branch2RightGray,0;', obj.addresses);
                    obj.sender.send('enable,Branch3LeftGray,0;', obj.addresses);
                    obj.sender.send('enable,Branch3RightGray,0;', obj.addresses);
                    %turn of stage3 Stim
                    obj.sender.send('enable,Branch3Left_stage3,0;', obj.addresses);
                    obj.sender.send('enable,Branch3Right_stage3,0;', obj.addresses);
                    
                    obj.sender.send('enable,Branch3LeftGratingHighFreq,1;', obj.addresses);
                    obj.sender.send('enable,Branch3RightGratingHighFreq,0;', obj.addresses);
                    
                     
                    
                    %move all stimuli to desired angle from midline
                    Midangle = 90
                    obj.moveStimAngle(Midangle)
                    
                    
                otherwise
                    obj.sender.send('enable,CombinedMesh-MeshBaker-MeshBaker-mesh,1;', obj.addresses);
                    obj.scheduler.repeat(@obj.onUpdate, 1 / obj.fps);
            end
            
            
                
        end
        
        function moveStimAngle(obj, angle)
           
            r = 40;
            x = r*sind(angle) +467;
            y = r*cosd(angle) -30;
         
            
%             obj.sender.send(Tools.compose([sprintf(...
%                         'position,Branch3Right_stage3,%.2f,6,%.2f;', x,y), ...
%                         'rotation,Branch3Right_stage3,90,%.2f,0;'], angle ), ...
%                         obj.addresses);
%         
%             x = -r*sind(angle) +467;
%             
%             obj.sender.send(Tools.compose([sprintf(...
%                         'position,Branch3Left_stage3,%.2f,6,%.2f;', x,y), ...
%                         'rotation,Branch3Left_stage3,90,%.2f,0;'], -angle ), ...
%                         obj.addresses);

%this is for setting gratings stim thick instead of blinking stim
                obj.sender.send(Tools.compose([sprintf(...
                    'position,Branch3RightGratingThick,%.2f,6,%.2f;', x,y), ...
                    'rotation,Branch3RightGratingThick,90,%.2f,0;'], angle ), ...
                    obj.addresses);
                
                obj.sender.send(Tools.compose([sprintf(...
                    'position,Branch3RightGray,%.2f,6,%.2f;', x,y), ...
                    'rotation,Branch3RightGray,90,%.2f,0;'], angle ), ...
                    obj.addresses);

                obj.sender.send(Tools.compose([sprintf(...
                    'position,Branch3RightGratingHighFreq,%.2f,6,%.2f;', x,y), ...
                    'rotation,Branch3RightGratingHighFreq,90,%.2f,0;'], angle ), ...
                    obj.addresses);
                
                x = -r*sind(angle) +467;

                obj.sender.send(Tools.compose([sprintf(...
                    'position,Branch3LeftGratingThick,%.2f,6,%.2f;', x,y), ...
                    'rotation,Branch3LeftGratingThick,90,%.2f,0;'], -angle ), ...
                    obj.addresses);
                
                obj.sender.send(Tools.compose([sprintf(...
                    'position,Branch3LeftGray,%.2f,6,%.2f;', x,y), ...
                    'rotation,Branch3LeftGray,90,%.2f,0;'], -angle ), ...
                    obj.addresses);
                
                obj.sender.send(Tools.compose([sprintf(...
                    'position,Branch3LeftGratingHighFreq,%.2f,6,%.2f;', x,y), ...
                    'rotation,Branch3LeftGratingHighFreq,90,%.2f,0;'], -angle ), ...
                    obj.addresses);
                
                
                        
        end
        
        
        function stage1(obj)
            %turn on blank screen
            %give water every 30 sec
            obj.sender.send('enable,Blank,1;', obj.addresses);
            if obj.enabled
                if toc(obj.startTime)>obj.rewardInterval
                obj.rewardInterval = obj.rewardInterval + 20;%add twenty seconds for next reward    
                obj.treadmill.reward(obj.rewardDuration);
                'reward_stage1'
                obj.log('note,reward');
                end
                if obj.logOnUpdate
                     str = sprintf('data,%i,%i,%i,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f, %i,%i,%i,%i', obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),obj.treadmill.frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2),obj.vectorPosition(1),obj.vectorPosition(2),obj.speed,obj.steeringPushfactor ,obj.currentBranch,obj.rewardInterval);
                     if ~strcmp(str, obj.update)
                         obj.update = str;
                         obj.log(str);
                     end
                     
                 end
            end
        end
        
        function stage2(obj, step)
            %blank screen
            
            %turn wheel some degrees to recieve water
             if obj.enabled
                 if obj.trial >  obj.stage2GainInterval & obj.gain > 1.5
                     obj.gain = obj.gain-.5
                      obj.stage2GainInterval =obj.stage2GainInterval +10;
                 end
        
                 obj.yRotation = obj.yRotation + step * obj.gain;
                 
                 if obj.yRotation < 70 || obj.yRotation > 110
                     
                     obj.treadmill.reward(obj.rewardDuration);
                     'reward_stage2'
                     obj.log('note,reward_stage2');
                     obj.yRotation = 90;
                     obj.blank(obj.intertrialDuration);
                     obj.trial = obj.trial + 1;
                     
                     obj.newGUI_figurehandle.trialNumberLabel.Text = num2str(obj.trial);
                   
                 end
                 
                 if obj.logOnUpdate
                     str = sprintf('data,%i,%i,%i,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f, %i,%i,%i,%i,%i', obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),obj.treadmill.frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2),obj.vectorPosition(1),obj.vectorPosition(2),obj.speed,obj.steeringPushfactor ,obj.currentBranch,obj.gain,obj.rewardInterval);
                     if ~strcmp(str, obj.update)
                         obj.update = str;
                         obj.log(str);
                     end
                     
                 end
             end

        end
        
        function stage3Timer(obj)
            if toc(obj.startTime) > obj.timeout && obj.enabled %30 seconds passed
               %end trial with error 
                obj.errorStage3() %error 
                
            elseif ~obj.enabled 
                obj.timeout = toc(obj.startTime)+30;%error side
                
            end
        end
        function stage3(obj,step) 
            %take input from encoder and rotate camera in front of the
            %decision point. if it exceeds error angle, play error tone. if
            %it exceeds correct side, give water, reset trial.
            if obj.enabled
               
                
                
                
                
                obj.yRotation = obj.yRotation + step * obj.gain;
                
                if obj.yRotation > 155
                    obj.yRotation = 155;
                elseif obj.yRotation < 35
                    obj.yRotation = 35;
                end
                
                obj.sender.send(Tools.compose([sprintf(...
                        'position,Main Camera,%.2f,6,%.2f;', 467, -30), ...
                        'rotation,Main Camera,0,%.2f,0;'], obj.yRotation-90 + obj.offsets), ...
                        obj.addresses);
                    
%                 disp(toc(obj.startTime))
%                 disp(obj.timeout)
                    
                if obj.yRotation == obj.stage3Array(3) && obj.stage3Array(1) 
                    obj.errorStage3() %error side chosen
                elseif obj.yRotation == obj.stage3Array(4) %correct side chosen
                    obj.timeout = toc(obj.startTime)+30;
                    obj.Stage3RecordList(obj.trial) = 1;
                    obj.stage3_newTrial()
                    
                    obj.stage3BlockArray(length(obj.stage3BlockArray)+1)= 1;
                    disp(obj.stage3BlockArray)
                end
            end
       
            
             if obj.logOnUpdate
                     str = sprintf('data,%i,%i,%i,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f, %i,%i,%i,%i', obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),obj.treadmill.frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2),obj.vectorPosition(1),obj.vectorPosition(2),obj.speed,obj.steeringPushfactor ,obj.currentBranch,obj.gain);
                     if ~strcmp(str, obj.update)
                         obj.update = str;
                         obj.log(str);
                     end
                     
             end
      
             
        end
        function errorStage3(obj)
            
                    obj.timeout = toc(obj.startTime)+30;%error side
                    %play error tone
                   
                    
                    obj.stage3Record = obj.stage3Record + 1; %keep record of errors for log file
                    obj.Stage3RecordList(obj.trial) = 0;%error
                    %disp(obj.Stage3RecordList)
                    
                    obj.stage3Array(1) = 0;
                    %obj.blank(obj.intertrialDuration);
                    obj.stage3_newTrial()
            
        end
       
        function stage3_newTrial(obj)
         
                 
            if obj.stage3Array(1) ~= 0 %trial was correct
                Tools.tone(300,1); %reward tone
                %pause(3); %pause for 3 seconds looking at blinking stim
                
                 obj.treadmill.reward(obj.rewardDuration);
                 'reward'
                 obj.log('note,reward');
                 obj.blank(obj.intertrialDuration);
                 obj.choiceArray(obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),2) = 1; %correct side chosen
            else
                obj.treadmill.airpuff(obj.airpuffDuration);
                Tools.tone(obj.errorTone(1), obj.errorTone(2)); %incorrect
                 
                %pause(2)
                obj.blank(obj.intertrialDuration+2);
                pause(1)
                
                obj.choiceArray(obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),2) = 0; %incorrect side chosen
            end
            obj.trial = obj.trial + 1;
            obj.newGUI_figurehandle.trialNumberLabel.Text = num2str(obj.trial);
            
            obj.MouseGraph(); %update the mouseGraph in GUI
            
            right = 35;
            if obj.stage3Array(3) == right %right
                side = 'right';
            else
                side = 'left';
            end
            
            obj.log_trial('trial: %i. errors so far: %i. error/trial = %f. side: %s', obj.trial, obj.stage3Record,obj.stage3Record/obj.trial,side);
            
            try
               obj.Stage3RecordList(end-10:end)
                last10TrialsRatio = sum(obj.Stage3RecordList(end-10:end))/10; %ratio from 0 to 1 that show how accurate over last 10 trials
            catch
                last10TrialsRatio = 1;
            end
            
                if obj.trial >  obj.stage2GainInterval & obj.gain > 1.5 & last10TrialsRatio <= 0.5
                     obj.gain = obj.gain-.5
                     obj.stage2GainInterval =obj.stage2GainInterval +10;
                %elseif obj.trial >  obj.stage2GainInterval & obj.gain > 1.5 & last10TrialsRatio > 0.5
%                     obj.gain = obj.gain+.5
%                     obj.stage2GainInterval =obj.stage2GainInterval +10;
                end
             
            %blank screen
%             if obj.intertrialBehavior
%                 obj.blank(obj.intertrialDuration);
%             else
%                 obj.pause(obj.intertrialDuration);
%             end
            
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
            
            obj.sender.send('enable,Branch3Left_stage3,0;', obj.addresses);
            obj.sender.send('enable,Branch3Right_stage3,0;', obj.addresses);
            
            obj.sender.send('enable,Branch3RightGratingHighFreq,0;', obj.addresses);
            obj.sender.send('enable,Branch3LeftGratingHighFreq,0;', obj.addresses);
       % obj.sender.send('enable,Floor,1;', obj.addresses);
        
           
            
            obj.stage3_setStim()
            obj.stage3Array(1) = 1;
            
            obj.yRotation = 90;
            obj.sender.send(Tools.compose([sprintf(...
                        'position,Main Camera,%.2f,6,%.2f;', 467, -30), ...
                        'rotation,Main Camera,0,%.2f,0;'], obj.yRotation-90 + obj.offsets), ...
                        obj.addresses);
                    
            
        end
        
        function stage3_setStim(obj)
            right = 155;
            left = 35;
            
            if obj.stage3Array(3) == right %right
                side = 'right';
            else
                side = 'left';
            end
            if 0 %random stimulus
                
                if rand<.5%left
%                      obj.sender.send('enable,Branch3LeftGray,0;', obj.addresses);
%                      obj.sender.send('enable,Branch3RightGray,1;', obj.addresses);

%                     obj.sender.send('enable,Branch3LeftGray,1;', obj.addresses);
%                     obj.sender.send('enable,Branch3RightGray,0;', obj.addresses);
                     obj.sender.send('enable,Branch3LeftGratingHighFreq,0;', obj.addresses);
                     obj.sender.send('enable,Branch3RightGratingHighFreq,1;', obj.addresses);



%                     obj.sender.send('enable,Branch3Left_stage3,0;', obj.addresses);
%                     obj.sender.send('enable,Branch3Right_stage3,1;', obj.addresses);
                    obj.sender.send('enable,Branch3LeftGratingThick,1;', obj.addresses);
                    obj.sender.send('enable,Branch3RightGratingThick,0;', obj.addresses);


                     obj.stage3Array(3:4) = [right,left];
                 else %right
%                     obj.sender.send('enable,Branch3LeftGray,1;', obj.addresses);
%                     obj.sender.send('enable,Branch3RightGray,0;', obj.addresses);
                     obj.sender.send('enable,Branch3LeftGratingHighFreq,1;', obj.addresses);
                     obj.sender.send('enable,Branch3RightGratingHighFreq,0;', obj.addresses);



%                     obj.sender.send('enable,Branch3Left_stage3,0;', obj.addresses);
%                     obj.sender.send('enable,Branch3Right_stage3,1;', obj.addresses);
                    obj.sender.send('enable,Branch3LeftGratingThick,0;', obj.addresses);
                    obj.sender.send('enable,Branch3RightGratingThick,1;', obj.addresses);



                    obj.stage3Array(3:4) = [left,right];
                 end
                
                
                
            elseif 1%blocks method stimulus
                %disp(sum(obj.stage3BlockArray))
                if sum(obj.stage3BlockArray) == 4
                  mode = 0; %if 0 same side, if ~0 switch side
                  obj.stage3BlockArray = [];
                else
                  mode = 1;
                end

                 if strcmp(side,'left') & mode == 0 || strcmp(side,'right') & mode ~= 0
%                      obj.sender.send('enable,Branch3LeftGray,0;', obj.addresses);
%                      obj.sender.send('enable,Branch3RightGray,0;', obj.addresses);
% 
%                      obj.sender.send('enable,Branch3Left_stage3,1;', obj.addresses);
%                      obj.sender.send('enable,Branch3Right_stage3,0;', obj.addresses);


                     obj.sender.send('enable,Branch3LeftGratingHighFreq,0;', obj.addresses);
                     obj.sender.send('enable,Branch3RightGratingHighFreq,1;', obj.addresses);



%                     obj.sender.send('enable,Branch3Left_stage3,0;', obj.addresses);
%                     obj.sender.send('enable,Branch3Right_stage3,1;', obj.addresses);
                    obj.sender.send('enable,Branch3LeftGratingThick,1;', obj.addresses);
                    obj.sender.send('enable,Branch3RightGratingThick,0;', obj.addresses);

                     obj.stage3Array(3:4) = [right,left];
                 else %right
%                     obj.sender.send('enable,Branch3LeftGray,0;', obj.addresses);
%                     obj.sender.send('enable,Branch3RightGray,0;', obj.addresses);
% 
%                     obj.sender.send('enable,Branch3Left_stage3,0;', obj.addresses);
%                     obj.sender.send('enable,Branch3Right_stage3,1;', obj.addresses);


                    obj.sender.send('enable,Branch3LeftGratingHighFreq,1;', obj.addresses);
                     obj.sender.send('enable,Branch3RightGratingHighFreq,0;', obj.addresses);



%                     obj.sender.send('enable,Branch3Left_stage3,0;', obj.addresses);
%                     obj.sender.send('enable,Branch3Right_stage3,1;', obj.addresses);
                    obj.sender.send('enable,Branch3LeftGratingThick,0;', obj.addresses);
                    obj.sender.send('enable,Branch3RightGratingThick,1;', obj.addresses);

                    obj.stage3Array(3:4) = [left,right];
                 end
            end

        end
%         function stage3_setStim(obj)  
%         %this function will randomly place
%         stim on either side if chosen correctly and keep stim on same
%         side if chosen incorrectly.

%          %if correct the first time. Random grating side
%          %if incorrect first time. grating on the same side
%          %initially turn off all stimulus. turn off thin
%         
%          
%          if obj.stage3Array(1) %correct
%              %random side
%              rnd = rand();
%              if rnd>.5 %left
%                  obj.sender.send('enable,Branch3LeftGray,0;', obj.addresses);
%                  obj.sender.send('enable,Branch3RightGray,0;', obj.addresses);
%                  
%                  obj.sender.send('enable,Branch3Left_stage3,1;', obj.addresses);
%                  obj.sender.send('enable,Branch3Right_stage3,0;', obj.addresses);
%                  
%                  
%                  
%                  obj.stage3Array(3:4) = [165,15];
%              else %right
%                  obj.sender.send('enable,Branch3LeftGray,0;', obj.addresses);
%                 obj.sender.send('enable,Branch3RightGray,0;', obj.addresses);
%                 
%                 obj.sender.send('enable,Branch3Left_stage3,0;', obj.addresses);
%                 obj.sender.send('enable,Branch3Right_stage3,1;', obj.addresses);
%                     
%                
%                 
%                 obj.stage3Array(3:4) = [15,165];
%              end
%          else %incorrect
%              %same side
%              
%          end
%             
%         end
        
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
            
            
            if obj.hardware == 0
                obj.nodes.vertices = obj.vertices(branchNum,:);
                disp(obj.nodes.vertices)
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
                    
           if ~strcmp(obj.stage, 'stage1') & ~strcmp(obj.stage,'stage2')
                    
                    
                    
                    % Hide user menu.
                    obj.sender.send('enable,Menu,0;', obj.addresses);
                    
                    % Hide blank and enable external devices and behavior.
                    obj.sender.send('enable,Blank,0;', obj.addresses);
           
               
           end
           if strcmp(obj.stage, 'stage3')
               obj.timeout = toc(obj.startTime)+30;%error side
           end
               
                    obj.stopDuringBlank = false;
                    
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
           obj.log('note,Manual reward');
          
          
        end
        
        function ManualAirpuff(obj)
           %send pulse to airpuff
           
           obj.treadmill.airpuff(obj.airpuffDuration);
           obj.log('note,Manual airpuff');
          obj.moveStimAngle(40)
        end
        
        
        function delete(obj)
            % LinearMaze.delete()
            % Release all resources.
           % obj.treadmill.reward(obj.rewardDuration);
            obj.sender.send('enable,Blank,1;', obj.addresses);
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
            
            obj.trialGraph%plot trial xy data and save in folder
            obj.stageThreeGraphs();
        end
        
        
        function stageThreeGraphs(obj)
           name = obj.newGUI_figurehandle.EnterMouseNameEditField.Value
           trial_ = obj.trial
           time_ = toc(obj.startTime)
           accuracy_ = 1-obj.stage3Record/(obj.trial-1)
           
           %save this session to table. save timeDuration, trialNumbers, accuracy
           if strcmp(name, 'test')
               
               load test
               time = [time time_];
               accuracy = [accuracy accuracy_];
               trial = [trial trial_];
               
               save test accuracy time trial
               
           end
           
           if strcmp(name, 'a1')
               
               load a1
               time = [time time_];
               accuracy = [accuracy accuracy_];
               trial = [trial trial_];
               
               save a1 accuracy time trial
               
           end
           
           if strcmp(name, 'a2')
               
               load a2
               time = [time time_];
               accuracy = [accuracy accuracy_];
               trial = [trial trial_];
               
               save a2 accuracy time trial
               
           end
            
           if strcmp(name, 'zd53')
               
               load zd53
               time = [time time_];
               accuracy = [accuracy accuracy_];
               trial = [trial trial_];
               
               save zd53 accuracy time trial
           end
            
           if strcmp(name, 'db_cx3cr1_4c')
               
               load db_cx3cr1_4c
               time = [time time_];
               accuracy = [accuracy accuracy_];
               trial = [trial trial_];
               
               save db_cx3cr1_4c accuracy time trial
            end
           %graph trials over days
          obj.TrialsOverDays(trial,name)
           %graph accuracy over days
           figure(2)
           obj.AccuracyOverDays(accuracy,name)
            
            
        end
        
        function TrialsOverDays(obj,trials,name)
            plot(1:length(trials),trials)
            title(sprintf('Trials Over Days, %s',name))
            xlabel('days')
            ylabel('Number of Trials')
        end
        
        function AccuracyOverDays(obj,accuracy,name)
            plot(1:length(accuracy),accuracy)
            title(sprintf('Accuracy Over Days, %s',name))
            xlabel('days')
            ylabel('Accuracy (%)')
        end
        
        function trialGraph(obj)
            %make a folder with figures that show the path taken by the
            %user for each trial
            if isnan(obj.stage) % only make graphs for stages after stage 3
                
            data = xlsread(obj.filename);
            %             XYdata = [data(:,3),data(:,8:12)];
            %
            %             rows = 1;
            %             while true %take out any rows containing NaNs
            %                 if rows == length(XYdata)+1
            %                     break
            %                 elseif sum(isnan(XYdata(rows,:))) ~= 0%contains nan
            %                     XYdata(rows,:) = [];
            %                 else
            %                     rows= rows+1;
            %                 end
            %             end
            %
            %             realXYList = zeros(length(XYdata),2); %make list of actual XY position. Choose movie or hardware mode position as needed
            %             for entries = 1:length(XYdata)
            %                 if XYdata(entries,end) == 0 %if moviespeed is zero take coords from hardware columns
            %                     realXYList(entries,1:2) = XYdata(entries,end-2:end-1);
            %                 else%if moviespeed is not zero take coords from moviemode columns
            %                     realXYList(entries,1:2) = XYdata(entries,2:3);
            %                 end
            %             end
            %             realXYList = [XYdata(:,1), realXYList];%append trial numbers to array
            %
            %
            %             numTrials = realXYList(end,1); %get max number of trials from file
            %             for trials = 1:numTrials
            %                 newMatrix{trials} = realXYList(realXYList(:,1) == trials,:);
            %             end%separate based on trial
            %
            %             folder = fullfile(getenv('USERPROFILE'), 'Documents');
            %             session = sprintf('trialFigures/%s', obj.dateCreated);
            %             session = [session(1:end-8),'-',session(end-7:end-6),'-',session(end-5:end-4),'_',session(end-3:end)];
            %             filename_plots = fullfile(folder, sprintf('%s', session));
            %             mkdir(filename_plots)%make new folder for this session
            %
            %
            %
            %             for trials = 1:numTrials
            %                 list = newMatrix{trials};
            %                 y = list(:,3);
            %                 x = list(:,2);
            %
            %
            %                      plot(list(1:length(x(y<-33)),2),y(y<-33),'b.')%plot xy data as points before decision point
            %
            %                      hold on
            %                      plot(list(length(x(y<-33))+1:end,2),y(y>-33),'r.')%plot xy data as points
            %
            %                      %make outline of the 3rd branch
            %                      plot([457,457],[-158,-28],'k')%left line
            %                      plot([477,477],[-158,-28],'k')%right line
            %                      plot([457,431],[-28,10],'k')%leftwall
            %                      plot([477,503],[-28,10],'k')%rightwall
            %                      plot([467,452],[-28,10],'k')%left inner wall
            %                      plot([467,482],[-28,10],'k')%right inner wall
            %
            %                      %show where where the stimulus is on graph
            %                      %plot(
            %
            %
            %
            %
            %
            %
            %                      hold off
            %                 title(sprintf('trial %i',trials))
            %                 xlim([430 504])
            %                 ylim([-100 5])
            %
            %                 yticks([-100 -50 0])
            %                 yticklabels([0 50 100])
            % %
            %                 xticks([431 467 503])
            %                 xticklabels([-36 0 36])
            %
            %                 session = sprintf([obj.mouseName,'_trial_%i'],trials);
            %                 file = fullfile(filename_plots, sprintf('%s.png', session));
            %                 saveas(gcf,file)
            %             end
            %
            XYdata = [data(:,3),data(:,8:12)];
            RotationData = [data(:,3),data(:,1),data(:,15)];
            
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
            
            rows = 1;
            while true %take out any rows containing NaNs
                if rows == length(RotationData)+1
                    break
                elseif sum(isnan(RotationData(rows,:))) ~= 0%contains nan
                    RotationData(rows,:) = [];
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
                splitRotationData{trials} = RotationData(RotationData(:,1) ==trials,:);
            end%separate based on trial
            
            folder = fullfile(getenv('USERPROFILE'), 'Documents');
            session = sprintf('trialFigures');
            %session = [session(1:end-8),'-',session(end-7:end-6),'-',session(end-5:end-4),'_',session(end-3:end)];
            filename_plots = fullfile(folder, sprintf('%s', session));
            mkdir(filename_plots)%make new folder for this session
            
            
            
            for trials = 1:numTrials
                list = newMatrix{trials};
                
                y = list(:,3);
                x = list(:,2);
                
                
                %     scatter(list(1:length(x(y<-33)),2),y(y<-33),'b.')%plot xy data as points before decision point
                %
                %     hold on
                %     scatter(list(length(x(y<-33))+1:end,2),y(y>-33),'r.')%plot xy data as points
                cmap = copper(length(x));
                %figure('Name','xyData')
                for i = 1:length(x)
                    plot(x(i),y(i),'.','color', cmap(i,:))
                    hold on
                end
                
                %make outline of the 3rd branch
                plot([457,457],[-158,-28],'k')%left line
                plot([477,477],[-158,-28],'k')%right line
                plot([457,431],[-28,10],'k')%leftwall
                plot([477,503],[-28,10],'k')%rightwall
                plot([467,452],[-28,10],'k')%left inner wall
                plot([467,482],[-28,10],'k')%right inner wall
                
                %show where where the stimulus is on graph
                %plot(
                
                
                title(sprintf('trial %i, xyData',trials))
                xlim([430 504])
                ylim([-100 5])
                
                yticks([-100 -50 0])
                yticklabels([0 50 100])
                %
                xticks([431 467 503])
                xticklabels([-36 0 36])
                
                hold off
                session = sprintf(['trial_%i'],trials);
                file = fullfile(filename_plots, sprintf('%s.png', session));
                saveas(gcf,file)
                
                
                
            end
            
          
            
            rotList = splitRotationData{1};
            
            figure(2)
            for i =1:length(rotList)
                plot(rotList(i,2),rotList(i,3),'.','color', cmap(i,:))
                hold on
            end
            title(sprintf('trial %i, rotational data',trials))
            xlabel('time (sec)')
            ylabel('rotation (deg)')
            yticks([20:20:120])
            end
        end
        
        function MouseGraph(obj)
            %add another number to y-axis on graphic in GUI
            %add marker to right/left indicating right/wrong
            %this function gets called in newTrial()
            handle_mouseChoice = obj.newGUI_figurehandle.MouseChoiceGraph; %handle to mouseChoiceGraph on GUI
            handle_choiceAccuracy = obj.newGUI_figurehandle.ChoiceAccuracyGraph;%handle to ChoiceAccuracyGraph on GUI
            
            lastTrial = obj.trial - 1 + obj.trialNumberFactor*height(obj.csvDataTable); %this is because we care about plotting the previous trial
            %disp(lastTrial)
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
            
            if isnan(obj.stage)
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
            
            
            obj.sender.send('enable,Branch3Left_stage3,0;', obj.addresses);
            obj.sender.send('enable,Branch3Right_stage3,0;', obj.addresses);
            
            
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
                obj.gratingSideArray(obj.trial+obj.trialNumberFactor*height(obj.csvDataTable)) = 0; %left
            else%if side == 3%right
                obj.sender.send(strcat('enable,Branch', num2str(obj.currentBranch) ,'RightGrating',obj.stimSize_string,',1;'), obj.addresses);
                obj.sender.send(strcat('enable,Branch', num2str(obj.currentBranch) ,'LeftGray,1;'), obj.addresses);
                obj.ActualSide = 3;%this is to see if the side chosen was correct or not for the reward
                obj.gratingSideArray(obj.trial+obj.trialNumberFactor*height(obj.csvDataTable)) = 1;
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
        
        function laserPin(obj, data)
            %make a log of the vysinc signal coming from laser
            obj.log('laser vysinc');
            disp('laser')
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
                if ~strcmp(obj.stage,'stage1') &~strcmp(obj.stage,'stage2')
                obj.sender.send('enable,Blank,0;', obj.addresses);
                end
                obj.enabled = true;
                
                %starting tone
                
                if strcmp(obj.stage,'stage3')
                    obj.pauseInputs(2);
                    
                else
                    Tools.tone(obj.startTone(1), obj.startTone(2));
                end
            elseif duration > 0
                obj.enabled = false;
                obj.sender.send('enable,Blank,1;', obj.addresses);
                %obj.blankId = %this also gave me a problem on pc
                obj.scheduler.delay({@obj.blank, 0}, duration);
            end
        end
        
        function pauseInputs(obj, duration)
            % LinearMaze.pause(duration)
            % Show blank for a given duration.
            
           
            %Objects.delete(obj.blankId); %this gave me a problem on the
            %basement pc
            if duration == 0
               
                obj.enabled = true;
                Tools.tone(obj.startTone(1), obj.startTone(2));
                %starting tone
                %Tools.tone(obj.startTone(1), obj.startTone(2));
                
            elseif duration > 0
                obj.enabled = false;
                %Tools.tone(700, obj.startTone(2)); 
                %obj.sender.send('enable,Blank,1;', obj.addresses);
                %obj.blankId = %this also gave me a problem on pc
                obj.scheduler.delay({@obj.pauseInputs, 0}, duration);
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
%             obj.sender.send('enable,Plane,1;', obj.addresses);
%             obj.sender.send('enable,Planerock,1;', obj.addresses);
            
            yo =find(strcmp(obj.newGUI_figurehandle.SteeringOnOffDropDown.Items,obj.newGUI_figurehandle.SteeringOnOffDropDown.Value));
            if yo == 1 && ~isempty(obj.com)
                obj.hardware = 2;
                obj.mSpeed = 0;
                
            elseif ~isempty(obj.com)
                obj.hardware = 0;
            end
           
            
            
            correctness = 1;
            if obj.hardware == 2
                if obj.vectorPosition(1)<obj.branchArray(obj.currentBranch,2)
                    sidechosen = 'left';
                    obj.choiceArray(obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),1) = 2; %the mouse went left
                else
                    sidechosen = 'right';
                    obj.choiceArray(obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),1) = 4;%the mouse went right
                end
                
                if obj.vectorPosition(1)<obj.branchArray(obj.currentBranch,2) && obj.ActualSide == 2    %left
                    %correct
                    %obj.newGUI_figurehandle.ChoiceEditField.Value = 'correct left';
                    obj.intertrialDuration = 1;
                    
                    %Tools.tone(obj.rewardTone(1), obj.rewardTone(2));% This makes a reward tone
                    obj.treadmill.reward(obj.rewardDuration);
                    
                    obj.log('note,reward');
                    
                    obj.choiceArray(obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),2) = 1; %correct side chosen
                    
                    
                elseif obj.vectorPosition(1)> obj.branchArray(obj.currentBranch,2) && obj.ActualSide == 3  %right
                    %correct
                    %obj.newGUI_figurehandle.ChoiceEditField.Value = 'correct right';
                    obj.intertrialDuration = 1;
                    
                    %Tools.tone(obj.rewardTone(1), obj.rewardTone(2)); %This makes a reward tone
                    
                    obj.treadmill.reward(obj.rewardDuration);
                    
                    obj.log('note,reward');
                    
                    obj.choiceArray(obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),2) = 1; %correct side chosen
                else
                    %incorrect
                    
                    %Tools.tone(obj.errorTone(1), obj.errorTone(2)); %This makes a error tone
                   
                    obj.treadmill.airpuff(obj.airpuffDuration);
                    %obj.newGUI_figurehandle.ChoiceEditField.Value = 'incorrect';
                    obj.intertrialDuration = 3;
                    correctness = 0;
                    
                    obj.choiceArray(obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),2) = 0; %incorrect side chosen
                end
            else%hardware off
                if obj.nodes.yaw < 0
                    sidechosen = 'left';
                    obj.choiceArray(obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),1) = 2;%the mouse went left
                else
                    sidechosen = 'right';
                    obj.choiceArray(obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),1) = 4;%the mouse went right
                end
                
                if obj.nodes.yaw < 0 && obj.ActualSide == 2          %left
                    %correct
                    
                    %obj.newGUI_figurehandle.ChoiceEditField.Value = 'correct left';
                    obj.intertrialDuration = 1;
                    obj.treadmill.reward(obj.rewardDuration);
                    %Tools.tone(obj.rewardTone(1), obj.rewardTone(2)); %This makes a reward tone
                    obj.log('note,reward');
                    obj.choiceArray(obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),2) = 1; %correct side chosen
                    
                elseif obj.nodes.yaw > 0 && obj.ActualSide == 3    %right
                    %correct
                    %obj.newGUI_figurehandle.ChoiceEditField.Value = 'correct right';
                    obj.intertrialDuration = 1;
                    obj.treadmill.reward(obj.rewardDuration);
                    %Tools.tone(obj.rewardTone(1), obj.rewardTone(2));% This makes a reward tone
                    obj.log('note,reward');
                    obj.choiceArray(obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),2) = 1; %correct side chosen
                else
                    %incorrect
                    %Tools.tone(obj.errorTone(1), obj.errorTone(2)); %This makes a error tone
                   
                    obj.treadmill.airpuff(obj.airpuffDuration);
                    %obj.newGUI_figurehandle.ChoiceEditField.Value = 'incorrect';
                    obj.intertrialDuration = 3;
                    correctness = 0;
                    
                    obj.choiceArray(obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),2) = 0; %incorrect side chosen
                end
            end
            
            %log last trial
            %obj.log('data,%i,%i,%i,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f, %i,%i,%i', obj.trial,obj.treadmill.frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2),obj.vectorPosition(1),obj.vectorPosition(2),obj.speed,obj.steeringPushfactor ,obj.currentBranch);
            obj.log_trial('%i,%i,%i,%s,%s,%.2f,%i,%i,%i', obj.trial,correctness,obj.ActualSide,sidechosen,obj.stimSize_string,obj.stimRot-90,obj.currentBranch,obj.hardware,obj.steeringLength); 
            
            %obj.print('trial,%i', obj.trial); %print trial in command window and log in file

            obj.trial = obj.trial + 1; %increment the trial number
            if obj.trial > height(obj.csvDataTable)
                obj.trial = 1;
                obj.trialNumberFactor = obj.trialNumberFactor + 1;
            end
                
                
%             try  %this makes a black screen whenever the end of the preset csv file has been reached                
%                 
%             catch
%                 obj.stop() 
%                 obj.newGUI_figurehandle.debugEditField.Value = 'end of preset csv file reached';
%             end
            obj.currentBranch = obj.csvDataTable{obj.trial,2};%find(strcmp(obj.newGUI_figurehandle.BranchNumberDropDown.Items,obj.newGUI_figurehandle.BranchNumberDropDown.Value));
            
            
            obj.newGUI_figurehandle.trialNumberLabel.Text = num2str(obj.trial+obj.trialNumberFactor*height(obj.csvDataTable)); %change trial number in GUI
            
            obj.MouseGraph(); %update the mouseGraph in GUI

            
            %try  %this makes a black screen whenever the end of the preset csv file has been reached                
            obj.steeringLength = obj.csvDataTable{obj.trial,9};%find(strcmp(obj.newGUI_figurehandle.SteeringLengthDropDown.Items,obj.newGUI_figurehandle.SteeringLengthDropDown.Value));
            %catch
%                 obj.stop() 
%                 obj.newGUI_figurehandle.debugEditField.Value = 'end of preset csv file reached';
%             end
            
            
            obj.updateFromCSV() %update input values from csv file
            obj.setStimulus(); %put the stimulus in place with correct rotation

            obj.vectorPosition = obj.vertices(obj.currentBranch,1:2);
            if mod(obj.trial,2)~=0
                obj.vectorPosition(1) = obj.vectorPosition(1)+.1;
            end
            obj.yRotation = 90; %reset rotation on new trial
            obj.z_yRotation = 1;
            obj.x_yRotation = 0;
           
            
            %if movie mode, and random then switch the final node randomly
            %left or right
            if obj.hardware == 0  %if not using steering 
                obj.setNodes_movieMode(); %set path left or right for movie mode camera

            else%obj.hardware == 2

                %obj.sender.send(sprintf('rotation,Main Camera,0,%.2f,0;', obj.yRotation-90), obj.addresses);
                obj.sender.send(Tools.compose([sprintf(...
                'position,Main Camera,%.2f,3,%.2f;', obj.vectorPosition(1), obj.vectorPosition(2)), ...
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
%             LinearMaze.onChange(position, distance, yaw)
%             Update monitors with any change in position and rotation.
%             Create an entry in the log file if logOnChange == true.
            
            obj.sender.send(Tools.compose([sprintf(...
                'position,Main Camera,%.2f,20,%.2f;', position(1), position(2)), ...
                'rotation,Main Camera,0,%.2f,0;'], yaw + obj.offsets), ...
                obj.addresses);
            
            if obj.logOnChange
                obj.log('data,%i%i,%i,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f, %i,%i,%i',obj.trial+obj.trialNumberFactor*height(obj.csvDataTable), obj.treadmill.frame, obj.treadmill.step, distance, yaw, position(1), position(2),obj.vectorPosition(1),obj.vectorPosition(2),obj.speed,obj.steeringPushfactor ,obj.currentBranch);
            end
        end
        
        function onFrame(obj, frame)
            % LinearMaze.onFrame(frame)
            % The trigger input changed from low to high.
            % Create an entry in the log file if logOnFrame == true.
            
            % Log changes including frame count and rotary encoder changes.
            
            
            if obj.logOnFrame
                obj.log('data,%i%i,%i,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f, %i,%i,%i',obj.trial+obj.trialNumberFactor*height(obj.csvDataTable), frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2),obj.vectorPosition(1),obj.vectorPosition(2),obj.speed,obj.steeringPushfactor ,obj.currentBranch);
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
                
                if obj.yRotation > 140
                    obj.yRotation = 140;
                elseif obj.yRotation < 40
                    obj.yRotation = 40;
                end
                
                obj.x_yRotation = cosd(obj.yRotation);
                obj.z_yRotation = sind(obj.yRotation);
          
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
                
                if obj.hardware == 0 & obj.enabled%obj.speed ~= 0 && obj.enabled && ~obj.nodes.rotating
                    % Open-loop updates position when open-loop speed is different 0.
                    obj.nodes.push(obj.speed / obj.nodes.fps);
                    x = obj.nodes.position;
                    rot = obj.nodes.yaw;
                   
                    obj.sender.send(Tools.compose([sprintf(...
                        'position,Main Camera,%.2f,6,%.2f;', x(1), x(2)), ...
                        'rotation,Main Camera,0,%.2f,0;'], rot + obj.offsets), ...
                        obj.addresses);
                elseif obj.enabled  %hardware on, obj enabled
                     
                    
                
%                     if ~isempty(obj.textBox_speed_h.String)
%                         obj.steeringPushfactor = obj.csvDataTable{obj.trial,8} * .05;%str2double(obj.textBox_speed_h.String)*.05;%steering factor based off speed textbox and random 0.05 number
%                     else
%                         obj.steeringPushfactor = 1.25; %= 25*.05. This is the default push factor if nothing is put in the text box
%                     end
                    obj.steeringPushfactor = obj.newGUI_figurehandle.EnterSpeedEditField.Value * 0.0185;
                    
                    obj.vectorPosition(1) = obj.vectorPosition(1) - (obj.x_yRotation*obj.steeringPushfactor);
                    obj.vectorPosition(2) = obj.vectorPosition(2) + (obj.z_yRotation*obj.steeringPushfactor);
                    
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
% try 
%     obj.vectorPosition(1)
%                   obj.vectorPosition(2) 
% catch
% end
                obj.sender.send(Tools.compose([sprintf(...
                'position,Main Camera,%.2f,6,%.2f;', obj.vectorPosition(1), obj.vectorPosition(2)), ...
                'rotation,Main Camera,0,%.2f,0;'], obj.yRotation-90 + obj.offsets), ...
                obj.addresses);
                    %---------------------------------------------------------------------------------
%                     obj.sender.send(sprintf(...
%                     'position,Main Camera,%.2f,1,%.2f;', obj.vectorPosition(1), obj.vectorPosition(2)), ...
%                     obj.addresses);
                         %obj.vectorPosition
%             obj.vertices(obj.choosebranch_h.Value,end)
                    if obj.logOnUpdate
                        str = sprintf('data,%i,%i,%i,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f, %i,%i,%i,%i', obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),obj.treadmill.frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2),obj.vectorPosition(1),obj.vectorPosition(2),obj.speed,obj.steeringPushfactor ,obj.currentBranch,obj.yRotation);
                        if ~strcmp(str, obj.update)
                            obj.update = str;
                            obj.log(str);
                        end
                 
                    end
                     if y_coord > obj.vertices(obj.currentBranch,end) %get to reset node: then reset camera position

                            obj.newTrial();
                     end  
                     
                 end
        
%             if obj.logOnUpdate
%                 str = sprintf('data,%i,%i,%i,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f, %i,%i,%i', obj.trial+obj.trialNumberFactor*height(obj.csvDataTable),obj.treadmill.frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2),obj.vectorPosition(1),obj.vectorPosition(2),obj.speed,obj.steeringPushfactor ,obj.currentBranch);
%                 if ~strcmp(str, obj.update)
%                     obj.update = str;
%                     obj.log(str);
%                 end
%                 
%             end
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
%         function trial = trialFunc(trialNum,trialNumberFactor,length)
%             trial = trialNum + trialNumberFactor * length;
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
            x = z/(-1.75) + 449;
           elseif branch == 2 %branch 2 
            x = (z-1335)/(-5.33);
          
           else%if branch == 1 %branch 1
            
            x = (z+40)/(-1.3);
           end
        end
        
        function x = right_leftwall(z, branch)
            %left side of right branch
            
           if branch == 3 %branch 3
            x = z/1.7 + 486;
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

% filename = 'C:\Users\Gandhi Lab.DESKTOP-IQP0LND\Documents\VR_TimeBased\test_VR_TimeBased_2019-01-30_1907.csv';
% data = xlsread(filename);
% XYdata = [data(:,3),data(:,8:12)];
% 
% 
% rows = 1;
% while true %take out any rows containing NaNs
%     if rows == length(XYdata)+1
%         break
%     elseif sum(isnan(XYdata(rows,:))) ~= 0%contains nan
%         XYdata(rows,:) = [];
%     else
%         rows= rows+1;
%     end
% end
% 
% realXYList = zeros(length(XYdata),2); %make list of actual XY position. Choose movie or hardware mode position as needed
%  for entries = 1:length(XYdata)
%      if XYdata(entries,end) == 0
%          realXYList(entries,1:2) = XYdata(entries,end-2:end-1);
%      else
%          realXYList(entries,1:2) = XYdata(entries,2:3);
%      end
%  end
%  realXYList = [XYdata(:,1), realXYList]%append trial numbers to array
% 
%  
% numTrials = realXYList(end,1);
% for trials = 1:numTrials
%     newMatrix{trials} = realXYList(realXYList(:,1) == trials,:);
% end%separate based on trial
%      
% 
% %do plot stuff with 'newMatrix'

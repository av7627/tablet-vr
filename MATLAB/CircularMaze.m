% CircularMaze - Controller for a circular maze using custom behavioral apparatus.
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
% CircularMaze methods:
%   blank  - Show blank for a given duration.
%   delete - Release all resources.
%   log    - Create a log entry using the same syntax as sprintf.
%   pause  - Show blank and disable behavior for a given duration.
%   print  - Print on screen and create a log entry using the same syntax as sprintf.
%   reset  - Reset trial, position, rotation, frame count and encoder steps.
%   start  - Send high pulse to trigger-out and enable behavior.
%   stop   - Send low pulse to trigger-out and disable behavior.
% 
% CircularMaze properties:
%   gain   - Forward speed factor in closed-loop when the rotary encoder produces movement.
%   speed  - Forward speed in open-loop.
%
% Please note that these classes are in early stages and are provided "as is"
% and "with all faults". You should test throughly for proper execution and
% proper data output before running any behavioral experiments.
% 
% Tested on MATLAB 2018a.
% 
% See also LinearMaze, TableTop, TwoChoice.

% 2017-12-13. Leonardo Molina.
% 2018-05-25. Last modified.
classdef CircularMaze < handle
    properties (Access = public)
        % intertrial - Duration (s) of an intertrial when last node is reached.
        intertrialDuration = 0
        
        % logOnChange - Create a log entry with every change in position or rotation.
        logOnChange = false
        
        % logOnFrame - Create a log entry with every trigger-input.
        logOnFrame = true
        
        % logOnUpdate - Create a log entry at the frequency of the behavior controller.
        logOnUpdate = true
		
        % rewardDuration - Duration (s) the reward valve remains open after a trigger.
        rewardDuration = 0.050
        
        % scene - Name of an existing scene.
        scene = 'Classroom'
        
        % treadmill - Arduino controlled apparatus.
        treadmill
    end
    
    properties (SetAccess = private)
        % distance - Traveled distance over the path.
        distance = 0
        
        % filename - Name of the log file.
        filename
        
        % position - Current x/z position.
        position = [0, 0]
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
        enabled = false
        
        % fid - Log file identifier.
        fid
        
        % figureHandle - UI handle to control figure.
        figureHandle
        
        mGain = 1;
        
        mSpeed = 0;
        
        % offsets - Monitor rotation offset listed under monitors.
        offsets
        
        % pauseId - Process id for scheduling pauses.
        pauseId
        
        % radius - Radius (cm) of the circular path.
        radius = 38
        
        % rotation - Rotation of the camera.
        rotation = 0
        
        % scheduler - Scheduler object for non-blocking pauses.
        scheduler
        
        % sender - Network communication object.
        sender
        
        % startTime - Reference to time at start.
        startTime
        
        % textBox - Textbox GUI.
        textBox
        
        % trial - Trial number.
        trial = 1
        
        % vertices - Vertices of the maze (x1, y1, x2, y2, ... in cm).
        vertices
        
        catDistance = 0
    end
    
    properties (Constant)
        % fps - Frames per seconds for time integration; should match VR game.
        fps = 50
        
        % programVersion - Version of this function.
        programVersion = '20180525'
    end
    
    methods
        function obj = CircularMaze(varargin)
            % CircularMaze()
            %   Controller for a liner-maze.
            % CircularMaze('com', comPortName, ...)
            %   Provide the serial port name of the treadmill (rotary encoder, pinch valve,
            %   photo-sensor, and lick-sensors assumed connected to an Arduino microcontroller
            %   running a matching firmware).
            % CircularMaze('monitors', {ip1, offset1, ip2, offset2, ...}, ...)
            %   Provide IP address of each monitor tablet and rotation offset for each camera.
            
            keys = varargin(1:2:end);
            values = varargin(2:2:end);
            k = find(strcmpi(keys, 'com'), 1);
            if isempty(k)
                com = [];
            else
                com = values{k};
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
            %disp(obj.offsets)
            obj.sender = UDPSender(32000);
            
            % Log file.
            root = getenv('USERPROFILE');
            folder = fullfile(root, 'Documents', 'VR');
            if exist(folder, 'dir') ~= 7
                mkdir(folder);
            end
            session = sprintf('VR%s', datestr(now, 'yyyymmddHHMMSS'));
            obj.filename = fullfile(folder, sprintf('%s.csv', session));
            obj.fid = fopen(obj.filename, 'a');
            obj.startTime = tic;
                        
            % Log program versions.
            obj.startTime = tic;
            obj.className = mfilename('class');
            obj.print('maze-version,%s-%s', obj.className, CircularMaze.programVersion);
            obj.print('filename,%s', obj.filename);
            
            % Initialize treadmill controller.
            if isempty(com)
                obj.treadmill = TreadmillInterface();
                obj.print('treadmill-version,%s', TreadmillInterface.programVersion);
            else
                obj.treadmill = ArduinoTreadmill(com);
                obj.print('treadmill-version,%s', ArduinoTreadmill.programVersion);
            end
            obj.treadmill.register('Frame', @obj.onFrame);
            obj.treadmill.register('Step', @obj.onStep);
            
            % Release resources when the figure is closed.
            obj.figureHandle = figure('Name', mfilename('Class'), 'MenuBar', 'none', 'NumberTitle', 'off', 'DeleteFcn', @(~, ~)obj.delete());
            h(1) = uicontrol('Style', 'PushButton', 'String', 'Stop',  'Callback', @(~, ~)obj.stop());
            h(2) = uicontrol('Style', 'PushButton', 'String', 'Start', 'Callback', @(~, ~)obj.start());
            h(3) = uicontrol('Style', 'PushButton', 'String', 'Reset', 'Callback', @(~, ~)obj.reset());
            h(4) = uicontrol('Style', 'PushButton', 'String', 'Log text', 'Callback', @(~, ~)obj.onLogButton());
            h(5) = uicontrol('Style', 'Edit');
            p = get(h(1), 'Position');
            set(h, 'Position', [p(1:2), 4 * p(3), p(4)]);
            align(h, 'Left', 'Fixed', 0.5 * p(1));
            obj.textBox = h(5);
            set(obj.figureHandle, 'Position', [obj.figureHandle.Position(1), obj.figureHandle.Position(2), 4 * p(3) + 2 * p(1), 2 * numel(h) * p(4)])
            
            % Auto-start.
            obj.speed = 15;
            
            % Load an existing scene.
            obj.sender.send(sprintf('scene,%s;', obj.scene), obj.addresses);
            
            obj.scheduler = Scheduler();
            obj.scheduler.repeat(@obj.onUpdate, 1 / obj.fps);
        end
        
        function blank(obj, duration)
            % CircularMaze.pause(duration)
            % Show blank for a given duration.
            
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
            obj.print('speed,%.2f', speed);
            obj.mSpeed = speed;
        end
        
        function speed = get.speed(obj)
            speed = obj.mSpeed;
        end
        
        function delete(obj)
            % CircularMaze.delete()
            % Release all resources.
            
            obj.treadmill.trigger = false;
            delete(obj.scheduler);
            delete(obj.treadmill);
            delete(obj.sender);
            obj.log('note,delete');
            fclose(obj.fid);
            CircularMaze.export(obj.filename);
            if ishandle(obj.figureHandle)
                set(obj.figureHandle, 'DeleteFcn', []);
                delete(obj.figureHandle);
            end
        end
        
        function log(obj, format, varargin)
            % CircularMaze.log(format, arg1, arg2, ...)
            % Create a log entry using the same syntax as sprintf.
            
            fprintf(obj.fid, '%.4f,%s\n', toc(obj.startTime), sprintf(format, varargin{:}));
        end
        
        function pause(obj, duration)
            % CircularMaze.pause(duration)
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
            % CircularMaze.print(format, arg1, arg2, ...)
            % Print on screen and create a log entry using the same syntax as sprintf.
            
            fprintf('[%.1f] %s\n', toc(obj.startTime), sprintf(format, varargin{:}));
            obj.log(format, varargin{:});
        end
        
        function reset(obj)
            % CircularMaze.reset()
            % Reset trial, position, rotation, frame count and encoder steps.
            
            obj.trial = 1;
            % Frame counts and steps are reset to zero.
            obj.treadmill.frame = 0;
            obj.treadmill.step = 0;
            obj.print('note,reset');
        end
        
        function start(obj)
            % CircularMaze.start()
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
            % CircularMaze.stop()
            % Send low pulse to trigger-out and disable behavior.
            
            % Show blank and disable external devices and behavior.
            obj.treadmill.trigger = false;
            obj.sender.send('enable,Blank,1;', obj.addresses);
            obj.enabled = false;
            obj.print('note,stop');
        end
    end
    
    methods (Access = private)
        function onFrame(obj, frame)
            % CircularMaze.onFrame(frame)
            % The trigger input changed from low to high.
            % Create an entry in the log file if logOnFrame == true.
            
            % Log changes including frame count and rotary encoder changes.
            if obj.logOnFrame
                obj.log('data,%i,%.2f,%.2f,%.2f,%.2f,%.2f', frame, obj.treadmill.step, obj.distance, obj.rotation, obj.position(1), obj.position(2));
            end
        end
        
        function onLogButton(obj)
            % CircularMaze.onLogButton()
            % Log user text.
            
            if ~isempty(obj.textBox.String)
                obj.print('note,%s', obj.textBox.String);
                obj.textBox.String = '';
            end
        end
        
        function onStep(obj, step)
            % CircularMaze.onStep(step)
            % The rotary encoder changed, update behavior if enabled
            % Create an entry in the log file otherwise.
            
            if obj.enabled && obj.speed == 0
                obj.pushCamera(step * obj.gain);

                % Create an entry in the log file.
                if obj.logOnChange
                    obj.log('data,%i,%.2f,%.2f,%.2f,%.2f,%.2f', obj.treadmill.frame, obj.treadmill.step, obj.distance, obj.rotation, obj.position(1), obj.position(2));
                end
            end
        end
        
        function onUpdate(obj)
            % CircularMaze.onUpdate()
            % Create an entry in the log file if logOnUpdate == true.
            tic
            if obj.enabled
                % Move camera around the circle.
                if obj.speed ~= 0
                    % Open-loop updates position when open-loop speed is different 0.
                    obj.pushCamera(obj.speed / obj.fps);
                end
                
                % Log.
                if obj.logOnUpdate
                    obj.log('data,%i,%.2f,%.2f,%.2f,%.2f,%.2f', obj.treadmill.frame, obj.treadmill.step, obj.distance, obj.rotation, obj.position(1), obj.position(2));
                end
                toc
            end
                
            % Move cat around a smaller circle.
            obj.catDistance = obj.catDistance - 0.5 * obj.speed / obj.fps;
            r = 1.025 * obj.radius;
            theta = obj.catDistance / r;
            pos = r * [sin(theta), cos(theta)];
            rot = 90 + atan2(pos(1), pos(2)) / pi * 180;
            obj.sender.send(sprintf('position,Cat,%.2f,%.2f,%.2f;rotation,Cat,0,%.2f,0;', pos(1), sin(45 * theta) + 1.5, pos(2), rot), obj.addresses);
        end
        
        function pushCamera(obj, change)
            obj.distance = obj.distance + change;
            theta = obj.distance / obj.radius;
            obj.position = obj.radius * [sin(theta), cos(theta)];

            % Update monitors with any change in position and rotation.
            % Always head tangent to the circle.
            obj.rotation = 90 + atan2(obj.position(1), obj.position(2)) / pi * 180;
            obj.sender.send(Tools.compose([sprintf(...
                'position,Main Camera,%.2f,1,%.2f;', obj.position(1), obj.position(2)), ...
                'rotation,Main Camera,0,%.2f,0;'], obj.rotation + obj.offsets), ...
                obj.addresses);
        end
    end
    
    methods (Static)
        function export(filename)
            % CircularMaze.export(filename)
            % Convert log file to a mat file.
            
            header = {'time (s)', 'frame', 'encoder-step (cm)', 'unfolded-distance (cm)', 'y-rotation (degrees)', 'x-position (cm)', 'z-position (cm)'};
            data = str2double(CSV.parse(CSV.load(filename), [-1 1:6], 'data'));
            [folder, filename] = fileparts(filename);
            save(fullfile(folder, sprintf('%s.mat', filename)), 'header', 'data');
        end
    end
end

%#ok<*NASGU>
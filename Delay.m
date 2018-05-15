% Delay.
% Control execution of events based on the timing of a sequence of steps.
% The steps are analogous to entering and exiting an elevator:
%   - Start outside the elevator.
%   - Wait for doors to open (enterDelay)
%   - Enter before doors close (enterTimeout)
%   - Don't try to exit before reaching the destination (reachDelay)
%   - Wait for doors to open (exitDelay)
%   - Exit before doors close (exitTimeout)
% 
% Each step is cued:
%   - Waiting: started inside, exit before opening doors.
%   - Opening: Doors are opening, do not enter yet.
%   - EntryAllowed: Doors are fully opened, enter now.
%   - Reached: Elevator has reached it's destination. Doors are opening, do not exit yet.
%   - ExitAllowed: Doors are fully opened, exit now.
% 
% Events issued after each step:
%   - EarlyEntry: Entered before the cue.
%   - PromptEntry: Entered timely after the cue.
%   - NoEntry: Took too long to enter.
%   - RushedExit: Exited before the cue.
%   - PromptExit: Exited timely after the cue.
%   - NoExit: Took too long to exit.
% 
% Failing to respect the timing of the sequence will terminate it.
% 
% Entry/Exit events are reported before any stage.
% Error events are reported after EarlyEntry, NoEntry, EarlyExit, RushedExit, and NoExit stages.
%
% Example:
%   % Create a callback function to display time and the output stage.
%   ref = tic;
%   printStage = @(~, stage) fprintf('[%.1f] %s \n', toc(ref), stage);
%   % Create a Delay object: start with the 
%   obj = Delay(true, 2, 5, 1, 2, 5, printStage);
%   obj.step(); % Exit to start.
%   pause(2.5); % Wait for entry message.
%   obj.step(); % Enter.
%   pause(1.5); % Wait for reach message.
%   pause(2.5); % Wait for exit message.
%   obj.step(); % Exit.

% 2017-05-24. Leonardo Molina.
% 2018-05-03. Last modified.
classdef Delay < Event
    properties (Access = private)
        enterDelay
        enterTimeout
        reachDelay
        exitDelay
        exitTimeout
        className
        stage
        
        inside
        scheduler
        
        mverbose = false
    end
    
    properties
        callback = @Callbacks.void;
    end
    
    methods
        function obj = Delay(inside, enterDelay, enterTimeout, reachDelay, exitDelay, exitTimeout, callback)
            % enterDelay is relative to Stages.Opening.
            % enterTimeout is relative to Stages.EntryAllowed.
            % reachDelay is relative to Stages.PromptEntry.
            % exitDelay is relative to Stages.Reached.
            % exitTimeout is relative to Stages.ExitAllowed.
            
            obj.className = mfilename('class');
            
            obj.inside = inside;
            obj.enterDelay = enterDelay;
            obj.enterTimeout = enterTimeout;
            obj.reachDelay = reachDelay;
            obj.exitDelay = exitDelay;
            obj.exitTimeout = exitTimeout;
            obj.scheduler = Scheduler();
            
            if nargin == 7
                obj.callback = callback;
            end
            
            if inside
                obj.stage = Delay.Stages.Waiting;
                obj.report(Delay.Stages.Waiting);
            else
                obj.stage = Delay.Stages.Opening;
                obj.scheduler.delay({@obj.delayed, Delay.Stages.EntryAllowed}, obj.enterDelay);
                obj.report(Delay.Stages.Opening);
            end
        end
        
        function delete(obj)
            delete(obj.scheduler);
        end
        
        function step(obj)
            obj.inside = ~obj.inside;
            if obj.inside
                obj.report(Delay.Stages.Entry);
            else
                obj.report(Delay.Stages.Exit);
            end
            switch obj.stage
                case Delay.Stages.Waiting
                    obj.stage = Delay.Stages.Opening;
                    obj.report(Delay.Stages.Opening);
                    obj.scheduler.delay({@obj.delayed, Delay.Stages.EntryAllowed}, obj.enterDelay);
                case Delay.Stages.Opening
                    obj.scheduler.stop();
                    obj.stage = Delay.Stages.EarlyEntry;
                    obj.report(Delay.Stages.EarlyEntry);
                    obj.report(Delay.Stages.Error);
                case Delay.Stages.EntryAllowed
                    obj.scheduler.stop();
                    obj.stage = Delay.Stages.PromptEntry;
                    obj.report(Delay.Stages.PromptEntry);
                    obj.scheduler.delay({@obj.delayed, Delay.Stages.Reached}, obj.reachDelay);
                case Delay.Stages.PromptEntry
                    obj.scheduler.stop();
                    obj.stage = Delay.Stages.EarlyExit;
                    obj.report(Delay.Stages.EarlyExit);
                    obj.report(Delay.Stages.Error);
                case Delay.Stages.Reached
                    obj.scheduler.stop();
                    obj.stage = Delay.Stages.RushedExit;
                    obj.report(Delay.Stages.RushedExit);
                    obj.report(Delay.Stages.Error);
                case Delay.Stages.ExitAllowed
                    obj.scheduler.stop();
                    obj.stage = Delay.Stages.PromptExit;
                    obj.report(Delay.Stages.PromptExit);
            end
        end
    end
    
    methods (Access = private)
        function delayed(obj, stage)
            obj.stage = stage;
            switch stage
                case Delay.Stages.EntryAllowed
                    obj.report(Delay.Stages.EntryAllowed)
                    obj.scheduler.delay({@obj.delayed, Delay.Stages.NoEntry}, obj.enterTimeout);
                case Delay.Stages.NoEntry
                    obj.report(Delay.Stages.NoEntry);
                    obj.report(Delay.Stages.Error);
                case Delay.Stages.Reached
                    obj.report(Delay.Stages.Reached);
                    obj.scheduler.delay({@obj.delayed, Delay.Stages.ExitAllowed}, obj.exitDelay);
                case Delay.Stages.ExitAllowed
                    obj.report(Delay.Stages.ExitAllowed);
                    obj.scheduler.delay({@obj.delayed, Delay.Stages.NoExit}, obj.exitTimeout);
                case Delay.Stages.NoExit
                    obj.report(Delay.Stages.NoExit);
                    obj.report(Delay.Stages.Error);
            end
        end
        
        function report(obj, stage)
            Callbacks.invoke(obj.callback, stage);
        end
    end
end
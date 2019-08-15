% TreadmillInterface()
% Treadmill interface for debugging purposes.
% 
% TreadmillInterface methods:
%   reward   - Send a reward for the given duration.
%   register - Register to events.
% 
% TreadmillInterface events - obj.register(eventName, @callback):
%   Frame - An input frame was detected.
%   Step  - Treadmill position changed.

% 2018-03-05. Leonardo Molina.
% 2018-05-23. Last modified.
classdef TreadmillInterface < Event
    properties
        % step - Encoder position.
        step = 0
        
        % frame - trigger-in count.
        frame = 0
    end
    
    properties (Dependent)
        % trigger - trigger-out pulse.
        trigger
    end
    
    properties (Constant)
        % programVersion - Program version.
        programVersion = '20180523'
    end
    
    properties (Access = private)
        % triggerState - Binary state of the triggerPin.
        triggerState = false
    end
    
    methods
        function obj = TreadmillInterface()
            % TreadmillInterface()
            % Create a pretend treadmill that does nothing.
            
        end
        
        function delete(~)
            % TreadmillInterface.delete
        end
        
        function reward(~, ~)
            % TreadmillInterface.reward(duration)
            % Pretend to send a pulse for the given duration to the rewarding device (e.g. pinch-valve).
        end
        
        function airpuff(~, ~)
            % TreadmillInterface.airpuff(duration)
            % Pretend to send a pulse for the given duration to the airpuff device (e.g. pinch-valve).
        end
        
        function triggerState = get.trigger(obj)
            triggerState = obj.triggerState;
        end
        
        function set.trigger(obj, triggerState)
            if numel(triggerState) == 1 && islogical(triggerState)
                obj.triggerState = triggerState;
            end
        end
    end
end
% 2017-06-18. Leonardo Molina.
% 2018-05-03. Last modified.
classdef ServoMotor < handle
    properties (Access = private)
        pwm
        minTic
        deltaTic
        maxAngle
        scheduler
        
        map = struct('angle', repmat({NaN}, 1, 64), 'stop', repmat({NaN}, 1, 64), 'running', repmat({false}, 1, 64));
        
        running = 0
        queue = struct('channel', {}, 'angle', {}, 'duration', {});
    end
    
    methods
        function obj = ServoMotor(bridge, basePulse, minPulse, maxPulse, maxAngle)
            % Bridge.ServoMotor(bridge, basePulse, minPulse, maxPulse, maxAngle)
            % Setup a PWM driver connected to an Arduino via bridge. basePulse, minPulse,
            % maxPulse, and maxAngle are used to scale input angles with the set method.
            
            if nargin < 2
                basePulse = 14225;
            end
            if nargin < 3
                minPulse = 326;
            end
            if nargin < 4
                maxPulse = 2116;
            end
            if nargin < 5
                maxAngle = 180;
            end
            
            MHz = 1 / (basePulse + minPulse + maxPulse);
            
            obj.minTic = minPulse * MHz * 4096;
            obj.deltaTic = maxPulse * MHz * 4096 - obj.minTic;
            obj.maxAngle = maxAngle;
            
            obj.scheduler = Scheduler();
            obj.pwm = Bridge.PWM(bridge, round(1e6 * MHz));
        end
        
        function delete(obj)
            % ServoMotor.delete()
            % Stop scheduler controlling processes.
            
            delete(obj.scheduler);
        end
        
        function angle = angle(obj, channel)
            % Bridge.ServoMotor.angle(channel)
            % Get the angle of a servo.
            
            index = channel + 1;
            angle = obj.map(index).angle;
        end
        
        function set(obj, channel, angle, duration)
            % ServoMotor.set(channel, angle, duration)
            % Set a angle for a channel inmediately for the given duration
            % then release the channel.
            
            index = channel + 1;
            fall = round(angle / obj.maxAngle * obj.deltaTic + obj.minTic);
            obj.pwm.set(index, fall);
            
            if obj.map(index).running
                % Cancel a previously scheduled stop.
                obj.scheduler.stop(obj.map(index).stop);
            else
                obj.running = obj.running + 1;
            end
            
            % Schedule a stop.
            obj.map(index).running = true;
            obj.map(index).stop = obj.scheduler.delay({obj, 'stop', channel}, duration);
        end
        
        function schedule(obj, channel, angle, duration)
            % Bridge.ServoMotor.schedule(channel, angle, duration)
            % When the queue is free, set the angle for a channel for the
            % given duration then release the channel.
            
            % Add to the back.
            n = numel(obj.queue) + 1;
            obj.queue(n).channel = channel;
            obj.queue(n).angle = angle;
            obj.queue(n).duration = duration;
            if n == 1
                obj.set(channel, angle, duration);
            end
        end
        
        function stop(obj, channel)
            % Bridge.ServoMotor.stop(channel)
            % Cancel all scheduleSame as set.
            
            index = channel + 1;
            if obj.map(index).running
                obj.map(index).running = false;
                obj.pwm.set(channel, 0);
                obj.running = obj.running - 1;
            end
            
            if obj.running > 0
                % Pop next element in the queue.
                channel = obj.queue(1).channel;
                angle = obj.queue(1).angle;
                duration = obj.queue(1).duration;
                obj.queue(1) = [];
                obj.setup(channel, angle, duration);
            end
        end
    end
end
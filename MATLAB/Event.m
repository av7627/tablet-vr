% Event - Event handler.
% Event methods:
%   register - Invoke a generic method with the given event.
% 
% Convenient event notification mechanism which accepts any delegate, as 
% opposed to MATLAB's event mechanism which expects recipients with one type
% of argument (a child of event.EventData).
% 
% See also Callbacks.invoke.

% 2018-03-08. Leonardo Molina.
% 2018-05-21. Last modified.
classdef Event < handle
    properties (Access = private)
        map = cell(3, 0)
    end
    
    properties (Access = protected)
        uid = 0
    end
    
    methods
        function obj = Event()
        end
        
        function [handle, id] = register(obj, name, callback)
            n = size(obj.map, 2);
            obj.uid = obj.uid + 1;
            id = obj.uid;
            obj.map(:, n + 1) = {id; name; callback};
            handle = Event.Object(obj, id);
        end
    end
    
    methods (Hidden)
        function unregister(obj, ids)
            % Event.unregister(ids)
            % Remove previously registered callbacks.
            
            uids = [obj.map{1, :}];
            k = ismember(uids, ids);
            obj.map(:, k) = [];
        end
    end
    
    methods (Access = protected)
        function invoke(obj, name, varargin)
            % Event.invoke(name, parameter1, parameter2, ...)
            % Invoke callbacks with parameters registered with a given name.
            
            names = obj.map(2, :);
            k = ismember(names, name);
            callbacks = obj.map(3, k);
            for c = 1:numel(callbacks)
                Callbacks.invoke(callbacks{c}, varargin{:});
            end
        end
    end
end
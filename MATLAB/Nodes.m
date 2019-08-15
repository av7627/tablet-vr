% Nodes - Abstraction of a task that occurs following a path in an arbitrary 2D mesh.
% Define a navigable path. A method 'push' moves a pointer by a given amount and 
% changes its rotation to face the next node. Events are raised to indicate when 
% nodes are reached or laps are completed.
% Position and rotation are for a left-handed coordinate system.
% 
% Nodes methods:
%   delete       - Release resources.
%   push         - Move forward or backward by a given amount.
%   rotate       - Rotate.
%   select       - Get position of a subset of nodes by their index.
% 
% Nodes properties:
%   angularSpeed - Speed (deg/s) at which to rotate camera at each node.
%   count        - Number of nodes.
%   distance     - Traveled distance over the path.
%   fps          - Frames per seconds for time integration; should match VR game.
%   node         - Node index in the select list.
%   position     - Current x/z position.
%   rotating     - Whether a rotation operation is in place.
%   rotation     - Current bearing direction (y-rotation).
%   vertices     - Location of the nodes that define a path in the arena.
%   yaw          - Camera angle.
%   width        - Length of the unfolded path.
%   
% Nodes events - obj.register(eventName, @callback):
%   Change   - A change in position, yaw, or rotation has occurred.
%   Lap      - A full lap was traversed.
%   Node     - A new node was reached.
%   Rotating - Automatic rotation started.
%   Update   - A time step has passed.

% 2018-03-05. Leonardo Molina.
% 2018-05-21. Last modified.
classdef Nodes < Event
    properties
        % angularSpeed - Speed (deg/s) at which to rotate camera at each node.
        angularSpeed = 90
        
        % verbose - Display information each integration step.
        verbose = false
    end
    
    properties (SetAccess = private)
        % distance - Traveled distance over the path.
        distance = NaN
        
        % position - Current x/z position.
        position = [NaN; NaN]
        
        % rotating - Whether a rotation operation is in place.
        rotating = false
        
        % rotation - Current bearing direction (y-rotation).
        rotation = NaN
        
        % yaw - Camera angle.
        yaw = NaN
        
        % width - Length of the unfolded path.
        width = NaN
    end
    
    properties (Constant)
        % fps - Frames per seconds for time integration; should match VR game.
        fps = 50
        
        % programVersion - Version of this class.
        programVersion = '20180521'
    end
    
    properties (Dependent)
        % count - Number of nodes.
        count
        
        % node - Node index in the select list.
        node
        
        % vertices - Location of the nodes that define a path in the arena.
        vertices
    end
    
    properties (Access = private)
        % angleStep - Angle integration step.
        angleStep
        
        % changed - Position or rotation changed.
        changed = false
        
        % className - Name of this class.
        className
        
        % deltaNode - Separation from current node.
        deltaNode
        
        % forward - Currently moving forward.
        forward = true
        
        % index - Cummulative index of the active node.
        index = 1
        
        % lap - Lap counter
        lap = 0
        
        % mVertices - Reshaped representation of vertices.
        mVertices
        
        % nextIndex - Node index marking a lap change ahead.
        nextIndex
        
        % nextNode - Distance from current to next node.
        nextNode
        
        % prevIndex - Node index marking a lap change behind.
        prevIndex
        
        % prevNode - Distance from current to previous node.
        prevNode
        
        % scheduler - Scheduler object for producing routines.
        scheduler
    end
    
    methods
        function obj = Nodes()
            % Nodes()
            % Create a holder for a navigable path.
            
            obj.className = mfilename('Class');
            
            % Update every frame.
            obj.scheduler = Scheduler();
            obj.scheduler.repeat(@obj.onUpdate, 1 / obj.fps);
        end
        
        function delete(obj)
            % Nodes.delete()
            % Release resources.
            
            delete(obj.scheduler);
        end
        
        function count = get.count(obj)
            count = size(obj.vertices, 2);
        end
        
        function node = get.node(obj)
            node = mod(obj.index - 1, obj.count) + 1;
        end
        
        function distance = push(obj, delta)
            % Nodes.push(delta)
            % Move forward or backward by a given amount.
            
            if obj.count > 1
                notifyNode = false;
                notifyLap = false;
                obj.distance = mod(obj.distance + delta, obj.width);
                obj.deltaNode = obj.deltaNode + delta;
                if delta > 0
                    obj.changed = true;
                    if obj.deltaNode >= obj.nextNode
                        notifyNode = true;
                        if obj.forward
                            obj.index = obj.index + 1;
                        else
                            obj.forward = true;
                        end
                        obj.position = obj.select(obj.node);
                        if obj.index == obj.nextIndex
                            notifyLap = true;
                            obj.lap = obj.lap + 1;
                            obj.prevIndex = obj.index - obj.count;
                            obj.nextIndex = obj.index + obj.count;
                        end
                        obj.rotation = obj.nodeRotation(obj.node, obj.node + 1);
                        obj.rotate(obj.yaw, obj.rotation, obj.angularSpeed);
                        delta = obj.deltaNode - obj.nextNode;
                        obj.deltaNode = delta;
                        [x, z] = obj.select([obj.node, obj.node + 1]);
                        obj.nextNode = +sqrt(diff(x) .^ 2 + diff(z) .^ 2);
                        obj.prevNode = 0;
                    end
                    obj.position = obj.position + rotate([0; delta], obj.rotation);
                elseif delta < 0
                    obj.changed = true;
                    if obj.deltaNode <= obj.prevNode
                        notifyNode = true;
                        if obj.forward
                            obj.forward = false;
                        else
                            obj.index = obj.index - 1;
                        end
                        obj.position = obj.select(obj.node);
                        if obj.index == obj.prevIndex
                            notifyLap = true;
                            obj.lap = obj.lap + 1;
                            obj.prevIndex = obj.index - obj.count;
                            obj.nextIndex = obj.index + obj.count;
                        end
                        obj.rotation = obj.nodeRotation(obj.node - 1, obj.node);
                        obj.rotate(obj.yaw, obj.rotation, obj.angularSpeed);
                        delta = obj.deltaNode - obj.prevNode;
                        obj.deltaNode = delta;
                        [x, z] = obj.select([obj.node - 1, obj.node]);
                        obj.prevNode = -sqrt(diff(x) .^ 2 + diff(z) .^ 2);
                        obj.nextNode = 0;
                    end
                    obj.position = obj.position + rotate([0; delta], obj.rotation);
                end
                if notifyNode
                    obj.invoke('Node', obj.node);
                end
                if notifyLap
                    obj.invoke('Lap', obj.lap);
                end
            end
            distance = obj.distance;
            if obj.verbose
                fprintf('[%s] r=%02i: d=%.2f (%.2f,%.2f)\n', obj.className, round(obj.rotation), distance, obj.position(1), obj.position(2));
            end
        end
        
        function rotate(obj, start, finish, angularSpeed)
            % Nodes.rotate(start, finish, angularSpeed)
            % Rotate between start and finish angles at the given angularSpeed.
            % 
            % Nodes.rotate(angle)
            % Rotate to the given rotation right away.
            
            theta = deltaAngle(start, finish);
            if nargin == 2 || theta == 0
                obj.rotating = false;
                obj.rotation = start;
                obj.yaw = start;
            else
                obj.rotating = true;
                obj.rotation = finish;
                obj.yaw = start;
                obj.angleStep = sign(theta) * angularSpeed / obj.fps;
            end
        end
        
        function vertices = get.vertices(obj)
            vertices = obj.mVertices;
        end
        
        function set.vertices(obj, vertices)
            % Updating the vertices also changes width, current node and the
            % reference for the next lap.
            obj.mVertices = reshape(vertices, [2, numel(vertices) / 2]);
            obj.index = 1;
            obj.distance = 0;
            obj.deltaNode = 0;
            obj.prevNode = 0;
            [x, z] = obj.select([obj.node, obj.node + 1]);
            obj.nextNode = sqrt(diff(x) .^ 2 + diff(z) .^ 2);
            obj.position = obj.select(obj.node);
            obj.prevIndex = obj.index - obj.count;
            obj.nextIndex = obj.index + obj.count;
            obj.rotation = obj.nodeRotation(obj.node, obj.node + 1);
            obj.yaw = obj.rotation;
            obj.changed = true;
            [x, z] = obj.select([1:obj.count 1]);
            k = isinf(x) | isinf(z); x(k) = []; z(k) = [];
            obj.width = sum(sqrt(diff(x) .^ 2 + diff(z) .^ 2));
        end
        
        function varargout = select(obj, nodes)
            % vertices = Nodes.select(node)
            % [xs, zs] = Nodes.select(node)
            % Get position of a subset of nodes by their index.
            
            nodes = mod(nodes - 1, obj.count) + 1;
            if nargout == 1
                varargout{1} = obj.vertices(:, nodes);
            elseif nargout == 2
                varargout{1} = obj.vertices(1, nodes);
                varargout{2} = obj.vertices(2, nodes);
            end
        end
    end
    
    methods (Access = private)
        function degrees = nodeRotation(obj, node1, node2)
            % Nodes.nodeRotation(node1, node2)
            % Heading direction between two nodes.
            
            [x1, z1] = obj.select(node1);
            [x2, z2] = obj.select(node2);
            radians = atan2(x2 - x1, z2 - z1);
            degrees = radians / pi * 180;
        end
        
        function onUpdate(obj)
            % Nodes.onUpdate()
            % A time step has passed.
            
            if obj.rotating
                if (obj.angleStep > 0 && deltaAngle(obj.yaw, obj.rotation) <= 0) || (obj.angleStep < 0 && deltaAngle(obj.yaw, obj.rotation) >= 0)
                    % Yaw finished changing.
                    obj.yaw = obj.rotation;
                    obj.rotating = false;
                  
                    obj.invoke('Rotating', false);
                else
                    % Update yaw.
                    obj.yaw = obj.yaw + obj.angleStep;
                    obj.changed = true;
                end
            end
            if obj.changed
                obj.changed = false;
                
                obj.invoke('Change', obj.position, obj.distance, obj.yaw, obj.rotation);
            end
            obj.invoke('Update');
        end
    end
end

function theta = deltaAngle(start, finish)
    % theta = deltaAngle(start, finish)
    % Difference between two angles (in degrees for a left-hand coordinate system).
    
    theta = mod(finish - start + 180, 360) - 180;
end

function point = rotate(point, degrees)
    % rotate(point, degrees)
    % Rotate a point a number of degrees (left-hand coordinate system).
    
    radians = degrees / 180 * pi;
    cosv = cos(radians);
    sinv = sin(radians);
    point = [point(1) * cosv + point(2) * sinv; point(2) * cosv - point(1) * sinv];
end
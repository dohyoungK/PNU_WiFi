classdef (Abstract) hWirelessNode < handle
%hWirelessNode Base class for nodes of wireless networks
%
%   hWirelessNode properties:
%
%   NodeID              - Node identifier
%   NodePosition        - Node position

%   Copyright 2021 The MathWorks, Inc.

properties
    %NodeID Node identifier
    %   Specify this property as an integer. This is the identifier for
    %   this particular node in the network.
    NodeID = 1
    
    %NodePosition Node position
    %   Specify this property as a row vector with 3 elements. This
    %   property identifies the position of the node in the network.
    NodePosition = [0 0 0]
end

methods
    % Constructor
    function obj = hWirelessNode(varargin)
        % Name-value pairs
        for idx = 1:2:nargin
            obj.(varargin{idx}) = varargin{idx+1};
        end
    end
    
    % Set Node ID
    function set.NodeID(obj, value)
        validateattributes(value, {'numeric'}, {'scalar', ...
            'positive', 'integer'}, mfilename, 'NodeID');
        obj.NodeID = value;
    end
    
    % Set node position
    function set.NodePosition(obj, value)
        validateattributes(value, {'numeric'}, {'row', 'numel', 3}, ...
            mfilename, 'NodePosition');
        obj.NodePosition = value;
    end
    
    % Get node position
    function value = get.NodePosition(obj)
        value = obj.NodePosition;
    end
end
end

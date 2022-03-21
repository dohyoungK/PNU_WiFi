classdef hApplication < handle
%hApplication Create an object to represent application layer in WLAN
%   APP = hApplication creates an object for WLAN application layer.
%
%   APP = hApplication(Name, Value) creates an object for WLAN application
%   layer with the specified property Name set to the specified Value. You
%   can specify additional name-value pair arguments in any order as
%   (Name1, Value1, ..., NameN, ValueN).
%
%   APP = hApplication(MaxApplications, Name, Value) same as above but
%   additionally accepts the maximum number of applications,
%   MaxApplications, that can be installed.
%
%   hApplication properties:
%
%   NodeID          - Node identifier
%   FillPayload     - Fill packet payload bytes, instead of just length

%   Copyright 2021 The MathWorks, Inc.

properties
    %NodeID Node identifier
    NodeID = 0;
    
    %FillPayload Fill the payload bytes in the generated application packet
    %   Set this property to true to fill payload in application packet
    FillPayload = true;
end

properties (Constant)    
    %MaxPacketLength Maximum number of bytes for the application data
    MaxPacketLength = 2304;
end

properties(Access = private)
    %Applications A column vector of data traffic models installed on this node
    Applications = cell(1, 1);
    
    %ApplicationsCount Count of applications already added
    ApplicationsCount = 0;
    
    %NextInvokeTime Next invoke time
    %   Next invoke time for application packet generation operation
    NextInvokeTime = 0;
        
    % Maximum interfaces
    MaxInterfaces = 3;
end

% Statistics
properties
    % Vector of size 1-by-N, where N is the maximum number of interfaces.
    % Each element contains total number of application packets
    % transmitted.
    AppTx;
    
    % Vector of size 1-by-N, where N is the maximum number of interfaces.
    % Each element contains total number of application packets received
    AppRx;
    
    % Vector of size 1-by-N, where N is the maximum number of interfaces.
    % Each element contains total number of bytes received at application
    % layer
    AppRxBytes;
    
    % Vector of size 1-by-N, where N is the maximum number of interfaces.
    % Each element contains average packet latency at application layer.
    AppAvgPacketLatency;
    
    % Vector of size M-by-N, where M is the maximum number of nodes and N
    % is the maximum number of interfaces. Each element contains number of
    % application packets sent to MAC layer.
    AppTxPerDestination;
end

properties(Constant)
    ApplicationPacket = struct('PacketLength', 0, ... % in octets
        'PriorityID', 0, ... % Identifier for the data used in MAC layer
        'DestinationID', 0, ... % Final destination ID
        'Timestamp', 0, ... % Packet generation time stamp at origin
        'Data', zeros(hApplication.MaxPacketLength, 1, 'uint8'));
end

methods
    function obj = hApplication(numNodes, varargin)
        % Name-value pairs
        for idx = 1:2:numel(varargin)
            obj.(varargin{idx}) = varargin{idx+1};
        end
        
        % Initialize APP stats
        [obj.AppTx, obj.AppRx, obj.AppRxBytes, obj.AppAvgPacketLatency] = deal(zeros(1,obj.MaxInterfaces));
        obj.AppTxPerDestination = zeros(numNodes, obj.MaxInterfaces);
    end
    
    function nextInvokeTime = runApplication(obj, elapsedTime, pushData)
        %runApplication Generate application packet and the next invoke time
        %
        % runApplication(OBJ, ELAPSEDTIME, PUSHDATA) generates application
        % packet and calculates the time to generate the next packet, if
        % time elapsed since last call is sufficient to generate a packet.
        % Otherwise, returns balance wait time remaining for generating the
        % packet.
        %
        % ELAPSEDTIME - Time completed since last run (in microseconds)
        %
        % PUSHDATA - A function handle for pumping data to the lower layer
        
        minNextInvokeTime = inf;
        if elapsedTime < obj.NextInvokeTime
            % Not yet ready to generate the next packet
            for idx=1:obj.ApplicationsCount
                obj.Applications{idx}.TimeLeft = obj.Applications{idx}.TimeLeft - elapsedTime;
                if obj.Applications{idx}.TimeLeft < minNextInvokeTime
                    minNextInvokeTime = obj.Applications{idx}.TimeLeft;
                end
            end
            obj.NextInvokeTime = minNextInvokeTime;
        else
            % Ready to generate the next packet
            for idx=1:obj.ApplicationsCount
                obj.Applications{idx}.TimeLeft = obj.Applications{idx}.TimeLeft - elapsedTime;
                
                if obj.Applications{idx}.TimeLeft <= 0
                    % Generate packet from the application traffic pattern
                    [dt, packetSize, packetData] = generate(obj.Applications{idx}.App);
                    
                    % Generate packet for transmission
                    packet = obj.ApplicationPacket;
                    packet.Data = packetData;
                    packet.PacketLength = packetSize;
                    packet.PriorityID = obj.Applications{idx}.PriorityID;
                    packet.DestinationID = obj.Applications{idx}.DestinationID;
                    obj.Applications{idx}.TimeLeft = (obj.Applications{idx}.TimeLeft + (dt * 1000)); % In microseconds
                    %obj.Applications{idx}.TimeLeft = (obj.Applications{idx}.TimeLeft + (dt * 20000)); % In microseconds
                    
                    % Push the data to the lower layer
                    pushData(packet, obj.Applications{idx}.TimeLeft);
                end
                
                % Next invoke time
                if obj.Applications{idx}.TimeLeft < minNextInvokeTime
                    minNextInvokeTime = obj.Applications{idx}.TimeLeft;
                end
            end
            obj.NextInvokeTime = minNextInvokeTime;
        end
        nextInvokeTime = obj.NextInvokeTime;
    end
    
    function addApplication(obj, app, metaData)
        %appApplication Add application traffic model to the node
        %
        % appApplication(OBJ, APP, METADATA) adds the application traffic model
        % for the node.
        %
        % APP is a handle object that generates the application
        % traffic. It should be one of networkTrafficOnOff or
        % networkTrafficVoIP or networkTrafficFTP
        %
        % METADATA is a structure and contains following fields.
        %   DestinationNode - Destination node id
        %   AccessCategory - Access category
        
        obj.ApplicationsCount = obj.ApplicationsCount + 1;
        appIdx = obj.ApplicationsCount;
        
        if obj.FillPayload % Generate packet with payload
            app.GeneratePacket = true;
        end
        obj.Applications{appIdx}.App = app;
        obj.Applications{appIdx}.TimeLeft = 0;
        obj.Applications{appIdx}.DestinationID = metaData.DestinationNode;
        obj.Applications{appIdx}.PriorityID = metaData.AccessCategory;
    end
    
    function receivePacket(obj, packet, freqID)
        % receivePacket Update statistics for the packets received from network
        obj.AppRx(freqID) = obj.AppRx(freqID) + 1;
        obj.AppRxBytes(freqID) = obj.AppRxBytes(freqID) + packet.PacketLength;
    end
    
    function availableMetrics = getMetricsList(~)
    %getMetricsList Return the available metrics in application
    %   
    %   AVAILABLEMETRICS is a cell array containing all the available
    %   metrics in the application layer
    
        availableMetrics = {'AppTx', 'AppRx', 'AppRxBytes', ...
            'AppAvgPacketLatency'};
    end
end
end

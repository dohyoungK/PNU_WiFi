classdef hChannel
%hChannel Create an object for WLAN channel
%   CHANNEL = hChannel creates an object for WLAN channel
%
%   CHANNEL = hChannel(Name, Value) creates an object for WLAN channel
%   with the specified property Name set to the specified Value. You can
%   specify additional name-value pair arguments in any order as (Name1,
%   Value1, ..., NameN, ValueN).
%
%   hChannel properties:
%
%   ReceiverPosition        - Receiver node position
%   EnableFreeSpacePathloss - Flag to enable free space pathloss
%   Frequency               - Operating frequency (GHz)

%   Copyright 2021 The MathWorks, Inc.

properties
    %ReceiverID Receiver node identifier
    %   Specify the receiver node identifier.
    ReceiverID = 0;

    % Frequency Operating frequency (GHz)
    Frequency = 5.18;

    %EnableCustomPathlossModel Flag to enable custom pathloss model
    %   Set this property to true to apply a custom pathloss model. The
    %   Model used is implemented using the property PathlossFn. The
    %   default is false.
    EnableCustomPathlossModel = false;
    
    %PathlossFn Function handle for custom pathloss model
    %   Specify a function handle to a custom path loss model:
    %      PL = PathlossFn(SourceID,ReceiverID,Frequency)
    %         PL is the returned pathloss in dB (positive)
    %         SourceID is the transmitting node identifier
    %         ReceiverID is the receiving node identifier
    %         Frequency is the carrier frequency in GHz 
    %   This property is applicable when EnableCustomPathlossModel is true.
    PathlossFn;

    %EnableFreeSpacePathloss Flag to enable free space pathloss
    %   Set this property to true to apply free space pathloss. This
    %   property is applicable when EnableCustomPathlossModel is false.
    EnableFreeSpacePathloss = true;
    
    %ReceiverPosition Receiver node position
    %   Specify this property as a row vector with 3 elements. This
    %   property is applicable when EnableFreeSpacePathloss is true.
    ReceiverPosition = [0 0 0];
end

methods
    function obj = hChannel(varargin)
        % Name-value pairs
        for idx = 1:2:nargin
            obj.(varargin{idx}) = varargin{idx+1};
        end
    end

    function wlanSignal = run(obj, wlanSignal)
    %run Run the channel models
    %   WLANSIGNAL = run(OBJ, WLANSIGNAL) applies the configured
    %   channel impairments on the given WLAN signal
    %
    %   WLANSIGNAL is a structure with at least these properties, in
    %   addition to other properties:
    %       SourceNodePosition  - Source node position specified as a 
    %                             row vector with 3 integers
    %       SourceID            - Source node identifier specified as
    %                             an integer
    %       SignalPower         - Transmit signal power

        if obj.EnableCustomPathlossModel
            % Calculate free space path loss (in dB)
            pathLoss = obj.PathlossFn(wlanSignal.Metadata.SourceID,obj.ReceiverID,obj.Frequency);
            % Apply pathloss on the signal power of the waveform  
            %pathLoss = 98; 
            wlanSignal.Metadata.SignalPower = wlanSignal.Metadata.SignalPower - pathLoss;
            
        elseif obj.EnableFreeSpacePathloss
            % Calculate distance between sender and receiver in meters
            distance = norm(wlanSignal.Metadata.SourcePosition - obj.ReceiverPosition);
            % Apply free space path loss
            lambda = physconst('LightSpeed')/(obj.Frequency*1e9);
            % Calculate free space path loss (in dB)
            pathLoss = fspl(distance, lambda);
            % Apply pathloss on the signal power of the waveform
            wlanSignal.Metadata.SignalPower = wlanSignal.Metadata.SignalPower - pathLoss;
        end
    end
end
end
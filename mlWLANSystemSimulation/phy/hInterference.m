classdef hInterference < handle
%hInterference Create an object to model interference in the PHY
%receiver
%   OBJ = hInterference creates an object to model interference in the
%   PHY receiver
%
%   OBJ = hInterference(Name, Value) creates an object to model
%   interference in the PHY receiver, OBJ, with the specified property Name
%   set to the specified Value. You can specify additional name-value pair
%   arguments in any order as (Name1, Value1, ..., NameN, ValueN).
%
%   hInterference methods:
%
%   addSignal                - Add signal to the interference signal buffer
%   updateSignalBuffer       - Update interference signal buffer and timer
%   getSignalBuffer          - Get active interference signals
%   getTotalSignalPower      - Get total power of interference signals
%   getTotalNumOfSignals     - Get number of active interference signals
%   getInterferenceTimer     - Get time at which the next interfering
%                              signal elapses
%   logInterferenceTime      - Log duration of interference experienced 
%                              during signal reception
%   resetInterferenceLogTime - Reset timers for logging interference
%   getInterferenceTime      - Get interference time for current signal
%                              reception
%
%   hInterference properties:
%
%   BufferSize              - Interference signal buffer maximum size 
%   SignalMetadataPrototype - Signal metadata prototype
%   ExtractMetadataFn       - Function to extract metadata from a signal

%   Copyright 2021 The MathWorks, Inc.

    properties
        % Maximum number of signals to be stored. The default value is 10.
        BufferSize = 10;

        % Prototype array or structure to store interference signal
        % metadata in addition to the source ID, receiver power and
        % duration. This allows metadata within a wlanSignal structure to
        % be used within the abstraction.
        SignalMetadataPrototype = [];

        % Function handle which consumes a wlanSignal structure and returns
        % a structure or array (specified by the SignalMetadataPrototype
        % property) containing metadata to store in the interference
        % buffer:
        %   SIGNALBUFFERELEMENT = ExtractMetadataFn(SIGNAL)
        % SIGNALBUFFERELEMENT must be a structure with the same fields as
        % SignalMetadataPrototype. This allows metadata within a wlanSignal
        % structure to be used within the abstraction.
        ExtractMetadataFn = @(x)[];
    end

    properties (Access = private)
        % Timer (in microseconds) to update the tracked signal list.
        % Contains the smallest absolute (in simulation time timestamp)
        % time for a signal to be removed from the signal list.
        TimeUntilNextSignalUpdate  = -1;

        % Array containing the details of all the signals being received
        % For each signal, it contains transmitting node ID, received
        % signal power in dBm, end time in absolute simulation time units,
        % and metadata defined by the SignalMetadataPrototype property.
        SignalBuffer

        % Array indicating if a buffer element is active or not
        IsActive;

        % Array indicating the absolute time a buffer element will become
        % inactive
        SignalEndTime = [];

        % Number of signals present at a point of time
        NumSignals = 0;

        % Interference signals total power in watts
        TotalSignalPower = 0;

        % Total duration of interference accumulated over a signal of
        % interest
        InterferenceTime = 0;

        % End time of previous interference signal encountered during the
        % current signal of interest
        PrevInterferenceEndTime = 0;

        % Structure containing the default entry in the signal buffer
        DefaultSignalBufferElement
    end

    methods 
        function obj =  hInterference(varargin)
        %hInterference Construct an instance of this class

            % Set name-value pairs
            for idx = 1:2:nargin
                obj.(varargin{idx}) = varargin{idx+1};
            end

            % Create default signal buffer entry
            obj.DefaultSignalBufferElement = struct('SourceID',-1, ...
                'RxPower',-1, ...
                'EndTime',-1, ...
                'Metadata', obj.SignalMetadataPrototype());

            % Allocate signal buffer
            obj.SignalBuffer = repmat(obj.DefaultSignalBufferElement,obj.BufferSize,1);

            % Initialize indices and other buffers
            obj.IsActive = false(1,obj.BufferSize);
            obj.SignalEndTime = -1*ones(1,obj.BufferSize);
        end
    end

    methods
        function addSignal(obj, wlanSignal)
        %addSignal Add signal to the interference signal buffer
        %
        %   addSignal(OBJ, WLANSIGNAL) adds a new interference signal to
        %   the signal buffer.
        %
        %   OBJ is instance of class hInterference.
        %
        %   WLANSIGNAL is the received WLAN waveform. It is represented
        %   as a structure holding the signal information.
            
            % Total duration of the waveform
            ppduDuration = wlanSignal.Metadata.PreambleDuration + wlanSignal.Metadata.HeaderDuration + ...
                wlanSignal.Metadata.PayloadDuration;

            sigPowerInWatts = power(10.0, (wlanSignal.Metadata.SignalPower - 30)/ 10.0); % Converting from dBm to watts

            % Update the total signal power (add current signal power to
            % the total power)
            obj.TotalSignalPower = obj.TotalSignalPower + sigPowerInWatts;
            obj.NumSignals = obj.NumSignals + 1;

            % Store the sender node ID, the corresponding Rx signal power,
            % the end time, and any metadata of the received waveform
            idx = find(~obj.IsActive,1); % Find an inactive buffer element
            assert(~isempty(idx), 'No empty signal buffer element when attempting to store a signal')
            obj.IsActive(idx) = true;
            obj.SignalEndTime(idx) = ppduDuration + wlanSignal.Metadata.StartTime; % Start time in signal metadata is current simulation time
            obj.SignalBuffer(idx).SourceID = wlanSignal.Metadata.SourceID;
            obj.SignalBuffer(idx).RxPower = sigPowerInWatts;
            obj.SignalBuffer(idx).EndTime = obj.SignalEndTime(idx);
            obj.SignalBuffer(idx).Metadata = obj.ExtractMetadataFn(wlanSignal);

            % Update timer with the next minimum time (in simulation time
            % stamp) we need to update the signal buffer
            obj.TimeUntilNextSignalUpdate = min(obj.SignalEndTime(obj.IsActive));
        end

        function updateSignalBuffer(obj, currSimTime)
        %updateSignalBuffer Update interference signal buffer and timer
        %
        %   updateSignalBuffer(OBJ, CURRSIMTIME) updates the signal
        %   tracking buffer and timer. Elapsed signals are removed from the
        %   tracked signal list based on the current simulation time.
        %
        %   OBJ is instance of class hInterference.
        %
        %   CURRSIMTIME is the current simulation time

            % Remove active interferers which have finished from the signal set
            rmIdx = obj.IsActive & (obj.SignalEndTime<=currSimTime);
            if any(rmIdx)
                obj.TotalSignalPower = obj.TotalSignalPower - sum([obj.SignalBuffer(rmIdx).RxPower]);
                obj.NumSignals = obj.NumSignals - sum(rmIdx);
                obj.IsActive(rmIdx) = false;
                obj.SignalEndTime(rmIdx) = -1;
            end

            % Update timer with the next minimum time (in simulation time
            % stamp) we need to update the signal buffer
            if obj.NumSignals>0
                obj.TimeUntilNextSignalUpdate = min(obj.SignalEndTime(obj.IsActive));
            else
                obj.TimeUntilNextSignalUpdate = -1;
            end
        end

        function logInterferenceTime(obj, soi, varargin)
        %logInterferenceTime Log duration of interference experienced
        %during signal reception
        %
        %   logInterferenceTime(OBJ, SOI) logs the duration of interference
        %   intersecting over the current signal reception where the
        %   interfering signal started before the start of signal of
        %   interest.
        %
        %   OBJ is instance of class hInterference.
        %
        %   SOI is a structure holding the information of the signal of
        %   interest.
        %
        %   logInterferenceTime(OBJ, SOI, INTERFERINGSIGNAL) logs the
        %   duration of interference intersecting over the current signal
        %   reception where the interfering signal started after the start
        %   of signal of interest.
        %
        %   INTERFERINGSIGNAL is a structure holding the information of the
        %   interfering signal.
        
            % Total duration for signal of interest
            signalOfInterestDuration = soi.Metadata.PreambleDuration + soi.Metadata.HeaderDuration + soi.Metadata.PayloadDuration;

            if isempty(varargin)
                % Check and log any active interference time with signal
                % strength < ED threshold, that started before the current
                % signal of interest reception

                signalOfInterestEndTime = soi.Metadata.StartTime + signalOfInterestDuration;
                interferenceEndTime = 0;

                % Find the longest interfering signal
                if obj.NumSignals>0
                    interferenceEndTime = max(obj.SignalEndTime(obj.IsActive));
                end

                if interferenceEndTime < signalOfInterestEndTime
                    %           <------------SoI------------>
                    %    <------Interference-1------>
                    interferenceTime = interferenceEndTime - soi.Metadata.StartTime;
                else
                    %           <------------SoI------------>
                    %    <----------Interference-1----------->
                    interferenceTime = signalOfInterestDuration;
                end

                obj.InterferenceTime = interferenceTime;
                obj.PrevInterferenceEndTime = interferenceEndTime;

            else % Interference that started after the signal of interest reception start
                interferingSignal = varargin{1};
                % Total duration for interfering signal
                interferingSignalDuration = interferingSignal.Metadata.PreambleDuration + interferingSignal.Metadata.HeaderDuration + interferingSignal.Metadata.PayloadDuration;
                % Remaining duration for signal of interest
                remainingSignalDuration = signalOfInterestDuration - (interferingSignal.Metadata.StartTime - soi.Metadata.StartTime);
                % End time of interfering signal
                interferenceEndTime = (interferingSignal.Metadata.StartTime + interferingSignalDuration);

                % Interference time
                if interferingSignalDuration < remainingSignalDuration
                    %      <------------------------SoI------------------------>
                    %           <----Interference-1---->
                    interferenceTime = interferingSignalDuration;
                else
                    %      <------------SoI------------>
                    %           <----------Interference-1---------->
                    interferenceTime = remainingSignalDuration;
                end

                if obj.PrevInterferenceEndTime
                    % Handling > 1 interference signals
                    if interferingSignal.Metadata.StartTime > obj.PrevInterferenceEndTime
                        % <------------------------SoI------------------------>
                        %    <----Interference-1---->
                        %                               <----Interference-2---->
                        obj.InterferenceTime = obj.InterferenceTime + interferenceTime;
                        obj.PrevInterferenceEndTime = interferenceEndTime;
                    else
                        if interferenceEndTime > obj.PrevInterferenceEndTime
                            % <------------------------SoI------------------------>
                            %       <----Interference-1---->
                            %                   <----Interference-2---->
                            obj.InterferenceTime = obj.InterferenceTime + interferenceTime - ...
                                (obj.PrevInterferenceEndTime - interferingSignal.Metadata.StartTime);
                            obj.PrevInterferenceEndTime = interferenceEndTime;
                        else
                            % <------------------------SoI------------------------>
                            %        <------------Interference-1------------>
                            %                <----Interference-2---->

                            % No change in interfering time
                        end
                    end
                else % First interfering signal
                    obj.InterferenceTime = interferenceTime;
                    obj.PrevInterferenceEndTime = interferenceEndTime;
                end
            end
        end
        
        function time = getInterferenceTime(obj)
        %getInterferenceTime Returns interference time for current signal
        %reception
        %
        %   TIME = getInterferenceTime(OBJ) returns the overall duration of
        %   interference experienced by the receiver over the current
        %   signal reception
        %
        %   TIME is the total interference time over the current signal
        %
        %   OBJ is instance of class hInterference.

            time = obj.InterferenceTime;
        end

        function resetInterferenceLogTime(obj)
        %resetInterferenceLogTime Reset timers for logging interference
        %time on the next signal of interest

            obj.InterferenceTime = 0;
            obj.PrevInterferenceEndTime = 0;
        end

        function buffer = getSignalBuffer(obj)
        %getSignalBuffer Get active interference signals
        %
        %   getSignalBuffer(OBJ) returns a structure array containing
        %   active interference signals within the signal buffer. Call
        %   updateSignalBuffer() first to ensure the returned signals are
        %   up-to-date.
        
            buffer = obj.SignalBuffer(obj.IsActive);
        end

        function totalSignalPower = getTotalSignalPower(obj)
        %getTotalSignalPower Get total power of interference signals
        %
        %   getTotalSignalPower(OBJ) returns the total power of
        %   interference signals in Watts. Call updateSignalBuffer() first
        %   to ensure the returned signal power is up-to-date.

            totalSignalPower = obj.TotalSignalPower;
        end

        function numSignals = getTotalNumOfSignals(obj)
        %getTotalNumOfSignals Get number of active interference signals
        %
        %   getTotalNumOfSignals(OBJ) returns number of active interference
        %   signals. Call updateSignalBuffer() first to ensure the returned
        %   number of signals is up-to-date.
            numSignals = obj.NumSignals;
        end

        function timer = getInterferenceTimer(obj)
        %getInterferenceTimer Get time at which the next interfering signal elapses
        %
        %   getInterferenceTimer(OBJ) returns the minimum absolute time
        %   absolute time (in simulation timestamps) until the next
        %   interference signal elapses. If no interference signals are
        %   active -1 is returned. Call updateSignalBuffer() first to
        %   ensure the returned time is up-to-date.
            timer = obj.TimeUntilNextSignalUpdate;
        end
    end
end
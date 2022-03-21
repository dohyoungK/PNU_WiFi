classdef hStatsLogger < handle
% hStatsLogger Implements the logging and visualization of statistics
%  The class implements the functionality to plot the statistics at the end
%  of the simulation
%
%  hStatsLogger(param) Creates statistics logging and visualization object
%
%   hStatsLogger methods:
%   getStatistics - Returns the statistics of the simulation
%   updateVisualization - Let the visualization to refresh
%
%   hStatsLogger properties:
%   NumNodes  - Number of nodes
%   NodeNames - Node names
%   Nodes     - Node objects

%   Copyright 2021 The MathWorks, Inc.

properties (Access = private)
    % Number of nodes
    NumNodes;
    
    % Node names
    NodeNames;
    
    % Node objects
    Nodes;
end

methods
    function obj = hStatsLogger(param)
    %hStatsLogger Perform one-time calculations, initializes the properties
    %
    %   hStatsLogger(PARAM) is a constructor and initializes the properties
    %   of this class.
    %
    %   PARAM is a structure with following fields
    %       Nodes               - It is a vector of node objects.
    %       NodeNames (optional)- It is a string array. Each element in
    %       the array represents the name given to a node. By default,
    %       node names are like Node1, Node2 ... NodeN.

        obj.NumNodes = numel(param.Nodes);
        if isfield(param, 'NodeNames')
            obj.NodeNames = param.NodeNames;
        else
            obj.NodeNames = cell(1, obj.NumNodes);
            for n = 1:obj.NumNodes
                obj.NodeNames{n} = ['Node', num2str(param.Nodes{n}.NodeID)];
            end
        end
        obj.Nodes = param.Nodes;
        
        % Setup state transition visualization
        hPlotStateTransition(param);  
    end
    
    function statistics = getStatistics(obj, varargin)
    %getStatistics Returns the statistics of the simulation
    %
    %   [STATISTICS] = getStatistics(OBJ) Returns the statistics
    %
    %   STATISTICS is a cell array with 3 elements, where each element is a
    %   table containing statistics captured in a frequency. The first
    %   element corresponds to the lowest frequency and the last element
    %   corresponds to the highest frequency.
    %
    %   [STATISTICS] = getStatistics(OBJ, DISABLETABLEPOPUP)
    %   returns the statistics and specifies whether to pop up the figures
    %   or not for statistic tables.
        global TransmissionFail;
        global TransmissionData;
        global APFloor;
        
        numAPs = APFloor.numAP + APFloor.additionalNumAP;
        
        disableTablePopup = false;
        if numel(varargin) > 0
            disableTablePopup = varargin{1};
        end
        
        % Calculate the number of unique frequencies
        numNodes = obj.NumNodes;
        allFrequencies = cell(1, numNodes);
        for idx = 1:numNodes
            allFrequencies{idx} = obj.Nodes{idx}.Frequencies;
        end
        frequencies = unique([allFrequencies{:}]);
        numUniqueFreqs = numel(frequencies);
        
        % Initialize
        nodeNames = obj.NodeNames;
        statsLog = repmat(struct, numNodes, numUniqueFreqs);
        statistics = cell(1, numUniqueFreqs);
        
        for idx = 1:numNodes
            cntTransmission = 0;
            cntDelivery = 0;
            
            app = obj.Nodes{idx}.Application;
            mac = obj.Nodes{idx}.MAC;
            phyTx = obj.Nodes{idx}.PHYTx;
            phyRx = obj.Nodes{idx}.PHYRx;
            
            numInterfaces = numel(mac);
            for freqidx = 1:numInterfaces
                % Get all modules metrics
                phyRxMetrics = getMetricsList(phyRx(freqidx));
                phyTxMetrics = getMetricsList(phyTx(freqidx));
                macMetrics = getMetricsList(mac(freqidx));
                appMetrics = getMetricsList(app);
                operatingFreqID = mac(freqidx).OperatingFreqID;
                macPerACStats = {'MACInternalCollisionsAC', 'MACBackoffAC', 'MACTxAC', 'MACAggTxAC', 'MACTxRetriesAC', ...
                    'MACRxAC', 'MACAggRxAC', 'MACMaxQueueLengthAC', 'MACQueueoverflowAC', 'MACDuplicateRxAC'};

                if (mac(freqidx).MACAverageTimePerFrame ~= 0)
                    mac(freqidx).MACAverageTimePerFrame = mac(freqidx).MACAverageTimePerFrame/(mac(freqidx).MACDataTx);
                end
                
                if (app.AppRx(operatingFreqID) ~= 0)
                    app.AppAvgPacketLatency(operatingFreqID) = app.AppAvgPacketLatency(operatingFreqID)/(app.AppRx(operatingFreqID));
                end
                
                % Log metrics
                for statIdx = 1:numel(appMetrics)
                    statsLog(idx, operatingFreqID).ActiveOperationInFreq = 1;
                    statsLog(idx, operatingFreqID).(appMetrics{statIdx}) = app.(appMetrics{statIdx})(operatingFreqID);
                end
                for statIdx = 1:numel(macMetrics)
                    if ismember(macMetrics{statIdx}, macPerACStats)
                        statsLog = updatePerACStats(obj, macMetrics{statIdx}, mac(freqidx).(macMetrics{statIdx}), statsLog, idx, operatingFreqID);
                    else
                        statsLog(idx, operatingFreqID).(macMetrics{statIdx}) = mac(freqidx).(macMetrics{statIdx});
                    end
                end
%                 statsLog(idx, operatingFreqID).PacketLossRatio = 0;
%                 %if statsLog(idx, operatingFreqID).MACDataTx > 0
%                     %statsLog(idx, operatingFreqID).PacketLossRatio = (statsLog(idx, operatingFreqID).MACDataTx - statsLog(idx, operatingFreqID).MACTxSuccess)/statsLog(idx, operatingFreqID).MACDataTx;
%                 %end
%                 if ~isempty(obj.Nodes{idx}.SourceNode) && statsLog(obj.Nodes{idx}.SourceNode, operatingFreqID).MACDataTx > 0
%                     for j = 1:numel(TransmissionFail)
%                         if idx == TransmissionFail(j).DestinationSTA
%                             statsLog(idx, operatingFreqID).PacketLossRatio = (TransmissionFail(j).numRetries + TransmissionFail(j).numFails)/statsLog(obj.Nodes{idx}.SourceNode, operatingFreqID).MACDataTx;
%                         end
%                     end
%                 end
                
                % 추가 사항(PDR, PER)
                statsLog(idx, operatingFreqID).PacketDeliveryRatio = 0;
                %if statsLog(idx, operatingFreqID).MACDataTx > 0
                    %statsLog(idx, operatingFreqID).PacketDeliveryRatio = statsLog(idx, operatingFreqID).MACTxSuccess/statsLog(idx, operatingFreqID).MACDataTx;
                %end
                if ~isempty(obj.Nodes{idx}.SourceNode) && statsLog(obj.Nodes{idx}.SourceNode, operatingFreqID).MACDataTx > 0
                    for j = 1:numel(TransmissionData)
                        if idx == TransmissionData(j).DestinationStation
                            cntTransmission = cntTransmission + 1;
                            if TransmissionData(j).Result == "Success"
                                cntDelivery = cntDelivery + 1;
                            end
                        end
                    end
                    statsLog(idx, operatingFreqID).PacketDeliveryRatio = cntDelivery/cntTransmission;
                end
                
%                 statsLog(idx, operatingFreqID).PacketErrorRatio = 0;
%                 %if statsLog(idx, operatingFreqID).MACDataTx > 0
%                     %statsLog(idx, operatingFreqID).PacketErrorRatio = statsLog(idx, operatingFreqID).MACTxFails/statsLog(idx, operatingFreqID).MACDataTx;
%                 %end
%                 if ~isempty(obj.Nodes{idx}.SourceNode) && statsLog(obj.Nodes{idx}.SourceNode, operatingFreqID).MACDataTx > 0
%                     for j = 1:numel(TransmissionFail)
%                         if idx == TransmissionFail(j).DestinationSTA
%                             if isempty(TransmissionFail(j).numFails)
%                                 TransmissionFail(j).numFails = 0;
%                             end
%                             statsLog(idx, operatingFreqID).PacketErrorRatio = TransmissionFail(j).numFails/statsLog(obj.Nodes{idx}.SourceNode, operatingFreqID).MACDataTx;
%                         end
%                     end
%                 end
                
                if idx <= numAPs
                    statsLog(idx, operatingFreqID).Throughput = (statsLog(idx, operatingFreqID).MACTxBytes*8)/getCurrentTime(obj.Nodes{1}); % in Mbps
                else
                    statsLog(idx, operatingFreqID).Throughput = (statsLog(idx, operatingFreqID).AppRxBytes*8)/getCurrentTime(obj.Nodes{1}); % in Mbps
                end
                for statIdx = 1:numel(phyTxMetrics)
                    statsLog(idx, operatingFreqID).(phyTxMetrics{statIdx}) = phyTx(freqidx).(phyTxMetrics{statIdx});
                end
                for statIdx = 1:numel(phyRxMetrics)
                    statsLog(idx, operatingFreqID).(phyRxMetrics{statIdx}) = phyRx(freqidx).(phyRxMetrics{statIdx});
                end
            end
        end
 
        % Set the empty fields of the structures in the statistics cell
        % array to value 0
        allMetrics = fieldnames(statsLog(1, 1));
        for i = 1:numNodes
            for j = 1:numUniqueFreqs
                for k = 1:numel(allMetrics)
                    if isempty(statsLog(i, j).(allMetrics{k}))
                        statsLog(i, j).(allMetrics{k}) = 0;
                    end
                end
            end
        end
        % Fill statistics
        for i=1:numUniqueFreqs
            statistics{i} = struct2table(statsLog(1:numNodes, i),'RowNames',nodeNames);
        end

        if ~disableTablePopup
            for idx = 1:numUniqueFreqs
                tmp = table2array(statistics{idx});
                statisticsTable = array2table(tmp');
                statisticsTable.Properties.RowNames = statistics{idx}.Properties.VariableNames;
                statisticsTable.Properties.VariableNames = statistics{idx}.Properties.RowNames;
                activeNodes = find(statistics{idx}.ActiveOperationInFreq);
                bandAndChannel = obj.Nodes{activeNodes(1)}.BandAndChannel;
                if numUniqueFreqs > 1
                    if i > 3
                        disp(['Statistics table for band ', char(num2str(bandAndChannel{2}(1))), ' and channel number ', char(num2str(bandAndChannel{2}(2)))]);
                    else
                        disp(['Statistics table for band ', char(num2str(bandAndChannel{1}(1))), ' and channel number ', char(num2str(bandAndChannel{1}(2)))]);
                    end
                end
                statisticsTable %#ok<NOPRT>
            end
        end
    end
    
    function updateVisualization(~)
    %updateVisualization Refresh the visualization
        
        pause(0.0000001); % Let visualization refresh
    end
end

methods (Access = private)
    function statsLog = updatePerACStats(~, statStr, perACCounters, statsLog, nodeIdx, operatingFreqID)
        numACs = 4;
        for idx = 1:numACs
            perACStr = [statStr, num2str(48+idx, '%c')];
            statsLog(nodeIdx, operatingFreqID).(perACStr)= perACCounters(idx);
        end
    end
end
end
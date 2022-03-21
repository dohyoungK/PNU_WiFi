function [txs,rxs] = hCreateSitesFromNodes(nodeConfigs, APNames, APFloor)
%createSitesFromNodes Create transmitter and receiver sites
%   [TXS,RXS] = hCreateSitesFromNodes(NODECONFIGS) returns transmitter and
%   receiver sites for the given NumNodes length node configuration
%   structure array NODECONFIGS.
%
%   TXS and RXS are a NumFreq-by-NumNodes array containing the transmitter
%   and receiver sites for each unique frequency in the network. NumFreq is
%   the number of unique frequencies.

%   Copyright 2020-2021 The MathWorks, Inc.

% Initialize
numNodes = numel(nodeConfigs);

% Update the frequencies from the band and channel numbers
for nodeIdx = 1:numNodes
    config = nodeConfigs(nodeIdx);
    
    % Number of interfaces in the node
    numInterfaces = numel(config.BandAndChannel);
    for idx = 1:numInterfaces
        config.Frequency(idx) = ...
            hChannelToFrequency(config.BandAndChannel{idx}(2), config.BandAndChannel{idx}(1));
    end
    nodeConfigs(nodeIdx).Frequency = config.Frequency;
end

% Get node locattions (Assume same unit as triangulation unit)
nodeLocations = reshape([nodeConfigs.NodePosition],3,numNodes);

nodeFreqs = [nodeConfigs.Frequency];
uniqueFreqs = unique(nodeFreqs);
txs = repmat(txsite,numel(uniqueFreqs),numNodes);
%nodeNames = arrayfun(@(x)strcat(" Node",num2str(x)),1:numNodes);

APName = [];
if APFloor.floor == 1
    APName = APNames.firstFloor;
elseif APFloor.floor == 2
    APName = APNames.secondFloor;
elseif APFloor.floor == 3
    APName = APNames.thirdFloor;
end
if APFloor.additionalNumAP ~= 0
    for i = 1:APFloor.additionalNumAP
        APName = [APName strcat("Additional AP",num2str(i))];
    end
end

% 층 별 AP 개수
firstFloorNumAP = 0;
secondFloorNumAP = 0;
thirdFloorNumAP = 0;

for apIdx = 1:(APFloor.numAP+APFloor.additionalNumAP)
    if nodeConfigs(apIdx).NodePosition(3) == 2
        firstFloorNumAP = firstFloorNumAP + 1; 
    end
    if nodeConfigs(apIdx).NodePosition(3) == 6
        secondFloorNumAP = secondFloorNumAP + 1; 
    end
    if nodeConfigs(apIdx).NodePosition(3) == 10
        thirdFloorNumAP = thirdFloorNumAP + 1; 
    end
end

additionalCnt = 1;
if APFloor.floor == 0
    APName = APNames.firstFloor;
    if firstFloorNumAP-numel(APNames.firstFloor) ~= 0
        for i = 1:(firstFloorNumAP-numel(APNames.firstFloor))
            APName = [APName strcat("Additional AP",num2str(additionalCnt))];
            additionalCnt = additionalCnt + 1;
        end
    end
    
    APName = [APName APNames.secondFloor];
    if secondFloorNumAP-numel(APNames.secondFloor) ~= 0
        for i = 1:(secondFloorNumAP-numel(APNames.secondFloor))
            APName = [APName strcat("Additional AP",num2str(additionalCnt))];
            additionalCnt = additionalCnt + 1;
        end    
    end
    
    APName = [APName APNames.thirdFloor];
    if thirdFloorNumAP-numel(APNames.thirdFloor) ~= 0
        for i = 1:(thirdFloorNumAP-numel(APNames.thirdFloor))
            APName = [APName strcat("Additional AP",num2str(additionalCnt))];
            additionalCnt = additionalCnt + 1;
        end    
    end
end

STANames = arrayfun(@(x)strcat(" STA",num2str(x)),1:numNodes-APFloor.numAP-APFloor.additionalNumAP);
nodeNames = [APName STANames];
% Although we dont need a receiver site per frequency this allows other
% large scale parameters to be changed per interface as required.
rxs = repmat(rxsite,numel(uniqueFreqs),numNodes);
for i = 1:numel(uniqueFreqs)
    txs(i,:) = txsite("cartesian","Name",nodeNames,"AntennaPosition",nodeLocations,"TransmitterFrequency",uniqueFreqs(i)*1e9); % Frequencies are in GHz so convert to Hz
    rxs(i,:) = rxsite("cartesian","Name",nodeNames,"AntennaPosition",nodeLocations);
end

end
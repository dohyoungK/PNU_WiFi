function [nodeConfigs, trafficConfigs] = hLoadConfiguration(scenarioParameters, apPositions, staPositions, APFloor, APNames, numRx, getOriginResult)
%loadConfiguration Returns the node and traffic configuration
%   [NODECONFIGS, TRAFFICCONFIGS] = hLoadConfiguration(SCENARIO,
%   APPOSITIONS, STAPOSITIONS)
%
%   NODECONFIGS is an array of structures of type wlanNodeConfig. The array
%   size is equal to the number of nodes in the network, specifying MAC and
%   PHY configurations for all the nodes.
%
%   TRAFFICCONFIGS is an array of structures of type wlanTrafficConfig. The
%   array size is equal to the total number of receivers in the building,
%   specifying traffic generation for each destination.
%
%   SCENARIO is a structure specifying the following parameters:
%       BuildingLayout  - Layout in the form of [x,y,z] specifying number 
%                         of rooms in x-direction, number of rooms in 
%                         y-direction, and number of floors
%       RoomSize        - Size of the room in the form [x,y,z] in meters
%       NumRxPerRoom    - Number of stations per room
%
%   APPOSITIONS is an N-by-M array where N is the number of APs per room
%   and M is the number of floors. It holds the positions of the
%   transmitters (APs) in the scenario.
%
%   STAPOSITIONS is an N-by-M array where N is the number of STAs per room
%   and M is the number of floors. It holds the positions of the
%   receivers (STAs) in the scenario.

%   Copyright 2021 The MathWorks, Inc.

numAPs = APFloor.numAP + APFloor.additionalNumAP;
numSTAs = scenarioParameters.NumRx;
numNodes = numAPs + numSTAs;

% Get the node IDs and positions for all the nodes
[nodeIDs, positions] = hGetIDsAndPositions(scenarioParameters, apPositions, staPositions, APFloor);

% Load the application traffic configuration for WLAN nodes
s = load('wlanTrafficConfig.mat', 'wlanTrafficConfig');

% Configure application traffic such that each AP has traffic for all STAs
% present in same room.
trafficConfigs = repmat(s.wlanTrafficConfig, 1, numSTAs);

% % 층 별 AP 개수
% firstFloorNumAP = 0;
% secondFloorNumAP = 0;
% thirdFloorNumAP = 0;
% 
% for apIdx = 1:numAPs
%     if apPositions(apIdx,3) == 2
%         firstFloorNumAP = firstFloorNumAP + 1; 
%     end
%     if apPositions(apIdx,3) == 6
%         secondFloorNumAP = secondFloorNumAP + 1; 
%     end
%     if apPositions(apIdx,3) == 10
%         thirdFloorNumAP = thirdFloorNumAP + 1; 
%     end
% end

% % 층 별 AP 당 STA 개수
% numSTAsPerAP.firstFloor = ceil(sum(numRx.firstFloor)/firstFloorNumAP);
% numSTAsPerAP.secondFloor = ceil(sum(numRx.secondFloor)/secondFloorNumAP);
% numSTAsPerAP.thirdFloor = ceil(sum(numRx.thirdFloor)/thirdFloorNumAP);
% 
% for apIdx = 1:numAPs
%     if apPositions(apIdx,3) == 2
%         AP(apIdx).possibleSTA = numSTAsPerAP.firstFloor;
%     end
%     if apPositions(apIdx,3) == 6
%         AP(apIdx).possibleSTA = numSTAsPerAP.secondFloor;
%     end
%     if apPositions(apIdx,3) == 10
%         AP(apIdx).possibleSTA = numSTAsPerAP.thirdFloor;
%     end
% end
% 
% % STA를 가까운 AP와 연결(AP별로 균등하게)
% distance = [];
% if APFloor.floor == 0
%    for staIdx = 1:sum(numRx.firstFloor)
%         for apIdx = 1:firstFloorNumAP
%             distance = [distance norm(apPositions(apIdx)-staPositions(staIdx))];
%         end
%         for i = 1:numel(distance)
%             if min(distance) == distance(i)
%                 trafficConfigs(staIdx).SourceNode = i;
%                 trafficConfigs(staIdx).DestinationNode = numAPs + staIdx;
%                 AP(i).possibleSTA = AP(i).possibleSTA - 1;
%                 if AP(i).possibleSTA == 0
%                     apPositions(i,1) = 1000;
%                     apPositions(i,2) = 1000;
%                     apPositions(i,3) = 1000;
%                 end
%                 break
%             end
%         end
%         distance = [];
%     end
%     for staIdx = (sum(numRx.firstFloor)+1):(sum(numRx.firstFloor)+sum(numRx.secondFloor))
%         for apIdx = (firstFloorNumAP+1):(firstFloorNumAP+secondFloorNumAP)
%             distance = [distance norm(apPositions(apIdx)-staPositions(staIdx))];
%         end
%         for i = 1:numel(distance)
%             if min(distance) == distance(i)
%                 trafficConfigs(staIdx).SourceNode = firstFloorNumAP+i;
%                 trafficConfigs(staIdx).DestinationNode = numAPs + staIdx;
%                 AP(firstFloorNumAP+i).possibleSTA = AP(firstFloorNumAP+i).possibleSTA - 1;
%                 if AP(firstFloorNumAP+i).possibleSTA == 0
%                     apPositions(firstFloorNumAP+i,1) = 1000;
%                     apPositions(firstFloorNumAP+i,2) = 1000;
%                     apPositions(firstFloorNumAP+i,3) = 1000;
%                 end
%                 break
%             end
%         end
%         distance = [];
%     end
%    for staIdx = (sum(numRx.firstFloor)+sum(numRx.secondFloor)+1):(sum(numRx.firstFloor)+sum(numRx.secondFloor)+sum(numRx.thirdFloor))
%         for apIdx = (firstFloorNumAP+secondFloorNumAP+1):(firstFloorNumAP+secondFloorNumAP+thirdFloorNumAP)
%             distance = [distance norm(apPositions(apIdx)-staPositions(staIdx))];
%         end
%         for i = 1:numel(distance)
%             if min(distance) == distance(i)
%                 trafficConfigs(staIdx).SourceNode = firstFloorNumAP+secondFloorNumAP+i;
%                 trafficConfigs(staIdx).DestinationNode = numAPs + staIdx;
%                 AP(firstFloorNumAP+secondFloorNumAP+i).possibleSTA = AP(firstFloorNumAP+secondFloorNumAP+i).possibleSTA - 1;
%                 if AP(firstFloorNumAP+secondFloorNumAP+i).possibleSTA == 0
%                     apPositions(firstFloorNumAP+secondFloorNumAP+i,1) = 1000;
%                     apPositions(firstFloorNumAP+secondFloorNumAP+i,2) = 1000;
%                     apPositions(firstFloorNumAP+secondFloorNumAP+i,3) = 1000;
%                 end
%                 break
%             end
%         end
%         distance = [];
%     end
% end 
%      
% if APFloor.floor == 1 || APFloor.floor == 2 || APFloor.floor == 3
%     for staIdx = 1:numSTAs
%         for apIdx = 1:numAPs
%             distance = [distance norm(apPositions(apIdx)-staPositions(staIdx))];
%         end
%         for i = 1:numel(distance)
%             if min(distance) == distance(i)
%                 trafficConfigs(staIdx).SourceNode = i;
%                 trafficConfigs(staIdx).DestinationNode = numAPs + staIdx;
%                 AP(i).possibleSTA = AP(i).possibleSTA - 1;
%                 if AP(i).possibleSTA == 0
%                     apPositions(i,1) = 1000;
%                     apPositions(i,2) = 1000;
%                     apPositions(i,3) = 1000;
%                 end
%                 break
%             end
%         end
%         distance = [];
%     end
% end



        

% 기존 ap와 sta 연결방식
apIdx = 1;
cfgIdx = 0;
if sum(numRx.firstFloor) > 0
    for nodeIdx = 1:length(numRx.firstFloor)
        % Node IDs of AP and STAs present in apartment
        apID = apIdx;
        if(numRx.firstFloor(nodeIdx) > 0)
            for staIdx = 1:numRx.firstFloor(nodeIdx)    
                trafficConfigs(cfgIdx + staIdx).SourceNode = apID;
                trafficConfigs(cfgIdx + staIdx).DestinationNode = numAPs + cfgIdx + staIdx;
            end
            cfgIdx = cfgIdx + numRx.firstFloor(nodeIdx);
        end
        apIdx = apIdx + 1;
    end
end
if sum(numRx.secondFloor) > 0
    for nodeIdx = 1:length(numRx.secondFloor)
        % Node IDs of AP and STAs present in apartment
        apID = apIdx;
        if(numRx.secondFloor(nodeIdx) > 0)
            for staIdx = 1:numRx.secondFloor(nodeIdx)    
                trafficConfigs(cfgIdx + staIdx).SourceNode = apID;
                trafficConfigs(cfgIdx + staIdx).DestinationNode = numAPs + cfgIdx + staIdx;
            end
            cfgIdx = cfgIdx + numRx.secondFloor(nodeIdx);
        end
        apIdx = apIdx + 1;
    end
end
if sum(numRx.thirdFloor) > 0
    for nodeIdx = 1:length(numRx.thirdFloor)
        % Node IDs of AP and STAs present in apartment
        apID = apIdx;
        if(numRx.thirdFloor(nodeIdx) > 0)
            for staIdx = 1:numRx.thirdFloor(nodeIdx)    
                trafficConfigs(cfgIdx + staIdx).SourceNode = apID;
                trafficConfigs(cfgIdx + staIdx).DestinationNode = numAPs + cfgIdx + staIdx;
            end
            cfgIdx = cfgIdx + numRx.thirdFloor(nodeIdx);
        end
        apIdx = apIdx + 1;
    end
end

if ~getOriginResult
    % Association Algorithm
    staPerAp = struct;
    staPerAp = getStaPerAp(staPerAp, apPositions, trafficConfigs);

    interference = struct;
    for i = 1:size(staPositions,1)
        interference(i).apID = [];
        for j = 1:size(apPositions,1)
            if apPositions(j,3) == staPositions(i,3)
                dist = norm(apPositions(j,:)-staPositions(i,:));
                if dist < 20
                    interference(i).apID = [interference(i).apID j];
                end
            end
        end
    end

    for i = 1:size(staPositions,1)
        numAp = [];
        APID = 0;
        minimum = 0;
        if ~isempty(interference(i).apID)
            for j = 1:numel(interference(i).apID)
                ind = interference(i).apID(j);
                numAp = [numAp staPerAp(ind).numSTA];
            end
            minimum = min(numAp);

            for j = 1:numel(numAp)
                if minimum == numAp(j)
                    APID = interference(i).apID(j);
                end
            end

            for j = 1:numel(trafficConfigs)
                if trafficConfigs(j).DestinationNode == i+numAPs && trafficConfigs(j).SourceNode ~= APID
                    apid = trafficConfigs(j).SourceNode;
                    staPerAp(apid).numSTA = staPerAp(apid).numSTA - 1;

                    trafficConfigs(j).SourceNode = APID;
                    staPerAp(APID).numSTA = staPerAp(APID).numSTA + 1;
                end
            end
        end
    end
end


% Load the node configuration structure and initialize for all the nodes
s = load('wlanNodeConfig.mat', 'wlanNodeConfig');
nodeConfigs = repmat(s.wlanNodeConfig, 1, numNodes);

% Customize configuration for nodes
% Set node positions in each node configuration
for nodeIdx = 1:numNodes
    nodeID = nodeIDs(nodeIdx);
    nodeConfigs(nodeID).NodePosition = positions{nodeIdx};
    nodeConfigs(nodeID).ReceiverRange = 20;
end
end

function [nodeIDs, positions] = hGetIDsAndPositions(scenarioParameters, apPositions, staPositions, APFloor)
%hGetIDsAndPositions Returns the IDs and positions of nodes in the network
%
%   [NODEIDS, POSITIONS] = hGetIDsAndPositions(SCENARIO, APPOSITIONS,
%   STAPOSITIONS) returns the IDs and positions of nodes in the network.
%
%   NODEIDS is an array of size N x M where N is the number of rooms and M
%   is the number of nodes in a room. It contains the ID assigned to each
%   node.
%
%   POSITIONS is a cell array of size N x M where N is the number of rooms
%   and M is the number of nodes in each room. It contains the positions of
%   each node.
%
%   SCENARIO is a structure specifying the following parameters:
%       BuildingLayout  - Layout in the form of [x,y,z] specifying number 
%                         of rooms in x-direction, number of rooms in 
%                         y-direction, and number of floors
%       RoomSize        - Size of the room in the form [x,y,z] in meters
%       NumRxPerRoom    - Number of stations per room
%
%   APPOSITIONS is an N-by-M array where N is the number of APs per room
%   and M is the number of floors. It holds the positions of the
%   transmitters (APs) in the scenario.
%
%   STAPOSITIONS is an N-by-M array where N is the number of STAs per room
%   and M is the number of floors. It holds the positions of the
%   receivers (STAs) in the scenario.

%   Copyright 2020 The MathWorks, Inc.

numAPs = APFloor.numAP + APFloor.additionalNumAP;
numSTAs = scenarioParameters.NumRx;
% numAPPerRoom = 1; % One AP in each room
numNodes = numAPs + numSTAs;

% Each node in the building is identified by a node ID. Node IDs 1 to N are
% assigned to the APs, where N is the number of APs in building. Node IDs
% (N + 1) to (N + M) are assigned to stations where M is the number of
% stations in the building.
apNodeIDs = (1:numAPs)';
staNodeIDs = (numAPs+1:numNodes);

% Initialize an array of size N x M where N is the number of rooms and M is
% the number of nodes in a room. This array will contain the IDs of nodes
% present in the network. Each row corresponds to a room.
nodeAPIDs = zeros(numAPs, 1);
nodeSTAIDs = zeros(numSTAs, 1);

% Initialize a cell array of size N x M where N is the number of rooms and
% M is the number of nodes in each room. The cells will contain the
% position of nodes present in the network. Each row corresponds to a room.
apPos = cell(numAPs, 1);
staPos = cell(numSTAs, 1);

% Assign IDs and positions to each node
nodeAPIDs(:, 1) = apNodeIDs;
for APIdx = 1:numAPs
    apPos{APIdx, 1} = apPositions(APIdx, :);
end

nodeSTAIDs(:, 1) = staNodeIDs;
for staIdx = 1:numSTAs
    staPos{staIdx, 1} = staPositions(staIdx, :);
end

nodeIDs = [nodeAPIDs; nodeSTAIDs];
positions = [apPos; staPos];
end

function staPerAp = getStaPerAp(STAPerAP, apPositions, trafficConfigs)
for i = 1:size(apPositions,1)
    staPerAp(i).numSTA = 0;
    for j = 1:numel(trafficConfigs)
        if trafficConfigs(j).SourceNode == i
            staPerAp(i).numSTA = staPerAp(i).numSTA + 1;
        end
    end
end
end
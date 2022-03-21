function [txPositions, rxPositions] = hDropNodes(scenario, APFloor, numRx)
%hDropNodes Returns random node positions based on scenario
%
%   [TXPOSITIONS, RXPOSITIONS] = hDropNodes(SCENARIO) generates and returns
%   random positions to the transmitter and receiver nodes in the network.
%
%   TXPOSITIONS is an N-by-M array where N is the number of APs per room
%   and M is the number of floors. It holds the positions of the
%   transmitters (APs) in the scenario.
%
%   RXPOSITIONS is an N-by-M array where N is the number of STAs per room
%   and M is the number of floors. It holds the positions of the
%   receivers (STAs) in the scenario.
%
%   SCENARIO is a structure specifying the following parameters:
%       BuildingLayout  - Layout in the form of [x,y,z] specifying number 
%                         of rooms in x-direction, number of rooms in 
%                         y-direction, and number of floors
%       RoomSize        - Size of the room in the form [x,y,z] in meters
%       NumRxPerRoom    - Number of stations per room

%   Copyright 2021 The MathWorks, Inc.

% AP Positioning
    numTx1F = 3; 
    numTx2F = 8;
    numTx3F = 6;
    
    numRx1F = sum(numRx.firstFloor,2);
    numRx2F = sum(numRx.secondFloor,2);
    numRx3F = sum(numRx.thirdFloor,2);

    Height = scenario.RoomSize(1,3)/2;
    
    tx_x1 = [14; 27; 38];
    tx_x2 = [15; 35; 20; 35; 50; 30; 10; 10];
    tx_x3 = [10; 30; 25; 10; 30; 40];
    
    tx_y1 = [18; 27; 35];
    tx_y2 = [35; 35; 10; 15; 35; 25; 10; 25];
    tx_y3 = [25; 35; 10; 10; 25; 15];
    
    if APFloor.floor == 1
        x0 = tx_x1;
        y0 = tx_y1;
        z0 = [zeros(numTx1F,1) + Height];
        z1 = [zeros(numRx1F,1)];
    elseif APFloor.floor == 2
        x0 = tx_x2;
        y0 = tx_y2;
        z0 = [zeros(numTx2F,1) + Height*3];
        z1 = [zeros(numRx2F,1) + 6];
    elseif APFloor.floor == 3
        x0 = tx_x3;
        y0 = tx_y3;
        z0 = [zeros(numTx3F,1) + Height*5];
        z1 = [zeros(numRx3F,1) + 10];
    else
        x0 = [tx_x1; %1F
            tx_x2; %2F
            tx_x3]; %3F 
        y0 = [tx_y1; %1F
            tx_y2; %2F
            tx_y3]; %3F    
        z0 = [zeros(numTx1F,1) + Height; zeros(numTx2F,1) + Height*3; zeros(numTx3F,1) + Height*5];
        z1 = [zeros(numRx1F,1) + 2; zeros(numRx2F,1) + 6; zeros(numRx3F,1) + 10];
    end
    
    txPositions = [x0, y0, z0];
    
    
% STA Positioning
    rx_x1 = zeros(numRx1F,1);
    rx_x2 = zeros(numRx2F,1);
    rx_x3 = zeros(numRx3F,1);
    
    rx_y1 = [];
    rx_y2 = [];
    rx_y3 = [];
    
    x1 = [];
    y1 = [];
    % z1은 위에서 tx와 같이 초기화
    
% Receiver Range에 따른 각 AP에 STA 랜덤 뿌리기 
    if (APFloor.floor == 0) || (APFloor.floor == 1)
        for i = 1:numel(numRx.firstFloor)
            if(numRx.firstFloor(i) ~= 0)
                for j = 1:numRx.firstFloor(i)
                    distance = 1000;
                    while(distance > scenario.ReceiverRange)
                        rx_x1(j,1) = 60 * rand(1);
                        if(rx_x1(j,1) < 8)
                            rx_y1(j,1) = 33 * rand(1);
                        elseif(rx_x1(j,1) < 15)
                            rx_y1(j,1) = 45 * rand(1);
                        elseif(rx_x1(j,1) < 28)
                            rx_y1(j,1) = 60 * rand(1);
                        elseif(rx_x1(j,1) < 40)
                            rx_y1(j,1) = 50*rand(1) + 10;
                        elseif(rx_x1(j,1) < 52)
                            rx_y1(j,1) = 34*rand(1) + 26;
                        else
                            rx_y1(j,1) = 24*rand(1) + 36;
                        end
                        txPosition = [tx_x1(i,1), tx_y1(i,1), 2];
                        nodePosition = [rx_x1(j,1), rx_y1(j,1), 2];
                        distance = norm(txPosition - nodePosition);
                    end
                    x1 = [x1; rx_x1(j,1)];
                    y1 = [y1; rx_y1(j,1)];
                end
            end
        end
    end
    
    if (APFloor.floor == 0) || (APFloor.floor == 2)
        for i = 1:numel(numRx.secondFloor)
            if(numRx.secondFloor(i) ~= 0)
                for j = 1:numRx.secondFloor(i)
                    distance = 1000;
                    while(distance > scenario.ReceiverRange)
                        rx_x2(j,1) = 60 * rand(1);
                        if(rx_x2(j,1) < 8)
                            rx_y2(j,1) = 33 * rand(1);
                        elseif(rx_x2(j,1) < 15)
                            rx_y2(j,1) = 45 * rand(1);
                        elseif(rx_x2(j,1) < 28)
                            rx_y2(j,1) = 60 * rand(1);
                        elseif(rx_x2(j,1) < 40)
                            rx_y2(j,1) = 50*rand(1) + 10;
                        elseif(rx_x2(j,1) < 52)
                            rx_y2(j,1) = 34*rand(1) + 26;
                        else
                            rx_y2(j,1) = 27*rand(1) + 33;
                        end
                        txPosition = [tx_x2(i,1), tx_y2(i,1), 6];
                        nodePosition = [rx_x2(j,1), rx_y2(j,1), 6]; 
                        distance = norm(txPosition - nodePosition);
                    end
                    x1 = [x1; rx_x2(j,1)];
                    y1 = [y1; rx_y2(j,1)];
                end
            end
        end
    end
    
    if (APFloor.floor == 0) || (APFloor.floor == 3)
        for i = 1:numel(numRx.thirdFloor)
            if(numRx.thirdFloor(i) ~= 0)
                for j = 1:numRx.thirdFloor(i)
                    distance = 1000;
                    while(distance > scenario.ReceiverRange)
                        rx_x3(j,1) = 60 * rand(1);
                        if(rx_x3(j,1) < 8)
                            rx_y3(j,1) = 33 * rand(1);
                        elseif(rx_x3(j,1) < 15)
                            rx_y3(j,1) = 45 * rand(1);
                        elseif(rx_x3(j,1) < 28)
                            rx_y3(j,1) = 60 * rand(1);
                        elseif(rx_x3(j,1) < 44)
                            rx_y3(j,1) = 55*rand(1) + 5;
                        elseif(rx_x3(j,1) < 52)
                            rx_y3(j,1) = 34*rand(1) + 26;
                        else
                            rx_y3(j,1) = 24*rand(1) + 36;
                        end
                        txPosition = [tx_x3(i,1), tx_y3(i,1), 10];
                        nodePosition = [rx_x3(j,1), rx_y3(j,1), 10]; 
                        distance = norm(txPosition - nodePosition);
                    end
                    x1 = [x1; rx_x3(j,1)];
                    y1 = [y1; rx_y3(j,1)];
                end
            end
        end
    end
    
    rxPositions = [x1, y1, z1];
end
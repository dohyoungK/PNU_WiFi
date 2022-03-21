function hPlotNetworkStats(statistics, wlanNodes, nodeConfigs, trafficConfigs, expectedThroughput, getOriginResult, simulationTime)
%hPlotNetworkStats Plots throughput, packet loss ratio, and latencies at
%each node

%   Copyright 2021 The MathWorks, Inc.
global APFloor
numAP = APFloor.numAP + APFloor.additionalNumAP;

for idx = 1:numel(statistics)
    %statistics{idx}([1:numAP],:) = [];
    if idx == 1
        throughput = statistics{idx}.Throughput;
        pdr = statistics{idx}.PacketDeliveryRatio;
    else
        throughput = throughput + statistics{idx}.Throughput;
        pdr = pdr + statistics{idx}.PacketDeliveryRatio;
    end
end

ratio = struct;
for i = 1:numAP
    datarate = 0;
    ratio(i).tRatio = 1;

    if nodeConfigs(i).Bandwidth == 20
        datarate = 52;
    elseif nodeConfigs(i).Bandwidth == 40
        datarate = 108;
    else
        datarate = 234;
    end

    if throughput(i) >= datarate
        ratio(i).tRatio = datarate / throughput(i); 
    end

    for j = 1:numel(trafficConfigs)
        if trafficConfigs(j).SourceNode == i
            throughput(trafficConfigs(j).DestinationNode) = throughput(trafficConfigs(j).DestinationNode) * ratio(i).tRatio;
        end
    end
end

throughput([1:numAP]) = [];
pdr([1:numAP]) = [];

if getOriginResult 
    save('OriginThroughput.mat', 'throughput');
    save('OriginPDR.mat', 'pdr')
else
    originThroughput = load('OriginThroughput.mat', 'throughput');
    originPDR = load('OriginPDR.mat', 'pdr');
end

throughputSecond = throughput;
pdrSecond = pdr;
for i = 1:numel(throughput)
    if ~getOriginResult
        throughput(i,2) = throughput(i,1);
        throughput(i,1) = originThroughput.throughput(i);
        throughputSecond(i,2) = throughputSecond(i,1);
        throughputSecond(i,1) = expectedThroughput(i);
        
        pdr(i,2) = pdr(i,1);
        pdr(i,1) = originPDR.pdr(i);
    end
end

if ~getOriginResult
    % 기존 건물과 비교
    figure;
    % Plot the throughput at each node
    s1 = subplot(15, 1, 1:4);
    bar(s1, throughput);
    plotTitle = 'Comparision of Original Throughput and Simulated Throughput at each receiver';
    title(gca, plotTitle);
    legend('Original Throughput', 'Simulation Throughput', 'Location', 'Best');

    xlabel(gca, 'STATION ID');
    ylabel(gca, 'Throughput (Mbps)');
    xticks(1:numel(throughput));
    hold on;
    
    % Plot the packet delivery ratio at each node
    s3 = subplot(15, 1, 9:12);
    bar(s3, pdr);
    plotTitle = 'Comparision of Original Packet Delivery Ratio and Simulated Packet Delivery Ratio at each receiver';
    plotTitle = 'Packet Delivery Ratio at each receiver';
    title(gca, plotTitle);
    legend('Original PDR', 'Simulation PDR', 'Location', 'Best');

    xlabel(gca, 'STATION ID');
    ylabel(gca, 'Packet Delivery Ratio');
    xticks(1:numel(pdr));
    hold off;

    % 예상 처리량과 비교
    figure;
    % Plot the throughput at each node
    s1 = subplot(15, 1, 1:4);
    bar(s1, throughputSecond);
    plotTitle = 'Comparision of Expected Throughput and Simulated Throughput at each receiver';
    title(gca, plotTitle);
    legend('Expected Throughput', 'Simulation Throughput', 'Location', 'Best');

    xlabel(gca, 'STATION ID');
    ylabel(gca, 'Throughput (Mbps)');
    xticks(1:numel(throughputSecond));
    hold on;
    
    % Plot the packet delivery ratio at each node
    s3 = subplot(15, 1, 9:12);
    bar(s3, pdrSecond, 'r');
    plotTitle = 'Simulated Packet Delivery Ratio at each receiver';
    title(gca, plotTitle);

    xlabel(gca, 'STATION ID');
    ylabel(gca, 'Packet Delivery Ratio');
    xticks(1:numel(pdrSecond));
    hold off;
end
end


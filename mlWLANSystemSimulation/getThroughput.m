function expectedThroughput = getThroughput(nodeConfigs, trafficConfigs, APFloor)
    expectedThroughput = [];
    range = nodeConfigs(1).ReceiverRange;
    numAPs = APFloor.numAP + APFloor.additionalNumAP;
    numSTA = [];
    
    for i = 1:numAPs
        numSTA(i) = 0;
        for j = 1:numel(trafficConfigs)
            if trafficConfigs(j).SourceNode == i
                numSTA(i) = numSTA(i) + 1;
            end
        end
    end
        
    for i = 1:numAPs
        interferenceCnt = 0;
        for j = 1:numAPs
            dist = norm(nodeConfigs(i).NodePosition - nodeConfigs(j).NodePosition);
            if i ~= j && nodeConfigs(i).BandAndChannel{1}(2) == nodeConfigs(j).BandAndChannel{1}(2) && dist < range*2 %&& nodeConfigs(i).NodePosition(3) == nodeConfigs(j).NodePosition(3) 
                if numSTA(j) ~= 0
                    interferenceCnt = interferenceCnt + 1;
                end
            end
        end 
        
        for j = 1:numel(trafficConfigs)
            if trafficConfigs(j).SourceNode == i
                datarate = trafficConfigs(j).DataRateKbps/1000;
            end
        end
        
        if interferenceCnt ~= 0
            throughput = datarate / (numSTA(i)*interferenceCnt+1);
        else
            throughput = datarate / (numSTA(i));
        end
        for j = 1:numel(trafficConfigs)
            if trafficConfigs(j).SourceNode == i
                ind = trafficConfigs(j).DestinationNode - numAPs;
                expectedThroughput(ind) = throughput;
            end
        end
    end
end


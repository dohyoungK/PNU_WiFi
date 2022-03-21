function [nodeChannelConfigs, trafficConfig] = ChannelConfiguration(nodeConfigs, trafficConfigs, APFloor, numSTA, getOriginResult)
    range = nodeConfigs(1).ReceiverRange;
    numAPs = APFloor.numAP + APFloor.additionalNumAP;
    InterferenceAP = struct;
    fiveGHzInterferenceAP = struct;
    onlyTwoGHz = [14 18 2; 27 27 2; 35 35 6; 20 10 6; 35 15 6; 30 35 10; 25 10 10];
    
    if ~getOriginResult
        % 간섭 존재하는 ap 찾기
        for i = 1:numAPs
            nodeConfigs(i).BandAndChannel{1} = [];
            InterferenceAP(i).APID = [];
            fiveGHzInterferenceAP(i).APID = [];
            for j = 1:numAPs
                if i ~= j %&& nodeConfigs(i).NodePosition(3) == nodeConfigs(j).NodePosition(3)
                    distance = norm(nodeConfigs(i).NodePosition - nodeConfigs(j).NodePosition);
                    if distance < range*2
                        InterferenceAP(i).APID = [InterferenceAP(i).APID j];
                        if ~ismember(nodeConfigs(i).NodePosition ,onlyTwoGHz, 'rows') && ~ismember(nodeConfigs(j).NodePosition ,onlyTwoGHz, 'rows')
                            fiveGHzInterferenceAP(i).APID = [fiveGHzInterferenceAP(i).APID j];
                        end
                    end
                end
            end
        end

        twoGHz = [1 6 11];
        twoGHzCnt = 1;
        % 2.4GHz 채널 설정
        for i = 1:numAPs
            if isempty(nodeConfigs(i).BandAndChannel{1}) && ismember(nodeConfigs(i).NodePosition, onlyTwoGHz, 'rows')
                twoGHzCnt = mod(twoGHzCnt,3);
                if twoGHzCnt == 0
                    twoGHzCnt = 3;
                end
                nodeConfigs(i).BandAndChannel{1} = [2.4 twoGHz(twoGHzCnt)];
                twoGHzCnt = twoGHzCnt + 1;
                if ~isempty(InterferenceAP(i).APID)
                    for j = 1:numel(InterferenceAP(i).APID)
                        nodeIdx = InterferenceAP(i).APID(j);
                        if isempty(nodeConfigs(nodeIdx).BandAndChannel{1}) && ismember(nodeConfigs(nodeIdx).NodePosition, onlyTwoGHz, 'rows')
                            twoGHzCnt = mod(twoGHzCnt,3);
                            if twoGHzCnt == 0
                                twoGHzCnt = 3;
                            end
                            nodeConfigs(nodeIdx).BandAndChannel{1} = [2.4 twoGHz(twoGHzCnt)];
                            twoGHzCnt = twoGHzCnt + 1;
                        end
                    end
                end
            end
        end

        % 5GHz 채널 설정
        fiveGHzCntFirst = 1;
        fiveGHzCntSecond = 4;
        fiveGHzCntThird = 8;
        for i = 1:numAPs
            if ~ismember(nodeConfigs(i).NodePosition, onlyTwoGHz, 'rows')
                if ~isempty(fiveGHzInterferenceAP(i).APID)
                    if numel(fiveGHzInterferenceAP(i).APID)+1 <= 2
                        fiveGHz = [42 58];
                        fiveGHzCntFirst = mod(fiveGHzCntFirst,2);
                        if fiveGHzCntFirst == 0
                            fiveGHzCntFirst = 2;
                        end
                        nodeConfigs(i).BandAndChannel{1} = [5 fiveGHz(fiveGHzCntFirst)];
                        nodeConfigs(i).Bandwidth = 80;
                        fiveGHzCntFirst = fiveGHzCntFirst + 1;
                        for j = 1:numel(fiveGHzInterferenceAP(i).APID)
                            fiveGHzCntFirst = mod(fiveGHzCntFirst,2);
                            if fiveGHzCntFirst == 0
                                fiveGHzCntFirst = 2;
                            end
                            nodeIdx = fiveGHzInterferenceAP(i).APID(j);
                            nodeConfigs(nodeIdx).BandAndChannel{1} = [5 fiveGHz(fiveGHzCntFirst)];
                            nodeConfigs(nodeIdx).Bandwidth = 80;
                            fiveGHzCntFirst = fiveGHzCntFirst + 1;
                        end
                    elseif numel(fiveGHzInterferenceAP(i).APID)+1 <= 4
                        fiveGHz = [38 46 54 62];
                        fiveGHzCntSecond = mod(fiveGHzCntSecond,4);
                        if fiveGHzCntSecond == 0
                            fiveGHzCntSecond = 4;
                        end
                        nodeConfigs(i).BandAndChannel{1} = [5 fiveGHz(fiveGHzCntSecond)];
                        nodeConfigs(i).Bandwidth = 40;
                        fiveGHzCntSecond = fiveGHzCntSecond - 1;
                        for j = 1:numel(fiveGHzInterferenceAP(i).APID)
                            fiveGHzCntSecond = mod(fiveGHzCntSecond,4);
                            if fiveGHzCntSecond == 0
                                fiveGHzCntSecond = 4;
                            end
                            nodeIdx = fiveGHzInterferenceAP(i).APID(j);
                            nodeConfigs(nodeIdx).BandAndChannel{1} = [5 fiveGHz(fiveGHzCntSecond)];
                            nodeConfigs(nodeIdx).Bandwidth = 40;
                            fiveGHzCntSecond = fiveGHzCntSecond - 1;
                        end
                    else
                        fiveGHz = [36 40 44 48 52 56 60 64];
                        fiveGHzCntThird = mod(fiveGHzCntThird,8);
                        if fiveGHzCntThird == 0
                            fiveGHzCntThird = 8;
                        end
                        nodeConfigs(i).BandAndChannel{1} = [5 fiveGHz(fiveGHzCntThird)];
                        nodeConfigs(i).Bandwidth = 20;
                        fiveGHzCntThird = fiveGHzCntThird - 1;
                        for j = 1:numel(fiveGHzInterferenceAP(i).APID)
                            fiveGHzCntThird = mod(fiveGHzCntThird,8);
                            if fiveGHzCntThird == 0
                                fiveGHzCntThird = 8;
                            end
                            nodeIdx = fiveGHzInterferenceAP(i).APID(j);
                            nodeConfigs(nodeIdx).BandAndChannel{1} = [5 fiveGHz(fiveGHzCntThird)];
                            nodeConfigs(nodeIdx).Bandwidth = 20;
                            fiveGHzCntThird = fiveGHzCntThird - 1;
                        end
                    end
                else
                    nodeConfigs(i).BandAndChannel{1} = [5 52];
                    nodeConfigs(i).Bandwidth = 80;
                end
            end
        end
    end
    
    for i = 1:numAPs
        for j = 1:numel(trafficConfigs)
            if trafficConfigs(j).SourceNode == i
                if nodeConfigs(i).Bandwidth == 20
                    trafficConfigs(j).DataRateKbps = 52000;
                elseif nodeConfigs(i).Bandwidth == 40
                    trafficConfigs(j).DataRateKbps = 108000;
                else
                    trafficConfigs(j).DataRateKbps = 234000;
                end                              
                nodeConfigs(trafficConfigs(j).DestinationNode).BandAndChannel = nodeConfigs(i).BandAndChannel;
                nodeConfigs(trafficConfigs(j).DestinationNode).Bandwidth = nodeConfigs(i).Bandwidth;
            end
        end
    end

    trafficConfig = trafficConfigs;
    nodeChannelConfigs = nodeConfigs;    
end


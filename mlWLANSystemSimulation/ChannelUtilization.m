function channelUtil = ChannelUtilization(wlanNodes)
    twoGHzChannel = [1 6 11];
    fiveGHzChannel = [36 40 44 48 52 56 60 64];
    
    channelUtil = struct;
    for i = 1:numel(twoGHzChannel)
        channelUtil(i).channel = twoGHzChannel(i);
        channelUtil(i).AP = [];
        for nodeIdx = 1:numel(wlanNodes)
            if channelUtil(i).channel == wlanNodes{1,nodeIdx}.BandAndChannel{1}(2)
                channelUtil(i).AP = [channelUtil(i).AP; wlanNodes{1,nodeIdx}.NodeID];
            end
        end
    end
    
    for i = 1:numel(fiveGHzChannel)
        channelUtil(i+3).channel = fiveGHzChannel(i);
        channelUtil(i+3).AP = [];
        for nodeIdx = 1:numel(wlanNodes)
            if channelUtil(i+3).channel == wlanNodes{1,nodeIdx}.BandAndChannel{1}(2)
                channelUtil(i+3).AP = [channelUtil(i+3).AP; wlanNodes{1,nodeIdx}.NodeID];
            end
        end
    end
end


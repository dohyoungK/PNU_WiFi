function status = isIntraBSSFrame(~, rxCfg, bssID)
%isIntraBSSFrame Determines whether the received frame is intra-BSS frame
%
% STATUS = isIntraBSSFrame(OBJ, RXCFG, BSSID) returns STATUS as true if the
% received frame is intra-BSS, otherwise returns false. OBJ is the object
% of type hEDCAMAC. RXCFG is the MAC frame configuration object of the
% received frame. BSSID is the basic service set identifier.

%   Copyright 2021 The MathWorks, Inc.

status = false;

bssid = [2 hex2dec(reshape(extractAfter(bssID, 2), 2, 5)')'];

% QoS Data frame or Data frame
if strcmp(rxCfg.FrameType, 'QoS Data') || strcmp(rxCfg.FrameType, 'Data')
    if strcmp(rxCfg.Address1, reshape(dec2hex(bssid, 2)', 1, [])) || ...
            strcmp(rxCfg.Address2, reshape(dec2hex(bssid, 2)', 1, [])) || ...
            strcmp(rxCfg.Address3, reshape(dec2hex(bssid, 2)', 1, []))
        status = true;
    end
elseif strcmp(rxCfg.FrameType, 'RTS') || strcmp(rxCfg.FrameType, 'Block Ack')
    % RTS frame or Block Ack frame
    if strcmp(rxCfg.Address1, reshape(dec2hex(bssid, 2)', 1, [])) || ...
            strcmp(rxCfg.Address2, reshape(dec2hex(bssid, 2)', 1, []))
        status = true;
    end
elseif strcmp(rxCfg.FrameType, 'CTS') || strcmp(rxCfg.FrameType, 'ACK')
    % CTS frame or ACK frame
    if strcmp(rxCfg.Address1, reshape(dec2hex(bssid, 2)', 1, []))
        status = true;
    end
end
end

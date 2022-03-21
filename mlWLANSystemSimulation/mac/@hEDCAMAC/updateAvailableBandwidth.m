function updateAvailableBandwidth(edcaMAC, phyIndication)
%updateAvailableBandwidth Update the available bandwidth based on CCA indication
%   updateAvailableBandwidth(EDCAMAC, PHYINDICATION) updates the available
%   bandwidth based on CCA state indication.
%
%   EDCAMAC is an object of type hEDCAMAC
%
%   PHYINDICATION is the CCA state indication received from PHY. This is a
%   structure of type hEDCAMAC.EmptyPHYIndication.

%   Copyright 2021 The MathWorks, Inc.

if phyIndication.MessageType == hPHYPrimitivesEnum.CCABusyIndication
    edcaMAC.AvailableBandwidth = 0;
else % phyIndication.MessageType == hPHYPrimitivesEnum.CCAIdleIndication
    edcaMAC.AvailableBandwidth = phyIndication.ChannelBandwidth;
end

end

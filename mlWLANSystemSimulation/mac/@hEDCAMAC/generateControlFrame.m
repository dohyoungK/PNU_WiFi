function [frameToPHY, controlFrameLength] = generateControlFrame(edcaMAC, controlFrameData)
%generateControlFrame Generates and returns a MAC control frame and its
%length
%   [FRAMETOPHY, CONTROLFRAMELENGTH] = generateControlFrame(EDCAMAC,
%   CONTROLFRAMEDATA) generates a control frame, and returns the frame
%   along with its length.
%
%   FRAMETOPHY is a structure of type hEDCAMAC.EmptyFrame, indicates
%   the MAC control frame passed to PHY transmitter.
%
%   CONTROLFRAMELEN is an integer, indicates the length of the control
%   frame, in bytes.
%
%   EDCAMAC is an object of type hEDCAMAC.
%
%   CONTROLFRAMEDATA is a structure with the information about the
%   generated control frame.

%   Copyright 2021 The MathWorks, Inc.

frameToPHY = edcaMAC.EmptyFrame;
frameToPHY.IsEmpty = false;
macFrame = edcaMAC.EmptyMACFrame;
macFrame.IsEmpty = false;
numSubframes = 1;

switch controlFrameData.FrameType
    case 'RTS'
        controlFrameLength = 20;
    case {'CTS', 'ACK'}
        controlFrameLength = 14;
    otherwise % Block Ack
        if edcaMAC.BABitmapLength == 64
            controlFrameLength = 32;
        else % edcaMAC.BABitmapLength == 256
            controlFrameLength = 56;
        end
        macFrame.TID = controlFrameData.TID;
        macFrame.SequenceNumber(1,1) = controlFrameData.SSN;
        macFrame.BABitmap = controlFrameData.BABitmap;
end

macFrame.FrameType = controlFrameData.FrameType;
macFrame.FrameFormat = 'Non-HT';
macFrame.Address1 = controlFrameData.Address1;
macFrame.Address2 = controlFrameData.Address2;
macFrame.Duration = controlFrameData.Duration;
macFrame.MPDULength(numSubframes, edcaMAC.UserIndexSU) = controlFrameLength;
macFrame.PSDULength(edcaMAC.UserIndexSU) = controlFrameLength;
macFrame.FCSPass(numSubframes, edcaMAC.UserIndexSU) = true;

dataFrame = [];
% Return output frame
frameToPHY.MACFrame = macFrame;
frameToPHY.Data(1:numel(dataFrame), edcaMAC.UserIndexSU) = dataFrame;
frameToPHY.PSDULength(edcaMAC.UserIndexSU) = controlFrameLength;
frameToPHY.SubframeBoundaries(numSubframes, :, edcaMAC.UserIndexSU) = [1, controlFrameLength];
frameToPHY.NumSubframes(edcaMAC.UserIndexSU) = numSubframes;

end

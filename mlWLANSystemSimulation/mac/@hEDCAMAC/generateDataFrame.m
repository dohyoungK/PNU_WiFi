function frameToPHY = generateDataFrame(edcaMAC, retry, durationField, frameData, userIdx)
%generateDataframe Generates and returns a MAC data frame
%
%   FRAMETOPHY = generateDataframe(EDCAMAC, RETRY, DURATIONFIELD,
%   FRAMEDATA) generates and returns the data frame PSDU and its
%   information.
%
%   FRAMETOPHY is a structure of type hEDCAMAC.EmptyFrame, indicates
%   the MAC data frame passed to PHY transmitter.
%
%   EDCAMAC is an object of type hEDCAMAC.
%
%   RETRY is boolean flag, indicates the retransmission value for the
%   frame.
%
%   DURATIONFIELD is an integer, indicates the estimated time (in micro
%   seconds) to transmit the frame(s).
%
%   FRAMEDATA is a structure indicates the transmission frame dequeued from
%   MAC queue.

%   Copyright 2021 The MathWorks, Inc.

tx = edcaMAC.Tx;

% User index for single user processing.
userIndexSU = edcaMAC.UserIndexSU;

% Initialize output frame
frameToPHY = edcaMAC.EmptyFrame;
frameToPHY.IsEmpty = false;
macFrame = edcaMAC.EmptyMACFrame;
macFrame.IsEmpty = false;

subframeBoundaries = zeros(edcaMAC.MaxSubframes, 2);

% Generate MAC frame
if ~edcaMAC.MPDUAggregation
    % Fill sub frames information. In case of MPDU consider it as single
    % subframe
    numMPDUs = 1;
    numSubframes = numMPDUs;
    subframeBoundaries(1, :) = [1, tx.TxPSDULength(userIdx)];
    
else % Aggregated frame of format HT, VHT, HE-SU, or HE-EXT-SU
    % Number of MPDUs being transmitted in the A-MPDU. Since there is no
    % MSDU aggregation (A-MSDU) each A-MPDU subframe consists only one
    % MSDU.
    numMPDUs = frameData.MSDUCount;
    numSubframes = numMPDUs;
    subframeStartIndex = 1;
    for idx = 1:numMPDUs
        subframeBoundaries(idx, 1) = subframeStartIndex;
        subframeBoundaries(idx, 2) = tx.TxMPDULengths(idx, userIdx);
        subframeStartIndex = subframeStartIndex + tx.TxSubframeLengths(idx, userIdx);
    end
end

retryList = repmat(retry, 1, numMPDUs);
macFrame.FrameType = 'QoS Data';
macFrame.Address1 = frameData.DestinationMACAddress;
macFrame.Address2 = edcaMAC.MACAddress;
isGroupAddr = isGroupAddress(edcaMAC, macFrame.Address1);
macFrame.FourAddressFrame(1:numMPDUs, userIndexSU) = frameData.FourAddressFrame(1:numMPDUs);
for idx = 1:numMPDUs
    if macFrame.FourAddressFrame(idx, userIndexSU)
        macFrame.Address3(idx, :, userIndexSU) = frameData.MeshDestinationAddress(idx, :);
        macFrame.Address4(idx, :, userIndexSU) = frameData.MeshSourceAddress(idx, :);
    else
        macFrame.Address3(idx, :, userIndexSU) = edcaMAC.BSSID;
        if isGroupAddr
            macFrame.Address3(idx, :, userIndexSU) = frameData.MeshSourceAddress(idx, :);
        end
    end
    macFrame.MeshSequenceNumber(idx, userIndexSU) = frameData.MeshSequenceNumber(idx);
    macFrame.FCSPass(idx, userIndexSU) = true;
    macFrame.DelimiterFails(idx, userIndexSU) = false;
end
macFrame.Duration = durationField;
macFrame.TID = edcaMAC.AC2TID(frameData.AC+1);
macFrame.SequenceNumber(1:numMPDUs) = tx.TxSequenceNumbers(1:numMPDUs);
macFrame.Retransmission(1:numMPDUs) = retryList;
macFrame.MPDUAggregation = edcaMAC.MPDUAggregation;
macFrame.MPDULength = tx.TxMPDULengths(:, userIdx);
macFrame.PSDULength(userIndexSU) = tx.TxPSDULength(userIdx);
macFrame.PayloadLength(1:numMPDUs, userIndexSU) = frameData.MSDULength(1:numMPDUs);

if edcaMAC.DisableAck || isGroupAddr
    macFrame.AckPolicy = 'No Ack';
else
    macFrame.AckPolicy = 'Normal Ack/Implicit Block Ack Request';
end

switch edcaMAC.TxFormat
    case hFrameFormatsEnum.HTMixed
        macFrame.FrameFormat = 'HT-Mixed';
    case hFrameFormatsEnum.VHT
        macFrame.FrameFormat = 'VHT';
    case hFrameFormatsEnum.HE_SU
        macFrame.FrameFormat = 'HE-SU';
    case hFrameFormatsEnum.HE_EXT_SU
        macFrame.FrameFormat = 'HE-EXT-SU';
    case hFrameFormatsEnum.HE_MU
        macFrame.FrameFormat = 'HE-MU';
end

dataFrame = [];

% Return output frame
frameToPHY.MACFrame = macFrame;
frameToPHY.Data(1:numel(dataFrame), userIndexSU) = dataFrame;
frameToPHY.PSDULength(userIndexSU) = tx.TxPSDULength(userIdx);
frameToPHY.Timestamp(1:numMPDUs, userIndexSU) = frameData.Timestamp(1:numMPDUs);
frameToPHY.SubframeBoundaries(:, :, userIndexSU) = subframeBoundaries;
frameToPHY.NumSubframes(userIndexSU) = numSubframes;
end

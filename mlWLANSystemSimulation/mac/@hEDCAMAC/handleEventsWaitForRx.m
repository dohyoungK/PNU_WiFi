function nextInvokeTime = handleEventsWaitForRx(obj, phyIndication, elapsedTime)
%handleEventsWaitForRx Runs MAC Layer state machine for receiving
%response frames
%
%   This function performs the following operations:
%   1. Waits for response frames of data and RTS.
%   2. If it doesn't receive any frame within timeout duration,
%      try to retransmit that particular data or RTS frame again.
%   3. Discards packet from retransmission buffer, if maximum
%      retransmission limit is reached.
%   4. Moves to EIFS state, if it receives an error.
%   5. Moves to Rx state, if it receives any frame other than ACK/CTS/BA.
%
%   NEXTINVOKETIME = handleEventsWaitForRx(OBJ, PHYINDICATION,
%   ELAPSEDTIME) performs MAC Layer wait for rx actions.
%
%   NEXTINVOKETIME returns the time (in microseconds) after which the
%   run function must be invoked again.
%
%   PHYINDICATION is indication from PHY Layer.
%
%   ELAPSEDTIME is the time elapsed in microseconds between the
%   previous and current call of this function.

%   Copyright 2021 The MathWorks, Inc.

% Initialize
nextInvokeTime = obj.SlotTime;

% Process if there is any indication received from PHY layer
if ~phyIndication.IsEmpty
    isFail = handlePhyIndicationWaitForRx(obj, phyIndication);
    updateTxStatus(obj, isFail);
    if obj.MACState ~= obj.WAITFORRX_STATE
        nextInvokeTime = obj.NextInvokeTime*(obj.NextInvokeTime > 0);
        return;
    end
end

% Update response timeout counter
obj.Rx.WaitForResponseTimer = obj.Rx.WaitForResponseTimer - elapsedTime;
if obj.Rx.WaitForResponseTimer > 0
    nextInvokeTime = obj.Rx.WaitForResponseTimer;
end

% Process if any response frame is received
if ~(obj.RxData.IsEmpty)
    isFail = processResponse(obj, obj.RxData.MACFrame);
    nextInvokeTime = 0;
    updateTxStatus(obj, isFail);
    return;
end

if obj.Rx.WaitForResponseTimer <= 0
    isFail = handleResponseTimeout(obj);
    updateTxStatus(obj, isFail);
end

end

function updateTxStatus(obj, isFail)
%updateTxStatus Update transmission status to the rate control algorithm
%   updateTxStatus(OBJ, ISFAIL) updates the transmission status to the
%   configured rate control algorithm.
%
%   ISFAIL is a flag indicating whether the transmission has failed 

tx = obj.Tx;
rx = obj.Rx;

TransmissionInfo = struct;

% Update transmission status to rate control algorithm
if all(isFail >= 0)
    % Fill the required Tx status info for rate control algorithm
    rateControlInfo = obj.RateControl.TxStatusInfo;
    rateControlInfo.IsFail = isFail;
    rateControlInfo.RSSI = rx.RxRSSI;
    if tx.WaitingForCTS
        % RTS transmission status
        rateControlInfo.FrameType = 'Control';
        % Reset waiting For CTS flag
        tx.WaitingForCTS = false;
    else
        % Data transmission status
        rateControlInfo.FrameType = 'Data';
        if tx.IsShortFrame
            rateControlInfo.NumRetries = tx.ShortRetries(obj.DestinationStationID, obj.OwnerAC+1);
        else
            rateControlInfo.NumRetries = tx.LongRetries(obj.DestinationStationID, obj.OwnerAC+1);
        end
    end
    updateStatus(obj.RateControl, obj.DestinationStationID, rateControlInfo);
    
    % 전송 내역
    TransmissionInfo.SourceAP = obj.NodeID;
    TransmissionInfo.DestinationStation = obj.DestinationStationID;
    %if MACTxFails
    if ~rateControlInfo.IsFail
        TransmissionInfo.Result = "Success";
    else
        TransmissionInfo.Result = "Fail";
        TransmissionInfo.NumRetry = rateControlInfo.NumRetries;
    end
    updateTransmissionData(TransmissionInfo);
end
end

function updateTransmissionData(TransmissionInfo)
    global TransmissionData;
    idx = size(TransmissionData,2);
    
    if TransmissionData(idx).SourceAP ~= 0
        idx = idx + 1;
    end
    
    TransmissionData(idx).SourceAP = TransmissionInfo.SourceAP;
    TransmissionData(idx).DestinationStation = TransmissionInfo.DestinationStation;
    TransmissionData(idx).Result = TransmissionInfo.Result;
    
    if TransmissionInfo.Result == "Fail"
        if TransmissionInfo.NumRetry ~= 0
            TransmissionData(idx).NumRetry = TransmissionInfo.NumRetry;
        else
            TransmissionData(idx).NumRetry = 7;
        end
    end
end

function isFail = handlePhyIndicationWaitForRx(edcaMAC, phyIndication)
%handlePhyIndicationWaitForRx handles physical layer indication in wait for Rx state
%   ISFAIL = handlePhyIndicationWaitForRx(EDCAMAC, PHYINDICATION) handles
%   indications from physical layer in wait for Rx state and sets the
%   corresponding Rx state context and MAC context for a node.
%
%   ISFAIL returns 1 to indicate transmission failure, 0 to indicate
%   transmission success, and -1 to indicate no status.
%
%   EDCAMAC is an object of type hEDCAMAC.
%
%   PHYINDICATION is the indication received from PHY layer.

isFail = -1;
rx = edcaMAC.Rx;

% PHY Rx start indication
if phyIndication.MessageType == hPHYPrimitivesEnum.RxStartIndication
    % Ignore response timeout trigger
    rx.IgnoreResponseTimeout = true;
    % Received frame length
    rx.RxFrameLength = phyIndication.PSDULength(edcaMAC.UserIndexSU);
    % Aggregated MPDU
    rx.RxAggregatedMPDU = phyIndication.AggregatedMPDU;
    % Received frame format
    rx.RxFrameFormat = phyIndication.FrameFormat;
    % Received signal strength
    rx.RxRSSI = phyIndication.RSSI;
    
    % PHY Rx error indication
elseif phyIndication.MessageType == hPHYPrimitivesEnum.RxErrorIndication
    % Set PHY Rx error flag
    rx.RxErrorIndication = true;
    rx.IgnoreResponseTimeout = true;
    % Consider Rx error indication as response failure
    handleResponseFailure(edcaMAC);
    isFail = 1;
    
    % PHY CCA Busy indication
elseif phyIndication.MessageType == hPHYPrimitivesEnum.CCABusyIndication
    edcaMAC.CCAState = hPHYPrimitivesEnum.CCABusyIndication;
    updateAvailableBandwidth(edcaMAC, phyIndication);
    
    % PHY CCA Idle indication
elseif phyIndication.MessageType == hPHYPrimitivesEnum.CCAIdleIndication
    updateAvailableBandwidth(edcaMAC, phyIndication);
    % Ignore CCA Idle indication if CCA state is already idle
    if (edcaMAC.CCAState == hPHYPrimitivesEnum.CCAIdleIndication)
        return;
    end
    
    % Reset PHY state
    edcaMAC.CCAState = hPHYPrimitivesEnum.CCAIdleIndication;
    
    if (rx.RxErrorIndication)
        % Reset PHY Rx error flag
        rx.RxErrorIndication = false;
        % Move to EIFS state
        stateChange(edcaMAC, edcaMAC.EIFS_STATE);
    elseif rx.MoveToSendData
        % Reset flag
        rx.MoveToSendData = false;
        % Move to SendData state
        stateChange(edcaMAC, edcaMAC.SENDINGDATA_STATE);
    else
        % Move to contend state
        stateChange(edcaMAC, edcaMAC.CONTENTION_STATE);
    end
end
end


function isFail = processResponse(edcaMAC, frameFromPHY)
%processResponse Decodes and processes the response frame.
%   ISFAIL = processResponse(EDCAMAC, FRAMEFROMPHY) decodes and processes response
%   frame and updates corresponding context specific to receiving state,
%   MAC context and rate context.
%
%   ISFAIL returns 1 to indicate transmission failure, 0 to indicate
%   transmission success, and -1 to indicate no status. A vector indicates
%   the status for multiple subframes in an A-MPDU.
%
%   EDCAMAC is an object of type hEDCAMAC.
%
%   FRAMEFROMPHY is the received response frame.

rx = edcaMAC.Rx;
tx = edcaMAC.Tx;
isFail = 1;
if edcaMAC.BABitmapLength == 64
    baFrameLength = 32;
else % edcaMAC.BABitmapLength == 256
    baFrameLength = 56;
end

% If received response frame length is not matching with the length of
% Ack/CTS/BA frames, consider it as Tx failure and switch to Rx to process
% the received frame
if (rx.RxFrameLength ~= edcaMAC.AckOrCtsFrameLength) && (rx.RxFrameLength ~= baFrameLength)    
    % Increase retry count
    incrementRetryCount(edcaMAC);
    edcaMAC.MACNonRespFrames = edcaMAC.MACNonRespFrames + 1;
    
    % Copy the received frame to MAC Rx buffer
    edcaMAC.RxData = frameFromPHY;
    
    % Move to receiving state
    stateChange(edcaMAC, edcaMAC.RECEIVING_STATE);
    return;
end

% Decode the received MPDU
[rxCfg, fcsPass] = decodeAbstractedMACFrame(edcaMAC, frameFromPHY, 1);

if fcsPass
    % Get the number of frames waiting for acknowledgment
    acIndex = edcaMAC.TID2AC(rxCfg.TID+1) + 1;
    
    % Frame is intended to this node
    if strcmp(rxCfg.Address1, edcaMAC.MACAddress)
        % If received frame is CTS and node is waiting for CTS frame
        if strcmp(rxCfg.FrameType, 'CTS') && tx.WaitingForCTS
            edcaMAC.MACCTSRx = edcaMAC.MACCTSRx + 1;
            edcaMAC.MACRTSSuccess = edcaMAC.MACRTSSuccess + 1;

            % Set flag to indicate move to SendData state on medium IDLE
            rx.MoveToSendData = true;
            
            % Return the transmission status
            isFail = 0;
            
            % If received frame is Ack and node is waiting for Ack
        elseif strcmp(rxCfg.FrameType, 'ACK') && any(tx.TxWaitingForAck(tx.TxStationIDs(edcaMAC.UserIndexSU), :))
            edcaMAC.MACAckRx = edcaMAC.MACAckRx + 1;
            edcaMAC.MACTxBytes = edcaMAC.MACTxBytes + tx.TxMSDULengths(tx.TxStationIDs(edcaMAC.UserIndexSU), edcaMAC.OwnerAC+1, 1);
            edcaMAC.MACTxSuccess = edcaMAC.MACTxSuccess + 1;
            
            % Return the transmission status
            isFail = 0;
            
            % Reset retry count and waiting for Ack flag
            resetRetryCount(edcaMAC);
            
            % If received frame is Block Ack and node is waiting for Block Ack
        elseif strcmp(rxCfg.FrameType, 'Block Ack') && (tx.TxWaitingForAck(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex) > 0)
            % Reset contention window
            edcaMAC.CW(edcaMAC.OwnerAC+1) = edcaMAC.CWMin(edcaMAC.OwnerAC+1);
            
            % Get sequence numbers of the frames that are acknowledged in BA bitmap
            baSeqNums = getSeqNumsFromBitmap(rxCfg.BlockAckBitmap, rxCfg.SequenceNumber);
            
            % Get sequence numbers of the AMPDU subframes which are not
            % acknowledged for access category of the BA
            txSeqNums = edcaMAC.SeqNumWaitingForAck(1:tx.TxWaitingForAck(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex), acIndex);
            ackedIndices = ismember(txSeqNums, baSeqNums);
            ackedSeqNums = txSeqNums(ackedIndices);
            % Sequence numbers that are not acknowledged in this BA
            seqNumsToBeAcked = txSeqNums(~ackedIndices);
            
            % Update statistics
            edcaMAC.MACTxSuccess = edcaMAC.MACTxSuccess + numel(ackedSeqNums);
            edcaMAC.MACBARx = edcaMAC.MACBARx + 1;
            % Remove acknowledged MSDUs from MAC queue
            tx.MSDUDiscardCount(edcaMAC.UserIndexSU) = numel(ackedSeqNums);
            tx.MSDUDiscardIndices(1:tx.MSDUDiscardCount(edcaMAC.UserIndexSU), edcaMAC.UserIndexSU) = ...
                reshape(find(ismember(mod(tx.TxSSN(acIndex): ...
                tx.TxSSN(acIndex)+ tx.InitialSubframesCount(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex)-1, 4096),...
                ackedSeqNums)), [], 1);
            msduIndices = find(ismember(mod(txSeqNums-tx.TxSSN(acIndex), 4096)+1, tx.MSDUDiscardIndices(1:tx.MSDUDiscardCount(edcaMAC.UserIndexSU), edcaMAC.UserIndexSU)));
            edcaMAC.MACTxBytes = edcaMAC.MACTxBytes + sum(tx.TxMSDULengths(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex, msduIndices));
            % All the subframes are acknowledged
            if(isempty(seqNumsToBeAcked))
                % Reset retry count
                resetRetryCount(edcaMAC);
                
                % Return the transmission status
                isFail = false;
                
            else % Some or all subframes of the A-MPDU are not acknowledged
                tx.TxWaitingForAck(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex) = numel(seqNumsToBeAcked);
                % Update context of the sequence numbers that are need to be
                % acknowledged
                edcaMAC.SeqNumWaitingForAck(1:tx.TxWaitingForAck(tx.TxStationIDs(edcaMAC.UserIndexSU), acIndex), acIndex) = seqNumsToBeAcked;
                
                % Increase retry count
                incrementRetryCount(edcaMAC);
                
                % Return the transmission status
                isFail = ~ackedIndices;
            end
            
            edcaQueueManagement(edcaMAC, 'discard');
        else % Received frame is not an acknowledgment
            % Response failure
            handleResponseFailure(edcaMAC);
            edcaMAC.MACNonRespFrames = edcaMAC.MACNonRespFrames + 1;
            
            % Copy the received frame to MAC Rx buffer
            edcaMAC.RxData = frameFromPHY;
            % Move to Rx state
            stateChange(edcaMAC, edcaMAC.RECEIVING_STATE);
        end
        
        % Received frame is destined to others
    else
        % Response failure
        handleResponseFailure(edcaMAC);
        edcaMAC.MACOthersFramesInWaitForResp = edcaMAC.MACOthersFramesInWaitForResp + 1;
        
        if edcaMAC.EnableSROperation
            if isIntraBSSFrame(edcaMAC, rxCfg, edcaMAC.BSSID) % Frame is intra-BSS
                duration = rxCfg.Duration;
                
                % Update intra NAV
                if edcaMAC.IntraNAV < duration
                    edcaMAC.IntraNAV = duration;
                    edcaMAC.MACNumIntraNavUpdates = edcaMAC.MACNumIntraNavUpdates + 1;
                end
                
                if strcmp(rxCfg.FrameType, 'CTS')
                    % Reset waiting for NAV reset flag
                    rx.WaitingForNAVReset = false;
                end
            else % Received frame is inter-BSS or neither inter nor intra-BSS
                if strcmp(rxCfg.FrameType, 'CTS') ||...
                        strcmp(rxCfg.FrameType, 'ACK') || strcmp(rxCfg.FrameType, 'Block Ack') || rx.RxRSSI >= edcaMAC.UpdatedOBSSPDThreshold
                    
                    duration = rxCfg.Duration;
                    
                    % Update inter NAV
                    if edcaMAC.InterNAV < duration
                        edcaMAC.InterNAV = duration;
                        edcaMAC.MACNumBasicNavUpdates = edcaMAC.MACNumBasicNavUpdates + 1;    
                    end
                else
                    edcaMAC.LimitTxPower = true;
                end
            end
        else
            duration = rxCfg.Duration;
            
            % Update NAV
            if edcaMAC.NAV < duration
                edcaMAC.NAV = duration;
                edcaMAC.MACNumBasicNavUpdates = edcaMAC.MACNumBasicNavUpdates + 1;
            end
            if strcmp(rxCfg.FrameType, 'CTS')
                % Reset waiting for NAV reset flag
                rx.WaitingForNAVReset = false;
            end
        end
        
        if edcaMAC.IntraNAV ~= 0  || edcaMAC.InterNAV ~= 0 || edcaMAC.NAV ~= 0
            % Move to NAV wait state
            stateChange(edcaMAC, edcaMAC.RECEIVING_STATE);
            edcaMAC.Rx.RxState = edcaMAC.Rx.NAVWAIT;
        end
        
    end
    
    % Failed to decode the received frame
else
    % Response failure
    handleResponseFailure(edcaMAC);
    edcaMAC.MACRespErrors = edcaMAC.MACRespErrors + 1;
    edcaMAC.MACRxDrop = edcaMAC.MACRxDrop + 1;
    % Move to EIFS state, when there is no energy in the channel
    if (edcaMAC.CCAState == hPHYPrimitivesEnum.CCAIdleIndication)
        stateChange(edcaMAC, edcaMAC.EIFS_STATE);
    else
        rx.RxErrorIndication = true;
    end
end
end

function isFail = handleResponseTimeout(edcaMAC)
%handleResponseTimeout Increments the retry counter and invokes the
%retransmission
%   ISFAIL = handleResponseTimeout(EDCAMAC) increments the retry counter
%   and invokes the retransmission and updates corresponding rx context, tx
%   context and rate context. EDCAMAC is an object of type hEDCAMAC.
%
%   ISFAIL indicates if the frame transmission really failed due to lack of
%   acknowledgment.
isFail = -1;
rx = edcaMAC.Rx;

if rx.IgnoreResponseTimeout == false
    % Response failure
    handleResponseFailure(edcaMAC);
    
    if edcaMAC.CCAState == hPHYPrimitivesEnum.CCAIdleIndication
        % Move to contend state
        stateChange(edcaMAC, edcaMAC.CONTENTION_STATE);
    end
    rx.IgnoreResponseTimeout = true;
    isFail = true;
end
end

function handleResponseFailure(edcaMAC)
%handleResponseFailure Performs the operations required when expected
%response is not received
%   handleResponseFailure(EDCAMAC) performs the operations required when
%   expected response is not received and updates corresponding tx context
%   and rate context. EDCAMAC is an object of type hEDCAMAC.

tx = edcaMAC.Tx;

% Increase retry count
incrementRetryCount(edcaMAC);

% Reset RTSSent flag
tx.RTSSent = false;
end

function seqNums = getSeqNumsFromBitmap(baBitmap, ssn)
%getSeqNumsFromBitmap(...) Returns acknowledged sequence numbers using
%bitmap and starting sequence number.

% Convert hexadecimal bitmap to binary bitmap
bitmapDec = hex2dec((reshape(baBitmap, 2, [])'));
bitmapDec(1:end) = bitmapDec(end:-1:1);
bitmapBits = reshape(de2bi(bitmapDec, 8)', [], 1);

% Return the successfully acknowledged sequence numbers
seqNums = rem(ssn+find(bitmapBits)-1, 4096);
end

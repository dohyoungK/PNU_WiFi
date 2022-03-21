function [macReqToPHY, frameToPHY, nextInvokeTime] = ...
    handleEventsReceiving(obj, phyIndication, elapsedTime)
%handleEventsReceiving Runs MAC Layer state machine for receiving data
%
%   This function performs the following operations:
%   1. Processes any received packet.
%   2. Constructs response frame for the received frame if it is
%   needed.
%   3. Updates the NAV (Network allocation vector) duration if
%   received frame is not destined for it and received frame
%   duration is greater than the current NAV duration.
%   4. After NAV becomes 0, it moves to Contention state.
%   Otherwise, it will be in Rx state only.
%
%   [MACREQTOPHY, FRAMETOPHY, NEXTINVOKETIME] = handleEventsReceiving(OBJ,
%   PHYINDICATION, ELAPSEDTIME) performs MAC Layer receiving actions.
%
%   MACREQTOPHY returns Transmission Request to PHY Layer.
%
%   FRAMETOPHY returns Data frame to PHY Layer.
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
macReqToPHY = obj.EmptyPHYIndication;
frameToPHY = obj.EmptyFrame;
nextInvokeTime = -1;

if ~phyIndication.IsEmpty
    handlePHYIndicationRx(obj, phyIndication);
    if (obj.Rx.RxState == -1) && (phyIndication.MessageType == hPHYPrimitivesEnum.RxStartIndication)
        obj.Rx.RxState = obj.Rx.PROCESSING;
    end
    if obj.MACState ~= obj.RECEIVING_STATE
        return;
    end
end

switch(obj.Rx.RxState)
    case obj.Rx.PROCESSING % Rx Processing
        % Initialize next invoke time. This is updated in processRx
        % to SIFS if response frame needs to be transmitted
        obj.NextInvokeTime = -1;
        
        if ~obj.Rx.ProcessingEntry
            obj.Rx.ProcessingEntryTS = getCurrentTime(obj);
            
            if ~(obj.RxData.IsEmpty)
                obj.ResponseFrame = processRx(obj, obj.RxData.MACFrame, obj.RxData.Timestamp);
                if obj.MACState ~= obj.RECEIVING_STATE
                    return;
                end
            end
            % Set Processing Flag
            obj.Rx.ProcessingEntry = true;
        else
            if ~(obj.RxData.IsEmpty)
                updateNAV(obj, obj.Rx.ProcessingEntryTS);
                obj.ResponseFrame = processRx(obj, obj.RxData.MACFrame, obj.RxData.Timestamp);
                if obj.MACState ~= obj.RECEIVING_STATE
                    return;
                end
                % Reset Processing Flag
                obj.Rx.ProcessingEntry = false;
            end
        end
        nextInvokeTime = obj.NextInvokeTime;
        
    case obj.Rx.RESPONDING % Responding
        obj.PHYMode.IsEmpty = false;
        obj.PHYMode.PHYRxOn = false;
        
        % Wait for SIFS time before sending Tx start request
        obj.NextInvokeTime = obj.NextInvokeTime - elapsedTime;
        nextInvokeTime = obj.NextInvokeTime*(obj.NextInvokeTime > 0);
            
        if ~obj.Rx.RespondingEntry
            % Stop PHY receiver
            obj.Rx.RespondingEntryTS = getCurrentTime(obj);
            obj.Rx.RespondingEntry = true;
        end
            
        if obj.NextInvokeTime <= 0
            macReqToPHY = sendTxRequest(obj, "Start", ...
                obj.Rx.RxChannelBandwidth, ...
                double(hFrameFormatsEnum.NonHT), ...
                [obj.Rx.ResponseMCS; zeros(8, 1)], ...
                [obj.Rx.ResponseLength; zeros(8, 1)]);
            % Reset RespondingEntry flag
            obj.Rx.RespondingEntry = false;
        end
        
    case obj.Rx.TXENDREQUEST % Tx End Request
        % Wait for frame transmission time before sending Tx end request
        obj.NextInvokeTime = obj.NextInvokeTime - elapsedTime;
        nextInvokeTime = obj.NextInvokeTime*(obj.NextInvokeTime > 0);
        
        if ~obj.Rx.TxEndRequestEntry
            frameToPHY = obj.ResponseFrame;
            % Capture entry timestamp
            obj.Rx.TxEndReqEntryTS = getCurrentTime(obj);
            % Plot state transition
            hPlotStateTransition([obj.NodeID obj.OperatingFreqID], 2,  getCurrentTime(obj), obj.Tx.FrameTxTime, obj.NumNodes);
            obj.Rx.TxEndRequestEntry = true;
        end
        
        % Frame transmission time is completed
        if obj.NextInvokeTime <= 0
            macReqToPHY = sendTxRequest(obj, "End");
            % Reset TxEndRequestEntry flag
            obj.Rx.TxEndRequestEntry = false;
        end
        
    case obj.Rx.NAVWAIT % NAV Wait
        if ~obj.Rx.NAVWaitEntry
            obj.Rx.NAVWaitEntryTS = getCurrentTime(obj);
            
            % Wait for minimum of response timeout or maximum
            % of NAV, Inter-NAV and Intra-NAV
            obj.Rx.WaitForResponseTimer = obj.ResponseTimeout;
            obj.Rx.WaitForNAVTimer = max(obj.NAV, max(obj.IntraNAV, obj.InterNAV));
            
            obj.NextInvokeTime = min(obj.Rx.WaitForResponseTimer, obj.Rx.WaitForNAVTimer);
            nextInvokeTime = obj.NextInvokeTime;
            
            obj.Rx.NAVWaitEntry = true;
            
        else
            % Decrement the timers
            obj.Rx.WaitForResponseTimer = obj.Rx.WaitForResponseTimer - elapsedTime;
            obj.Rx.WaitForNAVTimer = obj.Rx.WaitForNAVTimer - elapsedTime;
            
            % Response timeout expired
            if obj.Rx.WaitForResponseTimer <= 0
                if obj.Rx.WaitingForNAVReset
                    % Reset NAV and Intra NAV
                    obj.IntraNAV = 0;
                    obj.NAV = 0;
                    % Reset WaitingForNAVReset flag
                    obj.Rx.WaitingForNAVReset = false;
                    
                    if obj.CCAState == hPHYPrimitivesEnum.CCAIdleIndication
                        % Exit actions of NAV wait state
                        navWaitExit(obj);
                        stateChange(obj, obj.CONTENTION_STATE);
                        return;
                    end
                end
            end
            
            % NAV timeout expired
            if obj.Rx.WaitForNAVTimer <= 0
                % Reset NAV, InterNAV and IntraNAV
                obj.IntraNAV = 0;
                obj.NAV = 0;
                obj.InterNAV = 0;
                if obj.CCAState == hPHYPrimitivesEnum.CCAIdleIndication
                    % Exit actions of NAV wait state
                    navWaitExit(obj);
                    stateChange(obj, obj.CONTENTION_STATE);
                    return;
                end
            end
            
            % Check if any timer is remaining to be expired and set next
            % invoke time accordingly
            if (obj.Rx.WaitForResponseTimer > 0) || (obj.Rx.WaitForNAVTimer > 0)
                if (obj.Rx.WaitForResponseTimer <= 0) || ((obj.Rx.WaitForNAVTimer > 0) && (obj.Rx.WaitForNAVTimer < obj.Rx.WaitForResponseTimer))
                    obj.NextInvokeTime = obj.Rx.WaitForNAVTimer;
                else
                    obj.NextInvokeTime = obj.Rx.WaitForResponseTimer;
                end
                nextInvokeTime = obj.NextInvokeTime;
            end
        end
end
end


function handlePHYIndicationRx(edcaMAC, phyIndication)
%handlePHYIndicationRx Handles PHY indications in receiving state
%   handlePHYIndicationRx(EDCAMAC, PHYINDICATION) handles indications from
%   PHY layer and sets the corresponding context specific to receiving
%   state and MAC context for a node.
%
%   EDCAMAC is an object of type hEDCAMAC.
%
%   PHYINDICATION is the indication received from PHY layer.

% Comment: This declaration is to avoid double-dot notation
rx = edcaMAC.Rx;

% Rx-Error indication
if phyIndication.MessageType == hPHYPrimitivesEnum.RxErrorIndication
    % Set PHY Rx error flag
    rx.RxErrorIndication = true;
    rx.RxState = -1;
    
    % Rx-Start indication: Store Rx vector information
elseif phyIndication.MessageType == hPHYPrimitivesEnum.RxStartIndication
    
    % Received frame length
    rx.RxFrameLength = phyIndication.PSDULength(edcaMAC.UserIndexSU);
    % Aggregated MPDU
    rx.RxAggregatedMPDU = phyIndication.AggregatedMPDU;
    % Received frame MCS
    rxMCS = phyIndication.MCSIndex(edcaMAC.UserIndexSU);
    % Received frame format
    rx.RxFrameFormat = phyIndication.FrameFormat;
    % Received channel bandwidth
    rx.RxChannelBandwidth = phyIndication.ChannelBandwidth;
    % Received signal strength
    rx.RxRSSI = phyIndication.RSSI;
    % Response MCS
    rx.ResponseMCS = responseMCS(edcaMAC, rx.RxFrameFormat, ...
        phyIndication.ChannelBandwidth, rx.RxAggregatedMPDU, rxMCS, phyIndication.NumSpaceTimeStreams);
    
    % CCA-Idle indication
elseif phyIndication.MessageType == hPHYPrimitivesEnum.CCAIdleIndication
    edcaMAC.CCAState = hPHYPrimitivesEnum.CCAIdleIndication;
    updateAvailableBandwidth(edcaMAC, phyIndication);
    % If Rx-Error indication is received. Move to EIFS state after
    % receiving CCA-Idle
    if (rx.RxErrorIndication)
        % Update NAV
        switch(rx.RxState)
            case rx.PROCESSING
                entryTS = rx.ProcessingEntryTS;
            case rx.RESPONDING
                entryTS = rx.RespondingEntryTS;
            case rx.TXENDREQUEST
                entryTS = rx.TxEndReqEntryTS;
            otherwise % NAVWAIT
                entryTS = rx.NAVWaitEntryTS;
        end
        updateNAV(edcaMAC, entryTS);
        
        % Reset PHY Rx error flag
        rx.RxErrorIndication = false;
        % Move to EIFS state
        stateChange(edcaMAC, edcaMAC.EIFS_STATE);
    else
        % Reset PHY state
        edcaMAC.CCAState = hPHYPrimitivesEnum.CCAIdleIndication;
        % Update the transmit power restriction flag
        %
        % Reference: Section-26.10.2.4 in IEEE Draft P802.11ax_D4.1
        edcaMAC.LimitTxPower = phyIndication.LimitTxPower;
        if ((edcaMAC.InterNAV == 0) && (edcaMAC.IntraNAV == 0) && ...
                (edcaMAC.NAV == 0)) && (~rx.ResponseFlag)
            if rx.RxState == rx.NAVWAIT
                % NAV Wait exit action
                navWaitExit(edcaMAC);
            end
            % Move to contention state
            stateChange(edcaMAC, edcaMAC.CONTENTION_STATE);
        end
    end
    
    % CCA busy indication
elseif phyIndication.MessageType == hPHYPrimitivesEnum.CCABusyIndication
    edcaMAC.CCAState = hPHYPrimitivesEnum.CCABusyIndication;
    updateAvailableBandwidth(edcaMAC, phyIndication);
    
    if rx.RxState == rx.NAVWAIT
        % NAV Wait exit action
        navWaitExit(edcaMAC);
        % Move to processing substate
        rx.RxState = rx.PROCESSING;
    end
    
    % Tx start confirm
elseif phyIndication.MessageType == hPHYPrimitivesEnum.TxStartConfirm
    updateNAV(edcaMAC, rx.RespondingEntryTS);
    rx.RxState = rx.TXENDREQUEST;
    % Wait for frame transmission time before sending Tx End request
    edcaMAC.NextInvokeTime = edcaMAC.Tx.FrameTxTime;
    
    % Tx end confirm
elseif phyIndication.MessageType == hPHYPrimitivesEnum.TxEndConfirm
    rx.ResponseFlag = false;
    % Start PHY receiver
    edcaMAC.PHYMode.IsEmpty = false;
    edcaMAC.PHYMode.PHYRxOn = true;
    updateNAV(edcaMAC, rx.TxEndReqEntryTS);
    
    if (edcaMAC.IntraNAV ~= 0) || (edcaMAC.InterNAV ~= 0) || (edcaMAC.NAV ~= 0)
        % Move to NAVWAIT substate
        rx.RxState = rx.NAVWAIT;
    else
        rx.RxState = -1;
        if (edcaMAC.CCAState == hPHYPrimitivesEnum.CCAIdleIndication)
            % Move to contention state
            stateChange(edcaMAC, edcaMAC.CONTENTION_STATE);
        end
    end
    
end
end


function responseFrame = processRx(edcaMAC, rxFrame, timestamp)
%processRx Processes received frame
%   RESPONSEFRAME = processRx(EDCAMAC, RXFRAME, TIMESTAMP) processes the
%   received frame and generates response frame if required.
%
%   RESPONSEFRAME is the frame to be sent as response to received frame.
%
%   EDCAMAC is an object of type hEDCAMAC.
%
%   RXFRAME is the received frame.
%
%   TIMESTAMP is an M-by-N array of frame timestamps, where M is the
%   number of subframes and N is the number of users.

rx = edcaMAC.Rx;

edcaMAC.PacketToApp.MSDUCount = 0;
responseFrame = edcaMAC.EmptyFrame;

% Update RxFrameLength for HE format PSDUs. For all other formats
% RxFrameLength will be obtained from Rx vector
if ((rx.RxFrameFormat == hFrameFormatsEnum.HE_SU) || ...
        (rx.RxFrameFormat == hFrameFormatsEnum.HE_EXT_SU) || ...
        (rx.RxFrameFormat == hFrameFormatsEnum.HE_MU))
    rx.RxFrameLength = rxFrame.PSDULength(edcaMAC.UserIndexSU);
end

% Send SR parameters to PHYRx
if edcaMAC.EnableSROperation
    edcaMAC.PHYMode.IsEmpty = false;
    edcaMAC.PHYMode.PHYRxOn = true;
    edcaMAC.PHYMode.EnableSROperation = 1;
    edcaMAC.PHYMode.BSSColor = edcaMAC.BSSColor;
    edcaMAC.PHYMode.OBSSPDThreshold = edcaMAC.UpdatedOBSSPDThreshold;
end

rx.ResponseFlag = false;

% Update statistics
switch rx.RxFrameFormat
    case hFrameFormatsEnum.NonHT
        edcaMAC.MACNonHTRx = edcaMAC.MACNonHTRx + 1;
    case hFrameFormatsEnum.HTMixed
        edcaMAC.MACHTRx = edcaMAC.MACHTRx + 1;
    case hFrameFormatsEnum.VHT
        edcaMAC.MACVHTRx = edcaMAC.MACVHTRx + 1;
    case hFrameFormatsEnum.HE_SU
        edcaMAC.MACHESURx = edcaMAC.MACHESURx + 1;
    case hFrameFormatsEnum.HE_EXT_SU
        edcaMAC.MACHEEXTSURx = edcaMAC.MACHEEXTSURx + 1;
    case hFrameFormatsEnum.HE_MU
        edcaMAC.MACHEMURx = edcaMAC.MACHEMURx + 1;
    otherwise
        error('received frame format is unsupported');
end

% Non aggregated MPDU
if (rx.RxAggregatedMPDU == 0) && ...
        (rx.RxFrameFormat < hFrameFormatsEnum.VHT)
    
    if rx.RxFrameLength > edcaMAC.MPDUMaxLength
        edcaMAC.MACRxDrop = edcaMAC.MACRxDrop + 1;
        % Move to EIFS state, when there is no more energy on the channel
        if edcaMAC.CCAState == hPHYPrimitivesEnum.CCAIdleIndication
            stateChange(edcaMAC, edcaMAC.EIFS_STATE);
        else
            rx.RxErrorIndication = true;
        end
    else
        % Decode the received MPDU
        
        [rxCfg, fcsPass] = decodeAbstractedMACFrame(edcaMAC, rxFrame, 1);
        
        if fcsPass
            edcaMAC.MACRx = edcaMAC.MACRx + 1;            
            % Frame is intended to this node
            if strcmp(rxCfg.Address1, edcaMAC.MACAddress)
                if strcmp(rxCfg.FrameType, 'QoS Data') % QoS Data frame
                    edcaMAC.MACDataRx = edcaMAC.MACDataRx + 1;
                    
                    % Access category of the received QoS Data frame
                    acIndex = edcaMAC.TID2AC(rxCfg.TID+1) + 1; % AC starts at 0
                    
                    % Update per AC statistics
                    edcaMAC.MACRxAC(acIndex) = edcaMAC.MACRxAC(acIndex) + 1;
                    
                    getNodeIDCommand = 2;
                    [~, srcIndex] = hNodeInfo(getNodeIDCommand, edcaMAC.NodeID, rxCfg.Address2);
                    srcIndex = srcIndex(1);
                    
                    % Check for duplicate reception
                    %
                    % Reference: Section-10.3.2.11.3 in IEEE Std 802.11-2016
                    if rxCfg.Retransmission && (rxCfg.SequenceNumber == rx.LastRxSequenceNum(srcIndex,acIndex))
                        isDuplicateFrame = true;
                    else
                        isDuplicateFrame = false;
                    end
                    
                    if isDuplicateFrame
                        % Update MAC Rx duplicate counters
                        edcaMAC.MACDuplicateRxAC(acIndex) = edcaMAC.MACDuplicateRxAC(acIndex) + 1;
                    else
                        sendDataToApp(edcaMAC, rxFrame, acIndex-1, 1, timestamp);
                        rx.LastRxSequenceNum(srcIndex, acIndex) = rxCfg.SequenceNumber;
                    end
                    
                    % Send Acknowledgment, if required
                    if strcmp(rxCfg.AckPolicy, 'Normal Ack/Implicit Block Ack Request')
                        edcaMAC.MACAckTx = edcaMAC.MACAckTx + 1;
                        duration = 0;
                        responseFrame = sendResponse(edcaMAC, rxCfg.Address2, 'ACK', duration);
                    end
                    
                elseif strcmp(rxCfg.FrameType, 'RTS') % RTS frame
                    edcaMAC.MACRTSRx = edcaMAC.MACRTSRx + 1;
                    edcaMAC.MACCTSTx = edcaMAC.MACCTSTx + 1;
                    
                    cbw = 20;
                    numSTS = 1;
                    % Calculate response frame Tx time
                    txTime = calculateTxTime(edcaMAC, cbw, rx.ResponseMCS, edcaMAC.AckOrCtsFrameLength, hFrameFormatsEnum.NonHT, numSTS);
                    duration = rxCfg.Duration - edcaMAC.SIFSTime - txTime;
                    if duration < 0
                        duration = 0;
                    end
                    % Send CTS
                    responseFrame = sendResponse(edcaMAC, rxCfg.Address2, 'CTS', duration);
                    
                else % Received an unsupported MPDU
                    
                    edcaMAC.MACRxDrop = edcaMAC.MACRxDrop + 1;
                    % Since this example doesn't support other than
                    % QoS-Data and RTS frames, considering this as an Rx
                    % errored frame. Move to EIFS state, when there is no
                    % more energy on the channel
                    if edcaMAC.CCAState == hPHYPrimitivesEnum.CCAIdleIndication
                        stateChange(edcaMAC, edcaMAC.EIFS_STATE);
                    else
                        rx.RxErrorIndication = true;
                    end
                end
                
                % Groupcast frame
            elseif rem(hex2dec(rxCfg.Address1(1:2)), 2)
                % Access category of received QoS Data frame
                acIndex = edcaMAC.TID2AC(rxCfg.TID+1) + 1; % AC starts at 0
                
                % MAC payload is not empty
                if rxFrame.PayloadLength(1, edcaMAC.UserIndexSU)
                    % Update MAC Rx counters
                    edcaMAC.MACRxAC(acIndex) = edcaMAC.MACRxAC(acIndex) + 1;
                    sendDataToApp(edcaMAC, rxFrame, acIndex-1, 1, timestamp);
                end
                
            else % Received frame is intended to others
                if edcaMAC.EnableSROperation
                    if isIntraBSSFrame(edcaMAC, rxCfg, edcaMAC.BSSID) % Frame is intra-BSS
                        if strcmp(rxCfg.FrameType, 'RTS')
                            % Set waiting for NAV reset flag
                            rx.WaitingForNAVReset = true;
                        elseif strcmp(rxCfg.FrameType, 'CTS')
                            % Reset waiting for NAV reset flag
                            rx.WaitingForNAVReset = false;
                        end
                        
                        % Update Intra NAV
                        tmpNav = rxCfg.Duration;
                        if edcaMAC.IntraNAV < tmpNav
                            edcaMAC.IntraNAV = tmpNav;
                            edcaMAC.MACNumIntraNavUpdates = edcaMAC.MACNumIntraNavUpdates + 1;
                        end
                    else % Received frame is inter-BSS or neither inter nor intra-BSS
                        updateInterNAV = false;
                        
                        if strcmp(rxCfg.FrameType, 'CTS') || ...
                                strcmp(rxCfg.FrameType, 'ACK') || ...
                                strcmp(rxCfg.FrameType, 'Block Ack') || ...
                                rx.RxRSSI >= edcaMAC.UpdatedOBSSPDThreshold
                            updateInterNAV = true;
                        end
                        
                        if strcmp(rxCfg.FrameType, 'RTS')
                            % Entry timestamp for RTS
                            rx.RTSEntryTS = getCurrentTime(edcaMAC);
                            rx.UpdateRTSNAV = updateInterNAV;
                            
                        elseif strcmp(rxCfg.FrameType, 'CTS')
                            % Entry timestamp for CTS
                            rx.CTSEntryTS = getCurrentTime(edcaMAC);
                            % Time difference between RTS entry and CTS entry
                            diff = rx.CTSEntryTS - rx.RTSEntryTS;
                            
                            if (diff < edcaMAC.PIFSTime) && rx.RTSEntryTS ...
                                    && ~rx.UpdateRTSNAV && ...
                                    (rx.RxRSSI < edcaMAC.UpdatedOBSSPDThreshold)
                                updateInterNAV = false;
                            end
                            
                            % Reset RTS/CTS entry timestamps
                            rx.CTSEntryTS = 0;
                            rx.RTSEntryTS = 0;
                            
                            % Reset RTS nav status
                            rx.UpdateRTSNAV = true;
                        end
                        
                        if updateInterNAV
                            % Update inter NAV
                            tmpNav = rxCfg.Duration;
                            if edcaMAC.InterNAV < tmpNav
                                edcaMAC.InterNAV = tmpNav;
                                edcaMAC.MACNumBasicNavUpdates = edcaMAC.MACNumBasicNavUpdates + 1;
                            end
                        else
                            edcaMAC.LimitTxPower = true;
                        end
                    end
                else
                    if strcmp(rxCfg.FrameType, 'RTS')
                        % Set waiting for NAV reset flag
                        rx.WaitingForNAVReset = true;
                    elseif strcmp(rxCfg.FrameType, 'CTS')
                        % Reset waiting for NAV reset flag
                        rx.WaitingForNAVReset = false;
                    end
                    
                    % Update NAV
                    tmpNav = rxCfg.Duration;
                    if edcaMAC.NAV < tmpNav
                        edcaMAC.NAV = tmpNav;
                        edcaMAC.MACNumBasicNavUpdates = edcaMAC.MACNumBasicNavUpdates + 1;
                    end
                end
                
                % Move to NAV wait state
                rx.RxState = rx.NAVWAIT;
            end
            
        else % Failed to decode the received frame
            edcaMAC.MACRxDrop = edcaMAC.MACRxDrop + 1;
            % Move to EIFS state, when there is no more energy on the channel
            if edcaMAC.CCAState == hPHYPrimitivesEnum.CCAIdleIndication 
                stateChange(edcaMAC, edcaMAC.EIFS_STATE);
            else
                rx.RxErrorIndication = true;
            end
        end
    end
    
else % Received frame is an aggregated MPDU
    edcaMAC.MACAggRx = edcaMAC.MACAggRx + 1;
    
    % Number of subframes in the A-MPDU
    aggCount = nnz(rxFrame.PayloadLength(:, edcaMAC.UserIndexSU));
    delFails = rxFrame.DelimiterFails;
    rxSeqNums = zeros(aggCount, 1); % For codegen
    seqNumIdx = 0; % For codegen
    tid = 1; % For codegen
    subframeFailures = 0; % For codegen
    baDestinationAddress = '000000000000'; % For codegen
    % Default ack policy
    ackPolicy = 'No Ack';
    srcIndex = -1;
    mpduDuplicateCount = 0;
    
    % Decode each subframe
    for i = 1:aggCount
        % Invalid delimiter or length of the A-MPDU subframe exceeds
        % maximum MPDU length
        if delFails(i, edcaMAC.UserIndexSU) || (rxFrame.MPDULength(i, edcaMAC.UserIndexSU) > edcaMAC.MPDUMaxLength)
            fcsPass = 0;
            rxCfg = edcaMAC.EmptyMACConfig;
        else % Valid subframe
            % Decode the MPDU
            [rxCfg, fcsPass] = decodeAbstractedMACFrame(edcaMAC, rxFrame, i);
        end
        
        % Valid subframe
        if fcsPass
            edcaMAC.MACRx = edcaMAC.MACRx + 1;
            
            tid = rxCfg.TID;
            % Frame is intended to this node
            if strcmp(rxCfg.Address1, edcaMAC.MACAddress)
                edcaMAC.MACDataRx = edcaMAC.MACDataRx + 1;
                
                % Store the sequence numbers to generate Block Ack (BA)
                seqNumIdx = seqNumIdx+1;
                rxSeqNums(seqNumIdx) = rxCfg.SequenceNumber;
                
                [~, srcIndex] = hNodeInfo(2, edcaMAC.NodeID, rxCfg.Address2);
                srcIndex = srcIndex(1);
                
                % Duplicate detection
                acIndex = edcaMAC.TID2AC(rxCfg.TID+1) + 1; % AC starts at 0
                bitmap = rx.BABitmap(srcIndex, acIndex, 1:edcaMAC.BABitmapLength);
                ssn = rx.LastSSN(srcIndex, acIndex);
                
                rxBitmapIndex = rxCfg.SequenceNumber-ssn+1;
                if (rxBitmapIndex > 0) && (rxBitmapIndex <= numel(bitmap)) && ...
                        bitmap(rxBitmapIndex) && (rxCfg.Retransmission)
                    isDuplicateFrame = true;
                    % Update MAC Rx duplicate counters (per MPDU)
                    edcaMAC.MACDuplicateRxAC(acIndex) = edcaMAC.MACDuplicateRxAC(acIndex) + 1;
                    mpduDuplicateCount = mpduDuplicateCount + 1;
                else
                    isDuplicateFrame = false;
                end
                
                if ~isDuplicateFrame
                    sendDataToApp(edcaMAC, rxFrame, acIndex-1, i, timestamp);
                end
                
                % Capture frame configuration to generate BA
                baDestinationAddress = rxCfg.Address2;
                ackPolicy = rxCfg.AckPolicy;
                
                % Groupcast subframe
            elseif rem(hex2dec(rxCfg.Address1(1:2)), 2) == 1
                ac = edcaMAC.TID2AC(rxCfg.TID+1);
                % MAC payload is not empty
                if rxFrame.PayloadLength(i, edcaMAC.UserIndexSU)
                    sendDataToApp(edcaMAC, rxFrame, ac, i, timestamp);
                end
                seqNumIdx = seqNumIdx + 1;
                
            else % Received frame is not intended to this node
                
                if edcaMAC.EnableSROperation
                    if isIntraBSSFrame(edcaMAC, rxCfg, edcaMAC.BSSID) % Frame is intra-BSS frame
                        % Update intra NAV
                        tmpNav = rxCfg.Duration;
                        if edcaMAC.IntraNAV < tmpNav
                            edcaMAC.IntraNAV = tmpNav;
                            edcaMAC.MACNumIntraNavUpdates = edcaMAC.MACNumIntraNavUpdates + 1;
                        end
                    else % Received frame is inter-BSS or neither inter nor intra-BSS
                        if rx.RxRSSI >= edcaMAC.UpdatedOBSSPDThreshold
                            % Update inter NAV
                            tmpNav = rxCfg.Duration;
                            if edcaMAC.InterNAV < tmpNav
                                edcaMAC.InterNAV = tmpNav;
                                edcaMAC.MACNumBasicNavUpdates = edcaMAC.MACNumBasicNavUpdates + 1;
                            end
                        else
                            edcaMAC.LimitTxPower = true;
                        end
                    end
                else
                    % Update NAV and move to NAV wait state
                    tmpNav = rxCfg.Duration;
                    if edcaMAC.NAV < tmpNav
                        edcaMAC.NAV = max(edcaMAC.NAV, tmpNav);
                        edcaMAC.MACNumBasicNavUpdates = edcaMAC.MACNumBasicNavUpdates + 1;
                    end
                end
                
                % Move to NAV wait state
                rx.RxState = rx.NAVWAIT;
            end
            
            % Invalid A-MPDU subframe
        else
            subframeFailures = subframeFailures + 1;
            edcaMAC.MACRxDrop = edcaMAC.MACRxDrop + 1;
        end
    end
    
    if mpduDuplicateCount == aggCount
        % Entire A-MPDU is duplicate
        edcaMAC.MACDuplicateAMPDURx = edcaMAC.MACDuplicateAMPDURx + 1;
    end
    
    % All the subframes are invalid
    if subframeFailures == aggCount
        if edcaMAC.CCAState == hPHYPrimitivesEnum.CCAIdleIndication
            % Move to EIFS state, if there is no more energy on the channel
            stateChange(edcaMAC, edcaMAC.EIFS_STATE);
        else
            rx.RxErrorIndication = true;
        end
    else % Atleast one subframe is valid
        acIndex = edcaMAC.TID2AC(tid+1) + 1; % AC starts at 0. Adding 1 to index.
        
        % Update statistics
        edcaMAC.MACRxAC(acIndex) = edcaMAC.MACRxAC(acIndex) + seqNumIdx;
        edcaMAC.MACAggRxAC(acIndex) = edcaMAC.MACAggRxAC(acIndex) + 1;
        
        % Send Block Acknowledgment, if required
        if (seqNumIdx > 0) && strcmp(ackPolicy, 'Normal Ack/Implicit Block Ack Request')
            % VHT single MPDU or HE S-MPDU
            if (aggCount == 1) && ~strcmp(rx.RxFrameFormat, 'HT-Mixed')
                % Send Ack for VHT/HE S-MPDU
                edcaMAC.MACAckTx = edcaMAC.MACAckTx + 1;
                updateBABitmap(edcaMAC, rxSeqNums(1), tid, srcIndex);
                duration = 0;
                responseFrame = sendResponse(edcaMAC, baDestinationAddress, 'ACK', duration);
            else
                responseFrame = sendBA(edcaMAC, baDestinationAddress, rxSeqNums(1:seqNumIdx), tid, srcIndex);
            end
        end
    end
end
end


function responseFrame = sendBA(edcaMAC, destinationAddress, seqNums, tid, dstId)
% sendBA(...) generate and send BA frame.
edcaMAC.MACBATx = edcaMAC.MACBATx + 1;

% Update the BA bitmap context with the newly received sequence numbers
[updatedBitmap, ssn] = updateBABitmap(edcaMAC, seqNums, tid, dstId);
% Convert the BA bitmap to hexadecimal format
baBitmapDec = bi2de(reshape(updatedBitmap, 8, [])');
baBitmapDec(1:end) = baBitmapDec(end:-1:1);
bitmapHex = reshape(dec2hex(baBitmapDec, 2)', 1, []);

% Create a structure with properties corresponding to the input for
% generateControlFrame function to generate block acknowledgment.
responseFrameData = struct('FrameType', 'Block Ack', ...
    'Duration', 0, ...
    'Address1', destinationAddress, ...
    'Address2', edcaMAC.MACAddress, ...
    'BABitmap', bitmapHex, ...
    'TID', tid, ...
    'SSN', ssn);

% Generate BA frame
[responseFrame, responseLength] = generateControlFrame(edcaMAC, responseFrameData);
baLength = responseLength;

cbw = 20;
numSTS = 1;
% BA frame Tx time
edcaMAC.Tx.FrameTxTime = calculateTxTime(edcaMAC, cbw, edcaMAC.Rx.ResponseMCS,...
    baLength, hFrameFormatsEnum.NonHT, numSTS);

edcaMAC.Rx.ResponseLength = baLength;
edcaMAC.Rx.ResponseFlag = true;

% Move to responding state
edcaMAC.Rx.RxState = edcaMAC.Rx.RESPONDING;

% Maintain SIFS time before transmitting response frame for the
% received frame
edcaMAC.NextInvokeTime = edcaMAC.SIFSTime;
end


function responseFrame = sendResponse(edcaMAC, destinationAddress, responseType, duration)
% sendResponse(...) generates response frame to the received frame.

% Create a structure with properties corresponding to the input for
% generateControlFrame function to generate block acknowledgment.
responseFrameData = struct('FrameType', responseType, ...
    'Duration', duration, ...
    'Address1', destinationAddress, ...
    'Address2', edcaMAC.MACAddress, ...
    'BABitmap', false(edcaMAC.BABitmapLength, 1), ...
    'TID', 0, ...
    'SSN', 0);

% Generate response frame
[responseFrame, responseLength] = generateControlFrame(edcaMAC, responseFrameData);

cbw = 20;
numSTS = 1;
% Response frame Tx time
edcaMAC.Tx.FrameTxTime = calculateTxTime(edcaMAC, cbw, edcaMAC.Rx.ResponseMCS, responseLength, ...
    hFrameFormatsEnum.NonHT, numSTS);

edcaMAC.Rx.ResponseLength = responseLength;
edcaMAC.Rx.ResponseFlag = true;

% Move to responding state
edcaMAC.Rx.RxState = edcaMAC.Rx.RESPONDING;

% Maintain SIFS time before transmitting response frame for the
% received frame
edcaMAC.NextInvokeTime = edcaMAC.SIFSTime;
end


function [bitmap, ssn] = updateBABitmap(edcaMAC, rxSeqNums, tid, nodeIndex)
% updateBABitmap(...) updates the BA bitmap context and returns the
% updated BITMAP and starting sequence number (SSN).
%
% Reference: Section-10.24.7.3 in IEEE Std 802.11-2016

% Maximum allowed sequence number
maxSeqNum = 4095;
% Half of the maximum sequence number
maxSeqNumBy2 = 2048;
% Bitmap size (64-bits/256-bits)
bitMapSize = edcaMAC.BABitmapLength;
% Window size (64-bits/256-bits)
winSize = edcaMAC.BABitmapLength;

% Existing bitmap and SSN context of the TID
acIndex = edcaMAC.TID2AC(tid+1) + 1; % AC starts at 0. Add 1 for indexing.
bitmap = edcaMAC.Rx.BABitmap(nodeIndex, acIndex, 1:edcaMAC.BABitmapLength);
ssn = edcaMAC.Rx.LastSSN(nodeIndex, acIndex);

% Empty bitmap
emptyBitmap = false(bitMapSize, 1);

% Flag indicating updated window includes wrap-around
isWrapAround = false;

% Increment for array indexing
rxSeqNums = rxSeqNums+1;

if(rxSeqNums(end)-winSize)<0
    % Updated window includes sequence number wrap-around
    %
    %        SeqNums:  0------------------------------------------4095
    % Updated Window:       ]                                 [
    %                  Window-end                         Window-start
    ssn_new = maxSeqNum-(winSize-rxSeqNums(end))+1;
    isWrapAround = true;
else
    % Updated window does not include sequence number wrap-around
    %
    %        SeqNums:  0----------------------------------------4095
    % Updated Window:             [                ]
    %                       Window-start      Window-end
    ssn_new = rxSeqNums(end)-winSize;
end

% Flag indicating that previous window is in wrap-around condition
isPrevWindowWrapped = (ssn + winSize - 1) >= 4096;

if isPrevWindowWrapped
    winEnd = ssn + winSize-1 - 4096;
end

% New SSN is older than present SSN and updated window is overlapping
% with current window
% 1. Overlap due to updated window wrap-around
% 2. Overlap when previous window is not in wrap-around
% 3. Overlap when previous window is in wrap-around
if((ssn_new-ssn > maxSeqNumBy2) && (rxSeqNums(end) > ssn) && isWrapAround) || ...
        ((ssn_new < ssn) && (rxSeqNums(end) > ssn)) || ...
        ((ssn_new < ssn) && isPrevWindowWrapped && (rxSeqNums(end) > ssn || rxSeqNums(end) <= winEnd))
    ssn_new = ssn;
end

% Increment for array indexing
ssn = ssn+1;
ssn_new = ssn_new+1;
diff = ssn_new-ssn;

% New SSN is found after the window
if (diff >= winSize)
    if (diff > maxSeqNumBy2)
        % If the new SSN is found after half of the max sequence number
        % from previous window, then consider them as old sequence numbers.
        
        edcaMAC.MACDuplicateAMPDURx = edcaMAC.MACDuplicateAMPDURx + 1;
    else
        % If the new SSN is found after previous window and before half of
        % the max sequence numbers from previous window.

        % Clear the previous bitmap and update SSN to new SSN
        bitmap = emptyBitmap;
        ssn = ssn_new;
        
        if ((ssn_new + winSize-1) > maxSeqNum)
            % Window includes sequence numbers wrap-around
            %
            %   SeqNums:  0---------------------------------------4095
            %   Window:       ]                             [
            %             Window-end                    Window-start
            
            % Set the bits in the bitmap corresponding to the received
            % frame sequence numbers
            for i = 1:numel(rxSeqNums)
                if(rxSeqNums(i) >= ssn_new)
                    bitmap(rxSeqNums(i) - ssn_new + 1) = 1;
                else
                    bitmap(maxSeqNum + 1 + rxSeqNums(i) - ssn_new + 1) = 1;
                end
            end
        else
            % Window does not include sequence number wrap-around
            %
            %   SeqNums:  0------------------------------------4095
            %   Window:             [                ]
            %                   Window-start      Window-end
            
            % Set the bits in the bitmap corresponding to the sequence
            % numbers in the received frame
            bitmap(rxSeqNums-ssn+1) = 1;
        end
    end
    
% New SSN is found before the window
elseif (diff < 0)

    if (diff > -maxSeqNumBy2) || ...
            ((diff <= -maxSeqNumBy2) && (rxSeqNums(end) >= rem((ssn + maxSeqNumBy2), 4096)))
        % If the new SSN is found before previous window and after half of
        % the max sequence number from previous window, then consider them
        % as old sequence numbers.
        
        edcaMAC.MACDuplicateAMPDURx = edcaMAC.MACDuplicateAMPDURx + 1;

    else
        % If the new SSN is found before previous window and before half of
        % the max sequence number from previous window, consider them as
        % new sequence numbers.

        % Store the part of previous bitmap from SSN to max sequence
        % number, when SSN is at the boundary of sequence number wrap-
        % around
        partialBitmap = bitmap(maxSeqNum-ssn+2 : end);
        bitmap = emptyBitmap;
        bitmap(1:numel(partialBitmap)) = partialBitmap;
        ssn = ssn_new;
        % Set the bits in the bitmap corresponding to the sequence
        % numbers in the received frame
        wrapIdx = ssn_new + winSize-1 - 4096;
        % Received sequence numbers in a wrap-around case
        if wrapIdx > 0
            % Set bits for sequence numbers from 0 to last sequence number
            for idx = 1:wrapIdx
                if any(rxSeqNums == idx)
                    bitmap(winSize - (wrapIdx-idx)) = 1;
                end
            end

            % Set bits for sequence numbers from SSN to 4095
            for idx = 1:winSize-wrapIdx
                if any(rxSeqNums == ssn+idx-1)
                    bitmap(idx) = 1;
                end
            end
        else % No wrap-around
            bitmap(rxSeqNums - ssn + 1) = 1;
        end
    end
    
% New SSN is found with in the previous window
else
    % Store the part of the previous bitmap
    partialBitmap = bitmap(diff+1 : end);
    bitmap = emptyBitmap;
    bitmap(1:numel(partialBitmap)) = partialBitmap;
    ssn = ssn_new;
    
    % Remove the sequence numbers that are part of previous window
    if (ssn > rxSeqNums(end))
        rxSeqNums = [reshape(rxSeqNums(rxSeqNums >= ssn), [], 1); reshape(rxSeqNums(rxSeqNums < winSize), [], 1)];
    else
        rxSeqNums = rxSeqNums(rxSeqNums >= ssn);
    end
    
    % Sequence number wrap-around
    if ((ssn_new + winSize-1) > maxSeqNum)
        for i = 1:numel(rxSeqNums)
            % Set the bitmap bits corresponding to the sequence numbers
            % in the received frame
            if(rxSeqNums(i) >= ssn_new)
                bitmap(rxSeqNums(i) - ssn_new + 1) = 1;
            else
                bitmap(maxSeqNum + 1 + rxSeqNums(i) - ssn_new + 1) = 1;
            end
        end
    else
        % Set the bitmap bits corresponding to the sequence numbers in
        % the received frame
        bitmap(rxSeqNums - ssn + 1) = 1;
    end
end

% Update context of the bitmap and SSN for the TID
ssn = ssn-1;
edcaMAC.Rx.BABitmap(nodeIndex, acIndex, 1:edcaMAC.BABitmapLength) = bitmap;
edcaMAC.Rx.LastSSN(nodeIndex, acIndex) = ssn;
end


function sendDataToApp(edcaMAC, rxFrame, rxAC, msduIndex, timestamp)
%sendDataToApp Fill the output packet to be given to the application

edcaMAC.PacketToApp.IsEmpty = false;
edcaMAC.PacketToApp.MSDUCount = edcaMAC.PacketToApp.MSDUCount+1;
edcaMAC.PacketToApp.MSDULength(edcaMAC.PacketToApp.MSDUCount) = rxFrame.PayloadLength(msduIndex, edcaMAC.UserIndexSU);
edcaMAC.PacketToApp.AC = rxAC;
edcaMAC.PacketToApp.DestinationID = edcaMAC.NodeID;
edcaMAC.PacketToApp.DestinationMACAddress = rxFrame.Address1;
isGroupAddr = isGroupAddress(edcaMAC, rxFrame.Address1);
edcaMAC.PacketToApp.FourAddressFrame(edcaMAC.PacketToApp.MSDUCount) = rxFrame.FourAddressFrame(msduIndex, edcaMAC.UserIndexSU);
if isGroupAddr
    edcaMAC.PacketToApp.MeshSourceAddress(edcaMAC.PacketToApp.MSDUCount, :) = rxFrame.Address3(msduIndex, :, edcaMAC.UserIndexSU);
    % Get the destination ID from the destination address
    [~, destNode] = hNodeInfo(2, 0, rxFrame.Address1);
    edcaMAC.PacketToApp.DestinationID = destNode(1);
else
    edcaMAC.PacketToApp.MeshSourceAddress(edcaMAC.PacketToApp.MSDUCount, :) = rxFrame.Address4(msduIndex, :, edcaMAC.UserIndexSU);
end
edcaMAC.PacketToApp.MeshDestinationAddress(edcaMAC.PacketToApp.MSDUCount, :) = rxFrame.Address3(msduIndex, :, edcaMAC.UserIndexSU);
edcaMAC.PacketToApp.MeshSequenceNumber(edcaMAC.PacketToApp.MSDUCount) = rxFrame.MeshSequenceNumber(msduIndex, edcaMAC.UserIndexSU);
edcaMAC.PacketToApp.Timestamp(edcaMAC.PacketToApp.MSDUCount) = timestamp(msduIndex, edcaMAC.UserIndexSU);
edcaMAC.PacketToApp.Data = [];
end

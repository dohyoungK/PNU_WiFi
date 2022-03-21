function incrementRetryCount(edcaMAC)
%incrementRetryCount Increments the retry counter for the access category
%(AC) that has channel access.

%   Copyright 2021 The MathWorks, Inc.

tx = edcaMAC.Tx;
txStationIDs = tx.TxStationIDs(edcaMAC.UserIndexSU);
acIdx = edcaMAC.OwnerAC+1;

global TransmissionFail;
idx = size(TransmissionFail,2); 

if TransmissionFail(idx).DestinationSTA ~= 0
    idx = idx + 1;
end

if tx.RTSSent
    numRetries = 1;
else
    numRetries = tx.TxWaitingForAck(txStationIDs, acIdx);
end

if tx.IsShortFrame
    if (tx.ShortRetries(txStationIDs, acIdx) < (edcaMAC.MaxShortRetries-1)) % && ~edcaMAC.RateControlDiscard
        % Increment the retry counter
        tx.ShortRetries(txStationIDs, acIdx) = tx.ShortRetries(txStationIDs, acIdx) + 1;
        % Increase the contention window
        edcaMAC.CW(acIdx) = min(edcaMAC.CW(acIdx)*2+1, edcaMAC.CWMax(acIdx));
        
        % Update per AC retries statistics
        edcaMAC.MACTxRetriesAC(acIdx) = edcaMAC.MACTxRetriesAC(acIdx) + numRetries;
        edcaMAC.MACRetries = edcaMAC.MACRetries + numRetries; % total retries
        flag = 1;
        for j = 1:numel(TransmissionFail)
            if TransmissionFail(j).DestinationSTA == txStationIDs
                TransmissionFail(j).numRetries = edcaMAC.MACRetries;
                flag = 0;
            end
        end
        if flag
            TransmissionFail(idx).DestinationSTA = txStationIDs;
            TransmissionFail(idx).numRetries = edcaMAC.MACRetries;
            TransmissionFail(idx).numFails = 0;
        end
    else % Maximum retry limit is reached
        % Update statistics
        flag = 1;
        edcaMAC.MACTxFails = edcaMAC.MACTxFails + tx.TxWaitingForAck(txStationIDs, acIdx);
        for j = 1:numel(TransmissionFail)
            if TransmissionFail(j).DestinationSTA == txStationIDs
                TransmissionFail(j).numFails = edcaMAC.MACTxFails;
                flag = 0;
            end
        end
        if flag
            TransmissionFail(idx).DestinationSTA = txStationIDs;
            TransmissionFail(idx).numFails = edcaMAC.MACTxFails;
        end
        % Reset retry counter
        resetRetryCount(edcaMAC);
    end
else % Long retry
    if (tx.LongRetries(txStationIDs, acIdx) < (edcaMAC.MaxLongRetries-1)) % && ~edcaMAC.RateControlDiscard
        % Increment the retry counter
        tx.LongRetries(txStationIDs, acIdx) = tx.LongRetries(txStationIDs, acIdx) + 1;
        % Increase the contention window
        edcaMAC.CW(acIdx) = min(edcaMAC.CW(acIdx)*2+1, edcaMAC.CWMax(acIdx));
        
        % Update per AC retries statistics
        edcaMAC.MACTxRetriesAC(acIdx) = edcaMAC.MACTxRetriesAC(acIdx) + numRetries;
        edcaMAC.MACRetries = edcaMAC.MACRetries + numRetries; % total retries
        flag = 1;
        for j = 1:numel(TransmissionFail)
            if TransmissionFail(j).DestinationSTA == txStationIDs
                TransmissionFail(j).numRetries = edcaMAC.MACRetries;
                flag = 0;
            end
        end
        if flag
            TransmissionFail(idx).DestinationSTA = txStationIDs;
            TransmissionFail(idx).numRetries = edcaMAC.MACRetries;
            TransmissionFail(idx).numFails = 0;
        end
    else % Maximum retry limit is reached
        % Update statistics
        flag = 1;
        edcaMAC.MACTxFails = edcaMAC.MACTxFails + tx.TxWaitingForAck(txStationIDs, acIdx);
        for j = 1:numel(TransmissionFail)
            if TransmissionFail(j).DestinationSTA == txStationIDs
                TransmissionFail(j).numFails = edcaMAC.MACTxFails;
                flag = 0;
            end
        end
        if flag
            TransmissionFail(idx).DestinationSTA = txStationIDs;
            TransmissionFail(idx).numFails = edcaMAC.MACTxFails;
        end
        % Reset retry counter
        resetRetryCount(edcaMAC);
    end
end

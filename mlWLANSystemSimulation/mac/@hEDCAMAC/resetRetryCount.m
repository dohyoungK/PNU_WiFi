function resetRetryCount(edcaMAC)
%resetRetryCount Resets the retry counters and other transmission context
%   resetRetryCount = (EDCAMAC) resets the retry counters corresponding to
%   the access category of the last transmission and also resets other
%   transmission context.
%
%   EDCAMAC is an object of type hEDCAMAC. 

%   Copyright 2021 The MathWorks, Inc.

tx = edcaMAC.Tx;

% Reset the retry counter and CW min values
tx.ShortRetries(tx.TxStationIDs(edcaMAC.UserIndexSU), edcaMAC.OwnerAC+1) = 0;
tx.LongRetries(tx.TxStationIDs(edcaMAC.UserIndexSU), edcaMAC.OwnerAC+1) = 0;
edcaMAC.CW(edcaMAC.OwnerAC+1) = edcaMAC.CWMin(edcaMAC.OwnerAC+1);

% Reset waiting for ACK count.
tx.TxWaitingForAck(tx.TxStationIDs(edcaMAC.UserIndexSU), edcaMAC.OwnerAC+1) = 0;

% Number of MSDUs should be discarded from each user
for userIdx = 1:edcaMAC.NumTxUsers
    tx.MSDUDiscardCount(userIdx) = tx.InitialSubframesCount(tx.TxStationIDs(userIdx), tx.TxACs(userIdx));
end
tx.MSDUDiscardIndices = repmat((1:edcaMAC.MaxSubframes)', 1, edcaMAC.MaxMUStations);

% Remove last transmitted frame from MAC queue
edcaQueueManagement(edcaMAC, 'discard');
end

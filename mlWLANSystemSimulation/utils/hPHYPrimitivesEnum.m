classdef hPHYPrimitivesEnum
% hPHYPrimitivesEnum Enumeration for indications between the PHY and the MAC
% layer
%
%   Value = hPHYPrimitivesEnum.<ENUMVALUE> creates an enumeration with the
%   value specified by the ENUMVALUE.
%
%   hPHYPrimitivesEnum properties: 
%
%   CCAIdleIndication(1) - CCA idle indication
%   CCABusyIndication(2) - CCA busy indication
%   RxStartIndication(3) - Rx start indication
%   RxEndIndication(4) - Rx end indication
%   RxErrorIndication(5) - Rx error indication
%   TxStartRequest(7) - Tx start request
%   TxStartConfirm(8) - Tx start confirm
%   TxEndRequest(9) - Tx end request
%   TxEndConfirm(10) - Tx end confirm
%   UnknownIndication(11) - Unknown indication

%   Copyright 2021 The MathWorks, Inc.
    
    properties (Constant)
        % CCA idle indication
        CCAIdleIndication = 1
        % CCA busy indication
        CCABusyIndication = 2
        % Rx start indication
        RxStartIndication = 3
        % Rx end indication
        RxEndIndication = 4
        % Rx error indication
        RxErrorIndication = 5
        % Tx start request
        TxStartRequest = 7
        % Tx start confirm
        TxStartConfirm = 8
        % Tx end request
        TxEndRequest = 9
        % Tx end confirm
        TxEndConfirm = 10
        % Unknown / invalid indication
        UnknownIndication = 11
    end
end

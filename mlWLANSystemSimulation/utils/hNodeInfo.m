function [macAddr, nodeID] = hNodeInfo(opType, nodeID, varargin)
%hNodeInfo Performs get or set operation for MAC address of the given
% node
%
%   This method performs the operation specified by the OPTYPE. The OPTYPE
%   must be 0, 1 or 2. It supports the following operations.
%
%   MACADDR = hNodeInfo(0, NODEID) set the MAC address to the given
%   node ID, NODEID and returns it.
%
%   [MACADDR] = hNodeInfo(1, NODEID) returns the MAC address of the
%   given node ID, NODEID.
%
%   [~, NODEID] = hNodeInfo(2, NODEID, MACADDR) returns the node ID of
%   the node with the given MAC address, MACADDR.
%
%   NODEID is specified as either scalar or vector. If it is scalar, the
%   value specifies the node ID. If it is vector ([NODEID INTERFACEID]),
%   the value specifies the node ID, NODEID along with the interface ID,
%   INTERFACEID.
%
%   MACADDR is a decimal vector with 6 elements, representing the 6 octets
%   of the MAC address in decimal format.

%   Copyright 2021 The MathWorks, Inc.

% Information (node id and MAC address) of all nodes in the simulation
persistent nodeInfo;
% Count of number of nodes in the simulation
persistent nodeIdCounter;

% Initialize nodeInfo structure
if isempty(nodeInfo)
    s.id = 0;
    s.macAddr = [0 0 0 0 0 0];
    % Maximum number of nodes creation in a model is restricted to 1000.
    maxNumberOfNodes = 1000;
    % Maximum number of interfaces supported on each node
    maxSupportedInterfaces = 3;
    nodeInfo = repmat(s, maxNumberOfNodes, maxSupportedInterfaces);
end
% Initialize nodeIdCount to zero
if isempty(nodeIdCounter)
    nodeIdCounter = 0;
end

% First byte of MAC address contains the information about MAC address
% type. All MAC addresses that are locally managed should set Bit-1 (second
% bit from LSB) of the first byte to 1. Set it to 0 to use globally unique
% (OUI enforced) MAC addresses. This function assigns MAC addresses that
% are locally administrated.
macAddrByte1 = 2;

% Assign default value to output variable
macAddr = [macAddrByte1 0 0 0 0 0];

if numel(nodeID) > 1
    nID = nodeID(1);
    interface = nodeID(2);
else
    nID = nodeID;
    interface = 1;
end

% Switch to an operation type that is selected
switch(opType)
    case 0 % Assign MAC address
        % If MAC address of a node is all zeros, assign unique MAC address
        % to it. Otherwise, returns already assigned MAC address.
        if nodeInfo(nID, interface).id == 0
            % Increment nodeIdCounter by 1
            nodeIdCounter = nodeIdCounter+1;
            % Store nodeId in nodeInfo array
            nodeInfo(nID, interface).id = nID;

            % Generate a MAC address and store it in nodeInfo array
            % Use the 2nd byte for the node interface
            macAddr(2) = interface;
            macAddr(end-1) = floor(nID/250);
            macAddr(end) = rem(nID, 250);
            nodeInfo(nID, interface).macAddr = macAddr;
        end
        macAddr = nodeInfo(nID, interface).macAddr;
    case 1 % Return MAC address of the node
        % Find and return MAC address of a node using nodeId
        if (nID <= nodeIdCounter) && (nID > 0)
            macAddr = nodeInfo(nID, interface).macAddr;
        elseif nID == 65535 % Broadcast Node ID
            macAddr = [255 255 255 255 255 255];
        else
            error(['Cannot get MAC address for node ID ' int2str(nID)]);
        end
    case 2 % Returns Node ID corresponding to the given MAC address
        macAddrDec = hex2dec((reshape(varargin{1}, 2, [])'))';
        % Node address is broadcast address
        if isequal(macAddrDec, [255 255 255 255 255 255])
            nodeID = 65535; % Broadcast Node ID
        else
            nodeID(1) = macAddrDec(end-1)*250 + macAddrDec(end);
            nodeID(2) = macAddrDec(2);
        end
end

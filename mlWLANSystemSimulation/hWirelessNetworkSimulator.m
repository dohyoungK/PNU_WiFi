classdef hWirelessNetworkSimulator
%hWirelessNetworkSimulator Provides helper methods for simulating a wireless network

%   Copyright 2021 The MathWorks, Inc.

    methods
        function run(obj, nodes, simulationTime, statsLogger)
            %run Run the simulation
            %
            %   run(NODES, SIMULATIONTIME, STATSLOGGER) runs the simulation
            %   for all the nodes specified in the cell array NODES, for
            %   the specified simulation time, SIMULATIONTIME.
            %
            %   NODES is a cell array containing objects of type hWLANNode.
            %
            %   SIMULATIONTIME specifies the total simulation time.
            %
            %`  STATSLOGGER is an object of type hStatsLogger.
            
            % Initialize simulation parameters
            curTime = 0;                            % Current simulation time in microseconds
            elapsedTime = 0;                        % Elapsed time in microseconds
            numNodes = numel(nodes);                % Number of nodes
            nextInvokeTimes = zeros(1, numNodes);   % Next invoke times of all the nodes in microseconds
            
            while(curTime < simulationTime)
                % Run each node and advance the simulation time by 'elapsedTime'
                for nodeIdx = 1:numNodes
                    nextInvokeTimes(nodeIdx) = runNode(nodes{nodeIdx}, elapsedTime);
                end
                curTime = curTime + elapsedTime;
                
                % Distribute the transmitted packets (if any) from every node into the
                % receiving buffers of the other nodes. If there are no transmissions
                % to be processed by the nodes, advance the simulation time to the next
                % event.
                isPacketDistributed = distributePackets(obj, nodes);
                if isPacketDistributed
                    elapsedTime = 0;
                else
                    elapsedTime = min(nextInvokeTimes(nextInvokeTimes ~= -1));
                end
                
                % Update live visualization
                updateVisualization(statsLogger);
            end
        end
    end
    
    methods(Access = private)
        function txFlag = distributePackets(~, nodes)
            %distributePackets Distribute the transmitting data from the
            %nodes into the receiving buffers of all the nodes
            %
            %   TXFLAG = distributePackets(NODES) distributes the
            %   transmitting data from the nodes, NODES, into the receiving
            %   buffers of all the nodes and return, TXFLAG, to indicate if
            %   there is any transmission in the network
            %
            %   TXFLAG indicates if there is any transmission in the network
            %
            %   NODES is a cell array, where each element is an object of
            %   type 'hWLANNode'
            
            % Number of nodes
            numNodes = numel(nodes);
            % Reset the transmission flag to specify that the channel is free
            txFlag = false;
            
            % Get the data from all the nodes to be transmitted
            for nodeIdx = 1:numNodes
                txNode = nodes{nodeIdx};
                for interfaceIdx = 1:txNode.NumInterfaces
                    % Node has data to transmit
                    if (txNode.TxBuffer{interfaceIdx, 2}.Metadata.SubframeCount ~= 0)
                        txFrequency = txNode.TxBuffer{interfaceIdx, 1};
                        txData = txNode.TxBuffer{interfaceIdx, 2};
                        txFlag = true;
                        for rxIdx = 1:numNodes
                            % Copy Tx data into the receiving buffers of other nodes
                            if rxIdx ~= nodeIdx
                                rxNode = nodes{rxIdx};
                                pushChannelData(rxNode, txNode.NodePosition, txFrequency, txData);
                            end
                        end
                    end
                end
            end
        end
    end
end
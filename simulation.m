for ind = 1:2
    rng(2,'twister');                       % Seed for random number generator
    simulationTime = 0.5*1e6;               % Simulation time in microseconds
    showLiveStateTransitionPlot = true;     % Show live state transition plot for all nodes
    displayStatsInUITable = false;           % Display table of statistics
    showAPCoverage = false;                  % Show AP Coverage
    
    if ind == 2
        getOriginResult = false;
    else
        getOriginResult = true;
    end


    % Add the folder to the path for access to all helper files
    addpath(genpath(fullfile(pwd, 'mlWLANSystemSimulation')));

    % 2019-06-01 ~ 2019-12-31 Library-2 data
    % set LibraryData, Date, APNames, numSTA
    global APFloor
    [Date, APNames, numSTA, numStationAll, APFloor] = DataConfig(getOriginResult);

    numSTA.firstFloor
    numSTA.secondFloor
    numSTA.thirdFloor

    ScenarioParameters = struct;
    % Number of rooms in [x,y,z] directions
    ScenarioParameters.BuildingLayout = [1 1 APFloor.numAP];
    % Size of each room in meters [x,y,z]
    ScenarioParameters.RoomSize = [60 60 4];
    % Number of STAs
    ScenarioParameters.NumRx = numStationAll;
    % Receiver Range
    ScenarioParameters.ReceiverRange = 20;

    % Obtain random positions for placing nodes(기존 노드 위치 설정)
    [apPositions, staPositions] = hDropNodes(ScenarioParameters, APFloor, numSTA);

    if ~getOriginResult
        % Get STA Density and AP Additional Placement(추가 노드 위치 설정)
        [apPositions, APFloor]= AdditionalPlacement(apPositions, staPositions, APFloor, numSTA);
    end

    % Get the IDs and positions of each node
    [nodeConfigs, trafficConfigs] = hLoadConfiguration(ScenarioParameters, apPositions, staPositions, APFloor, APNames, numSTA, getOriginResult);


    % 채널 설정
    [nodeConfigs, trafficConfigs] = ChannelConfiguration(nodeConfigs, trafficConfigs, APFloor, numSTA, getOriginResult);


    % 기대 Throughput
    expectedThroughput = getThroughput(nodeConfigs, trafficConfigs, APFloor);


    % Create transmitter and receiver sites
    [txs,rxs] = hCreateSitesFromNodes(nodeConfigs, APNames, APFloor);

    % Create triangulation object and visualize the scenario
    tri = hTGaxResidentialTriangulation(ScenarioParameters);
    if ~getOriginResult
        hVisualizeLibraryScenario(tri,txs,rxs,apPositions,showAPCoverage);
    end

    % Generate propagation model and lookup table
    % 경로 손실 table(거리에 따른 신호 손실, 장애물에 따른 신호 손실)
    propModel = hTGaxResidentialPathLoss('Triangulation',tri,'ShadowSigma',0,'FacesPerWall',1);
    [pl,tgaxIndoorPLFn] = hCreatePathlossTable(txs,rxs,propModel); 

    % Create WLAN nodes
    wlanNodes = hCreateWLANNodes(nodeConfigs, trafficConfigs, simulationTime, tgaxIndoorPLFn);

    % channel utilization
    channelUtil = ChannelUtilization(wlanNodes);
    save('ChannelUtilization.mat', 'channelUtil');

    % Initialize visualization parameters and create an object for
    % hStatsLogger which is a helper for retrieving, and displaying
    % the statistics.
    global TransmissionData;
    TransmissionData = struct;
    TransmissionData(1).SourceAP = 0;

    global TransmissionFail;
    TransmissionFail = struct;
    TransmissionFail(1).DestinationSTA = 0;

    visualizationInfo = struct;
    visualizationInfo.DisablePlot = ~showLiveStateTransitionPlot;
    visualizationInfo.Nodes = wlanNodes;
    statsLogger = hStatsLogger(visualizationInfo);  % Object that handles retrieving and visualizing statistics
    networkSimulator = hWirelessNetworkSimulator;   % Object that handles network simulation

    % Run the simulation
    run(networkSimulator, wlanNodes, simulationTime, statsLogger);

    % Cleanup the persistent variables used in functions
    clear edcaPlotStats;

    % Save the TransmissionData to a mat file
    save('TransmissionData.mat', 'TransmissionData');
    save('TransmissionFail.mat', 'TransmissionFail');

    % Retrieve the statistics and store them in a mat file
    statistics = getStatistics(statsLogger, ~displayStatsInUITable);

    % Save the statistics to a mat file
    save('statistics.mat', 'statistics');

    % Plot the throughput, packet loss ratio, packet delivery ratio, ,packet error ratio, and average packet latency at each node
    hPlotNetworkStats(statistics, wlanNodes, nodeConfigs, trafficConfigs, expectedThroughput, getOriginResult, simulationTime);
    if getOriginResult
        clear;
    end
end

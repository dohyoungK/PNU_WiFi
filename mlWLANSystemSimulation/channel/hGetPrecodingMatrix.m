function W = hGetPrecodingMatrix(cfg,varargin)
%hGetPrecodingMatrix(CFGHE) return the precoding matrix
%
%   W = hGetPrecodingMatrix(CFGHE) returns the precoding matrix W given the
%   format configuration object CFG.
%
%   W is a Nst-by-Nsts-by-Ntx precoding matrix, where Nst is the number of
%   active subcarriers, Nsts is the number of space-time streams, and Ntx
%   is the number of transmit antennas.
%
%   CFG is the format configuration object of type <a href="matlab:help('wlanVHTConfig')">wlanVHTConfig</a>,
%   <a href="matlab:help('wlanHTConfig')">wlanHTConfig</a>, <a
%   href="matlab:help('wlanNonHTConfig')">wlanNonHTConfig</a>, <a
%   href="matlab:help('wlanS1GConfig')">wlanS1GConfig</a>, or
%   <a href="matlab:help('wlanHESUConfig')">wlanHESUConfig</a>.
%
%   W = hGetPrecodingMatrix(CFGHE,FIELD) returns the precoding used for the
%   field. FIELD can be 'data' or 'preamble'.
%
%   W = hGetPrecodingMatrix(CFG,FIELD,CFGREF,[RUIDXREF],FIELDREF) returns
%   the precoding specified in CFG and FIELD but for subcarriers defined by
%   CFGREF and FIELDREF. When CFGREF is of type <a
%   href="matlab:help('wlanHEMUConfig')">wlanHEMUConfig</a> RUIDXREF is the
%   RU index. When CFG is of type <a
%   href="matlab:help('wlanHEMUConfig')">wlanHEMUConfig</a> W is a cell
%   array, were each element contains the precoding matrix for an RU which
%   overlaps the reference OFDM subcarrier configuration.
%
%   W = hGetPrecodingMatrix(CFGHEMU,RUIDX,FIELD) returns the precoding for
%   the RU specified by RUIDX.
%
%   W = hGetPrecodingMatrix(...,SSFACTOR) returns the precoding with
%   subcarriers subsampled SSFACTOR times.

%   Copyright 2021 The MathWorks, Inc.

%#codegen

[field,ruIdx,cfgRef,ruIdxRef,fieldRef,subsampleFactor,diffOFDMRef] = parseInputs(cfg,varargin{:});

isMUCfg = isa(cfg,'wlanHEMUConfig');

if isMUCfg && strcmp(field,'data') && ruIdx==-1 
    % Extract the precoding from all RUs in a wlanHEMUConfig at subcarriers
    % specified by the reference configuration. Return a cell array where
    % each element corresponds to the overlapping subcarriers from an RU
    W = getOFDMAPrecodingMatrix(cfg,'data',cfgRef,fieldRef,ruIdxRef,subsampleFactor);
    return
end
    
% Get the cyclic shift applied per OFDM symbol and space-time stream or transmit antenna
[Wcs,ofdmInfo,activeSCInd] = getCyclicShiftMatrix(cfg,field,ruIdx,diffOFDMRef,cfgRef,fieldRef,ruIdxRef,subsampleFactor);

% Precoding includes per 20-MHz subchannel rotation
gamma = getCarrierRotation(cfg,field);
Wcs = bsxfun(@times,Wcs,gamma(ofdmInfo.ActiveFFTIndices,:,:));

if strcmp(field,'data') && ~isa(cfg,'wlanNonHTConfig')
    % Spatial mapping only relevant for:
    % * Data field, as not supporting BeamChange=false
    % * Configurations which perform spatial mapping
    Wsm = getSpatialMappingMatrix(cfg,ruIdx,ofdmInfo,activeSCInd);
    W = bsxfun(@times,Wsm,Wcs); % Nst-by-Nsts-by-Ntx
    
    if isMUCfg
        % wlanHEMUConfig
        % The transmit power is normalized by the number of space-time streams, RU size etc.
        allocInfo = ruInfo(cfg);
        numSTS = allocInfo.NumSpaceTimeStreamsPerRU;
        alpha = allocInfo.PowerBoostFactorPerRU;
        ruSize = allocInfo.RUSizes;
        ruScalingFactor = alpha(ruIdx)/sqrt(numSTS(ruIdx));
        allScalingFactor = sqrt(sum(ruSize))/sqrt(sum(alpha.^2.*ruSize));
        W = W*allScalingFactor*ruScalingFactor;
    else
        % The transmit power is normalized by the number of space-time
        % streams. To make things easier perform this normalization in the
        % precoder. The normalization by number of transmit antennas is
        % done as part of the spatial mapping matrix calculation.
        W = W/sqrt(cfg.NumSpaceTimeStreams);
    end
else
    W = Wcs;
    % The transmit power is normalized by the number of transmit antennas.
    % To make things easier perform this normalization in the precoder. For
    % other formats this is performed in spatial mapping - but there is no
    % spatial mapping for non-HT or preambles.
    W = W/sqrt(cfg.NumTransmitAntennas);
end

% The transmitter normalizes the waveform, therefore depending on the
% number of active subcarriers out of the FFT length the power per
% subcarrier can differ. Therefore, account for this difference by scaling
% the precoding matrix. If the reference has more active subcarriers than
% the interference, we would expect the energy per subcarrier when
% demodulating using the reference config to be higher than if demodulating
% the expected field/config.
if diffOFDMRef 
    ofdmInfoFOI = getOFDMInfo(cfg,field,ruIdx);
    ofdmInfoRef = getOFDMInfo(cfgRef,fieldRef,ruIdxRef);
    if isMUCfg && strcmp(field,'data')
        allocInfo = ruInfo(cfg);
        numTonesTotal = sum(allocInfo.RUSizes);
    else
        numTonesTotal = ofdmInfoFOI.NumTones;
    end
    activeScalar = numTonesTotal/ofdmInfoFOI.FFTLength;
    
    isMURefCfg = isa(cfgRef,'wlanHEMUConfig');
    if isMURefCfg && strcmp(fieldRef,'data')
        allocInfo = ruInfo(cfgRef);
        numTonesTotalRef = sum(allocInfo.RUSizes);
    else
        numTonesTotalRef = ofdmInfoRef.NumTones;
    end
    activeScalarRef = numTonesTotalRef/ofdmInfoRef.FFTLength;
    activeSCScaler = sqrt(activeScalarRef/activeScalar); % Convert power ratio to voltage scalar
    W = W*activeSCScaler;
end

end

function [field,ruIdx,cfgRef,ruIdxRef,fieldRef,ssFactor,diffOFDMRef,isMUFOI,isMURef] = parseInputs(cfg,varargin)
    
    % Defaults
    ruIdx = -1;
    cfgRef = [];
    ruIdxRef = 1;
    fieldRef = 'data';
    ssFactor = 1; % Subsample factor
    isMUFOI = false;
    isMURef = false;
    
    validateField = true;
    useRefCfg = false;
    
    switch nargin
        case 1
            % W = hGetPrecodingMatrix(CFG)
            field = 'data';
        case 2
            if isnumeric(varargin{1})
                % W = hGetPrecodingMatrix(CFG,RUIDX)
                isMUFOI = true;
                ruIdx = varargin{1};
                field = 'data';
                validateField = false;
            else
                % W = hGetPrecodingMatrix(CFG,FIELD)
                field = varargin{1};
            end
        case 3
            if isnumeric(varargin{1})
                % W = hGetPrecodingMatrix(CFG,RUIDX,FIELD)
                isMUFOI = true;
                ruIdx = varargin{1};
                if isnumeric(varargin{2})
                    field = 'data';
                    validateField = false;
                else
                    field = varargin{2};
                end
            else
                % W = hGetPrecodingMatrix(CFG,FIELD,SSFACTOR)
                field = varargin{1};
                ssFactor = varargin{2};
            end
        case 4
            if isnumeric(varargin{1})
                % W = hGetPrecodingMatrix(CFG,RUIDX,FIELD,SSFACTOR)
                isMUFOI = true;
                ruIdx = varargin{1};
                field = varargin{2};
                ssFactor = varargin{3};
            else
                % W = hGetPrecodingMatrix(CFG,FIELD,CFGREF,FIELDREF)
                field = varargin{1};
                cfgRef = varargin{2};
                fieldRef = varargin{3};
                useRefCfg = true;
            end
        case 5
            if isnumeric(varargin{3})
                % W = hGetPrecodingMatrix(CFG,FIELD,CFGREF,RUIDXREF,FIELDREF)
                isMURef = true;
                ruIdxRef = varargin{3};
                fieldRef = varargin{4};
            else
                % W = hGetPrecodingMatrix(CFG,FIELD,CFGREF,FIELDREF,SSFACTOR)
                fieldRef = varargin{3};
                ssFactor = varargin{4};
            end
            field = varargin{1};
            cfgRef = varargin{2};
            useRefCfg = true;
        case 6
            if isnumeric(varargin{1})
                % W = hGetPrecodingMatrix(CFGMU,RUIDX,FIELD,CFGREF,RUIDXREF,FIELDREF)
                isMUFOI = true;
                ruIdx = varargin{1};
                field = varargin{2};
                cfgRef = varargin{3};
                ruIdxRef = varargin{4};
                fieldRef = varargin{5};
            else
                % W = hGetPrecodingMatrix(CFG,FIELD,CFGREF,RUIDXREF,FIELDREF,SSFACTOR)
                field = varargin{1};
                cfgRef = varargin{2};
                ruIdxRef = varargin{3};
                fieldRef = varargin{4};
                ssFactor = varargin{5};
            end
            isMURef = true;
            useRefCfg = true;
        case 7
            % W = hGetPrecodingMatrix(CFGMU,RUIDX,FIELD,CFGREF,RUIDXREF,FIELDREF,SSFACTOR)
            isMUFOI = true;
            isMURef = true;
            ruIdx = varargin{1};
            field = varargin{2};
            cfgRef = varargin{3};
            ruIdxRef = varargin{4};
            fieldRef = varargin{5};
            ssFactor = varargin{6};
            useRefCfg = true;
    end
        
    if validateField
        validatestring(field,{'data','preamble'},mfilename);
    end
    
    if useRefCfg && isa(cfg,'wlanHEMUConfig')
        % If a refererence configuration is passed then the 
        isMUFOI = true;
    end
    
    % If field or waveform format for reference differ from
    % receiver then extract appropriate subcarriers
    diffOFDMRef = useRefCfg && ...
        (~strcmp(field,fieldRef) || ...           % Fields are different
        ~strcmp(class(cfgRef),class(cfg)) || ...  % Configurations are different
        (strcmp(class(cfgRef),class(cfg))) && isMUFOI && ((ruIdx~=ruIdxRef) || ~isequal(cfg.AllocationIndex,cfgRef.AllocationIndex))); % OFDMA allocations are different or RU indices are different
end

function gamma = getCarrierRotation(cfg,field)
% Get a vector of tone rotation per subcarrier
    if strcmp(field,'data')
        switch class(cfg)
            case {'wlanHEMUConfig','wlanHESUConfig'}
                Nfft = wlan.internal.cbw2nfft(cfg.ChannelBandwidth)*4;
                gamma = ones(Nfft,1);
            otherwise % {'wlanVHTConfig','wlanHTConfig','wlanNonHTConfig'}
                gamma = wlan.internal.vhtCarrierRotations(cfg.ChannelBandwidth);
        end
    else % 'preamble'
        % For all formats same pre-HE rotation applied
        gamma = wlan.internal.hePreHECarrierRotations(cfg);
    end
end

function [csd,ofdmInfo,activeSCInd] = getCyclicShiftMatrix(cfg,field,ruIndx,diffOFDMRef,cfgRef,fieldRef,ruIdxRef,subsampleFactor)
% CSD = getCyclicShiftMatrix(CFG) returns a Nst-by-Nsts-by-1/Ntx matrix
% containing the cyclic shift applied to each subcarrier and space-time
% stream in the Data filed. Nst is the number of active subcarriers and
% Nsts is the number of space-time streams. If the cyclic shift applied to
% each transmitter is the same the size of third dimension returned is 1.
%
% CSD = getCyclicShiftMatrix(CFG,FIELD) returns the cyclic shift applied to
% the FIELD. FIELD can be 'preamble' or 'data'.
%
% CSD = getCyclicShiftMatrix(CFGMU,RUIDX,FIELD) the cyclic shift
% applied to an RU with index RUIDX.
%
% CSD = getCyclicShiftMatrix(CFG,FIELD,CFGREF,FIELDREF) returns the cyclic
% shift specified in CFG and FIELD but for subcarriers defined by CFGREF
% and FIELDREF.
%
% CSD = getCyclicShiftMatrix(CFG,FIELD,CFGMUREF,RUIDXREF,FIELDREF) returns
% the cyclic shift specified in CFG and FIELD but for subcarriers defined
% by multi-user configuration CFGMUREF and RUIDXREF and FIELDREF.
%
% CSD = getCyclicShiftMatrix(...,SSFACTOR) returns subcarriers subsampled
% by SSFACTOR.
%
% [...,OFDMINFO,CLOSETSCIND] = getCyclicShiftMatrix(...) additionally
% returns a structure containing OFDM information (OFDMINFO) and an array
% containing the subcarrier indices of the OFDM configuration of CFG or
% CFGMU used to obtain the cyclic shift for OFDM configuration of CFGREF or
% CFGMUREF.

% Get OFDM info for OFDM config of field of interest
ofdmInfo = getOFDMInfo(cfg,field,ruIndx);

if diffOFDMRef
    % If the reference OFDM subcarrier indices differ from those of the
    % waveform configuration then set OFDM info such that the appropriate
    % subcarriers from the waveform configuration are selected
    
    ofdmInfoRef = getOFDMInfo(cfgRef,fieldRef,ruIdxRef);
    % Ratio of subcarrier spacing - ASSUME THE BANDWIDTH IS THE SAME
    r = ofdmInfoRef.FFTLength/ofdmInfo.FFTLength;
    
    % Find the closet subcarrier index of interferer which to each
    % subcarrier index of the reference OFDM configuration. closestSCDist
    % is the distance (in subcarriers), and activeSCInd contains the
    % indices the closest interfering subcarrier for each reference
    % subcarrier. These are the "active" subcarrier indices which are used
    % to extract the appropriate FFT indices and spatial mapping matrix
    % elements.
    [closestSCDist,activeSCInd] = min(abs(ofdmInfo.ActiveFrequencyIndices*r - ...
        ofdmInfoRef.ActiveFrequencyIndices'));
    
    % If the distance between the closest interference subcarrier and the
    % reference subcarrier is large then assume there is no active
    % overlapping interference subcarrier. Create an array of logical
    % indices, inactiveFFTLogInd, indicating inactive interfering
    % subcarriers.
    inactiveFFTLogInd = closestSCDist>r/2;
    
    % The above two processes result in the following:
    % Consider the interference configuration subcarrier spacing is 4x that
    % of the interference.
    %
    %       Interference:  x  x  x  A  x  x  x  B  x  x  x  C  x  x  x  D  x  x  x
    %          Reference:  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19
    %
    % The active subcarrier indices are the interference subcarrier indices
    % closest to each reference subcarrier. In the above example there are
    % four indices with values A, B, C, and D. Therefore:
    %
    %        activeSCInd:  1  1  1  1  1  2  2  2  2  3  3  3  4  4  4  4  4  4  4
    %
    % If active subcarriers are too far away they are deemed inactive:
    %
    %  inactiveFFTLogInd:  1  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  1
    %
    % This will result in the following precoding values being used at each
    % reference subcarrier (the inactive ones are set to 0):
    %
    %             result:  0  A  A  A  A  B  B  B  B  C  C  C  C  D  D  D  D  D  0
    
    % Update OFDM configuration of interference for subcarriers which will
    % be used for the reference configuration. Note inactive subcarriers
    % are included.
    ofdmInfo.ActiveFFTIndices = ofdmInfo.ActiveFFTIndices(activeSCInd);
    ofdmInfo.NumTones = numel(ofdmInfo.ActiveFFTIndices);
    ofdmInfo.ActiveFrequencyIndices = ofdmInfo.ActiveFFTIndices-(ofdmInfo.FFTLength/2+1);
else
    % All subcarriers to be used for reference
    activeSCInd = 1:ofdmInfo.NumTones;
    inactiveFFTLogInd = false(1,ofdmInfo.NumTones);
end

if subsampleFactor>1
    % Subsample the subcarriers
    activeSCInd = activeSCInd(1:subsampleFactor:end);
    inactiveFFTLogInd = inactiveFFTLogInd(1:subsampleFactor:end);
    ofdmInfo.ActiveFFTIndices = ofdmInfo.ActiveFFTIndices(1:subsampleFactor:end);
    ofdmInfo.NumTones = numel(ofdmInfo.ActiveFFTIndices);
    ofdmInfo.ActiveFrequencyIndices = ofdmInfo.ActiveFFTIndices-(ofdmInfo.FFTLength/2+1);
end

% Get the cyclic shift per space-time stream or transmit antenna depending
% on the format and field. For Non-HT format or preamble, the shift is per
% transmit antenna. Create a 'mock' channel estimate of the correct
% dimensions to apply the cyclic shift.
cbw = wlan.internal.cbwStr2Num(cfg.ChannelBandwidth);
isTxAntCSD = strcmp(field,'preamble') || isa(cfg,'wlanNonHTConfig');
if isTxAntCSD
    csh = wlan.internal.getCyclicShiftVal('OFDM',cfg.NumTransmitAntennas,cbw);
    mockHEst = ones(ofdmInfo.NumTones,cfg.NumTransmitAntennas); % Cyclic shift per-antenna
else
    if isa(cfg,'wlanHEMUConfig')
        allocInfo = ruInfo(cfg);
        numSTS = allocInfo.NumSpaceTimeStreamsPerRU(ruIndx);
        csh = wlan.internal.getCyclicShiftVal('VHT',numSTS,cbw); % Same CSD for HE, VHT, and HT
    else % 'wlanHESUConfig','wlanVHTConfig','wlanHTConfig'
        numSTS = cfg.NumSpaceTimeStreams;
        csh = wlan.internal.getCyclicShiftVal('VHT',cfg.NumSpaceTimeStreams,cbw); % Same CSD for HE, VHT, and HT
    end
    mockHEst = ones(ofdmInfo.NumTones,numSTS); % Cyclic shift per-space-time stream
end

% Apply cyclic shift
k = ofdmInfo.ActiveFrequencyIndices;
csdTmp = wlan.internal.cyclicShiftChannelEstimate(mockHEst,csh,ofdmInfo.FFTLength,k);

if isTxAntCSD
    % CSD applied over second dimension so permute to third dimension to represent transmit antennas
    csd = permute(csdTmp,[1 3 2]);
else
    csd = csdTmp;
end

% If subcarriers are deemed to be inactive then zero them - this will "turn
% them off" in calculations using the precoding matrix
csd(inactiveFFTLogInd,:,:) = 0;

end

function Q = getSpatialMappingMatrix(cfg,ruIdx,ofdmInfo,activeSCInd)
%getSpatialMappingMatrix Returns spatial mapping matrix used.
%   Q = getSpatialMappingMatrix(CFG,RUIDX,OFDMINFO,ACTIVESCIND) returns the
%   spatial mapping matrix used for each occupied subcarrier in the data
%   portion.
%
%   Q is Nst-by-Nsts-by-Ntx where Nst is the number of occupied
%   subcarriers, Nsts is the number of space-time streams, and Ntx is the
%   number of transmit antennas.
%
%   CFG is a format configuration object.
%
%   RUIDX is the index of the RU of interest. This is used to extract an RU
%   if CFG is of type wlanHEMUConfig.
%
%   OFDMINFO is the OFDM info structure.
%
%   ACTIVESCIND is an array containing subcarrier indices to use within
%   active RU subcarriers - this allows for subsampling of the spatial
%   mapping matrix.

    if isa(cfg,'wlanHEMUConfig')
        allocInfo = ruInfo(cfg);
        assert(ruIdx>0)
        numSTS = allocInfo.NumSpaceTimeStreamsPerRU(ruIdx);
        mappingType = cfg.RU{ruIdx}.SpatialMapping;
        mappingMatrix = cfg.RU{ruIdx}.SpatialMappingMatrix;
    else
        numSTS = sum(cfg.NumSpaceTimeStreams); % For VHT might be a vector
        mappingType = cfg.SpatialMapping;
        mappingMatrix = cfg.SpatialMappingMatrix;
    end
    numTx = cfg.NumTransmitAntennas;
    Nst = ofdmInfo.NumTones;

    switch mappingType
        case 'Direct'
            Q = repmat(permute(eye(numSTS,numTx),[3 1 2]),Nst,1,1);
        case 'Hadamard'
            hQ = hadamard(8);
            normhQ = hQ(1:numSTS,1:numTx)/sqrt(numTx);
            Q = repmat(permute(normhQ,[3 1 2]),Nst,1,1);
        case 'Fourier'
            [g1, g2] = meshgrid(0:numTx-1, 0:numSTS-1);
            normQ = exp(-1i*2*pi.*g1.*g2/numTx)/sqrt(numTx);
            Q = repmat(permute(normQ,[3 1 2]),Nst,1,1);
        otherwise % 'Custom'            
            if ismatrix(mappingMatrix) && (size(mappingMatrix, 1) == numSTS) && (size(mappingMatrix, 2) == cfg.NumTransmitAntennas)
                % MappingMatrix is Nsts-by-Ntx
                Q = repmat(permute(normalize(mappingMatrix(1:numSTS, 1:numTx),numSTS),[3 1 2]),Nst,1,1);
            else
                % MappingMatrix is Nst-by-Nsts-by-Ntx
                Q = mappingMatrix(activeSCInd,:,:); % Extract active subcarriers to use from the mapping matrix
                Qp = permute(Q,[2 3 1]);
                Qn = coder.nullcopy(complex(zeros(numSTS,numTx,Nst)));
                for i = 1:Nst
                    Qn(:,:,i) = normalize(Qp(:,:,i),numSTS); % Normalize mapping matrix
                end
                Q = permute(Qn,[3 1 2]);
            end
    end
end

function Q = normalize(Q,numSTS)
% Normalize mapping matrix
    Q = Q * sqrt(numSTS)/norm(Q,'fro');
end

function ofdmInfo = getOFDMInfo(cfg,field,varargin)
% Return a structure containing the OFDM configuration for a field and
% configuration.
    if strcmp(field,'data')
        % Get OFDM info for data fields of formats
        switch class(cfg)
            case 'wlanHEMUConfig'
                ofdmInfo = wlanHEOFDMInfo('HE-Data',cfg,varargin{:});
            case 'wlanHESUConfig'
                ofdmInfo = wlanHEOFDMInfo('HE-Data',cfg);
            case 'wlanVHTConfig'
                ofdmInfo = wlanVHTOFDMInfo('VHT-Data',cfg);
            case 'wlanHTConfig'
                ofdmInfo = wlanHTOFDMInfo('HT-Data',cfg);
            case 'wlanNonHTConfig'
                ofdmInfo = wlanNonHTOFDMInfo('NonHT-Data',cfg.ChannelBandwidth);
            otherwise
                error('Unexpected format');
        end
    else % 'preamble'
        % Get OFDM info for preamble fields of formats
        switch class(cfg)
            case 'wlanHEMUConfig'
                ofdmInfo = wlanHEOFDMInfo('HE-SIG-A',cfg);
            case 'wlanHESUConfig'
                ofdmInfo = wlanHEOFDMInfo('HE-SIG-A',cfg);
            case 'wlanVHTConfig'
                ofdmInfo = wlanVHTOFDMInfo('VHT-SIG-A',cfg);
            case 'wlanHTConfig'
                ofdmInfo = wlanHTOFDMInfo('HT-SIG',cfg);
            case 'wlanNonHTConfig'
                ofdmInfo = wlanNonHTOFDMInfo('NonHT-Data',cfg.ChannelBandwidth);
            otherwise
                error('Unexpected format');
        end
    end
end

function W = getOFDMAPrecodingMatrix(cfg,field,cfgRef,fieldRef,ruIdxRef,subsampleFactor)
% Return a cell array of matrices as the configuration of interest is OFDMA
% and therefore, multiple RUs may contribute to the precoding matrix at
% reference subcarriers.

    % Get the precoding matrix for each RU at reference subcarriers and
    % find the number of overlapping subcarriers in each RU.
    allocInfo = ruInfo(cfg);
    Q = cell(1,allocInfo.NumRUs);
    activeSCPerRU = cell(1,allocInfo.NumRUs);
    numActiveSCPerRU = zeros(1,allocInfo.NumRUs);
    for iru = 1:allocInfo.NumRUs
        Qtmp = hGetPrecodingMatrix(cfg,iru,field,cfgRef,ruIdxRef,fieldRef,subsampleFactor);
        Q{iru} = Qtmp;
        activeSCPerRUtmp = all(all(Qtmp~=0,3),2);
        activeSCPerRU{iru} = activeSCPerRUtmp;
        numActiveSCPerRU(iru) = sum(activeSCPerRUtmp);
    end

    % Find which RUs contribute to the precoding at the reference location
    % as they have active subcarriers
    activeRU = numActiveSCPerRU>0;
    numActiveRUs = sum(activeRU);

    if numActiveRUs==0
        % Return an zeros precoding matrix the size of the reference (use 1
        % space-time stream) as no RUs active
        W = {zeros(size(Qtmp,1),1,cfg.NumTransmitAntennas)};
        return
    end
    
    activeRUInd = find(activeRU);
    lastActiveRUInd = activeRUInd(end);

    % Find any subcarriers which are not active in any of the precoding RUs
    % and therefore will have "0" precoding
    inactiveSC = true(size(Q{iru},1),1);
    for iru = 1:numActiveRUs
        idx = activeRUInd(iru); % Index of RU to use
        inactiveSC(activeSCPerRU{idx}) = false;
    end

    % Handle zero precoding subcarriers by appending or prepending to an active RUs
    inactiveSCInd = find(inactiveSC);
    prependToRUidx = zeros(1,numel(inactiveSCInd));
    appendToRUidx = zeros(1,numel(inactiveSCInd));
    for iia = 1:numel(inactiveSCInd)
        idx = find(inactiveSCInd(iia)<cumsum(numActiveSCPerRU),1,'first');
        if ~isempty(idx)
            % Treat zero subcarrier as part of next RU
            prependToRUidx(iia) = idx;
            numActiveSCPerRU(idx) = numActiveSCPerRU(idx)+1;
        else
            % If idx is empty it means 0 subcarriers occur after the last RU
            appendToRUidx(iia) = lastActiveRUInd;
        end
    end

    W = cell(1,numActiveRUs);
    for iru = 1:numActiveRUs
        % Extract active subcarriers from RU
        idx = activeRUInd(iru); % Index of RU to use
        if any(idx==prependToRUidx) || any(idx==appendToRUidx)
            % Prepend and append zeros subcarriers to RU and
            [~,Nsts,Ntx] = size(Q{idx});
            numZerosPrepend = sum(idx==prependToRUidx);
            numZerosAppend = sum(idx==appendToRUidx);
            W{iru} = [zeros(numZerosPrepend, Nsts, Ntx); Q{idx}(activeSCPerRU{idx},:,:); zeros(numZerosAppend, Nsts, Ntx)]; % Extract active subcarriers from it
        else
            W{iru} = Q{idx}(activeSCPerRU{idx},:,:);
        end
    end

end
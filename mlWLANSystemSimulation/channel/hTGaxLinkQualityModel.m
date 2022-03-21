classdef hTGaxLinkQualityModel < handle
%hTGaxLinkQualityModel Create a link quality model object
%   abstraction = hTGaxLinkQualityModel returns a TGax link quality model.
%   This model is used to estimate the SINR for an 802.11ax single-user
%   link assuming perfect synchronization.
%
%   hTGaxLinkQualityModel methods:
%
%   estimateLinkQuality - returns the expected SINR per subcarrier.
%
%   See also hCalculateSINR.

%   Copyright 2021 The MathWorks, Inc.

%#codegen
  
    properties
        ChannelManager;
        NoiseFigure = 7; % Noise figure in dB
        SubcarrierSubsampling = 1; % Factor to subsample active subcarriers
    end
  
    methods
        function obj = hTGaxLinkQualityModel(cm)
            obj.ChannelManager = cm;
        end

        function SINR = estimateLinkQuality(obj, cfgSet, fieldSet, varargin)
            %channelAbstraction Calculate the SINR per subcarrier and
            % spatial stream given the signal of interest and interferers

            if nargin==5
                % SINR = estimateLinkQuality(obj, cfgSet, fieldSet, infoSet, rxIdx)
                infoSet = varargin{1};
                txIdxSet = infoSet(:,1);
                rxPowerSet = infoSet(:,2);
                rxIdx = varargin{2};
            else
                % SINR = estimateLinkQuality(obj, cfgSet, fieldSet, rxPowerSet, txIdxSet, rxIdx, ruIdx)
                rxPowerSet = varargin{1};
                txIdxSet = varargin{2};
                rxIdx = varargin{3};
                if nargin>6
                    ruIdx_soi = varargin{4};
                end
            end
            
            txIdx_soi = txIdxSet(1); % Index of transmitter of interest
            Ptxrx_soi = rxPowerSet(1); % Receive power of transmitter of interest
            
            % Number of interfering signals
            numInterferers = numel(txIdxSet)-1;
            
            if iscell(cfgSet)
                cfg_soi = cfgSet{1};
            else
                cfg_soi = cfgSet(1);
            end
            numCfgSet = numel(cfgSet);
            assert(any(numCfgSet==[1 numInterferers+1]),'Must be one configuration per transmission or only a single configuration')
            
            if ischar(fieldSet)
                field_soi = fieldSet;
            else
                if iscell(fieldSet)
                    field_soi = fieldSet{1};
                else
                    field_soi = fieldSet(1); % String array
                end
                assert(numCfgSet==numel(fieldSet),'Must be same number of configurations and fields provided')
            end
            
            % OFDM information of receiver processing - FFT length, number
            % of active tones and scalar for active to total number of
            % subcarriers
            isOFDMA = isa(cfg_soi,'wlanHEMUConfig');
            if isOFDMA && strcmp(field_soi,'data')
                % For OFDMA configuration ofdmInfo will contain active
                % tones for only the single RU of interest, but the
                % transmitter has normalized by total number of active
                % tones. Therefore,calculate the total number of active
                % subcarriers using ruInfo().
                rxOFDMInfo = getOFDMInfo(cfg_soi, field_soi, ruIdx_soi);
                allocInfo = ruInfo(cfg_soi);
                occupedSubcarrierScalar = 10*log10(rxOFDMInfo.FFTLength/sum(allocInfo.RUSizes));
            else
                rxOFDMInfo = getOFDMInfo(cfg_soi, field_soi);
                occupedSubcarrierScalar = 10*log10(rxOFDMInfo.FFTLength/rxOFDMInfo.NumTones);                
            end
            
            % Noise power at receiver scaled by ratio of receiver bandwidth
            % to occupied subcarriers
            fs = wlanSampleRate(cfg_soi);
            NF = obj.NoiseFigure;       % Noise figure (dB)
            T = 290;                    % Ambient temperature (K)
            BW = fs;                    % Bandwidth (Hz)
            k = physconst('Boltzmann'); % Boltzmann constant (J/K)
            N0FullBand = 10*log10(k*T*BW)+NF; % dB, this is for the full channel bandwidth
            N0 = 10^((N0FullBand-occupedSubcarrierScalar)/10);

            % Get channel matrix and precoding matrix for signal of interest
            if isOFDMA
                Htxrx_soi = getChannelMatrix(obj.ChannelManager, cfg_soi, ruIdx_soi, txIdx_soi, rxIdx, field_soi, obj.SubcarrierSubsampling);
                Wtx_soi = hGetPrecodingMatrix(cfg_soi, ruIdx_soi, field_soi, obj.SubcarrierSubsampling);
            else
                Htxrx_soi = getChannelMatrix(obj.ChannelManager, cfg_soi, txIdx_soi, rxIdx, field_soi, obj.SubcarrierSubsampling);
                Wtx_soi = hGetPrecodingMatrix(cfg_soi, field_soi, obj.SubcarrierSubsampling);
            end
            assert(cfg_soi.NumTransmitAntennas==size(Htxrx_soi,2),'Number of transmit antennas must match')
            
            % Get number of 20 MHz subchannels and determine whether they
            % should be combined
            Nsc = rxOFDMInfo.NumSubchannels;
            combineSC = Nsc>1 && (strcmp(field_soi,'preamble') || isa(cfg_soi,'wlanNonHTConfig'));
           
            % Combine subchannels for channel of interest
            if combineSC
                [Htxrx_soi,Wtx_soi] = combineSubchannels(Htxrx_soi, Wtx_soi, Nsc);
            end
            
            % This indicates interference is present. Since first one is signal of interest
            if numInterferers > 0
                Htxrx_int = cell(numInterferers, 1);
                Wtx_int = cell(numInterferers, 1);
                Ptxrx_int = zeros(numInterferers, 1);
                for i = 1:numInterferers
                    % Get channel matrix for interferer
                    txIntIdx = txIdxSet(i+1); % Skip the first value as it corresponds to signal of interest
                                        
                    % Get channel matrix for interferer (OFDM info based on signal of interest)
                    if isOFDMA
                        Hi = getChannelMatrix(obj.ChannelManager, cfg_soi, ruIdx_soi, txIntIdx, rxIdx, field_soi, obj.SubcarrierSubsampling);
                    else
                        Hi = getChannelMatrix(obj.ChannelManager, cfg_soi, txIntIdx, rxIdx, field_soi, obj.SubcarrierSubsampling);
                    end
                    
                    % If only single transmission configuration and field passed assume it is the same for all interferers
                    setIdx = mod((i+1)-1,numCfgSet)+1;
                    
                    % Get precoding matrix for interferer
                    if setIdx==1
                        % Assume same precoding used as signal of interest and already combined if required
                        Wi = Wtx_soi;
                        if combineSC
                            Hi = wlan.internal.mergeSubchannels(Hi, Nsc);
                        end
                    else
                        % Get precoding from interferer using signal of interest OFDM configuration 
                        [cfgInt,fieldInt] = getInterfererConfig(setIdx, cfgSet, fieldSet);
                        if isOFDMA
                            Wi = hGetPrecodingMatrix(cfgInt, fieldInt, cfg_soi, ruIdx_soi, field_soi, obj.SubcarrierSubsampling);
                        else
                            Wi = hGetPrecodingMatrix(cfgInt, fieldInt, cfg_soi, field_soi, obj.SubcarrierSubsampling);
                        end
                        if combineSC
                            [Hi,Wi] = combineSubchannels(Hi, Wi, Nsc);
                        end
                    end

                    Htxrx_int{i} = Hi;
                    Wtx_int{i} = Wi;
                    
                    Ptxrx_int(i) = rxPowerSet(i+1); % Skip the first value as it corresponds to signal of interest
                end
                SINR = hCalculateSINR(Htxrx_soi, Ptxrx_soi, Wtx_soi, N0, Htxrx_int, Ptxrx_int, Wtx_int);
            else
                % No interference
                SINR = hCalculateSINR(Htxrx_soi, Ptxrx_soi, Wtx_soi, N0);
            end
        end
    end
end

function [cfgInt,fieldInt] = getInterfererConfig(setIdx,cfgSet,fieldSet)
    % If only single transmission configuration and field passed assume it
    % is the same for all interferers

    if iscell(cfgSet)
        cfgInt = cfgSet{setIdx};
    elseif isvector(cfgSet)
        cfgInt = cfgSet(setIdx);
    else
        cfgInt = cfgSet;
    end
    if iscell(fieldSet)
        fieldInt = fieldSet{setIdx};
    elseif isstring(fieldSet)
        fieldInt = fieldSet(setIdx);
    else
        % Char array, assume same field for interferer as field of interest
        fieldInt = fieldSet;
    end
end

function ofdmInfo = getOFDMInfo(cfg,field,ruIndx)
   switch field
       case 'data'
           % Get OFDM info for data fields of formats
            switch class(cfg)
                case 'wlanHEMUConfig'
                    ofdmInfo = wlanHEOFDMInfo('HE-Data',cfg,ruIndx);
                case 'wlanHESUConfig'
                    ofdmInfo = wlanHEOFDMInfo('HE-Data',cfg);
                case 'wlanVHTConfig'
                    ofdmInfo = wlanVHTOFDMInfo('VHT-Data',cfg);
                case 'wlanHTConfig'
                    ofdmInfo = wlanHTOFDMInfo('HT-Data',cfg);
                case 'wlanNonHTConfig'
                    ofdmInfo = wlanNonHTOFDMInfo('NonHT-Data',cfg);
                otherwise
                    error('Unexpected format');
            end
       case 'preamble'
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
                    ofdmInfo = wlanNonHTOFDMInfo('NonHT-Data',cfg);
                otherwise
                    error('Unexpected format');
            end
       otherwise
           error('Unexpected field')
   end
end

function [HtxrxC,WtxC] = combineSubchannels(Htxrx,Wtx,Nsc)
    % Treat each subchannel like another receive antenna in the channel
    % matrix
    HtxrxC = wlan.internal.mergeSubchannels(Htxrx,Nsc);
    
    % Use precoding in first subchannel for all subchannels, this assumes
    % the precoding is the same. A potential enhacement is to form a
    % combined HW matrix here using the precoding from all subchannels. In
    % reality the preamble (or non-HT data) is not beamformed for the
    % signal of interset so this isn't needed. This would be more accurate
    % for interference modeling but we already make big assumptions about
    % how we model the data field interfering with preamble so it
    % practically will not make a big difference.
    if ~iscell(Wtx)
        Ntones = size(Wtx,1);
        WtxC = Wtx(1:Ntones/Nsc,:,:);
    else
        % Cell array were each cell contains precoding matrices per
        % subcarrier. The sum of which is the number of tones of interest
        NtonesPerRU = cellfun(@(x)size(x,1),Wtx);
        Ntones = sum(NtonesPerRU);
        numTonesToUse = Ntones/Nsc;
        
        tmp = cumsum(NtonesPerRU);
        maxRUUse = find(numTonesToUse<=tmp,1,'first'); % Index of last RU containing subcarriers to use
        if maxRUUse>1
            % If more than one RU required get the number of subcarriers required in the last RU
            numToUseInLastRU = numTonesToUse-tmp(maxRUUse-1);
        else
            % If only first RU required use required number of subcarriers
            numToUseInLastRU = numTonesToUse;
        end
        WtxC = Wtx(1:maxRUUse); % Extract required RUs
        WtxC{end} =  WtxC{end}(1:numToUseInLastRU,:,:); % Extract required number of subcarriers in the last RU
    end
end
function [sinr,Stxrx,Istxrx,Iotxrx,N] = hCalculateSINR(Htxrx,Ptxrx,Wtx,N0,varargin)
%hCalculateSINR calculate the SINR of a link given interferers
%   SINR = hCalculateSINR(HTXRX,PTXRX,WTX,N0) returns the SINR in decibels
%   assuming no interferers.
%
%   SINR is a Nst-by-Nsts-by-Nlinks array containing the SINR in decibels
%   per subcarrier and space-time stream. Nst is the number of subcarriers,
%   Nsts is the number of space-time streams, and Nlinks is the number of
%   links.
%
%   Htxrx is a Nst-by-Nt-by-Nr-Nlinks array containing the channel of
%   interest. Nt is the number of transmit antennas and Nr is the number of
%   receive antennas.
%
%   Ptxrx is a vector of length Nlinks containing the power in Watts of the
%   signal of interest.
%
%   Wtx is a Nst-by-Nsts-by-Nt-Nlinks array containing precoding of signal
%   of interest. Nsts is the number of space-time streams.
%
%   N0 is a vector if Nlinks containing noise power in Watts.
%
%   SINR = hCalculateSINR(...,HTXRX_INT,PTXRX_INT,WTX_INT) calculates the
%   SINR assuming interfering transmissions.
%
%   HTXRX_INT is a cell array of Nint arrays containing the channel between
%   each interferer and the receiver. Each element is a
%   Nst-by-Nt_int-by-Nr-by-Nlinks array.
%
%   PTXRX_INT is a column vector of length Nint containing the interference
%   power in Watts for each interferer, where Nint is the number of
%   interferers.
%
%   WTX_INT is a cell array with Nint elements containing the precoding
%   applied at each interferer. Each element is a
%   Nst-by-Nsts_int-by-Nt_int-by-Nlinks array, or a cell array containing
%   sets of precoding matrices which make up the required number of
%   subcarriers. A cell array per interferer allows for an OFDMA scenario
%   were different interfering RUs which overlap the subcarriers of
%   interest may use different precoding matrices and have different
%   numbers of space-time streams.
%
%   % Example: Calculate the SINR for a link with one interferer
%   Psoi = -20; % Signal of interest received power (dBm)
%   Pint = -45; % Interfering signal received power (dBm)
%   N0 = -85;   % Noise power (dBm)
%   Hsoi = rand(242,1); % Channel of interest
%   W = ones(242,1); % Precoding matrix (assume no precoding)
%   Hint = rand(242,1); % Channel of interest
%   sinr = hCalculateSINR(Hsoi,db2pow(Psoi-30),W,db2pow(N0-30),{Hint},db2pow(Pint-30),{W});
%
%   See also hTGaxLinkPerformanceModel.

%   Copyright 2021 The MathWorks, Inc.

%#codegen

% Check sizes are compatible for channel matrix and precoding matrix
[Nst,Nt,Nr,Nlinks] = size(Htxrx);
[Nst_w,Nsts,Nt_w,Nlinks_w] = size(Wtx);
assert(all([Nst Nt Nlinks]==[Nst_w Nt_w Nlinks_w]),'Mismatch in precoding and channel matrix dimensions')

if nargin>4
    % Interference is present
    Htxrx_int = varargin{1};
    Ptxrx_int = varargin{2};
    assert(iscolumn(Ptxrx_int))
    Wtx_int = varargin{3};

    % Make sure channel and precoding provided for each interferer
    assert(all(size(Htxrx_int)==size(Wtx_int)),'A channel and precoding matrix must be provided for each interferer')

    % Assume interference is present but if it is an empty cell array then no interference
    Nint = numel(Htxrx_int); % number of interferers

    if ~isempty(Htxrx_int)
        % Permute for efficiency Htxrx to Nst-by-Nlinks-by-Nt-by-Nr
        Htxrx_intT = cell(size(Htxrx_int,1),size(Htxrx_int,2));
        for ic = 1:numel(Htxrx_intT)
            % Check sizes are compatible for each precoding and channel
            % matrix and with the channel of interest
            
            [Nst_hi,Nt_hi,Nr_hi,Nlinks_hi] = size(Htxrx_int{ic});
            assert(all([Nst_hi Nr_hi Nlinks_hi]==[Nst Nr Nlinks]),'Mismatch in precoding and channel matrix dimensions for interferer')
            
            if ~iscell(Wtx_int{ic})
                [Nst_wi,~,Nt_wi,Nlinks_wi] = size(Wtx_int{ic});
                assert(all([Nst_hi Nt_hi Nlinks_hi]==[Nst_wi Nt_wi Nlinks_wi]),'Mismatch in precoding and channel matrix dimensions for interferer')
            else
                Nstint = 0;
                for ir = 1:numel(Wtx_int{ic})
                    [Nstintt,~,Ntxintt,Nlinksintt] = size(Wtx_int{ic}{ir});
                    Nstint = Nstint+Nstintt;
                    assert(all([Nt_hi Nlinks_hi]==[Ntxintt Nlinksintt]),'Mismatch in precoding and channel matrix dimensions for interfere')
                end
                % Sum of subcarriers for all RUs must equal sum in channel
                assert(Nst_hi==Nstint,'Mismatch in precoding and channel matrix dimensions for interferer')
            end
            
            Htxrx_intT{ic} = permute(Htxrx_int{ic},[1 4 2 3]);
        end
        % Permute for efficiency Wtx to Nst-by-Nlinks-by-Nt-by-Nsts
        Wtx_intT = cell(size(Wtx_int));
        for ic = 1:numel(Wtx_intT)
            if ~iscell(Wtx_int{ic})
                Wtx_intT{ic} = permute(Wtx_int{ic},[1 4 3 2]);
            else
                % The number of streams are different per subcarrier (OFDMA)
                Wtx_intT{ic} = cell(1,numel(Wtx_int{ic}));
                for ir = 1:numel(Wtx_int{ic})
                    Wtx_intT{ic}{ir} = permute(Wtx_int{ic}{ir},[1 4 3 2]);
                end
            end
        end
    else
        % No interference
        Nint = 0;
        Ptxrx_int = zeros(0,1); % for code to run
        Wtx_intT = cell(0,1); % for codegen
        Htxrx_intT = cell(0,1); % for codegen
    end 
else
    % No interference
    Nint = 0;
    Ptxrx_int = zeros(0,1); % for code to run
    Wtx_intT = cell(0,1); % for codegen
    Htxrx_intT = cell(0,1); % for codegen
end

% Calculate signal power (STXRX), inter-stream interference power (ISTXRX),
% and interference power (IOTXRX)

% Generate MMSE receive filter for receivers
Wout = hTGaxMMSEFilter(Htxrx,Wtx,Ptxrx,N0); % Nst-by-Nr-by-Nsts-by-Nlinks
WoutT = permute(Wout,[2 3 1 4]); % Nr-by-Nsts-by-Nst-by-Nlinks

% Calculate HWtxrx, which include channel and precoding response for
% channel of interest
HtxrxP = permute(Htxrx,[1 4 2 3]); % Nst-by-Nlinks-by-Nt-by-Nr
WtxP = permute(Wtx,[1 4 3 2]); % Nst-by-Nlinks-by-Nt-by-Nsts
HWtxrx = coder.nullcopy(complex(zeros(Nst,Nlinks,Nr,Nsts)));
for i = 1:Nr
    for j = 1:Nsts
        HWtxrx(:,:,i,j) = sum(HtxrxP(:,:,:,i).*WtxP(:,:,:,j),3);
    end
end
HWtxrxP = permute(HWtxrx,[3 4 1 2]); % Permute to Nr-by-Nsts-by-Nst-by-Nlinks

if Nint>0
    % Calculate H*W for interferers as a vector calculation
    HW_int = cell(1,Nint); % Cell array of Nst-by-Nlinks-by-Nr-by-Nsts
    for k = 1:Nint
        if ~iscell(Wtx_intT{k})
            Wint = Wtx_intT{k}; % Nst-by-Nlinks-by-Nt-by-Nsts
            Hi = Htxrx_intT{k}; % Nst-by-Nlinks-by-Nt-by-Nr
            NstsInt = size(Wint,4);
            HW_k = coder.nullcopy(complex(zeros(Nst,Nlinks,Nr,NstsInt)));
            for i = 1:Nr
                for j = 1:NstsInt
                    HW_k(:,:,i,j) = sum(Hi(:,:,:,i).*Wint(:,:,:,j),3);
                end
            end
            HW_int{k} = HW_k;
        else
            % The number of streams are different per subcarrier (OFDMA)
            Wint = Wtx_intT{k}; % Cell of Nst-by-Nlinks-by-Nt-by-Nsts
            Hi = Htxrx_intT{k}; % Nst-by-Nlinks-by-Nt-by-Nr
            offset = 0;
            for ir = 1:numel(Wint)
                NstsInt = size(Wint{ir},4);
                NstInt = size(Wint{ir},1);
                HW_k_ir = coder.nullcopy(complex(zeros(NstInt,Nlinks,Nr,NstsInt)));
                HiIdx = offset + (1:NstInt);
                for i = 1:Nr
                    for j = 1:NstsInt
                        HW_k_ir(:,:,i,j) = sum(Hi(HiIdx,:,:,i).*Wint{ir}(:,:,:,j),3);
                    end
                end
                HW_int{k}{ir} = HW_k_ir;
                offset = offset+NstInt;
            end
        end
    end

    % Interference power
    % For each active interferer calculate the power, then sum to create
    % the total interference
    T = permute(WoutT,[3 4 1 2]); % Nst-by-Nlinks-by-Nr-by-Nsts
    
    iok = coder.nullcopy(zeros(Nst,Nlinks,Nsts,Nint));
    for k = 1:Nint
        if ~iscell(HW_int{k})
            for j = 1:Nsts
                iok(:,:,j,k) = sum(abs(sum(T(:,:,:,j).*HW_int{k},3)).^2,4);
            end
        else
            % The number of streams are different per subcarrier (OFDMA)
            offset = 0;
            for ir = 1:numel(HW_int{k})
                NstInt = size(HW_int{k}{ir},1);
                HiIdx = offset + (1:NstInt);
                for j = 1:Nsts
                    iok(HiIdx,:,j,k) = sum(abs(sum(T(HiIdx,:,:,j).*HW_int{k}{ir},3)).^2,4);
                end
                offset = offset+NstInt;
            end
        end
    end
    Iotxrx = permute(sum(bsxfun(@times,permute(Ptxrx_int,[4 3 2 1]),iok),4),[1 3 2]); % Nst-by-Nsts-by-Nlinks
else
    % No interference
    Iotxrx = zeros(Nst,Nsts,Nlinks);
end

Stxrx = coder.nullcopy(zeros(Nst,Nsts,Nlinks));
Istxrx = coder.nullcopy(zeros(Nst,Nsts,Nlinks));
N = coder.nullcopy(zeros(Nst,Nsts,Nlinks));
for i = 1:Nlinks
    Ptxrx_l = Ptxrx(i);
    N0_l = N0;
    for j = 1:Nsts
        for m = 1:Nst                
            Tj = WoutT(:,j,m,i);

            % Noise power
            N(m,j,i) = (norm(Tj).^2)*N0_l;

            % Use the channel estimate directly rather than the
            % channel matrix and precoding matrix
            HW = HWtxrxP(:,:,m,i);
            Stxrx(m,j,i) = Ptxrx_l*abs(Tj.'*HW(:,j)).^2;
            Istxrx(m,j,i) = Ptxrx_l*norm(Tj.'*HW).^2-Stxrx(m,j,i);
        end
    end
end

% Nst-by-Nsts-by-Nlinks
sinrLin = Stxrx./(Istxrx + Iotxrx + N);

% Return in dB
sinr = 10*log10(abs(sinrLin)); % abs protects against very small negative values due to numeric precision

end
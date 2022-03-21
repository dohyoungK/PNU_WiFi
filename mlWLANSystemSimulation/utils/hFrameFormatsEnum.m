classdef hFrameFormatsEnum < uint8
%hFrameFormatsEnum Indicate the physical layer format of a WLAN MAC frame
%
%   This is an example helper class (Enumeration).
%
%   FORMAT = hFrameFormatsEnum.<ENUMVALUE> creates an enumeration with the
%   value specified by the ENUMVALUE. Valid values for ENUMVALUE are
%   mentioned below.
%
%   hFrameFormatsEnum properties: 
%
%   NonHT (0)      - Non-HT frame format
%   HTMixed (1)    - HT-Mixed frame format
%   VHT (2)        - VHT frame format
%   HE_SU (3)      - HE single user frame format
%   HE_EXT_SU (4)  - HE extended range single user frame format
%   HE_MU (5)      - HE multi-user frame format

%   Copyright 2021 The MathWorks, Inc. 

    enumeration
        %Non-HT frame format
        % NonHT is mapped to 0. This value indicates a Non-HT format.
        NonHT (0)
        
        %HT-Mixed frame format
        % HTMixed is mapped to 1. This value indicates a HT-Mixed format.
        HTMixed (1)
        
        %VHT frame format
        % VHT is mapped to 2. This value indicates a VHT format.
        VHT (2)
        
        %HE_SU frame format
        % HE_SU is mapped to 3. This value indicates a HE single user format.
        HE_SU (3)
        
        %HE_EXT_SU frame format
        % HE_EXT_SU is mapped to 4. This value indicates a HE extended range
        % single user format.
        HE_EXT_SU (4)
        
        %HE_MU frame format
        % HE_MU is mapped to 5. This value indicates a HE multi-user format.
        HE_MU (5)
    end
end

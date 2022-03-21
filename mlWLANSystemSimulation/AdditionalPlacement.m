function [txPositions, APFloor] = AdditionalPlacement(apPositions, staPositions, apFloor, numSTA)
    placementCondition = 10;
    STADensity = struct;
    for i = 1:3
        STADensity(i).numSTA = 0;
        STADensity(i).density = zeros(12);
    end
    density = zeros(12);
    position = [0,0,0];
    addtionalNumAP = 0;
    
    for idx = 1:size(staPositions,1)
        for i = 1:12
            if staPositions(idx,1) <= i*5 && staPositions(idx,1) >= i*5-5 % x position
                density_x = i;
            end
            if staPositions(idx,2) <= i*5 && staPositions(idx,2) >= i*5-5 % y position
                density_y = i;
            end
        end
        density(density_x,density_y) = density(density_x,density_y) + 1;
        if idx == sum(numSTA.firstFloor)
            STADensity(1).numSTA = idx;
            STADensity(1).density = density;
            density = zeros(12);
        elseif idx == sum(numSTA.firstFloor) + sum(numSTA.secondFloor)
            STADensity(2).numSTA = sum(numSTA.secondFloor);
            STADensity(2).density = density;
            density = zeros(12);
        elseif idx == sum(numSTA.firstFloor) + sum(numSTA.secondFloor) + sum(numSTA.thirdFloor)
            STADensity(3).numSTA = sum(numSTA.thirdFloor);
            STADensity(3).density = density;
        end 
    end

    for i = 1:3 % 퍼센티지 변환
        if STADensity(i).numSTA ~= 0
            for j = 1:12
                for k = 1:12
                    STADensity(i).density(j,k) = STADensity(i).density(j,k)/STADensity(i).numSTA * 100;
                end
            end
        end
    end
    
    STADensity(1).density
    STADensity(2).density
    STADensity(3).density
    maxFirstFloorDensity = max(max(STADensity(1).density))
    maxSecondFloorDensity = max(max(STADensity(2).density))
    maxThirdFloorDensity = max(max(STADensity(3).density))
    
    AP(1).additionalCnt = 0;
    AP(2).additionalCnt = 0;
    AP(3).additionalCnt = 0;
    for i = 1:3
        if i == 1
            maximum = maxFirstFloorDensity;
        elseif i == 2
            maximum = maxSecondFloorDensity;
        elseif i == 3
            maximum = maxThirdFloorDensity;
        end
        for j = 1:12
            for k = 1:12
                if STADensity(i).density(j,k) == maximum && maximum ~= 0 
                    if i == 1 && STADensity(i).numSTA >= 3 * placementCondition && AP(1).additionalCnt < 1
                        position = [j*5 - 2.5, k*5 - 2.5, i*4 - 2];
                        apPositions = [apPositions; position];
                        addtionalNumAP = addtionalNumAP + 1;
                        AP(1).additionalCnt = AP(1).additionalCnt + 1;
                    end
                    if i == 2 && STADensity(i).numSTA >= 8 * placementCondition && AP(2).additionalCnt < 2
                        position = [j*5 - 2.5, k*5 - 2.5, i*4 - 2];
                        apPositions = [apPositions; position];
                        addtionalNumAP = addtionalNumAP + 1;
                        AP(2).additionalCnt = AP(2).additionalCnt + 1;
                    end
                    if i == 3 && STADensity(i).numSTA >= 6 * placementCondition && AP(3).additionalCnt < 1
                        position = [j*5 - 2.5, k*5 - 2.5, i*4 - 2];
                        apPositions = [apPositions; position];
                        addtionalNumAP = addtionalNumAP + 1;
                        AP(3).additionalCnt = AP(3).additionalCnt + 1;
                    end
                end
            end
        end
    end
    
    apPositions = sortrows(apPositions,3); % 높이 기준 정렬
    APFloor = apFloor;
    APFloor.additionalNumAP = addtionalNumAP;
    txPositions = apPositions;
end
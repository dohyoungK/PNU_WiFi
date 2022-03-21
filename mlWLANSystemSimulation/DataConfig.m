function [Date, APNames, numSTA, numStationAll, APFloor] = setData(getOriginResult)
    totalData = readtable('lib2_data.csv', "VariableNamingRule", "preserve");
    totalData.Properties.RowNames = string((0:23));
    
    dataTwoGHz = readtable('Lib-2_2GHz.csv', "VariableNamingRule", "preserve");
    dataTwoGHz.Properties.RowNames = string((0:23));
    
    dataFiveGHz = readtable('Lib-2_5GHz.csv', "VariableNamingRule", "preserve");
    dataFiveGHz.Properties.RowNames = string((0:23));
    
    Input = struct;
    
    if ~getOriginResult
        load('Input.mat');
    end
    
    Date = struct;
    if ~getOriginResult
        Date.isWeekday = Input.isWeekday;
        Date.hour = Input.hour;
    else
        Date.isWeekday = input("Input Weekday(1) or Weekend(0): ");
        Date.hour = input("Input hour: ");
    end
    
    APNames = struct;
    APNames.firstFloor = ["11S-420-1-1" "11S-420-1-2" "16AP-420-1-3"];
    APNames.secondFloor = ["16AP-420-2-1" "11S-420-2-2" "11S-420-2-3" "11S-420-2-4" "16K-420-2-5" "16AP-420-2-6" "16AP-420-2-7" "18AP-420-2-8"];
    APNames.thirdFloor = ["16AP-420-3-1" "11S-420-3-2" "11S-420-3-3" "16AP-420-3-4" "16K-420-3-5" "16AP-420-3-6"];
    
    APFloor = struct;
    APFloor.additionalNumAP = 0;
    if ~getOriginResult
        APFloor.floor = Input.floor;
    else
        APFloor.floor = input("Select Floor(all=0, 1,2,3): ");
    end
    
    Input.isWeekday = Date.isWeekday;
    Input.hour = Date.hour;
    Input.floor = APFloor.floor;
    save('Input.mat', 'Input');
    
    numSTA = struct;
    numSTA.firstFloor = zeros(1,length(APNames.firstFloor));
    numSTA.secondFloor = zeros(1,length(APNames.secondFloor));
    numSTA.thirdFloor = zeros(1,length(APNames.thirdFloor));
    
    if (APFloor.floor == 0) || (APFloor.floor == 1)
        for m = 1:length(APNames.firstFloor)
            if(Date.isWeekday)
                numSTA.firstFloorTwoGHz(m) = round(dataTwoGHz{Date.hour, APNames.firstFloor(m)});
                numSTA.firstFloorFiveGHz(m) = round(dataFiveGHz{Date.hour, APNames.firstFloor(m)});
                numSTA.firstFloor(m) = numSTA.firstFloorTwoGHz(m) + numSTA.firstFloorFiveGHz(m);
            else
                name = strcat(APNames.firstFloor(m), "_1"); 
                numSTA.firstFloorTwoGHz(m) = round(dataTwoGHz{Date.hour, name});
                numSTA.firstFloorFiveGHz(m) = round(dataFiveGHz{Date.hour, name});
                numSTA.firstFloor(m) = numSTA.firstFloorTwoGHz(m) + numSTA.firstFloorFiveGHz(m);
            end
        end
    end

    if (APFloor.floor == 0) || (APFloor.floor == 2)
        for m = 1:length(APNames.secondFloor)
            if(Date.isWeekday)
                numSTA.secondFloorTwoGHz(m) = round(dataTwoGHz{Date.hour, APNames.secondFloor(m)});
                numSTA.secondFloorFiveGHz(m) = round(dataFiveGHz{Date.hour, APNames.secondFloor(m)});
                numSTA.secondFloor(m) = numSTA.secondFloorTwoGHz(m) + numSTA.secondFloorFiveGHz(m);
            else
                name = strcat(APNames.secondFloor(m), '_1'); 
                numSTA.secondFloorTwoGHz(m) = round(dataTwoGHz{Date.hour, name});
                numSTA.secondFloorFiveGHz(m) = round(dataFiveGHz{Date.hour, name});
                numSTA.secondFloor(m) = numSTA.secondFloorTwoGHz(m) + numSTA.secondFloorFiveGHz(m);
            end
        end
    end
         
    if (APFloor.floor == 0) || (APFloor.floor == 3)
        for m = 1:length(APNames.thirdFloor)
            if(Date.isWeekday)
                numSTA.thirdFloorTwoGHz(m) = round(dataTwoGHz{Date.hour, APNames.thirdFloor(m)});
                numSTA.thirdFloorFiveGHz(m) = round(dataFiveGHz{Date.hour, APNames.thirdFloor(m)});
                numSTA.thirdFloor(m) = numSTA.thirdFloorTwoGHz(m) + numSTA.thirdFloorFiveGHz(m);
            else
                name = strcat(APNames.thirdFloor(m), '_1'); 
                numSTA.thirdFloorTwoGHz(m) = round(dataTwoGHz{Date.hour, name});
                numSTA.thirdFloorFiveGHz(m) = round(dataFiveGHz{Date.hour, name});
                numSTA.thirdFloor(m) = numSTA.thirdFloorTwoGHz(m) + numSTA.thirdFloorFiveGHz(m);
            end
        end
    end
    
    if APFloor.floor == 1
        APFloor.numAP = size(APNames.firstFloor, 2);
        numStationAll = sum(numSTA.firstFloor,2);
    elseif APFloor.floor == 2
        APFloor.numAP = size(APNames.secondFloor, 2);
        numStationAll = sum(numSTA.secondFloor,2);
    elseif APFloor.floor == 3
        APFloor.numAP = size(APNames.thirdFloor, 2);
        numStationAll = sum(numSTA.thirdFloor,2);
    else
        APFloor.numAP = size(APNames.firstFloor, 2) + size(APNames.secondFloor, 2) + size(APNames.thirdFloor, 2);
        numStationAll = sum(numSTA.firstFloor,2) + sum(numSTA.secondFloor,2) + sum(numSTA.thirdFloor,2);
    end
end
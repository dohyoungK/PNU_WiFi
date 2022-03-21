function tri = hTGaxResidentialTriangulation(params)

%room data
%사각형[x_point; y_point; floor] 
RoomNumber(1).room = [22 0; 28 18; 1 0]; % 1F
RoomNumber(2).room = [34 18; 40 22; 1 0];
RoomNumber(3).room = [34 22; 40 26; 1 0];
RoomNumber(4).room = [44 26; 52 33; 1 0];
RoomNumber(5).room = [8 38; 15 45; 1 0];
RoomNumber(6).room = [15 38; 28 60; 1 0];
RoomNumber(7).room = [28 38; 46 60; 1 0];
RoomNumber(8).room = [46 36; 60 60; 1 0];

RoomNumber(9).room = [28 10; 40 18; 2 0]; % 2F
RoomNumber(10).room = [44 26; 52 33; 2 0];
RoomNumber(11).room = [8 33; 18 38; 2 0];
RoomNumber(12).room = [8 38; 15 45; 2 0];
RoomNumber(13).room = [15 38; 46 60; 2 0];
RoomNumber(14).room = [46 33; 60 60; 2 0];

RoomNumber(15).room = [22 0; 28 18; 3 0]; % 3F
RoomNumber(16).room = [22 0; 28 18; 3 0];
RoomNumber(17).room = [44 26; 52 33; 3 0];
RoomNumber(18).room = [8 33; 15 45; 3 0];
RoomNumber(19).room = [15 38; 46 60; 3 0];
RoomNumber(20).room = [46 33; 60 60; 3 0];

RoomNumber(21).room = [22 0; 28 18; 4 0]; % 4F
RoomNumber(22).room = [44 26; 52 33; 4 0];
RoomNumber(23).room = [8 33; 15 45; 4 0];

%삼각형[x_point; y_point; z_point; floor]
%RoomNumber(4).room = [50 50; 50 40; 40 40; 1 0];

%다각형[x_point; y_point; X_point; Y_point; floor]
RoomNumber(24).room = [22 0; 0 33; 0 0; 15 22; 1 0]; % 1F
RoomNumber(25).room = [28 0; 0 33; 0 0; 15 22; 2 0]; % 2F
RoomNumber(26).room = [22 0; 0 33; 0 0; 15 22; 3 0]; % 3F
RoomNumber(27).room = [28 5; 44 26; 44 5; 34 18; 3 0]; 
RoomNumber(28).room = [22 0; 0 33; 0 0; 15 22; 4 0]; % 4F
RoomNumber(29).room = [28 5; 44 26; 44 5; 34 18; 4 0]; 
RoomNumber(30).room = [15 60; 60 33; 60 60; 46 38; 4 0]; 


%hall data
global HallNumber;
HallNumber(1).wall = [8 33; 15 33; 15 22; 22 22; 22 18; 28 18; 28 10; 40 10; 40 18; 34 18; 34 26; 44 26; 44 33; 52 33; 52 36; 46 36; 46 38; 8 38; 1 0]; % 1F
HallNumber(2).wall = [15 33; 15 22; 28 22; 28 18; 40 18; 40 26; 44 26; 44 33; 46 33; 46 38; 18 38; 18 33; 2 0]; % 2F
HallNumber(3).wall = [15 38; 15 22; 22 22; 22 18; 34 18; 34 26; 44 26; 44 33; 46 33; 46 38; 3 0]; % 3F
HallNumber(4).wall = [15 38; 15 22; 22 22; 22 18; 34 18; 34 26; 44 26; 44 33; 46 33; 46 38; 4 0]; % 4F


%point
squarePts = [];
trianglePts = [];
polygonPts = [];
hallPts = [];
buildingPts = [];

for n = 1:numel(RoomNumber)
    Height = params.RoomSize(1,3);
    if size(RoomNumber(n).room, 1) == 3 % 사각형
        RoomNumber(n).square = [ RoomNumber(n).room(1,1) RoomNumber(n).room(1,2) (RoomNumber(n).room(3,1)-1)*Height;
                                 RoomNumber(n).room(2,1) RoomNumber(n).room(1,2) (RoomNumber(n).room(3,1)-1)*Height;
                                 RoomNumber(n).room(2,1) RoomNumber(n).room(2,2) (RoomNumber(n).room(3,1)-1)*Height;
                                 RoomNumber(n).room(1,1) RoomNumber(n).room(2,2) (RoomNumber(n).room(3,1)-1)*Height;
                                 RoomNumber(n).room(1,1) RoomNumber(n).room(1,2) RoomNumber(n).room(3,1)*Height;
                                 RoomNumber(n).room(2,1) RoomNumber(n).room(1,2) RoomNumber(n).room(3,1)*Height;
                                 RoomNumber(n).room(2,1) RoomNumber(n).room(2,2) RoomNumber(n).room(3,1)*Height;
                                 RoomNumber(n).room(1,1) RoomNumber(n).room(2,2) RoomNumber(n).room(3,1)*Height; ];
        squarePts = vertcat(squarePts, RoomNumber(n).square);
                   
    elseif size(RoomNumber(n).room, 1) == 4 % 삼각형
        RoomNumber(n).triangle = [ RoomNumber(n).room(1,1) RoomNumber(n).room(1,2) (RoomNumber(n).room(4,1)-1)*Height;
                                   RoomNumber(n).room(2,1) RoomNumber(n).room(2,2) (RoomNumber(n).room(4,1)-1)*Height;
                                   RoomNumber(n).room(3,1) RoomNumber(n).room(3,2) (RoomNumber(n).room(4,1)-1)*Height;                                       
                                   RoomNumber(n).room(1,1) RoomNumber(n).room(1,2) (RoomNumber(n).room(4,1))*Height;
                                   RoomNumber(n).room(2,1) RoomNumber(n).room(2,2) (RoomNumber(n).room(4,1))*Height;
                                   RoomNumber(n).room(3,1) RoomNumber(n).room(3,2) (RoomNumber(n).room(4,1))*Height; ];
        trianglePts = vertcat(trianglePts, RoomNumber(n).triangle);
            
    elseif size(RoomNumber(n).room, 1) == 5 % 다각형
        RoomNumber(n).polygon = [ RoomNumber(n).room(1,1) RoomNumber(n).room(1,2) (RoomNumber(n).room(5,1)-1)*Height;
                                  RoomNumber(n).room(2,1) RoomNumber(n).room(1,2) (RoomNumber(n).room(5,1)-1)*Height;
                                  RoomNumber(n).room(2,1) RoomNumber(n).room(2,2) (RoomNumber(n).room(5,1)-1)*Height;
                                  RoomNumber(n).room(4,1) RoomNumber(n).room(2,2) (RoomNumber(n).room(5,1)-1)*Height;
                                  RoomNumber(n).room(4,1) RoomNumber(n).room(4,2) (RoomNumber(n).room(5,1)-1)*Height;
                                  RoomNumber(n).room(1,1) RoomNumber(n).room(4,2) (RoomNumber(n).room(5,1)-1)*Height;
                                  RoomNumber(n).room(1,1) RoomNumber(n).room(1,2) RoomNumber(n).room(5,1)*Height;
                                  RoomNumber(n).room(2,1) RoomNumber(n).room(1,2) RoomNumber(n).room(5,1)*Height;
                                  RoomNumber(n).room(2,1) RoomNumber(n).room(2,2) RoomNumber(n).room(5,1)*Height;
                                  RoomNumber(n).room(4,1) RoomNumber(n).room(2,2) RoomNumber(n).room(5,1)*Height;
                                  RoomNumber(n).room(4,1) RoomNumber(n).room(4,2) RoomNumber(n).room(5,1)*Height;
                                  RoomNumber(n).room(1,1) RoomNumber(n).room(4,2) RoomNumber(n).room(5,1)*Height; ];
        polygonPts = vertcat(polygonPts, RoomNumber(n).polygon);
    end
end

for n = 1:numel(HallNumber)
    Height = 4;
    for m = 2:size(HallNumber(n).wall,1)-1
        HallNumber(n).hall = [ HallNumber(n).wall(m-1,1) HallNumber(n).wall(m-1,2) (HallNumber(n).wall(end,1)-1)*Height; 
                               HallNumber(n).wall(m,1) HallNumber(n).wall(m,2) (HallNumber(n).wall(end,1)-1)*Height;
                               HallNumber(n).wall(m,1) HallNumber(n).wall(m,2) HallNumber(n).wall(end,1)*Height;
                               HallNumber(n).wall(m-1,1) HallNumber(n).wall(m-1,2) HallNumber(n).wall(end,1)*Height;];
        
        hallPts = vertcat(hallPts, HallNumber(n).hall);
    end
    HallNumber(n).hall = [ HallNumber(n).wall(end-1,1) HallNumber(n).wall(end-1,2) (HallNumber(n).wall(end,1)-1)*Height; 
                           HallNumber(n).wall(1,1) HallNumber(n).wall(1,2) (HallNumber(n).wall(end,1)-1)*Height;
                           HallNumber(n).wall(1,1) HallNumber(n).wall(1,2) HallNumber(n).wall(end,1)*Height;
                           HallNumber(n).wall(end-1,1) HallNumber(n).wall(end-1,2) HallNumber(n).wall(end,1)*Height;];
    hallPts = vertcat(hallPts, HallNumber(n).hall);                           
end

buildingPts = [squarePts; trianglePts; polygonPts; hallPts];

% connect
allWallMesh = [];
squareMesh = [];
triangleMesh = [];
polygonMesh = [];

for j = 0:size(squarePts, 1)/8 - 1
    index = j*8;
    roomMesh = [index+1 index+2 index+3; index+3 index+4 index+1; index+5 index+6 index+7; index+7 index+8 index+5;
                index+1 index+2 index+6; index+6 index+5 index+1; index+2 index+3 index+7; index+7 index+6 index+2; index+4 index+3 index+7; index+7 index+8 index+4; index+4 index+1 index+5; index+5 index+8 index+4];
    if(j == 0)
        squareMesh = roomMesh;
    else
        squareMesh = [squareMesh; roomMesh];
    end
end

%Triangle Connect
for j = 0:size(trianglePts, 1)/6 - 1
    index = j*6 + size(squarePts, 1);
    roomMesh = [index+1 index+2 index+3; index+4 index+5 index+6;
                index+1 index+2 index+5; index+5 index+4 index+1; 
                index+2 index+5 index+6; index+6 index+3 index+2;
                index+3 index+1 index+4; index+4 index+6 index+3];
    if(j == 0)
        triangleMesh = roomMesh;
    else
        triangleMesh = [triangleMesh; roomMesh];
    end
end

%Polygon Connect
for k = 0:size(polygonPts, 1)/12 - 1
    ind = k*12 + size(squarePts, 1) + size(trianglePts, 1);
    roomMesh = [ind+6 ind+1 ind+2; ind+2 ind+5 ind+6;
                ind+2 ind+3 ind+4; ind+4 ind+5 ind+2;
                ind+12 ind+7 ind+8; ind+8 ind+11 ind+12;
                ind+8 ind+9 ind+10; ind+10 ind+11 ind+8;
                ind+1 ind+2 ind+8; ind+8 ind+7 ind+1;
                ind+2 ind+3 ind+9; ind+9 ind+8 ind+2; 
                ind+3 ind+4 ind+10; ind+10 ind+9 ind+3;
                ind+5 ind+4 ind+10; ind+10 ind+11 ind+5;
                ind+5 ind+6 ind+12; ind+12 ind+11 ind+5;
                ind+1 ind+6 ind+12; ind+12 ind+7 ind+1;];
    if(k == 0)
        polygonMesh = roomMesh;
    else
        polygonMesh = [polygonMesh; roomMesh];
    end
end

% Wall connect
for j = 0:size(hallPts, 1)/4 - 1
    index = j*4 + size(squarePts, 1) + size(trianglePts, 1) + size(polygonPts, 1);
    wallMesh = [index+1 index+2 index+3; index+3 index+4 index+1;];
    if(j == 0)
        allWallMesh = wallMesh;
    else
        allWallMesh = [allWallMesh; wallMesh];
    end
end

buildingMesh = [squareMesh; triangleMesh; polygonMesh; allWallMesh];

% Create a triangulation object to represent the building
tri = triangulation(buildingMesh, buildingPts);

% deletePts = [];
% floorPts = buildingPts;
% for l = 1:size(buildingPts, 1)
%     for m = l+1:size(buildingPts, 1)
%         if buildingPts(l,1:2) == buildingPts(m,1:2)
%            deletePts = [deletePts, l];
%         end
%     end
% end
% floorPts(deletePts,:) = [];
% floorPts(:,3) = [];
% floorPts = sortrows(floorPts);
% floorPts



end
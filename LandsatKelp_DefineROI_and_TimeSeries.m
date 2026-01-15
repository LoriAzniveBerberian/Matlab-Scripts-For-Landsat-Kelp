clear; 
clc; 
close all; 

%% Set Paths and Inspect NetCDF
% this is the path where you have the data file saved 
directory = 'Y:\personal\lberberian\Data\Algea\Landsat';
cd(directory)
% this is the path where you want the tables we'll create saved 
outdir = 'Y:\personal\lberberian\Geog277-CoastalGeography\outdir';

% name of file
ncfile = 'LandsatKelpBiomass_2025_Q3_v2_withmetadata.nc';
info = ncinfo(ncfile)

% your command window should read: 

    %   Filename: 'LandsatKelpBiomass_2025_Q3_v2_withmetadata.nc'
    %       Name: '/'
    % Dimensions: [1×2 struct]
    %  Variables: [1×14 struct]
    % Attributes: [1×50 struct]
    %     Groups: []
    %     Format: 'netcdf4'
    %  Datatypes: []

% now display all the meta data and global attributes
ncdisp(ncfile)
% now your command window will display all the info about the .nc file
% this will be a lot more information (e.g., source, format, global
% attributes, dimentions, variables, units and meta data)


%% Save Variables 
% this dataset hold observations from 1984-2025 Q2 however, the variable 
% time is stored as integers = "days since 1970-01-01" time_days (below)
% saves the raw time axis incase we need to reconstuct time again or line 
% up with other datasets  

time_days = double(ncread(ncfile,'time'));  % days since 1970-01-01
year = double(ncread(ncfile,'year'));
quarter = double(ncread(ncfile,'quarter'));

lat = ncread(ncfile,'latitude');
lon = ncread(ncfile, 'longitude');

area = ncread(ncfile, 'area');
area_se = ncread(ncfile,'area_se');
biomass = ncread(ncfile,'biomass');
biomass_se = ncread(ncfile,'biomass_se');

nLandsat_Image = ncread(ncfile,'passes');
nLandsat4_5_Image = ncread(ncfile,'passes5');
nLandsat7_Image = ncread(ncfile,'passes7');
nLandsat8_9_Image = ncread(ncfile,'passes8');
nLandsat6_Image = ncread(ncfile,'passes6');

%% Save Full Dataset as a Matlab Table (.mat file)
save(fullfile(outdir,'LandsatKelpBiomass_2025_Q3_v2.mat'),'info','ncfile','time_days','year','quarter','lat','lon', 'area','area_se','biomass','biomass_se','nLandsat_Image','nLandsat4_5_Image','nLandsat6_Image','nLandsat7_Image','nLandsat8_9_Image','-v7.3');
disp('file saved, now clear the work space with clc, clear all and load in the .mat')


%% Load LandsatKelpBiomass_2025_Q3_v2.mat
load('Y:\personal\lberberian\Geog277-CoastalGeography\outdir\LandsatKelpBiomass_2025_Q3_v2.mat');
whos

%% Region of Interest: User Input in Degrees
% for example, here we subset the data to Santa Barbara/Goleta
minLat = 34.35;
maxLat = 34.55;
minLon = -120.10;
maxLon = -119.55;

% find stations inside ROI
inBox = (lat>= minLat) & (lat <= maxLat) & (lon >= minLon) & (lon <= maxLon); 
station_index = find(inBox) 
station_index = sort(station_index);

% save variables for your ROI
lat_roi = lat(station_index); 
lon_roi = lon(station_index);

% this will convert your netcdf time variable to a real calendar date 
% before running this line if you click on the table in the worksapce for
% time_days you will see that they are stored as days since 1970
time_dt = datetime(1970,1,1) + days(time_days(:));

%% Subset ROI Arrays (station x time), Convert and Fill -1 Value With NaN
area_roi = double(area(station_index,:));
area_roi(area_roi == -1) = NaN;

area_se_roi = double(area_se(station_index,:));
area_se_roi(area_se_roi == -1) = NaN;

biomass_roi = double(biomass(station_index,:));
biomass_roi(biomass_roi == -1) = NaN;

biomass_se_roi = double(biomass_se(station_index,:));
biomass_se_roi(biomass_se_roi == -1) = NaN;

% image count variables
passes_roi  = double(nLandsat_Image(station_index,:));
passes5_roi = double(nLandsat4_5_Image(station_index,:));
passes6_roi = double(nLandsat6_Image(station_index,:));
passes7_roi = double(nLandsat7_Image(station_index,:));
passes8_roi = double(nLandsat8_9_Image(station_index,:));

%% ROI Sum by Quarter: one row per time step 
% counts
nStation = numel(station_index);  % how many pixels (stations)
nTime= numel(time_dt); % how many time steps (quarters)

% initiate empty table 
ROI_sum = table;
% time columns
ROI_sum.time = time_dt(:);
ROI_sum.year  = year(:);
ROI_sum.quarter = quarter(:);
% sums across roi each quarter
ROI_sum.area_sum_m2 = nansum(area_roi, 1).';
ROI_sum.biomass_sum_kg = nansum(biomass_roi, 1).'; 
% convert areaun it
ROI_sum.area_sum_km2 = ROI_sum.area_sum_m2 / 1e6;

% now ROI_sum is a table with one row per Q qith time, year, quarter,
% area_sum_m2, area_sum_km2, biomass_sum_kg, and your summaries)


%% Calculate Some Summaries
% data coverage (how many pixels contributed each quarter)
ROI_sum.nStations = repmat(nStation, nTime, 1);
ROI_sum.nValid_area = sum(~isnan(area_roi), 1).';
ROI_sum.nValid_biomass = sum(~isnan(biomass_roi), 1).';
ROI_sum.coverage_area_pct = 100 * (ROI_sum.nValid_area ./ ROI_sum.nStations);
ROI_sum.coverage_biomass_pct= 100 * (ROI_sum.nValid_biomass ./ ROI_sum.nStations);

% mean passes per pixel each quarter 
ROI_sum.passes_mean  = mean(passes_roi,  1, 'omitnan').';
ROI_sum.passes5_mean = mean(passes5_roi, 1, 'omitnan').';
ROI_sum.passes6_mean = mean(passes6_roi, 1, 'omitnan').';
ROI_sum.passes7_mean = mean(passes7_roi, 1, 'omitnan').';
ROI_sum.passes8_mean = mean(passes8_roi, 1, 'omitnan').';

% summed uncertainty of total (assumes independence)
ROI_sum.area_se_sum_m2 = sqrt(nansum(area_se_roi.^2, 1)).';
ROI_sum.biomass_se_sum_kg = sqrt(nansum(biomass_se_roi.^2, 1)).';  

%% save table
outdir = 'Y:\personal\lberberian\Geog277-CoastalGeography\outdir';
save(fullfile(outdir,'Landsat_Kelp_Roi_Sum_By_Quarter.mat'),'ROI_sum','station_index','minLat','maxLat','minLon','maxLon','-v7.3');
writetable(ROI_sum, fullfile(outdir,'landsat_kelp_roi_sum_by_quarter.csv'));


%% plot area (km2)
figure;
plot(ROI_sum.time, ROI_sum.area_sum_km2);
grid off;
xlabel('time');
ylabel('SB kelp canopy area (km^2)');
title('SB kelp canopy area (quarterly)');

%% plot biomass (kg)
figure;
plot(ROI_sum.time, ROI_sum.biomass_sum_kg);
grid off;
xlabel('time');
ylabel('SB kelp biomass (kg)');
title('SB kelp biomass (quarterly)');




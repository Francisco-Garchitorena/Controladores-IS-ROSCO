function [RainFlowStruct]=RunRainFlowAnalysis(Time,Sensor,SN_Slope,EqvFreq)

%%%%%%%%%%%%%% RAINFLOW ANALYSIS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% Sensor
RainFlowStruct.SimTime = Time;
RainFlowStruct.SensorLoad(1,:) = Sensor;
%%%
InputFile.RainFlowNumbFreqYear = 1;
InputFile.RainFlowNumbYears = 1;
if nargin>2                                             %Si se proporciona el argumento SN_Slope.
    InputFile.RainFlowEqvLoadsSlope = 1./SN_Slope;
else
    InputFile.RainFlowEqvLoadsSlope = 1./[4:1:13];
end
InputFile.RainFlowEqvLoadsFreq = EqvFreq;
InputFile.RainFlowNumbBins = 64;
InputFile.RainFlowMinRange = 0;
%%%
RainFlowStruct = RainflowAnalysis(RainFlowStruct,InputFile);

return
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [RainFlowStructNew] = RainflowAnalysis(RainFlowStruct,InputFile)

% From RainFlowFindSensors:
%
% RainFlowStruct.SensorLoad(i_mm_sens,:) = Sensor.MdtValues{i_all_sens}(InputFile.RainFlowSensorsListComponent{i_mm_sens},:); 
% RainFlowStruct.SimTime = Sensor.MdtTime; 
% 

% from RAINFLOW
%
% 'Row 1: amplitude' ---> to have the range=Row1*2
% 'Row 2: mean'      ---> ratio R = value_min/value_max
% 'Row 3: number of cycles (cycle or half cycle)'
% % % disp('Row 4: begin time of extracted cycle or half cycle')
% % % disp('Row 5: period of a cycle')   

sigtime = RainFlowStruct.SimTime;

Ttime = sigtime(end)-sigtime(1);

for i_sens=1:size(RainFlowStruct.SensorLoad,1)
    sigvalue = RainFlowStruct.SensorLoad(i_sens,:);

    % extracting extreme values
    sigext = sig2ext(sigvalue, sigtime);

    % counting cycle
    RainFlowStructNew.RainFlowCyclesCountingMatrix{i_sens} = rainflow(sigext,1);
    
    [RainFlowStructNew.MeanVect{i_sens},...
     RainFlowStructNew.RangeVect{i_sens},...
     RainFlowStructNew.Ncycle{i_sens},...
     RainFlowStructNew.Nrange{i_sens},...
     RainFlowStructNew.NrangeCum{i_sens},...
     RainFlowStructNew.EqvLoads{i_sens}] = PostProcessFatigue(RainFlowStructNew.RainFlowCyclesCountingMatrix{i_sens},InputFile,Ttime);
    
end
RainFlowStructNew.SimTime = RainFlowStruct.SimTime;
RainFlowStructNew.SensorLoad = RainFlowStruct.SensorLoad;

return
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [X_mean,X_range,Ncycle,Nrange,Nrange_cum,Leqtot] = PostProcessFatigue(matrix,InputFile,Ttime)

m = 1./InputFile.RainFlowEqvLoadsSlope;

row1=matrix(1,:)*2;     % RANGE
row2=matrix(2,:);       % MEAN VALUE
row3=matrix(3,:)*InputFile.RainFlowNumbFreqYear*InputFile.RainFlowNumbYears;

% max range
max_range = max(row1);

% Check
if (InputFile.RainFlowMinRange>max_range)
    InputFile.RainFlowMinRange=0;
    fprintf(1,'Warning! MinimumRange is too high!');
    fprintf(1,'         A zero value is used!');
end
%
N_range = InputFile.RainFlowNumbBins;           %entrada, numero de bins seleccionado
d_range = (max_range-InputFile.RainFlowMinRange)/N_range;       %ancho de cada bin en rango
X_range = [InputFile.RainFlowMinRange:d_range:N_range*d_range]; %Rango, vector con valores de la variable separados por el ancho de bin en el rango.

% max and min mean value
max_mean = max(row2);
min_mean = min(row2);

N_mean = InputFile.RainFlowNumbBins;
d_mean = (max_mean-min_mean)/N_mean;

X_mean = [min_mean:d_mean:max_mean];

for i_range = 2:length(X_range)
    
    % find amplitude in between the tabulated amplitude 
    ii_range = find((row1<=X_range(i_range))&(row1>X_range(i_range-1)));
    
    % n of cycle at the amplitude (not depending on the mean value)
    Nrange(i_range)=sum(row3(ii_range));
    
    for i_mean=2:length(X_mean)
        
        kk_mean = find((row2(ii_range)<=X_mean(i_mean))&(row2(ii_range)>X_mean(i_mean-1)));
        
        % number of cycle grouped by tne mean value
        Ncycle(i_range,i_mean) = sum(row3(ii_range(kk_mean)));
        clear kk_mean
        
    end
    clear ii_range
end

for i_m=1:length(m)
    % equivalent load for every mean value
    for i_mean = 2:length(X_mean)
        
        if sum(Ncycle(:,i_mean)) == 0
            Leq(i_m,i_mean)=0;
        else
            Leq(i_m,i_mean)=(sum((X_range.^(m(i_m))).*Ncycle(:,i_mean)'./sum(Ncycle(:,i_mean))))^(1/(m(i_m))); 
        end
        
    end
    
    % equivalent load 
    % Original from HJSutherland
    % Leqtot2(i_m)=(sum((X_range.^(m(i_m))).*Nrange./sum(Nrange)))^(1/(m(i_m)));
    % From Bladed Manual:
    Leqtot(i_m)= ( sum((X_range.^(m(i_m))).*Nrange) ./ (Ttime*InputFile.RainFlowEqvLoadsFreq) )^((1/m(i_m))); % sum(S^m *N)/neq
    
end

% Cumulative cycles
for i_range=1:length(X_range)
    Nrange_cum(i_range) = sum(Nrange(i_range:end));
end

return



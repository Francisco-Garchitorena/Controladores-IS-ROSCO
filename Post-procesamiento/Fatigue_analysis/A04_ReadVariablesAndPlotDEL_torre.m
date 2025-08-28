% Script que obtiene los DELs de los momentos foreaft y sideside en la base de la torre
% para cada combinación de shear e IT.

clear all
close all

%% Leer las salidas de OpenFAST
% Nombre del archivo *.out
l=1;
for i=[0.1,0.3]
  k=1;
  for j=[5,10]
    % Nombre del archivo *.out
    FileName = ['../Parte_3/s' num2str(i) '/TI' num2str(j) '/5MW_Land_DLL_WTurb_s'...
      num2str(i) '_TI' num2str(j) '.out'];
    %FileName = '../5MW_Land_DLL_WTurb/5MW_Land_DLL_WTurb.out';

     % Listar variables a leer del *.out
     vars = {'Time','TwrBsMxt','TwrBsMyt'};

     % Leer las variables
     [tSeries] = ReadOpenFASToutput(FileName,vars);

%% ------------------------- User inputs ----------------------------------

    iStart = 2000; % initial OPENFAST time step for DEL analysis
    iEnd   = 9601; % final OPENFAST time step for DEL analysis
    % 
    SN_Slope  =  4; % 10 para las palas, 4 para shaft y tower

% ------------------------- Computations ----------------------------------
addpath('./RainflowAnalysis')

EqvFreq = 1;

fprintf('\n>>>>>>>>>>>>>> COMPUTING RAINFLOW <<<<<<<<<<<<<<<<<<\n');

%--------------------- Side-Side Moment ---------------------%
Index = find(contains(vars,'Time'));
Time  = tSeries(iStart:iEnd,Index);

Index  = find(contains(vars,'TwrBsMxt'));
Sensor = tSeries(iStart:iEnd,Index);  
              
%--------------------- DEL computation -----------------------%
                
[RainFlowStruct] = RunRainFlowAnalysis(Time,Sensor,SN_Slope,EqvFreq);
       
%                 
DEL_torre_side_side(l,k) = cell2mat(RainFlowStruct.EqvLoads)

%--------------------- Fore-Aft Momento -----------------------%

Index = find(contains(vars,'Time'));
Time  = tSeries(iStart:iEnd,Index);

Index  = find(contains(vars,'TwrBsMyt'));
Sensor = tSeries(iStart:iEnd,Index);  
              
%--------------------- DEL computation -----------------------%
                
[RainFlowStruct] = RunRainFlowAnalysis(Time,Sensor,SN_Slope,EqvFreq);
       
%                 
DEL_torre_fore_aft(l,k) = cell2mat(RainFlowStruct.EqvLoads)
k=k+1;
    end
    l=l+1;
end


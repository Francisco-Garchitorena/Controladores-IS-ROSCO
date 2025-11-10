%close all
clear all;
clc
addpath RainflowAnalysis\
%SCRIPT USADO PARA OBTNER LOS INDICADORES POR TURBINA -----
%ULTIMO USO 04/09/25
%% Parámetros
Turbine =  "IEA3p4MW"; %"NREL2p3MW"; %"NREL5MW"; %          
turbine_base_name = "IEA-3.4-130-RWT"; % "NREL-2p3-116"; %  "NRELOffshrBsline5MW"; % 

% Velocidades, TI y semilla
% velocidades = [7.0, 8.0, 9.0];
velocidades = [7.5, 8.0, 8.5, 9.0, 9.5];

TI = "TI8.0";
sd = "sd0";

% Estrategias
estrategias = {'Norm_op','Tarnowski','Wang'};

% Variables a analizar
variables = {'RootMyb1','RootMxb1','TwrBsMyt','TwrBsMxt', 'LSSGagMya','LSSGagMza'};%
varnames  = {'FlapWise','EdgeWise','ForeAft','SideSide', 'LSSGagMya','LSSGagMza'};%
op_variables = {'RotSpeed','BldPitch1'};%
op_varnames  = {'Rotor speed','Blade 1 Pitch'};%
m_values  = [10, 10, 4, 4, 4, 4];  

dt = 0.01; % 0.00625; % 0.01; %
% Rango de análisis
iStart = 60/dt; 
iEnd   = 660/dt; 
EqvFreq = 1;

% Tiempo de inercia
t_inercia = 360; % [s]
duraciones = [5, 10]; % [s]

%% Resultados
DELs = struct();
maximos = struct();
medias = struct();
energias = struct();

base_path = "C:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO/Torque_2026_" + Turbine;

for v = 1:length(velocidades)
    Vstr = sprintf("%.1f", velocidades(v));
    Wind_Condition = "v" + Vstr + "_" + TI + "_sd0";  % etiqueta de condición de viento
    
    for e = 1:length(estrategias)
        estrategia = estrategias{e};
        
        % Construir path
        file_path = fullfile(base_path, ...
            estrategia, Vstr, TI, sd, ...
            turbine_base_name + "_" + estrategia + "_" + Wind_Condition + ".outb");
        
        fprintf("Procesando: %s\n", file_path);
        
        % Leer archivo
        [tSeries, ChanName, ~, ~, ~] = ReadFASTbinary(file_path);
        
        % --- DELs y máximos ---
        for vvar = 1:length(variables)
            var = variables{vvar};
            SN_Slope = m_values(vvar);
            
            % Buscar índice correcto
            idx = find(strcmp(ChanName, var));
            if isempty(idx)
                error(['Variable ', var, ' no encontrada en el archivo: ', file_path]);
            end
            
            % Extraer datos
            Time = tSeries(iStart:iEnd, 1);  
            Sensor = tSeries(iStart:iEnd, idx);
            
            % Calcular DEL
            RainFlowStruct = RunRainFlowAnalysis(Time, Sensor, SN_Slope, EqvFreq);
            DEL = cell2mat(RainFlowStruct.EqvLoads);
            %vel_field = char(Vstr);
            DELs.(estrategia).(['V' num2str(velocidades(v))]).(var) = DEL;
            maximos.(estrategia).(['V' num2str(velocidades(v))]).(var) = max(Sensor);
        end

        % --- medias ---
        for op_var = 1:length(op_variables)
            var = op_variables{op_var};
            
            % Buscar índice correcto
            idx = find(strcmp(ChanName, var));
            if isempty(idx)
                error(['Variable ', var, ' no encontrada en el archivo: ', file_path]);
            end
            
            % Extraer datos
            Time = tSeries(iStart:iEnd, 1);  
            Sensor = tSeries(iStart:iEnd, idx);
           
            medias.(estrategia).(['V' num2str(velocidades(v))]).(var) = mean(Sensor);
        end
        
        % --- Energía inyectada ---
        idxP = find(strcmp(ChanName, 'GenPwr'));
        if isempty(idxP)
            warning('Variable GenPwr no encontrada en %s', file_path);
        else
            Time = tSeries(:,1);
            Pgen = tSeries(:,idxP); % [kW]
            
            for d = 1:length(duraciones)
                t_start = t_inercia;
                t_end   = t_inercia + duraciones(d);
                mask = (Time >= t_start) & (Time <= t_end);
                
                E_kWs = trapz(Time(mask), Pgen(mask)); % kW*s
                E_kWh = E_kWs / 3600.0;
                
                energias.(estrategia).(['V' num2str(velocidades(v))]).(['Dur' num2str(duraciones(d)) 's']) = E_kWh;
            end
        end
    end
end

%% Ahora podés armar tablas y gráficos como antes, 
% pero ojo que ahora están organizados por estrategia Y velocidad:
% ejemplo: DELs.Norm_op.V7.0.RootMyb1
%          energias.Tarnowski.V9.0.Dur10s

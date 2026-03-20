%close all
clear; clc;
addpath RainflowAnalysis\

% SCRIPT USADO PARA OBTENER LOS INDICADORES POR SEMILLA PARA LA IEA 3.4MW   
% ULTIMO USO 04/09/25

%% Parámetros
Turbine =  "NREL5MW";%"IEA3p4MW"; %
turbine_base_name = "NRELOffshrBsline5MW"; %"IEA-3.4-130-RWT"; %

% Velocidades, TI y semillas
%velocidades       = [7.5, 8.0, 8.5, 9.0, 9.5];
%velocidades_names = ["7_5", "8", "8_5", "9", "9_5"];
 velocidades       = [8.0, 8.5, 9.0, 9.5, 10.0];
 velocidades_names = ["8_0", "8_5", "9_0", "9_5", "10_0"];
TI     = "TI8.0";
%CFG 10/09/25:
%seeds  = ["sd0","sd1","sd2","sd3","sd4","sd5","sd6","sd7","sd8","sd9","sd10","sd11"];
seeds  = ["sd0","sd1","sd2","sd3","sd4","sd5","sd6","sd7","sd8","sd9","sd10","sd11","sd12","sd13","sd14","sd15","sd16","sd17","sd18","sd19","sd20","sd21","sd22","sd23"];

% Estrategias
estrategias = {'Norm_op','Tarnowski','Wang','GMFC'}; %

% Variables a analizar
variables  = {'RootMyb1','RootMxb1','TwrBsMyt','TwrBsMxt','LSSGagMya','LSSGagMza','RotTorq'};
varnames   = {'FlapWise','ForeAft','LSS Moment y-axis','EdgeWise','SideSide','LSS Moment z-axis','LSS Moment x-axis'};
% variables  = {'TwrBsMxt','LSSGagMya','LSSGagMza','RotTorq'};
% varnames   = {'FlapWise','ForeAft','LSS Moment y-axis','EdgeWise','SideSide','LSS Moment z-axis','LSS Moment x-axis'};
op_variables  = {'RotSpeed','BldPitch1'};
op_varnames   = {'Rotor speed','Blade 1 Pitch'};
m_values   = [10, 10, 4, 4, 4, 4,4];  % pendiente S-N por variable

dt = 0.00625;
iStart = 60/dt;
iEnd   = 660/dt;
EqvFreq = 1;

% Ventanas de energía de inercia
t_inercia  = 360; % [s]
duraciones = [5, 10, 100]; % [s]

%% Resultados
DELs  = struct();                % por semilla
Maxs  = struct();                % por semilla
Medias   = struct();             % por semilla (op vars)
Energias = struct();             % por semilla

% Agregados ponderados por semilla (promedio generalizado con exponente m)
DELs_ponderados_seed  = struct();
Maxs_ponderados_seed  = struct();

%CFG 10/09/25: base_path = "C:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO/Torque_2026_" + Turbine;
base_path = "E:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO/Torque_2026_" + Turbine + "_24_seeds";

for v = 1:length(velocidades)
    Vstr      = sprintf("%.1f", velocidades(v));
    vel_field = "V" + velocidades_names(v);   % <-- nombre de campo seguro
    
    for e = 1:length(estrategias)
        estrategia = estrategias{e};

        % Buffers para agregar luego por semillas
        % (guardamos en arrays para hacer el promedio generalizado)
        DEL_buffer = containers.Map;   % key: var, value: vector de DELs por semilla
        MAX_buffer = containers.Map;   % key: var, value: vector de Max por semilla
        for vvar = 1:length(variables)
            DEL_buffer(variables{vvar}) = []; %#ok<*SAGROW>
            MAX_buffer(variables{vvar}) = [];
        end

        for sd = 1:length(seeds)
            sd_str   = seeds(sd);
            sd_field = sd_str;          % nombre de campo por semilla

            Wind_Condition = "v" + Vstr + "_" + TI + "_" + sd_str;  % etiqueta de viento

            % Path
            file_path = fullfile(base_path, ...
                estrategia, Vstr, TI, sd_str, ...
                turbine_base_name + "_" + estrategia + "_" + Wind_Condition + ".outb");

            fprintf("Procesando: %s\n", file_path);

            % Leer archivo
            [tSeries, ChanName, ~, ~, ~] = ReadFASTbinary(file_path);

            % --- DELs y máximos (por semilla) ---
            for vvar = 1:length(variables)
                var = variables{vvar};
                SN_Slope = m_values(vvar);

                idx = find(strcmp(ChanName, var), 1);
                if isempty(idx)
                    error('Variable %s no encontrada en el archivo: %s', var, file_path);
                end

                Time   = tSeries(iStart:iEnd, 1);
                Sensor = tSeries(iStart:iEnd, idx);

                % DEL (m-method)
                RF = RunRainFlowAnalysis(Time, Sensor, SN_Slope, EqvFreq);
                DEL_val = cell2mat(RF.EqvLoads);

                % Guardar por semilla
                DELs.(estrategia).(vel_field).(sd_field).(var) = DEL_val;
                Maxs.(estrategia).(vel_field).(sd_field).(var) = max(abs(Sensor));

                % Acumular para el ponderado por semilla
                DEL_buffer(var) = [DEL_buffer(var), DEL_val];
                MAX_buffer(var) = [MAX_buffer(var), max(abs(Sensor))];
            end

            % --- Medias (por semilla) ---
            for op_var = 1:length(op_variables)
                var = op_variables{op_var};
                idx = find(strcmp(ChanName, var), 1);
                if isempty(idx)
                    error('Variable %s no encontrada en el archivo: %s', var, file_path);
                end
                Sensor = tSeries(iStart:iEnd, idx);
                Medias.(estrategia).(vel_field).(sd_field).(var) = mean(Sensor);
            end

            % --- Energía inyectada (por semilla) ---
            idxP = find(strcmp(ChanName, 'GenPwr'), 1);
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

                    dur_field = "Dur" + string(duraciones(d)) + "s";
                    Energias.(estrategia).(vel_field).(sd_field).(dur_field) = E_kWh;
                end

                % %AP dip:
                % t_start = t_inercia;
                % %t_end   = t_inercia + duraciones(d);
                % mask = (Time >= t_start);% & (Time <= t_end);
                % 
                % P_IS = Pgen(mask);
                % 
                % 
                % dur_field = "Dur" + string(duraciones(d)) + "s";
                % Energias.(estrategia).(vel_field).(sd_field).(dur_field) = E_kWh;

            end
        end % semillas

        % === Agregados ponderados por semilla (promedio generalizado con m) ===
        % DEL: (mean(DEL.^m))^(1/m)
        % Max: (mean(Max.^m))^(1/m)
        for vvar = 1:length(variables)
            var = variables{vvar};
            m   = m_values(vvar);

            DEL_vec = DEL_buffer(var);
            MAX_vec = MAX_buffer(var);

            if isempty(DEL_vec)
                continue
            end

            DEL_m_weighted = ( mean( DEL_vec.^m ) )^(1/m);
            MAX_weighted = max(MAX_vec);
            
            DELs_ponderados_seed.(estrategia).(vel_field).(var) = DEL_m_weighted;
            Maxs_ponderados_seed.(estrategia).(vel_field).(var) = MAX_weighted;
        end

    end % estrategias
end % velocidades

%%
%save('DELs_Max_means_per_seed_24_seeds_with_GMFC_str.mat')
%save('DELs_Max_means_per_seed_24_seeds_with_AP_dip.mat')
%save('NREL5MW_DELs_Max_means_per_seed_24_seeds_with_komega2_controller.mat')
%save('NREL5MW_DELs_Max_means_per_seed_24_seeds_with_komega2_controller_journal.mat')
save('NREL5MW_DELs_Max_means_per_seed_24_seeds_with_komega2_controller_journal_with_GMFC_strat.mat')
%save('IEA3p4MW_DELs_Max_means_per_seed_24_seeds_with_komega2_controller_journal_with_GMFC_strat.mat')
close all
clc
addpath RainflowAnalysis\
%% Parámetros
Turbine = "IEA_3p4MW";          % o "NREL5MW"
Wind_Condition = "v8_TI10";
turbine_base_name = "IEA-3.4-130-RWT"; % o "NRELOffshrBsline5MW"

base_path = "C:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO/Test_Wang_OF";

% Simulaciones a procesar (usar fullfile para evitar arrays de string)
simulations = {
    fullfile(base_path, Turbine, Wind_Condition, ...
             turbine_base_name + "_norm_op_" + Wind_Condition + ".outb")
    fullfile(base_path, Turbine, Wind_Condition, ...
             turbine_base_name + "_Wang_" + Wind_Condition + ".outb")
};

simulations_names = {'Normal_op', 'Wang'};

% Variables a analizar (flap y edge de la pala 1)
variables = {'RootMyb1','RootMxb1', 'TwrBsMyt', 'TwrBsMxt'};  %, 'LSSGagMya', 'LSSGagMza'
m_values = [10, 10, 4, 4];  % pendiente S-N para ambas

% Rango de análisis
iStart = 60/0.00625; % índice inicial
iEnd   = 660/0.00625; % índice final
EqvFreq = 1;

%% Resultados
DELs = struct();
maximos = struct();
for i = 1:length(simulations)
    FileName = simulations{i};
    
    % Leer variables del archivo
    [tSeries, ChanName, ChanUnit, FileID, DescStr] = ReadFASTbinary(FileName);
    
    for v = 1:length(variables)
        var = variables{v};
        SN_Slope = m_values(v);
        
        % Buscar índice correcto en ChanName
        idx = find(strcmp(ChanName, var));
        if isempty(idx)
            error(['Variable ', var, ' no encontrada en el archivo: ', FileName]);
        end
        
        % Extraer datos
        Time = tSeries(iStart:iEnd, 1);   % Primera columna es Time
        Sensor = tSeries(iStart:iEnd, idx);
        
        % Graficar señal
        % figure;
        % plot(Time, Sensor, 'LineWidth',1.5);
        % xlabel('Time [s]'); ylabel(var); title(FileName, 'Interpreter','none');
        % grid on;
        
        % Calcular DEL con rainflow
        RainFlowStruct = RunRainFlowAnalysis(Time,Sensor,SN_Slope,EqvFreq);
        DEL = cell2mat(RainFlowStruct.EqvLoads);
        
        % Guardar resultados
        DELs.(simulations_names{i}).(var) = DEL;
        maximos.(simulations_names{i}).(var) = max(Sensor);
    end
end


%% Construir tablas comparativas
tabla_DEL = table();
tabla_Max = table();

for v = 1:length(variables)
    var = variables{v};
    base_DEL = DELs.(simulations_names{1}).(var);
    wang_DEL = DELs.(simulations_names{2}).(var);
    aumento_DEL = 100*(wang_DEL - base_DEL)/base_DEL;
    
    base_Max = maximos.(simulations_names{1}).(var);
    wang_Max = maximos.(simulations_names{2}).(var);
    aumento_Max = 100*(wang_Max - base_Max)/base_Max;
    
    % Llenar tablas
    tabla_DEL = [tabla_DEL; {var, base_DEL, wang_DEL, aumento_DEL}];
    tabla_Max = [tabla_Max; {var, base_Max, wang_Max, aumento_Max}];
end

tabla_DEL.Properties.VariableNames = {'Variable','DEL_Base','DEL_Wang','Aumento_pct'};
tabla_Max.Properties.VariableNames = {'Variable','Max_Base','Max_Wang','Aumento_pct'};

disp('===== Comparación de DELs =====');
disp(tabla_DEL);

disp('===== Comparación de Valores Máximos =====');
disp(tabla_Max);

%% Graficar resultados
figure; fontsize = 14;
bar(categorical(tabla_DEL.Variable), tabla_DEL.Aumento_pct);
ylabel('Increase in DEL [\%]', 'FontSize',fontsize, 'Interpreter','latex');
ax = gca;                      % eje actual
ax.TickLabelInterpreter = 'latex';
title('DEL analysis: Norm op vs Wang', 'FontSize',16, 'Interpreter','latex');
grid on;

figure;
ax = gca;                      % eje actual
ax.TickLabelInterpreter = 'latex';
bar(categorical(tabla_Max.Variable), tabla_Max.Aumento_pct);
ylabel('Increase in maximum value [\%]', 'FontSize',fontsize, 'Interpreter','latex');
title('Maximum values: Norm op vs Wang', 'FontSize',16, 'Interpreter','latex');
grid on;

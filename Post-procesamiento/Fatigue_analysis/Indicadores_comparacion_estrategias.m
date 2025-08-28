close all
clc
addpath RainflowAnalysis\

%% Parámetros
Turbine = "IEA_3p4MW";          % o "NREL5MW"
Wind_Condition = "v8_TI10";
turbine_base_name = "IEA-3.4-130-RWT"; % o "NRELOffshrBsline5MW"
% 
% % Simulaciones a procesar
% simulations = {
%     fullfile("C:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO/Operacion_normal", ...
%              Turbine, Wind_Condition, turbine_base_name + "_norm_op_" + Wind_Condition + ".outb")
%     fullfile("C:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO/Test_Tarnowski_OF", ...
%              Turbine, Wind_Condition, turbine_base_name + "_Tarnowski_" + Wind_Condition + ".outb")
%     fullfile("C:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO/Test_Wang_OF", ...
%              Turbine, Wind_Condition, turbine_base_name + "_Wang_" + Wind_Condition + ".outb")
% };

% Simulaciones a procesar
simulations = {
    fullfile("C:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO/Torque_2026_", ...
             Turbine + "/Norm_op/" + Wind_Condition, turbine_base_name + "_norm_op_" + Wind_Condition + ".outb")
    fullfile("C:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO/Test_Tarnowski_OF", ...
             Turbine, Wind_Condition, turbine_base_name + "_Tarnowski_" + Wind_Condition + ".outb")
    fullfile("C:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO/Test_Wang_OF", ...
             Turbine, Wind_Condition, turbine_base_name + "_Wang_" + Wind_Condition + ".outb")
};
simulations_names = {'Normalop','Tarnowski','Wang'};

% Variables a analizar (flap y edge de la pala 1 + torre)
variables = {'RootMyb1','RootMxb1','TwrBsMyt','TwrBsMxt', 'LSSGagMya','LSSGagMza'};
varnames = {'FlapWise','EdgeWise','ForeAft','SideSide', 'LSSGagMya', 'LSSGagMza'};
m_values = [10, 10, 4, 4, 4, 4];  

% Rango de análisis
iStart = 60/0.00625; % índice inicial
iEnd   = 660/0.00625; % índice final
EqvFreq = 1;

% Tiempo de inercia
t_inercia = 360; % [s]
duraciones = [5, 10]; % [s]

%% Resultados
DELs = struct();
maximos = struct();
energias = struct();

for i = 1:length(simulations)
    FileName = simulations{i};
    
    % Leer archivo
    [tSeries, ChanName, ~, ~, ~] = ReadFASTbinary(FileName);
    
    % --- DELs y máximos ---
    for v = 1:length(variables)
        var = variables{v};
        SN_Slope = m_values(v);
        
        % Buscar índice correcto en ChanName
        idx = find(strcmp(ChanName, var));
        if isempty(idx)
            error(['Variable ', var, ' no encontrada en el archivo: ', FileName]);
        end
        
        % Extraer datos
        Time = tSeries(iStart:iEnd, 1);   % primera columna es Time
        Sensor = tSeries(iStart:iEnd, idx);
        
        % Calcular DEL
        RainFlowStruct = RunRainFlowAnalysis(Time, Sensor, SN_Slope, EqvFreq);
        DEL = cell2mat(RainFlowStruct.EqvLoads);
        
        DELs.(simulations_names{i}).(var) = DEL;
        maximos.(simulations_names{i}).(var) = max(Sensor);
    end
    
    % --- Energía inyectada ---
    idxP = find(strcmp(ChanName, 'GenPwr')); % ojo al nombre exacto de la señal
    if isempty(idxP)
        warning('Variable GenPwr no encontrada en %s', FileName);
    else
        Time = tSeries(:,1);
        Pgen = tSeries(:,idxP); % [kW]
        
        for d = 1:length(duraciones)
            t_start = t_inercia;
            t_end   = t_inercia + duraciones(d);
            mask = (Time >= t_start) & (Time <= t_end);
            
            E_kWs = trapz(Time(mask), Pgen(mask)); % kW*s = kJ
            E_kWh = E_kWs / 3600.0;
            
            energias.(simulations_names{i}).(['Dur' num2str(duraciones(d)) 's']) = E_kWh;
        end
    end
end

%% Comparación DELs y máximos
tabla_DEL = table();
tabla_Max = table();

for v = 1:length(variables)
    var = variables{v};
    base_DEL = DELs.(simulations_names{1}).(var);
    fila_DEL = {var};
    fila_Max = {var};
    
    for i = 1:length(simulations_names)
        fila_DEL{end+1} = DELs.(simulations_names{i}).(var);
        fila_Max{end+1} = maximos.(simulations_names{i}).(var);
    end
    tabla_DEL = [tabla_DEL; fila_DEL];
    tabla_Max = [tabla_Max; fila_Max];
end

tabla_DEL.Properties.VariableNames = ['Variable', simulations_names];
tabla_Max.Properties.VariableNames = ['Variable', simulations_names];

disp('===== DELs absolutos =====');
disp(tabla_DEL);

disp('===== Valores máximos =====');
disp(tabla_Max);

%% Comparación de energías
tabla_E = table();
for d = duraciones
    fila = {['Energy in ' num2str(d) 's']};
    for i = 1:length(simulations_names)
        fila{end+1} = energias.(simulations_names{i}).(['Dur' num2str(d) 's']);
    end
    tabla_E = [tabla_E; fila];
end
tabla_E.Properties.VariableNames = ['Indicador', simulations_names];

disp('===== Energía inyectada (kWh) =====');
disp(tabla_E);

% === Gráfico de energía inyectada ===
figure('Units','normalized','OuterPosition',[0 0 1 1]); % pantalla completa
set(gcf,'Color','w');  % fondo blanco
fontsize = 14;
ax = gca; ax.TickLabelInterpreter = 'latex';
hold on;

% Extraer datos numéricos (sin la columna 'Indicador')
E_data = table2array(tabla_E(:,2:end));  % energías
bar(E_data, 'grouped');

% Etiquetas del eje x con las duraciones
xticks(1:height(tabla_E));
xticklabels(tabla_E.Indicador);

% Etiquetas, leyenda y formato
xlabel('Window (s)','FontSize',fontsize,'Interpreter','latex');
ylabel('Energy injected (kWh)','FontSize',fontsize,'Interpreter','latex');
legend(simulations_names, 'Location','Northwest','FontSize',12,'Interpreter','latex');
title('Energy injected to the grid','FontSize',16,'Interpreter','latex');

grid on;
hold off;
exportgraphics(gcf, sprintf('Imagenes/%s/Energia_inyec_comp_estrategias.png', Turbine), 'Resolution', 300);


%% Graficar aumentos relativos respecto a Normal
ref = simulations_names{1};

% --- DEL ---
figure('Units','normalized','OuterPosition',[0 0 1 1]); % pantalla completa
set(gcf,'Color','w');  % fondo blanco

for v = 1:length(variables)
    subplot(2,3,v)
    base = DELs.(ref).(variables{v});
    pct = [];
    for i = 2:length(simulations_names)
        pct(end+1) = 100*(DELs.(simulations_names{i}).(variables{v})-base)/base;
    end
    bar(categorical(simulations_names(2:end)), pct);
    ylabel('\% Increase', 'FontSize',fontsize,'Interpreter','latex');
    title(['DEL - ' varnames{v}], 'FontSize',16, 'Interpreter','latex');
    ax = gca;                      % eje actual
    ax.TickLabelInterpreter = 'latex';
    grid on;
end
exportgraphics(gcf, sprintf('Imagenes/%s/DELs_comp_estrategias.png', Turbine), 'Resolution', 1000);% --- Máximos ---
figure('Units','normalized','OuterPosition',[0 0 1 1]); % pantalla completa
set(gcf,'Color','w');  % fondo blanco

for v = 1:length(variables)
    subplot(2,3,v)
    base = maximos.(ref).(variables{v});
    pct = [];
    for i = 2:length(simulations_names)
        pct(end+1) = 100*(maximos.(simulations_names{i}).(variables{v})-base)/base;
    end
    bar(categorical(simulations_names(2:end)), pct);
    ylabel('\% Increase', 'FontSize',fontsize, 'Interpreter','latex');
    title(['Max - ' varnames{v}], 'FontSize',16, 'Interpreter','latex');
    ax = gca;                      % eje actual
    ax.TickLabelInterpreter = 'latex';
    grid on;
end
exportgraphics(gcf, sprintf('Imagenes/%s/Max_values_comp_estrategias.png', Turbine), 'Resolution', 1000);% --- Máximos ---


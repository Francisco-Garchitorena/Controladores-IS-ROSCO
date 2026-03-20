
%% ============================================================
%  Plot de Cargas Estructurales por Bin de Velocidad y compara con
%  resultados de inercia sintética
%  Basado en los resultados generados en el script de máximos/DELs
%  Fecha: 2025-10-23
% ============================================================
%%
clear all; close all; clc;
load DELs_Max_means_per_seed_24_seeds.mat
estrategias    = [ "Tarnowski","Wang"];   % estrategias a comparar
variables = {'RootMyb1','TwrBsMyt','LSSGagMya','RootMxb1','TwrBsMxt','RotTorq'};
varnames   = {'FlapWise','ForeAft','LSS Bending moment','EdgeWise','SideSide','LSS Torsional moment'};
Extremes = struct();
nVars = length(variables);
fs = 22;

for vvar = 1:nVars
   
    var      = variables{vvar};
    varname  = varnames{vvar};
    
    
    for e = 1:length(estrategias)
        estrategia = estrategias{e};
    
        % Inicializar estructura si no existe
        if ~isfield(Extremes, estrategia)
            Extremes.(estrategia) = struct();
        end
    
        data_vec = [];
        group_vec = [];
    
        for v = 1:length(velocidades)
            vel_field = "V" + velocidades_names(v);
            seeds_vals = [];
    
            for sd = 1:length(seeds)
                sd_field = seeds(sd);
                if isfield(Maxs.(estrategia).(vel_field), sd_field)
                    seeds_vals = [seeds_vals, Maxs.(estrategia).(vel_field).(sd_field{1}).(var)];
                end
            end
    
            [max_per_speed, idx_max] = max(seeds_vals);
    
            % Si no existe el campo de velocidad, crearlo
            if ~isfield(Extremes.(estrategia), vel_field)
                Extremes.(estrategia).(vel_field) = struct();
            end
    
            % Guardar el máximo encontrado
            Extremes.(estrategia).(vel_field).(var) = max_per_speed;
    
            data_vec  = [data_vec, seeds_vals];
            group_vec = [group_vec, repmat(v, 1, length(seeds_vals))];
         end
      end

end

%% Leer archivo con valores máximos por semilla
archivo_resultados ='ATLAS_IEA3p4MW/MaxIndividual_por_Velocidad.csv'; % <-- cambiar por tu archivo

resultados = readtable(archivo_resultados);

%% === FILTRAR VARIABLES ESTRUCTURALES ===
vars_plot = {
    'RootMyb1_[kN-m]', ...
    'TwrBsMyt_[kN-m]', ...
    'LSSGagMya_[kN-m]', ...
    'RootMxb1_[kN-m]', ...
    'TwrBsMxt_[kN-m]', ...
    'RotTorq_[kN-m]', ...
    };


%% === CONFIGURAR FIGURA ===
nVars = length(vars_plot);
nRows = 2;
nCols = 3;
figure('Units','normalized','OuterPosition',[0 0 1 1]); 
set(gcf,'Color','w');
tiledlayout(nRows, nCols, 'Padding','compact', 'TileSpacing','compact');
vars_plot_names = {'RootMyb1', 'TwrBsMyt', 'LSSGagMya', 'RootMxb1', 'TwrBsMxt', 'RotTorq'};
varnames   = {'FlapWise','ForeAft','LSS Bending moment','EdgeWise','SideSide','LSS Torsional moment'};

%colores = lines(2); % un color por estrategia
%marcadores = {'s','d'}; % cuadrado y rombo

%% === GRAFICAR ===
for i = 1:nVars
    varName = vars_plot{i};
    varlabel = varnames{i};
    vars_plot_name = vars_plot_names{i};
    nexttile;

    subset = resultados(strcmp(resultados.Variable, varName), :);

    [~, idx] = sort(subset.Uref);
    subset = subset(idx, :);

    % Plot principal (línea base)
    plot(subset.Uref, subset.MaxIndividual_porVel, '-o', 'LineWidth', 1.5, ...
         'DisplayName','Max per speed (24 seeds)');
    ylabel('Extreme value','FontSize',fs,'Interpreter','latex');
    grid on;
    hold on;

    % === Añadir valores máximos por estrategia ===
    for e = 1:length(estrategias)
        estrategia = estrategias(e);
        max_vals = [];
        for v = 1:length(velocidades)
            vel_field = "V" + velocidades_names(v);
            if isfield(Extremes.(estrategia), vel_field) && ...
               isfield(Extremes.(estrategia).(vel_field), vars_plot_name)
                max_vals = [max_vals, Extremes.(estrategia).(vel_field).(vars_plot_name)];
            else
                max_vals = [max_vals, NaN];
            end
        end
        % plot(velocidades, max_vals, ...
        %      marcadores{e}, 'Color', colores(e,:), 'LineWidth', 1.5, ...
        %      'MarkerSize', 6, 'DisplayName', sprintf('Máx %s', estrategia));
        plot(velocidades, max_vals, ...
             'o', 'LineWidth', 1.5, ...
             'MarkerSize', 6, 'DisplayName', sprintf(estrategia));
    end

    title(strrep(varlabel,'_','\_'),'FontSize',fs,'Interpreter','latex');
    xlabel('$v$ [m/s]','FontSize',fs,'Interpreter','latex');
    legend('Location','best','FontSize',fs-5,'Interpreter','latex');
    set(gca,'FontSize',fs-3,'TickLabelInterpreter','latex')
    xlim([3.5 25.5])
end


exportgraphics(gcf,'ATLAS_maxs_vs_IS_maxs_all_speeds.png','Resolution',300);




% %% === CARGAR RESULTADOS (de tu script anterior) ===
% % Si ya corriste el script anterior, podés simplemente comentar esta línea.
% archivo_resultados ='ATLAS_IEA3p4MW/Results_summary_IEA_3p4_24seeds.csv'; % <-- cambiar por tu archivo
% 
% resultados = readtable(archivo_resultados);
% 
% %% === FILTRAR VARIABLES ESTRUCTURALES ===
% % Acá podés especificar qué variables querés graficar (máximo 6)
% vars_plot = {
%     'RootMyb1_[kN-m]', ...
%     'TwrBsMyt_[kN-m]', ...
%     'LSSGagMya_[kN-m]', ...
%     'RootMxb1_[kN-m]', ...
%     'TwrBsMxt_[kN-m]', ...
%     'RotTorq_[kN-m]', ...
%     };
% 
% % Filtrar solo las que existan en la tabla
% vars_disp = vars_plot(ismember(vars_plot, unique(resultados.Variable)));
% 
% %% === CONFIGURAR FIGURA ===
% nVars = numel(vars_disp);
% nRows = 2;
% nCols = 3;
% figure('Name','Cargas Estructurales por Bin de Velocidad','Position',[100 100 1200 600]);
% 
% tiledlayout(nRows, nCols, 'Padding','compact', 'TileSpacing','compact');
% varnames   = {'FlapWise','ForeAft','LSS Bending moment','EdgeWise','SideSide','LSS Torsional moment'};
% 
% %% === GRAFICAR ===
% for i = 1:nVars
%     varName = vars_disp{i};
%     varlabel = varnames{i};
%     nexttile;
% 
%     subset = resultados(strcmp(resultados.Variable, varName), :);
% 
%     % Ordenar por velocidad
%     [~, idx] = sort(subset.Uref);
%     subset = subset(idx, :);
% 
%     % Plot principal
%   %  yyaxis left
%     plot(subset.Uref, subset.SeedWeightedMax, '-o', 'LineWidth', 1.5, 'DisplayName','Max individual');
%     ylabel('Máx individual');
%     grid on;
%     hold on;
% 
%     % yyaxis right
%     % plot(subset.Uref, subset.SeedWeightedDEL, '--s', 'LineWidth', 1.3, 'DisplayName','Seed-weighted DEL');
%     % ylabel('DEL ponderado');
% 
%     title(strrep(varlabel,'_','\_'));
%     xlabel('Velocidad del viento [m/s]');
%     legend('Location','best');
% end
% 
% 
% 

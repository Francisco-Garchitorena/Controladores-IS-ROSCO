%% Script para graficar scatter de Max o DEL vs velocidad
%clear; clc;
clear; clc; close all;
load DELs_Max_means_per_seed
%% PLOT DELS PER SEED AND SEED WEIGHTED VS SPEED FOR ONE STRATEGY
% === Configuración ===
tipo = "DEL";   % "DEL" o "Max"
estrategia = "Wang"; % estrategia a graficar

% Variables que querés graficar
variables  = {'RootMyb1','RootMxb1','TwrBsMyt','TwrBsMxt','LSSGagMya','LSSGagMza','RotTorq'};
varnames   = {'FlapWise','ForeAft','LSS Moment y-axis','EdgeWise','SideSide','LSS Moment z-axis','LSS Moment x-axis'};

% Cargar resultados (ajusta si ya están en workspace)
%load resultados_indicadores.mat DELs Maxs DELs_ponderados_seed Maxs_ponderados_seed

% Extraer velocidades disponibles
vels = fieldnames(DELs.(estrategia));  % ej. {'V7_5','V8','V8_5','V9','V9_5'}

figure;  fs = 14;
tiledlayout(2,3,'TileSpacing','compact');
for vvar = 1:length(variables)
    var = variables{vvar};
    varname = varnames{vvar};
    
    nexttile; hold on; grid on;
    xlim([7 10]);
    set(gca, 'TickLabelInterpreter','latex','Fontsize',fs);

    for v = 1:length(vels)
        vel_field = vels{v};
        
        % === Semillas ===
        if tipo=="DEL"
            seeds = fieldnames(DELs.(estrategia).(vel_field));
            vals = [];
            for s = 1:length(seeds)
                sd_field = seeds{s};
                if isfield(DELs.(estrategia).(vel_field).(sd_field), var)
                    vals(end+1) = DELs.(estrategia).(vel_field).(sd_field).(var); 
                end
            end
        else
            seeds = fieldnames(Maxs.(estrategia).(vel_field));
            vals = [];
            for s = 1:length(seeds)
                sd_field = seeds{s};
                if isfield(Maxs.(estrategia).(vel_field).(sd_field), var)
                    vals(end+1) = Maxs.(estrategia).(vel_field).(sd_field).(var); 
                end
            end
        end
        
        % Vel numérico (quita la "V")
        velnum = str2double(strrep(vel_field,"V","").replace("_","."));
        
        % Scatter de semillas
        scatter(velnum*ones(size(vals)), vals, 30, 'o','LineWidth', 1.5, ...
                'MarkerEdgeColor',[0.5 0.5 0.5], 'MarkerFaceColor','none');
        
        % === Valor ponderado ===
        if tipo=="DEL"
            if isfield(DELs_ponderados_seed.(estrategia).(vel_field), var)
                val_p = DELs_ponderados_seed.(estrategia).(vel_field).(var);
                plot(velnum, val_p, 'ro', 'LineWidth', 1.5, 'MarkerFaceColor','r', 'MarkerSize',7);
            end
        else
            if isfield(Maxs_ponderados_seed.(estrategia).(vel_field), var)
                val_p = Maxs_ponderados_seed.(estrategia).(vel_field).(var);
                plot(velnum, val_p, 'ro', 'LineWidth', 1.5, 'MarkerFaceColor','r', 'MarkerSize',7);
            end
        end
    end
    
    xlabel('Velocidad [m/s]','Fontsize',fs,'Interpreter','latex');
    ylabel(sprintf('%s (%s)', tipo, varname),'Fontsize',fs,'Interpreter','latex');
    title(varname,'Fontsize',14,'Interpreter','latex');
end

legend({'Semillas','Ponderado'},'Fontsize',fs,'Location','best','Interpreter','latex');
sgtitle(sprintf('DELs per seed and weighted vs speed for %s IC strategy', estrategia),'Interpreter','latex');

%% Plot comparativo de DELs ponderados por semilla (Norm_op vs otras estrategias)
% === Configuración ===
estrategia_ref = "Norm_op";   % referencia
estrategias    = ["Wang", "Tarnowski"];   % estrategias a comparar
estrategia_names = ["Normal operation", "Torque limit strategy", "StepWise strategy"];

variables  = {'RootMyb1','TwrBsMyt','LSSGagMya','RootMxb1','TwrBsMxt','LSSGagMza'};
varnames   = {'FlapWise','ForeAft','LSS Moment y-axis','EdgeWise','SideSide','LSS Moment z-axis'};

% === Cargar resultados (ajusta si ya están en workspace) ===

% Velocidades disponibles (ej. {'V7_5','V8','V8_5','V9','V9_5'})
vels = fieldnames(DELs_ponderados_seed.(estrategia_ref));

% === Plot ===
figure('Units','normalized','OuterPosition',[0 0 1 1]); 
set(gcf,'Color','w'); fs = 14; 
tiledlayout(2,3,'TileSpacing','compact');

for vvar = 1:length(variables)
    var = variables{vvar};
    varname = varnames{vvar};
    
    % Preasignación
    vals_ref = nan(1,length(vels));
    vals_cmp = nan(length(estrategias), length(vels));
    velnums  = nan(1,length(vels));
    
    % Recorremos velocidades
    for v = 1:length(vels)
        vel_field = vels{v};
        velnum = str2double(strrep(vel_field,"V","").replace("_","."));
        velnums(v) = velnum;
        
        % --- Normal operation (referencia)
        if isfield(DELs_ponderados_seed.(estrategia_ref).(vel_field), var)
            vals_ref(v) = DELs_ponderados_seed.(estrategia_ref).(vel_field).(var);
        end
        
        % --- Estrategias comparadas
        for e = 1:length(estrategias)
            estrategia_cmp = char(estrategias(e));
            if isfield(DELs_ponderados_seed.(estrategia_cmp).(vel_field), var)
                vals_cmp(e,v) = DELs_ponderados_seed.(estrategia_cmp).(vel_field).(var);
            end
        end
    end
    
    % --- Plot por variable ---
    nexttile; hold on; grid on;
    plot(velnums, vals_ref,'-o','LineWidth',1.5,'DisplayName',estrategia_names(1));
    i=2;
    for e = 1:length(estrategias)
        e
        plot(velnums, vals_cmp(e,:),'-s','LineWidth',1.5,'DisplayName',estrategia_names(i));
        i=i+1;
    end
    xlim([7.35 9.65]);
    xlabel('Speed [m/s]','Fontsize',fs,'Interpreter','latex');
    ylabel('Seed-weighted DEL [kNm]','Fontsize',fs,'Interpreter','latex');
    title(varname,'Fontsize',fs+2,'Interpreter','latex');
    set(gca,'TickLabelInterpreter','latex','Fontsize',fs);
end

legend('Location','best','Fontsize',fs,'Interpreter','latex');
sgtitle("Seed-weighted DELs: Normal operation vs Torque-limit vs StepWise",'Fontsize', 16,'Interpreter','latex');

exportgraphics(gcf,'Imagenes/Torque_2026/DEL_ponderado_comp_estrategias.png','Resolution',300);

%% DELS COMP NORMALIZADO
estrategia_ref = "Norm_op";   % referencia
estrategias    = ["Wang", "Tarnowski"];   % estrategias a comparar
estrategia_names = ["Normal operation", "Torque limit strategy", "StepWise strategy"];
variables = {'RootMyb1','TwrBsMyt','LSSGagMya','RootMxb1','TwrBsMxt','LSSGagMza'};
varnames  = {'FlapWise','ForeAft','LSSGagMya','EdgeWise','SideSide','LSSGagMza'};

% === Cargar resultados ===
vels = fieldnames(DELs_ponderados_seed.(estrategia_ref));  % velocidades disponibles

% === Encontrar índice de referencia para 8 m/s ===
velnums_tmp = str2double(strrep(vels,"V","").replace("_","."));
[~, idx_ref8] = min(abs(velnums_tmp - 8.5));

% === Plot ===
figure('Units','normalized','OuterPosition',[0 0 1 1]);
set(gcf,'Color','w'); 
fs = 20;
tiledlayout(2,3,'TileSpacing','compact');

for vvar = 1:length(variables)
    var = variables{vvar};
    varname = varnames{vvar};
    
    vals_ref = nan(1,length(vels));
    vals_cmp = nan(length(estrategias), length(vels));
    velnums  = nan(1,length(vels));
    
    % Recorremos velocidades
    for v = 1:length(vels)
        vel_field = vels{v};
        velnum = str2double(strrep(vel_field,"V","").replace("_","."));
        velnums(v) = velnum;
        
        % --- Normal operation (referencia) ---
        if isfield(DELs_ponderados_seed.(estrategia_ref).(vel_field), var)
            vals_ref(v) = DELs_ponderados_seed.(estrategia_ref).(vel_field).(var);
        end
        
        % --- Estrategias comparadas ---
        for e = 1:length(estrategias)
            estrategia_cmp = char(estrategias(e));
            if isfield(DELs_ponderados_seed.(estrategia_cmp).(vel_field), var)
                vals_cmp(e,v) = DELs_ponderados_seed.(estrategia_cmp).(vel_field).(var);
            end
        end
    end
    
    % --- Normalización respecto a DEL de operación normal a 8 m/s ---
    ref8 = vals_ref(idx_ref8);
    vals_ref_norm = vals_ref / ref8;
    vals_cmp_norm = vals_cmp / ref8;
    % vals_ref_norm = (vals_ref -ref8)*100/ ref8;
    % vals_cmp_norm = (vals_cmp-ref8) *100/ ref8;
    % --- Plot por variable ---
    nexttile; hold on; grid on;
    plot(velnums, vals_ref_norm,'-o','LineWidth',1.5,'DisplayName',estrategia_names(1));
    
    i = 2;
    for e = 1:length(estrategias)
        plot(velnums, vals_cmp_norm(e,:),'-s','LineWidth',1.5,'DisplayName',estrategia_names(i));
        i = i + 1;
    end
    
    xlim([7.35 9.65]);
    xlabel('$v$ [m/s]','Fontsize',fs,'Interpreter','latex');
    ylabel('Normalized seed-weighted DEL','Fontsize',fs,'Interpreter','latex');
    title(varname,'Fontsize',fs,'Interpreter','latex');
    set(gca,'TickLabelInterpreter','latex','Fontsize',fs);
end

legend('Location','best','Fontsize',fs-2,'Interpreter','latex');
sgtitle("Normalized seed-weighted DELs: Normal operation vs Torque-limit vs StepWise",'Fontsize', fs+2,'Interpreter','latex');

exportgraphics(gcf,'Imagenes/Torque_2026/DEL_ponderado_comp_estrategias_norm.png','Resolution',300);

%% Plot comparativo de MAX ponderados por semilla (Norm_op vs otras estrategias)

% === Configuración ===
estrategia_ref = "Norm_op";   % referencia
estrategias    = ["Wang", "Tarnowski"];   % estrategias a comparar
estrategia_names = ["Normal operation", "Torque limit strategy", "StepWise strategy"];


% === Cargar resultados (ajusta si ya están en workspace) ===

% Velocidades disponibles (ej. {'V7_5','V8','V8_5','V9','V9_5'})
vels = fieldnames(Maxs_ponderados_seed.(estrategia_ref));

% === Plot ===
figure('Units','normalized','OuterPosition',[0 0 1 1]); 
set(gcf,'Color','w');fs = 14; 
tiledlayout(2,3,'TileSpacing','compact');

for vvar = 1:length(variables)
    var = variables{vvar};
    varname = varnames{vvar};
    
    % Preasignación
    vals_ref = nan(1,length(vels));
    vals_cmp = nan(length(estrategias), length(vels));
    velnums  = nan(1,length(vels));
    
    % Recorremos velocidades
    for v = 1:length(vels)
        vel_field = vels{v};
        velnum = str2double(strrep(vel_field,"V","").replace("_","."));
        velnums(v) = velnum;
        
        % --- Normal operation (referencia)
        if isfield(Maxs_ponderados_seed.(estrategia_ref).(vel_field), var)
            vals_ref(v) = Maxs_ponderados_seed.(estrategia_ref).(vel_field).(var);
        end
        
        % --- Estrategias comparadas
        for e = 1:length(estrategias)
            estrategia_cmp = char(estrategias(e));
            if isfield(Maxs_ponderados_seed.(estrategia_cmp).(vel_field), var)
                vals_cmp(e,v) = Maxs_ponderados_seed.(estrategia_cmp).(vel_field).(var);
            end
        end
    end
    
    % --- Plot por variable ---
    nexttile; hold on; grid on;
    plot(velnums, vals_ref,'-o','LineWidth',1.5,'DisplayName',estrategia_names(1));
    i=2;
    for e = 1:length(estrategias)
        plot(velnums, vals_cmp(e,:),'-s','LineWidth',1.5,'DisplayName',estrategia_names(i));
        i=i+1;
    end
    xlim([7.35 9.65])
    xlabel('Speed [m/s]','Fontsize',fs,'Interpreter','latex');
    ylabel('Seeds maximum value [kNm]','Fontsize',fs,'Interpreter','latex');
    title(varname,'Fontsize',fs+2,'Interpreter','latex');
    set(gca,'TickLabelInterpreter','latex','Fontsize',fs);
end

legend('Location','best','Fontsize',fs,'Interpreter','latex');
sgtitle("Seeds maximum value: Normal operation vs Torque-limit vs StepWise",'Fontsize', 16,'Interpreter','latex');
exportgraphics(gcf,'Imagenes/Torque_2026/Max_ponderado_comp_estrategias.png','Resolution',300);


%% Plot comparativo de MAX ponderados por semilla + máximos de cada semilla 

% === Configuración ===
estrategia_ref = "Norm_op";   % referencia
estrategias    = ["Wang", "Tarnowski"];   % estrategias a comparar
estrategia_names = ["Normal operation", "Torque limit strategy", "StepWise strategy"];

% Velocidades disponibles (ej. {'V7_5','V8','V8_5','V9','V9_5'})
vels = fieldnames(Maxs_ponderados_seed.(estrategia_ref));

% Colores automáticos por estrategia
colors = lines(1 + length(estrategias)); % 1 referencia + comparadas

% === Plot ===
figure('Units','normalized','OuterPosition',[0 0 1 1]); 
set(gcf,'Color','w'); fs = 20; 
tiledlayout(2,3,'TileSpacing','compact');

for vvar = 1:length(variables)
    var = variables{vvar};
    varname = varnames{vvar};
    
    % Preasignación
    vals_ref = nan(1,length(vels));
    vals_cmp = nan(length(estrategias), length(vels));
    velnums  = nan(1,length(vels));
    
    % Guardamos máximos individuales de semillas
    seeds_ref = cell(1,length(vels));
    seeds_cmp = cell(length(estrategias), length(vels));
    
    % Recorremos velocidades
    for v = 1:length(vels)
        vel_field = vels{v};
        velnum = str2double(strrep(vel_field,"V","").replace("_",".")); 
        velnums(v) = velnum;
        
        % --- Normal operation (referencia) ---
        if isfield(Maxs_ponderados_seed.(estrategia_ref).(vel_field), var)
            vals_ref(v) = Maxs_ponderados_seed.(estrategia_ref).(vel_field).(var);
        end
        
        % Máximos de cada semilla
        seed_names = fieldnames(Maxs.(estrategia_ref).(vel_field));
        seeds_ref{v} = nan(1,length(seed_names));
        for s = 1:length(seed_names)
            seed = seed_names{s};
            if isfield(Maxs.(estrategia_ref).(vel_field).(seed), var)
                seeds_ref{v}(s) = Maxs.(estrategia_ref).(vel_field).(seed).(var);
            end
        end
        
        % --- Estrategias comparadas ---
        for e = 1:length(estrategias)
            estrategia_cmp = char(estrategias(e));
            if isfield(Maxs_ponderados_seed.(estrategia_cmp).(vel_field), var)
                vals_cmp(e,v) = Maxs_ponderados_seed.(estrategia_cmp).(vel_field).(var);
            end
            
            % Máximos de cada semilla
            seed_names_cmp = fieldnames(Maxs.(estrategia_cmp).(vel_field));
            seeds_cmp{e,v} = nan(1,length(seed_names_cmp));
            for s = 1:length(seed_names_cmp)
                seed = seed_names_cmp{s};
                if isfield(Maxs.(estrategia_cmp).(vel_field).(seed), var)
                    seeds_cmp{e,v}(s) = Maxs.(estrategia_cmp).(vel_field).(seed).(var);
                end
            end
        end
    end
    
    % --- Plot por variable ---
    nexttile; hold on; grid on;
    
    % --- Referencia ---
    plot(velnums, vals_ref,'-o','LineWidth',1.5,'Color',colors(1,:),'DisplayName',estrategia_names(1));
    % Puntos de semillas (una sola entrada en la leyenda)
    scatter_flag = true;
    for v = 1:length(vels)
        if scatter_flag
            scatter(repmat(velnums(v),1,length(seeds_ref{v})), seeds_ref{v}, 50, colors(1,:), 'filled','MarkerFaceAlpha',0.4,'DisplayName','seed values');
            scatter_flag = false; %sirve para el nombre en la leyend
        else
            scatter(repmat(velnums(v),1,length(seeds_ref{v})), seeds_ref{v}, 50, colors(1,:), 'filled','MarkerFaceAlpha',0.4,'HandleVisibility','off');
        end
    end
    
    % --- Estrategias comparadas ---
    for e = 1:length(estrategias)
        plot(velnums, vals_cmp(e,:),'-s','LineWidth',1.5,'Color',colors(e+1,:),'DisplayName',estrategia_names(e+1));
        
        scatter_flag = true;
        for v = 1:length(vels)
            if scatter_flag
                scatter(repmat(velnums(v),1,length(seeds_cmp{e,v})), seeds_cmp{e,v}, 50, colors(e+1,:), 'filled','MarkerFaceAlpha',0.4,'DisplayName','seed values');
                scatter_flag = false;
            else
                scatter(repmat(velnums(v),1,length(seeds_cmp{e,v})), seeds_cmp{e,v}, 50, colors(e+1,:), 'filled','MarkerFaceAlpha',0.4,'HandleVisibility','off');
            end
        end
    end
    
    xlim([7.35 9.65])
    xlabel('$v$ [m/s]','Fontsize',fs,'Interpreter','latex');
    ylabel('Seeds maximum value [kNm]','Fontsize',fs,'Interpreter','latex');
    title(varname,'Fontsize',fs,'Interpreter','latex');
    set(gca,'TickLabelInterpreter','latex','Fontsize',fs);
end

legend('Location','best','Fontsize',fs-4,'Interpreter','latex');
sgtitle("Seeds maximum value: Normal operation vs Torque-limit vs StepWise",'Fontsize', fs+2,'Interpreter','latex');
exportgraphics(gcf,'Imagenes/Torque_2026/Max_ponderado_comp_estrategias_con_scatter_seeds.png','Resolution',300);


%% --- Boxplots por variable y estrategia ---
clc;
figure('Units','normalized','OuterPosition',[0 0 1 1]); 
set(gcf,'Color','w'); fs = 20; 

estrategias      = [ "Norm_op","Wang", "Tarnowski"];   % estrategias a comparar
estrategia_names = ["Normal operation", "Torque limit strategy", "StepWise strategy"];
nVar = length(variables);
t = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
colors = lines(length(estrategias)); % colores distintos para estrategias
offset = 0.2; % desplazamiento para separar estrategias
fontsize = 14; % tamaño de letra configurable
linewidth = 1.5; % grosor de líneas de boxplot
velnums_tmp = str2double(strrep(velocidades_names, "_", "."));

for vvar = 1:nVar
    var      = variables{vvar};
    varname  = varnames{vvar};
    
    subplot(2,3,vvar); hold on; grid on;
    title(varname,'FontWeight','bold','Interpreter','latex','FontSize',fontsize);
    xlabel('Wind speed [m/s]','Interpreter','latex','FontSize',fontsize);
    ylabel('Max value','Interpreter','latex','FontSize',fontsize);

    ylim_min = inf;
    ylim_max = -inf;

    for e = 1:length(estrategias)
        estrategia = estrategias{e};
        data_vec = [];
        group_vec = [];
        
        for v = 1:length(velocidades)
            vel_field = "V" + velocidades_names(v);
            seeds_vals = [];

            % Recuperar valores máximos por semilla
            for sd = 1:length(seeds)
                sd_field = seeds(sd);
                if isfield(Maxs.(estrategia).(vel_field), sd_field)
                    seeds_vals = [seeds_vals, Maxs.(estrategia).(vel_field).(sd_field{1}).(var)];
                end
            end
            
            % Concatenar para boxplot
            data_vec  = [data_vec, seeds_vals];
            group_vec = [group_vec, repmat(v,1,length(seeds_vals))];
            
            % Para ajustar ylim
            if ~isempty(seeds_vals)
                ylim_min = min([ylim_min, min(seeds_vals)]);
                ylim_max = max([ylim_max, max(seeds_vals)]);
            end
        end

        % Ajustar posiciones para separar estrategias
        positions = unique(group_vec) + (e-2)*offset;

        % Boxplot
        h = boxplot(data_vec, group_vec, 'Positions', positions, 'Colors', colors(e,:), ...
            'Widths',0.15, 'Symbol','-');
        
        % Aumentar linewidth de todas las líneas del boxplot
        set(h, 'LineWidth', linewidth);
    end
    
    set(gca,'XTick',1:length(velocidades),'XTickLabel',velnums_tmp, 'FontSize', fontsize,'TickLabelInterpreter','latex');
    ylim([ylim_min*0.95, ylim_max*1.05]); % dejar margen visual
end

annotation('textbox',[0 0.95 1 0.05], ...
           'String',"Seeds maximum value: Normal operation vs Torque-limit str. vs StepWise str.", ...
           'FontSize',fontsize+2,'Interpreter','latex','HorizontalAlignment','center', ...
           'VerticalAlignment','middle','EdgeColor','none','FontWeight','bold');

hold on
for e = 1:length(estrategias)
    plot(nan, nan, 'Color', colors(e,:), 'LineWidth', 2); % líneas invisibles para la leyenda
end
legend(estrategia_names,'Location','best','Fontsize',fontsize-1,'Interpreter','latex');
exportgraphics(gcf,'Imagenes/Torque_2026/Boxplot_Max_ponderado_comp_estrategias_con_boxplot.png','Resolution',300);

%% === Comparación de Energías inyectadas ===  TODAS
figure;  clc;
dur_labels = cellstr("Dur" + string(duraciones) + "s");
n_dur = numel(duraciones);
n_estr = numel(estrategias);

for v = 1:length(velocidades)
    vel_field = "V" + velocidades_names(v);

    % Matriz para guardar energías promedio: [estrategia x duración]
    Ener_prom = nan(n_estr, n_dur);

    for e = 1:n_estr
        estrategia = estrategias{e};
        for d = 1:n_dur
            dur_field = "Dur" + string(duraciones(d)) + "s";

            % Recolectar todas las semillas
            vals = [];
            for sd = 1:length(seeds)
                sd_field = seeds(sd);
                if isfield(Energias.(estrategia).(vel_field).(sd_field{1}), dur_field{1})
                    vals(end+1) = Energias.(estrategia).(vel_field).(sd_field{1}).(dur_field{1});
                end
            end

            if ~isempty(vals)
                Ener_prom(e,d) = mean(vals);
            end
        end
    end

    % === Gráfico de barras para esta velocidad ===
    subplot(ceil(length(velocidades)/2), 2, v);
    bar(Ener_prom);
    title(sprintf('Energía inyectada - V = %.1f m/s', velocidades(v)));
    ylabel('Energía [kWh]');
    set(gca, 'XTickLabel', estrategias);
    legend(dur_labels, 'Location','northwest');
    grid on;
end

%% === Comparación de Energías inyectadas (en % respecto a Norm_op) ===
figure; 
dur_labels = cellstr(string(duraciones) + "s Window");
n_dur = numel(duraciones);
estrategias_SI = estrategias; % solo las estrategias con inercia
n_estr = numel(estrategias_SI);

for v = 1:length(velocidades)
    vel_field = "V" + velocidades_names(v);

    % --- Calcular promedio de Norm_op como referencia ---
    ref_vals = nan(1,n_dur);
    for d = 1:n_dur
        dur_field = "Dur" + string(duraciones(d)) + "s";
        vals_ref = [];
        for sd = 1:length(seeds)
            sd_field = seeds(sd);
            if isfield(Energias.("Norm_op").(vel_field).(sd_field{1}), dur_field{1})
                vals_ref(end+1) = Energias.("Norm_op").(vel_field).(sd_field{1}).(dur_field{1});
            end
        end
        if ~isempty(vals_ref)
            ref_vals(d) = mean(vals_ref);
        end
    end

    % --- Matriz de energías promedio para las demás estrategias ---
    Ener_prom = nan(n_estr, n_dur);
    for e = 1:n_estr
        estrategia = estrategias_SI{e};
        for d = 1:n_dur
            dur_field = "Dur" + string(duraciones(d)) + "s";
            vals = [];
            for sd = 1:length(seeds)
                sd_field = seeds(sd);
                if isfield(Energias.(estrategia).(vel_field).(sd_field{1}), dur_field{1})
                    vals(end+1) = Energias.(estrategia).(vel_field).(sd_field{1}).(dur_field{1});
                end
            end
            if ~isempty(vals)
                Ener_prom(e,d) = mean(vals);
            end
        end
    end

    % --- Calcular % respecto a Norm_op ---
    Ener_rel = (Ener_prom - ref_vals) ./ ref_vals * 100;

    % === Gráfico de barras para esta velocidad ===
    subplot(ceil(length(velocidades)/2), 2, v);
    bar(Ener_rel);
    fs = 14;
    title(sprintf('Injected energy - V = %.1f m/s', velocidades(v)),'FontSize',fs+2, 'Interpreter','latex');
    ylabel('$\%$ increase','FontSize',fs,'Interpreter','latex');
    set(gca, 'XTickLabel', estrategias_SI,'FontSize',fs);
    grid on;
    yline(0,'--k'); % línea base

    if  v ==1
            legend(dur_labels, 'Location','northwest','FontSize',fs-1);

    end
end


%% === Configuración ===

duracion_user = 5; % segundos de la ventana (puede ser 5 o 10, por ejemplo)
dur_field = "Dur" + string(duracion_user) + "s";

estrategias_SI = estrategias; % estrategias con inercia (sin Norm_op)
n_estr = numel(estrategias_SI);

n_vel = length(velocidades);

Ener_rel_all = nan(n_vel, n_estr);

for v = 1:n_vel
    vel_field = "V" + velocidades_names(v);

    % --- Referencia Norm_op ---
    vals_ref = [];
    for sd = 1:length(seeds)
        sd_field = seeds(sd);
        if isfield(Energias.("Norm_op").(vel_field).(sd_field{1}), dur_field{1})
            vals_ref(end+1) = Energias.("Norm_op").(vel_field).(sd_field{1}).(dur_field{1});
        end
    end
    if isempty(vals_ref)
        continue
    end
    ref_val = mean(vals_ref);

    % --- Estrategias comparadas ---
    for e = 1:n_estr
        estrategia = estrategias_SI{e};
        vals = [];
        for sd = 1:length(seeds)
            sd_field = seeds(sd);
            if isfield(Energias.(estrategia).(vel_field).(sd_field{1}), dur_field{1})
                vals(end+1) = Energias.(estrategia).(vel_field).(sd_field{1}).(dur_field{1});
            end
        end
        if ~isempty(vals)
            Ener_rel_all(v,e) = (mean(vals) - ref_val) / ref_val * 100; % relativo a Norm_op
        end
    end
end

figure('Units','normalized','OuterPosition',[0 0 0.5 0.5]); % ventana cuadrada
axis square   % fuerza a que los ejes tengan la misma escala
set(gcf,'Color','w');

fs = 20;
hb = bar(velocidades, Ener_rel_all, 'grouped');
ylabel('Relative injected energy [\%]','FontSize',fs,'Interpreter','latex');
xlabel('$v$ [m/s]','FontSize',fs,'Interpreter','latex');
title(sprintf('Injected energy relative to Norm\\_op (%ds window)', duracion_user), ...
      'FontSize',fs+2,'Interpreter','latex');
set(gca,'TickLabelInterpreter','latex','FontSize',fs);
legend(estrategias_SI,'Location','northwest','FontSize',fs-4,'Interpreter','latex');
grid on;

%exportgraphics(gcf,'Imagenes/Torque_2026/Energia_inyectada_5s_media_seed.png','Resolution',300);

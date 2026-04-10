%% === Script combinado: DELs y Boxplots de máximos (separados en 2 figuras) ===
clear; clc; %close all;

% === Cargar resultados ===
%load DELs_Max_means_per_seed_24_seeds
%load DELs_Max_means_per_seed_24_seeds_with_komega2_controller.mat
%load NREL5MW_DELs_Max_means_per_seed_24_seeds_with_komega2_controller_journal.mat;
load IEA3p4MW_DELs_Max_means_per_seed_compare_DeltaTover_GMFCstrat.mat;
name = '24 seeds';

% === Definir estrategias y variables ===
estrategia_ref   = "Norm_op";                 % referencia
estrategias      = ["GMFC_5","GMFC_10"];      % estrategias comparadas
estrategias_all  = ["Norm_op","GMFC_5","GMFC_10"];
estrategia_names = ["NO","SW","TL"];

variables = {'RootMyb1','TwrBsMxt','RotTorq'};
varnames  = {'FlapWise','SideSide','LSS torsional moment'};
fs = 24;

% === Colores ===
colors = lines(length(estrategias_all));

% === Velocidades ===
vels = fieldnames(DELs_ponderados_seed.(estrategia_ref));
velnums_tmp = str2double(strrep(vels,"V","").replace("_","."));
[~, idx_ref8] = min(abs(velnums_tmp - 8.5));

%% ---------------- Figura 1: DELs normalizados ----------------
figure('Units','normalized','OuterPosition',[0 0 1 0.5]); % media página
set(gcf,'Color','w');
t1 = tiledlayout(1,3,'TileSpacing','compact','Padding','compact');

for vvar = 1:length(variables)
    nexttile(t1);
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
        
        % Normal operation
        if isfield(DELs_ponderados_seed.(estrategia_ref).(vel_field), var)
            vals_ref(v) = DELs_ponderados_seed.(estrategia_ref).(vel_field).(var);
        end
        
        % Estrategias comparadas
        for e = 1:length(estrategias)
            estrategia_cmp = char(estrategias(e));
            if isfield(DELs_ponderados_seed.(estrategia_cmp).(vel_field), var)
                vals_cmp(e,v) = DELs_ponderados_seed.(estrategia_cmp).(vel_field).(var);
            end
        end
    end
    
    % Normalización por valor a 8.5 m/s
    ref8 = vals_ref(idx_ref8);
    vals_ref_norm = vals_ref / ref8;
    vals_cmp_norm = vals_cmp / ref8;
    
    hold on; grid on; box on;
    plot(velnums, vals_ref_norm,'-o','LineWidth',1.5,'Color',colors(1,:), ...
        'DisplayName',estrategia_names(1));
    for e = 1:length(estrategias)
        plot(velnums, vals_cmp_norm(e,:),'-s','LineWidth',1.5,'Color',colors(e+1,:), ...
            'DisplayName',estrategia_names(e+1));
    end
    
    xlim([7.35 9.65]);
    xlabel('$v$ [m/s]','FontSize',fs,'Interpreter','latex');
    ylabel('$\mathrm{DEL}_{\mathrm{norm}}$ [-]','FontSize',fs,'Interpreter','latex');
    title(varname,'FontSize',fs,'Interpreter','latex');
    set(gca,'TickLabelInterpreter','latex','FontSize',fs);
    
    if vvar==3
        legend('Location','best','FontSize',fs-2,'Interpreter','latex');
    end
end
%exportgraphics(gcf,'Imagenes/Torque_2026/24_semillas/DELs_selected.png','Resolution',300);

%% ---------------- Figura 2: Boxplots de máximos ----------------
offset = 0.26; % separación entre estrategias
linewidth = 1.5;

figure('Units','normalized','OuterPosition',[0 0 1 0.5]); % media página
set(gcf,'Color','w');
t2 = tiledlayout(1,3,'TileSpacing','compact','Padding','compact');

for vvar = 1:length(variables)
    nexttile(t2);
    var = variables{vvar};
    varname = varnames{vvar};
    
    hold on; grid on; box on;
    title(varname,'FontWeight','bold','Interpreter','latex','FontSize',fs);
    xlabel('$v$ [m/s]','Interpreter','latex','FontSize',fs);
    ylabel('Extreme values [kNm]','Interpreter','latex','FontSize',fs);
    
    ylim_min = inf; ylim_max = -inf;
    
    for e = 1:length(estrategias_all)
        estrategia = estrategias_all(e);
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
            
            data_vec  = [data_vec, seeds_vals];
            group_vec = [group_vec, repmat(v,1,length(seeds_vals))];
            
            if ~isempty(seeds_vals)
                ylim_min = min([ylim_min, min(seeds_vals)]);
                ylim_max = max([ylim_max, max(seeds_vals)]);
            end
        end
        
        positions = unique(group_vec) + (e-2)*offset;
        
        % --- Boxplot
        h = boxplot(data_vec, group_vec, ...
            'Positions', positions, ...
            'Whisker', Inf, ...
            'Colors', colors(e,:), ...
            'Widths', 0.23, ...
            'Symbol', 'k+');
        
        % --- Rellenar cajas ---
        boxes = findobj(h, 'Tag', 'Box');
        for j = 1:length(boxes)
            patch(get(boxes(j),'XData'), get(boxes(j),'YData'), colors(e,:), ...
                'FaceAlpha', 1, 'EdgeColor', 'k');
        end
        
        % --- Mediana negra ---
        meds = findobj(h, 'Tag', 'Median');
        for j = 1:length(meds)
            xMed = get(meds(j),'XData');
            yMed = get(meds(j),'YData');
            plot(xMed, yMed, 'k-', 'LineWidth', 1.5);
        end
        
        set(h,'LineWidth',linewidth);
    end
    
    set(gca,'XTick',1:length(velocidades),'XTickLabel',velnums_tmp, ...
        'FontSize',fs,'TickLabelInterpreter','latex');
    ylim([ylim_min, ylim_max]);
end

%exportgraphics(gcf,'Imagenes/Torque_2026/24_semillas/Extremes_selected.png','Resolution',300);


%% BOXplots comparando dos archivos .mat en la misma figura
clear; clc; close all;

files = { ...
 'DELs_Max_means_per_seed_24_seeds_with_komega2_controller.mat', ...
 'NREL5MW_DELs_Max_means_per_seed_24_seeds_with_komega2_controller_HIGHER_SPEEDS.mat'};

file_labels = {'Case A','Case B'};   % nombres para leyenda

%% === Configuración general ===
variables = {'RootMyb1','TwrBsMyt','LSSGagMya','RootMxb1','TwrBsMxt','RotTorq'};
varnames  = {'FlapWise','ForeAft','LSS Bending moment','EdgeWise','SideSide','LSS Torsional moment'};

estrategias       = ["Norm_op","Tarnowski","Wang"];
estrategia_names = ["NO","SW","TL"];

fs = 20;
offset = 0.26;      % separación entre estrategias
file_offset = 0.09; % pequeña separación entre archivos dentro de misma estrategia

%% === Cargar ambos archivos en memoria ===
DATA = cell(1,2);
for f = 1:2
    load(files{f});
    DATA{f}.Maxs = Maxs;
    DATA{f}.velocidades = velocidades;
    DATA{f}.velocidades_names = velocidades_names;
    DATA{f}.seeds = seeds;
end

velnums_tmp = str2double(strrep(DATA{1}.velocidades_names,"_","."));

%% === COLORES ===
colors = lines(length(estrategias));   % mismos colores que tu script original
alpha_file = [1.0, 0.4];               % archivo 1 sólido, archivo 2 transparente

%% === FIGURA ===
figure('Units','normalized','OuterPosition',[0 0 1 1]);
set(gcf,'Color','w');
t = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

%% === LOOP VARIABLES ===
for vvar = 1:length(variables)
    nexttile;
    var = variables{vvar};
    varname = varnames{vvar};
    
    hold on; grid on; box on;
    title(varname,'Interpreter','latex','FontSize',fs);
    xlabel('$v$ [m/s]','Interpreter','latex','FontSize',fs);
    ylabel('Extreme value','Interpreter','latex','FontSize',fs);

    ylim_min = inf;
    ylim_max = -inf;

    %% === LOOP ESTRATEGIAS ===
    for e = 1:length(estrategias)
        estrategia = char(estrategias(e));   % <- IMPORTANTE: string → char
        
        %% === LOOP ARCHIVOS ===
        for f = 1:2
            
            data_vec  = [];
            group_vec = [];
            
            for v = 1:length(DATA{f}.velocidades)
                vel_field = "V" + DATA{f}.velocidades_names(v);
                seeds_vals = [];
                
                for sd = 1:length(DATA{f}.seeds)
                    sd_field = DATA{f}.seeds(sd);
                    if isfield(DATA{f}.Maxs.(estrategia).(vel_field), sd_field)
                        seeds_vals = [seeds_vals, ...
                            DATA{f}.Maxs.(estrategia).(vel_field).(sd_field{1}).(var)];
                    end
                end
                
                data_vec  = [data_vec, seeds_vals];
                group_vec = [group_vec, repmat(v,1,length(seeds_vals))];
                
                if ~isempty(seeds_vals)
                    ylim_min = min([ylim_min min(seeds_vals)]);
                    ylim_max = max([ylim_max max(seeds_vals)]);
                end
            end
            
            % === posiciones de boxplots ===
            base_pos = unique(group_vec);
            pos = base_pos + (e-2)*offset + (f-1.5)*file_offset;
            
            % === boxplot ===
            h = boxplot(data_vec, group_vec, ...
                'Positions', pos, ...
                'Whisker', Inf, ...
                'Colors', colors(e,:), ...
                'Widths', 0.23, ...
                'Symbol','k+');
            
            % === rellenar cajas con transparencia ===
            boxes = findobj(h,'Tag','Box');
            for j=1:length(boxes)
                patch(get(boxes(j),'XData'), get(boxes(j),'YData'), ...
                      colors(e,:), ...
                      'FaceAlpha', alpha_file(f), ...
                      'EdgeColor','k');
            end
            
            % === mediana negra visible ===
            meds = findobj(h,'Tag','Median');
            for j=1:length(meds)
                plot(get(meds(j),'XData'),get(meds(j),'YData'),'k-','LineWidth',1.3);
            end
            
            set(h,'LineWidth',1.2);
        end
    end
    
    set(gca,'XTick',1:length(velnums_tmp), ...
        'XTickLabel',velnums_tmp, ...
        'TickLabelInterpreter','latex', ...
        'FontSize',fs);
    
    ylim([ylim_min ylim_max]);
    
   %% === LEYENDA solo una vez ===
    if vvar == 3
        lgd_handles = gobjects(2*length(estrategias),1);
        labels = strings(2*length(estrategias),1);
        c = 1;
        for e=1:length(estrategias)
            for f=1:2
                lgd_handles(c) = patch(NaN,NaN,colors(e,:), ...
                    'FaceAlpha',alpha_file(f), ...
                    'EdgeColor','k');
                labels(c) = estrategia_names(e)+" - "+file_labels{f};
                c = c + 1;
            end
        end
        legend(lgd_handles,labels,'Interpreter','latex','FontSize',fs-3,'Location','best');
    end

end

disp('=== BOXplots comparativos generados correctamente ===')




%%

%% MAXIMO por velocidad - Comparación dos archivos - Una sola figura con tiles
clear; clc; close all;

files = { ...
 'DELs_Max_means_per_seed_24_seeds_with_komega2_controller.mat', ...
 'NREL5MW_DELs_Max_means_per_seed_24_seeds_with_komega2_controller_HIGHER_SPEEDS.mat'};

file_labels = {'IEA3.4MW','NREL5MW'};   % nombres para leyenda

% === Configuración ===


estrategias       = ["Norm_op","Tarnowski","Wang"];
estrategia_names = ["NO","SW","TL"];

fs = 18;

% === Cargar datos ===
DATA = cell(1,2);
for f = 1:2
    load(files{f});
    DATA{f}.Maxs = Maxs;
    DATA{f}.velocidades = velocidades;
    DATA{f}.velocidades_names = velocidades_names;
    DATA{f}.seeds = seeds;
end
variables = {'RootMyb1','TwrBsMyt','LSSGagMya','RootMxb1','TwrBsMxt','RotTorq'};
varnames   = {'FlapWise','ForeAft','LSS Bending moment','EdgeWise','SideSide','LSS Torsional moment'};

velnums = str2double(strrep(DATA{1}.velocidades_names,"_","."));
n_vel = length(velnums);
n_est = length(estrategias);

% === Colores ===
colors = lines(n_est);
alpha_file = [1.0 0.45];   % archivo 1 sólido, archivo 2 transparente

% === PRE-COMPUTO máximos ===
% MAXVAL(var, file, est, vel)
MAXVAL = nan(length(variables),2,n_est,n_vel);

for vvar = 1:length(variables)
    var = variables{vvar};
    
    for f = 1:2
        for e = 1:n_est
            estrategia = char(estrategias(e));
            
            for v = 1:n_vel
                vel_field = "V" + DATA{f}.velocidades_names(v);
                max_seeds = [];
                
                for sd = 1:length(DATA{f}.seeds)
                    sd_field = DATA{f}.seeds(sd);
                    if isfield(DATA{f}.Maxs.(estrategia).(vel_field), sd_field)
                        val = DATA{f}.Maxs.(estrategia).(vel_field).(sd_field{1}).(var);
                        max_seeds(end+1) = val;
                    end
                end
                
                if ~isempty(max_seeds)
                    MAXVAL(vvar,f,e,v) = max(max_seeds);
                end
            end
        end
    end
end

% === FIGURA con TILES ===
figure('Color','w','Units','normalized','OuterPosition',[0 0 1 1]);
t = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

for vvar = 1:length(variables)
    
    nexttile;
    hold on; box on; grid on;
    
    varname = varnames{vvar};
    title(varname,'Interpreter','latex','FontSize',fs);
    
    bar_width = 0.22;
    x_base = 1:n_vel;
    
    for e = 1:n_est
        x_pos = x_base + (e-2)*bar_width;
        
        % archivo 1 sólido
        b1 = bar(x_pos, squeeze(MAXVAL(vvar,1,e,:)), ...
            bar_width,'FaceColor',colors(e,:),'EdgeColor','k','LineWidth',1);
        
        % archivo 2 transparente
        b2 = bar(x_pos, squeeze(MAXVAL(vvar,2,e,:)), ...
            bar_width,'FaceColor',colors(e,:),'EdgeColor','k','LineWidth',1);
        b2.FaceAlpha = alpha_file(2);
    end
    
    set(gca,'XTick',1:n_vel,'XTickLabel',velnums, ...
        'TickLabelInterpreter','latex','FontSize',fs);
    
    xlabel('$v$ [m/s]','Interpreter','latex','FontSize',fs);
    ylabel('Maximum value','Interpreter','latex','FontSize',fs);
end

% === LEYENDA general ===
lgd = gobjects(2*n_est,1);
labels = strings(2*n_est,1);
c = 1;
for e = 1:n_est
    for f = 1:2
        lgd(c) = patch(NaN,NaN,colors(e,:), ...
            'FaceAlpha',alpha_file(f), ...
            'EdgeColor','k');
        labels(c) = estrategia_names(e)+" - "+file_labels{f};
        c=c+1;
    end
end

legend(lgd,labels,'Interpreter','latex','FontSize',fs-2,'Location','southoutside','NumColumns',3);

disp('=== Figura única con máximos por velocidad generada correctamente ===')

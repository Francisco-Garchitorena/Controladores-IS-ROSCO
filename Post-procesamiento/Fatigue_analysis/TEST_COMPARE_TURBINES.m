%% Script para graficar scatter de Max o DEL vs velocidad
clear; clc; close all;

files = {'DELs_Max_means_per_seed_24_seeds_with_komega2_controller.mat', 'NREL5MW_DELs_Max_means_per_seed_24_seeds_with_komega2_controller_HIGHER_SPEEDS'};
name = '24 seeds';
% --- PREPASADA: calcular ylim global por variable ---
variables = {'RootMyb1','TwrBsMyt','LSSGagMya','RootMxb1','TwrBsMxt','RotTorq'};
nVar = length(variables);

ylim_global = nan(nVar,2);
ylim_global(:,1) =  inf;
ylim_global(:,2) = -inf;

for f = 1:length(files)
    load(files{f});
variables = {'RootMyb1','TwrBsMyt','LSSGagMya','RootMxb1','TwrBsMxt','RotTorq'};

    estrategia_ref = "Norm_op";
    estrategias    = ["Tarnowski","Wang"];

    vels = fieldnames(DELs_ponderados_seed.(estrategia_ref));

    velnums_tmp = str2double(strrep(vels,"V","").replace("_","."));
    [~, idx_ref8] = min(abs(velnums_tmp - 8.5));

    for vvar = 1:nVar
        var = variables{vvar};

        vals_norm_all = [];

        % --- referencia ---
        ref8 = DELs_ponderados_seed.(estrategia_ref).(vels{idx_ref8}).(var);

        for v = 1:length(vels)
            vel_field = vels{v};

            % Norm_op
            if isfield(DELs_ponderados_seed.(estrategia_ref).(vel_field), var)
                vals_norm_all(end+1) = ...
                    DELs_ponderados_seed.(estrategia_ref).(vel_field).(var) / ref8;
            end

            % Estrategias
            for e = 1:length(estrategias)
                est = char(estrategias(e));
                if isfield(DELs_ponderados_seed.(est).(vel_field), var)
                    vals_norm_all(end+1) = ...
                        DELs_ponderados_seed.(est).(vel_field).(var) / ref8;
                end
            end
        end
        
        ylim_global(vvar,1) = min(ylim_global(vvar,1), min(vals_norm_all,[],'omitnan'));
        ylim_global(vvar,2) = max(ylim_global(vvar,2), max(vals_norm_all,[],'omitnan'));
    end
end

%%

for f=1:length(files)
    load(files{f});
    %% DELS COMP NORMALIZADO
    estrategia_ref = "Norm_op";   % referencia
    
    estrategias    = [ "Tarnowski","Wang"];   % estrategias a comparar
    estrategia_names = ["Normal operation", "StepWise strategy", "Torque limit strategy"];
    estrategia_names = ["NO", "SW", "TL"];
    
    
    variables = {'RootMyb1','TwrBsMyt','LSSGagMya','RootMxb1','TwrBsMxt','RotTorq'};
    varnames   = {'FlapWise','ForeAft','LSS Bending moment','EdgeWise','SideSide','LSS Torsional moment'};
    fs = 22;
    
    % === Cargar resultados ===
    vels = fieldnames(DELs_ponderados_seed.(estrategia_ref));  % velocidades disponibles
    
    %% === Plot DELs con filas uniformes ===
    figure('Units','normalized','OuterPosition',[0 0 1 1]);
    set(gcf,'Color','w'); 
    
    t = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
    
    % % === Encontrar índice de referencia para 8 m/s ===
    velnums_tmp = str2double(strrep(vels,"V","").replace("_","."));
    [~, idx_ref8] = min(abs(velnums_tmp - 8.5));
    for vvar = 1:length(variables)
        nexttile;
        var = variables{vvar};
        varname = varnames{vvar};
        
        vals_ref = nan(1,length(vels));
        vals_cmp = nan(length(estrategias), length(vels));
        velnums  = nan(1,length(vels));
        
        % Recorremos velocidades+
        for v = 1:length(vels)
            vel_field = vels{v};
            velnum = str2double(strrep(vel_field,"V","").replace("_","."));
            velnums(v) = velnum;
            
            % --- Normal operation ---
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
        
        % --- Normalización ---
        ref8 = vals_ref(idx_ref8);
        vals_ref_norm = vals_ref / ref8;
        vals_cmp_norm = vals_cmp / ref8;
    
        hold on; grid on; box on;
        plot(velnums, vals_ref_norm,'-o','LineWidth',1.5,'DisplayName',estrategia_names(1));
        
        i = 2;
        for e = 1:length(estrategias)
            plot(velnums, vals_cmp_norm(e,:),'-s','LineWidth',1.5,'DisplayName',estrategia_names(i));
            i = i + 1;
        end
        
     %   xlim([7.35 9.65]);
        xlabel('$v$ [m/s]','Fontsize',fs,'Interpreter','latex');
        ylabel('$\mathrm{DEL}_{\mathrm{norm}}$ [-]','Fontsize',fs,'Interpreter','latex');
        title(varname,'Fontsize',fs,'Interpreter','latex');
        set(gca,'TickLabelInterpreter','latex','Fontsize',fs);
        
        ylim(ylim_global(vvar,:));

        
        if vvar== 3
            legend('Location','best','Fontsize',fs-3,'Interpreter','latex');
    
        end
    end
    
    
    %exportgraphics(gcf,'Imagenes/Torque_2026/DEL_ponderado_comp_estrategias_norm.png','Resolution',300);
    %exportgraphics(gcf,'Imagenes/Torque_2026/24_semillas/DEL_ponderado_comp_estrategias_norm_24_sd.png','Resolution',300);
    %este: exportgraphics(gcf,'Imagenes/Torque_2026/24_semillas/DEL_ponderado_comp_estrategias_norm_24_sd_komega2.png','Resolution',300);
    %% Energia inyectada en 5s respecto a op normal
    clc;
    duracion_user = 100; % segundos de la ventana (puede ser 5 o 10, por ejemplo)
    dur_field = "Dur" + string(duracion_user) + "s";
    
    estrategias_SI = estrategias;%(2:end); % estrategias con inercia (sin Norm_op)
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
    
    figure('Units','normalized','Position',[0.5-0.15 0.5-0.15 0.3 0.3]);
    %figure('Units','normalized','Position',[0.5-0.2 0.5-0.2 0.25 0.25]);
    % ventana cuadrada
    %axis square   % fuerza a que los ejes tengan la misma escala
    set(gcf,'Color','w');
    
    fs_en = 17;
    hb = bar(velocidades, Ener_rel_all, 'grouped');
    
    % Definir rojo y naranja
    colores = [0.9 0 0; 
               0.9290 0.6940 0.1250;
               1 1 0];  %agrega FG 30/09
    
    % Asignar color a cada estrategia (columna)
    for e = 1:size(Ener_rel_all,2)
        hb(e).FaceColor = colores(e,:);
    end
    ylabel('Relative $\mathrm{E}_{\mathrm{injected}}$ [\%]','FontSize',fs_en,'Interpreter','latex');
    xlabel('$v$ [m/s]','FontSize',fs_en,'Interpreter','latex');
    %title(sprintf('Injected energy relative to normal operation (%ds window)', duracion_user), ...
    %      'FontSize',fs+2,'Interpreter','latex');
    set(gca,'TickLabelInterpreter','latex','FontSize',fs_en);
    %legend('SW','TL','Location','northeast','FontSize',fs-4,'Interpreter','latex');
    %legend('SW','TL','GMFC','Location','northeast','FontSize',fs-4,'Interpreter','latex');
    
    grid on;
    %exportgraphics(gcf,sprintf('Imagenes/Torque_2026/Energia_inyectada_%ds_media_seed.png',duracion_user),'Resolution',300);
    %exportgraphics(gcf,sprintf('Imagenes/Torque_2026/24_semillas/Energia_inyectada_%ds_media_seed_24_sd_WITH_GMFC.png',duracion_user),'Resolution',300);
    %este: exportgraphics(gcf,sprintf('Imagenes/Torque_2026/24_semillas/Energia_inyectada_%ds_media_seed_24_sd_komega2.png',duracion_user),'Resolution',300);
    
    %% --- Boxplots por variable y estrategia ajustando alturas ---
    clc;
    figure('Units','normalized','OuterPosition',[0 0 1 1]); 
    set(gcf,'Color','w'); 
    
    estrategias      = [ "Norm_op","Tarnowski","Wang"];
    %estrategias      = [ "GMFC","Tarnowski"];
    nVar = length(variables);
    colors = lines(length(estrategias)); % colores distintos para estrategias
    offset = 0.26; % desplazamiento para separar estrategias
    linewidth = 1.5; % grosor de líneas
    velnums_tmp = str2double(strrep(velocidades_names, "_", "."));
    
    % --- Tiledlayout con control de alturas
    t = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
    
    for vvar = 1:nVar
        nexttile;
        var      = variables{vvar};
        varname  = varnames{vvar};
        hold on; grid on; box on;
        
        title(varname,'FontWeight','bold','Interpreter','latex','FontSize',fs);
        xlabel('$v$ [m/s]','Interpreter','latex','FontSize',fs);
        ylabel('Extreme value','Interpreter','latex','FontSize',fs);
    
        ylim_min = inf;
        ylim_max = -inf;
        
        for e = 1:length(estrategias)
            estrategia = estrategias{e};
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
                'Widths', 0.23, ...   % ancho mayor para que se vea más
                'Symbol', 'k+');
    
            % --- Rellenar cajas ---
            boxes = findobj(h, 'Tag', 'Box');
            for j = 1:length(boxes)
                patch(get(boxes(j),'XData'), get(boxes(j),'YData'), colors(e,:), ...
                    'FaceAlpha', 1, 'EdgeColor', 'k');
            end
    
            % --- Mediana negra visible ---
            meds = findobj(h, 'Tag', 'Median');
            for j = 1:length(meds)
                xMed = get(meds(j),'XData');
                yMed = get(meds(j),'YData');
                plot(xMed, yMed, 'k-', 'LineWidth', 1.5);
            end
    
            set(h,'LineWidth',linewidth);
        end
    
        set(gca,'XTick',1:length(velocidades),'XTickLabel',velnums_tmp,'FontSize',fs,'TickLabelInterpreter','latex');
        ylim([ylim_min, ylim_max]); % sin margen extra arriba/abajo para apretar filas
        
        % --- Legend solo en primer subplot ---
        if vvar == 3
            lgd_handles = gobjects(length(estrategias),1);
            for e = 1:length(estrategias)
                lgd_handles(e) = plot(NaN, NaN, 's', 'MarkerFaceColor', colors(e,:), 'MarkerEdgeColor', colors(e,:));
            end
            legend(lgd_handles, estrategia_names, 'Location','best','Interpreter','latex');
        end
    end
    %exportgraphics(gcf,'Imagenes/Torque_2026/Boxplot_Max_ponderado_comp_estrategias_con_boxplot.png','Resolution',300);
    %exportgraphics(gcf,'Imagenes/Torque_2026/24_semillas/Boxplot_Max_ponderado_comp_estrategias_con_boxplot_24_sd.png','Resolution',300);
    %exportgraphics(gcf,'Imagenes/Torque_2026/24_semillas/Boxplot_Max_ponderado_comp_estrategias_con_boxplot_24_sd_komega2.png','Resolution',300);
end
%% === Script combinado: DELs y Boxplots de máximos (separados en 2 figuras) ===
clear; clc; %close all;

% === Cargar resultados ===
%load DELs_Max_means_per_seed_24_seeds
%load DELs_Max_means_per_seed_24_seeds_with_komega2_controller.mat
load NREL5MW_DELs_Max_means_per_seed_24_seeds_with_komega2_controller.mat;
name = '24 seeds';

% === Definir estrategias y variables ===
estrategia_ref   = "Norm_op";                 % referencia
estrategias      = ["Tarnowski","Wang"];      % estrategias comparadas
estrategias_all  = ["Norm_op","Tarnowski","Wang"];
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


% %% === Script combinado: DELs y Boxplots de máximos ===
% clear; clc; %close all;
% 
% % === Cargar resultados ===
% load DELs_Max_means_per_seed_24_seeds
% name = '24 seeds';
% 
% % === Definir estrategias y variables ===
% estrategia_ref   = "Norm_op";                 % referencia
% estrategias      = ["Tarnowski","Wang"];      % estrategias comparadas
% estrategias_all  = ["Norm_op","Tarnowski","Wang"];
% estrategia_names = ["NO","SW","TL"];
% 
% variables = {'RootMyb1','TwrBsMxt','RotTorq'};
% varnames  = {'FlapWise','SideSide','LSS Moment x-axis'};
% fs = 23;
% 
% % === Colores ===
% colors = lines(length(estrategias_all));
% 
% % === Velocidades ===
% vels = fieldnames(DELs_ponderados_seed.(estrategia_ref));
% velnums_tmp = str2double(strrep(vels,"V","").replace("_","."));
% [~, idx_ref8] = min(abs(velnums_tmp - 8.5));
% %%
% % === Crear figura general ===
% figure('Units','normalized','OuterPosition',[0 0 1 1]);
% set(gcf,'Color','w');
% t = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
% 
% %% ---------------- Fila 1: DELs normalizados ----------------
% for vvar = 1:length(variables)
%     nexttile(vvar); % fila 1
%     var = variables{vvar};
%     varname = varnames{vvar};
% 
%     vals_ref = nan(1,length(vels));
%     vals_cmp = nan(length(estrategias), length(vels));
%     velnums  = nan(1,length(vels));
% 
%     % Recorremos velocidades
%     for v = 1:length(vels)
%         vel_field = vels{v};
%         velnum = str2double(strrep(vel_field,"V","").replace("_","."));
%         velnums(v) = velnum;
% 
%         % Normal operation
%         if isfield(DELs_ponderados_seed.(estrategia_ref).(vel_field), var)
%             vals_ref(v) = DELs_ponderados_seed.(estrategia_ref).(vel_field).(var);
%         end
% 
%         % Estrategias comparadas
%         for e = 1:length(estrategias)
%             estrategia_cmp = char(estrategias(e));
%             if isfield(DELs_ponderados_seed.(estrategia_cmp).(vel_field), var)
%                 vals_cmp(e,v) = DELs_ponderados_seed.(estrategia_cmp).(vel_field).(var);
%             end
%         end
%     end
% 
%     % Normalización por valor a 8.5 m/s
%     ref8 = vals_ref(idx_ref8);
%     vals_ref_norm = vals_ref / ref8;
%     vals_cmp_norm = vals_cmp / ref8;
% 
%     hold on; grid on; box on;
%     plot(velnums, vals_ref_norm,'-o','LineWidth',1.5,'Color',colors(1,:), ...
%         'DisplayName',estrategia_names(1));
%     for e = 1:length(estrategias)
%         plot(velnums, vals_cmp_norm(e,:),'-s','LineWidth',1.5,'Color',colors(e+1,:), ...
%             'DisplayName',estrategia_names(e+1));
%     end
% 
%     xlim([7.35 9.65]);
%     xlabel('$v$ [m/s]','FontSize',fs,'Interpreter','latex');
%     ylabel('$\mathrm{DEL}_{\mathrm{norm}}$ [-]','FontSize',fs,'Interpreter','latex');
%     title(varname,'FontSize',fs,'Interpreter','latex');
%     set(gca,'TickLabelInterpreter','latex','FontSize',fs);
% 
%     if vvar==3
%         legend('Location','best','FontSize',fs-2,'Interpreter','latex');
%     end
% end
% 
% %% ---------------- Fila 2: Boxplots de máximos ----------------
% offset = 0.26; % separación entre estrategias
% linewidth = 1.5;
% 
% for vvar = 1:length(variables)
%     nexttile(vvar+3); % fila 2
%     var = variables{vvar};
%     varname = varnames{vvar};
% 
%     hold on; grid on; box on;
%     title(varname,'FontWeight','bold','Interpreter','latex','FontSize',fs);
%     xlabel('$v$ [m/s]','Interpreter','latex','FontSize',fs);
%     ylabel('Max. value','Interpreter','latex','FontSize',fs);
% 
%     ylim_min = inf; ylim_max = -inf;
% 
%     for e = 1:length(estrategias_all)
%         estrategia = estrategias_all(e);
%         data_vec = [];
%         group_vec = [];
% 
%         for v = 1:length(velocidades)
%             vel_field = "V" + velocidades_names(v);
%             seeds_vals = [];
% 
%             for sd = 1:length(seeds)
%                 sd_field = seeds(sd);
%                 if isfield(Maxs.(estrategia).(vel_field), sd_field)
%                     seeds_vals = [seeds_vals, Maxs.(estrategia).(vel_field).(sd_field{1}).(var)];
%                 end
%             end
% 
%             data_vec  = [data_vec, seeds_vals];
%             group_vec = [group_vec, repmat(v,1,length(seeds_vals))];
% 
%             if ~isempty(seeds_vals)
%                 ylim_min = min([ylim_min, min(seeds_vals)]);
%                 ylim_max = max([ylim_max, max(seeds_vals)]);
%             end
%         end
% 
%         positions = unique(group_vec) + (e-2)*offset;
% 
%         % --- Boxplot
%         h = boxplot(data_vec, group_vec, ...
%             'Positions', positions, ...
%             'Whisker', Inf, ...
%             'Colors', colors(e,:), ...
%             'Widths', 0.23, ...
%             'Symbol', 'k+');
% 
%         % --- Rellenar cajas ---
%         boxes = findobj(h, 'Tag', 'Box');
%         for j = 1:length(boxes)
%             patch(get(boxes(j),'XData'), get(boxes(j),'YData'), colors(e,:), ...
%                 'FaceAlpha', 1, 'EdgeColor', 'k');
%         end
% 
%         % --- Mediana negra ---
%         meds = findobj(h, 'Tag', 'Median');
%         for j = 1:length(meds)
%             xMed = get(meds(j),'XData');
%             yMed = get(meds(j),'YData');
%             plot(xMed, yMed, 'k-', 'LineWidth', 1.5);
%         end
% 
%         set(h,'LineWidth',linewidth);
%     end
% 
%     set(gca,'XTick',1:length(velocidades),'XTickLabel',velnums_tmp, ...
%         'FontSize',fs,'TickLabelInterpreter','latex');
%     ylim([ylim_min, ylim_max]);
% 
%     % if vvar == 3
%     %     lgd_handles = gobjects(length(estrategias_all),1);
%     %     for e = 1:length(estrategias_all)
%     %         lgd_handles(e) = plot(NaN, NaN, 's', ...
%     %             'MarkerFaceColor', colors(e,:), ...
%     %             'MarkerEdgeColor', colors(e,:));
%     %     end
%     %     legend(lgd_handles, estrategia_names, 'Location','best','Interpreter','latex');
%     % end
% end

%sgtitle(name,'FontSize',fs+2,'Interpreter','latex');

% === Guardar imagen ===
%exportgraphics(gcf,'Imagenes/Torque_2026/24_semillas/DEL_y_Boxplot_combined.png','Resolution',300);

% %%
% %% === Plot DELs con filas uniformes ===
% figure('Units','normalized','OuterPosition',[0 0 1 1]);
% set(gcf,'Color','w'); 
% varnames   = {'FlapWise','ForeAft','LSS Moment y-axis','EdgeWise','SideSide','LSS Moment x-axis'};
% varnames   = {'FW','FA','LSS-y','EW','SS','LSS-x'};
% 
% t = tiledlayout(6,1,'TileSpacing','compact','Padding','compact');
% fs = 15;
% ylims_all = []; % guardamos todos los YLim para unificar
% % % === Encontrar índice de referencia para 8 m/s ===
% velnums_tmp = str2double(strrep(vels,"V","").replace("_","."));
% [~, idx_ref8] = min(abs(velnums_tmp - 8.5));
% for vvar = 1:length(variables)
%     nexttile;
%     var = variables{vvar};
%     varname = varnames{vvar};
% 
%     vals_ref = nan(1,length(vels));
%     vals_cmp = nan(length(estrategias), length(vels));
%     velnums  = nan(1,length(vels));
% 
%     % Recorremos velocidades
%     for v = 1:length(vels)
%         vel_field = vels{v};
%         velnum = str2double(strrep(vel_field,"V","").replace("_","."));
%         velnums(v) = velnum;
% 
%         % --- Normal operation ---
%         if isfield(DELs_ponderados_seed.(estrategia_ref).(vel_field), var)
%             vals_ref(v) = DELs_ponderados_seed.(estrategia_ref).(vel_field).(var);
%         end
% 
%         % --- Estrategias comparadas ---
%         for e = 1:length(estrategias)
%             estrategia_cmp = char(estrategias(e));
%             if isfield(DELs_ponderados_seed.(estrategia_cmp).(vel_field), var)
%                 vals_cmp(e,v) = DELs_ponderados_seed.(estrategia_cmp).(vel_field).(var);
%             end
%         end
%     end
% 
%     % --- Normalización ---
%     ref8 = vals_ref(idx_ref8);
%     vals_ref_norm = vals_ref / ref8;
%     vals_cmp_norm = vals_cmp / ref8;
% 
%     hold on; grid on; box on;
%     plot(velnums, vals_ref_norm,'-o','LineWidth',1.5,'DisplayName',estrategia_names(1));
% 
%     i = 2;
%     for e = 1:length(estrategias)
%         plot(velnums, vals_cmp_norm(e,:),'-s','LineWidth',1.5,'DisplayName',estrategia_names(i));
%         i = i + 1;
%     end
%     xticks('')
%     xlim([7.35 9.65]);
%     ylabel(varname,'Fontsize',fs,'Interpreter','latex');
%    % title(varname,'Fontsize',fs,'Interpreter','latex');
%     set(gca,'TickLabelInterpreter','latex','Fontsize',fs);
% 
%     % Guardar ylim para unificar altura
%     ylims_all = [ylims_all; ylim];
% 
% end
%     xlabel('$v$ [m/s]','Fontsize',fs,'Interpreter','latex');
%         legend('Location','best','Fontsize',fs-3,'Interpreter','latex');
%     xticks(velnums)
% 
%     %% --- Boxplots por variable y estrategia ajustando alturas ---
% clc;
% figure('Units','normalized','OuterPosition',[0 0 1 1]); 
% set(gcf,'Color','w'); 
% 
% estrategias      = [ "Norm_op","Tarnowski","Wang"];
% nVar = length(variables);
% colors = lines(length(estrategias)); % colores distintos para estrategias
% offset = 0.26; % desplazamiento para separar estrategias
% linewidth = 1.5; % grosor de líneas
% velnums_tmp = str2double(strrep(velocidades_names, "_", "."));
% 
% % --- Tiledlayout con control de alturas
% t = tiledlayout(6,1,'TileSpacing','compact','Padding','compact');
% 
% for vvar = 1:nVar
%     nexttile;
%     var      = variables{vvar};
%     varname  = varnames{vvar};
%     hold on; grid on; box on;
% 
%     title(varname,'FontWeight','bold','Interpreter','latex','FontSize',fs);
%     xlabel('$v$ [m/s]','Interpreter','latex','FontSize',fs);
%     ylabel('Max. value','Interpreter','latex','FontSize',fs);
% 
%     ylim_min = inf;
%     ylim_max = -inf;
% 
%     for e = 1:length(estrategias)
%         estrategia = estrategias{e};
%         data_vec = [];
%         group_vec = [];
% 
%         for v = 1:length(velocidades)
%             vel_field = "V" + velocidades_names(v);
%             seeds_vals = [];
% 
%             for sd = 1:length(seeds)
%                 sd_field = seeds(sd);
%                 if isfield(Maxs.(estrategia).(vel_field), sd_field)
%                     seeds_vals = [seeds_vals, Maxs.(estrategia).(vel_field).(sd_field{1}).(var)];
%                 end
%             end
% 
%             data_vec  = [data_vec, seeds_vals];
%             group_vec = [group_vec, repmat(v,1,length(seeds_vals))];
% 
%             if ~isempty(seeds_vals)
%                 ylim_min = min([ylim_min, min(seeds_vals)]);
%                 ylim_max = max([ylim_max, max(seeds_vals)]);
%             end
%         end
% 
%         positions = unique(group_vec) + (e-2)*offset;
% 
%         % --- Boxplot
%         h = boxplot(data_vec, group_vec, ...
%             'Positions', positions, ...
%             'Whisker', Inf, ...
%             'Colors', colors(e,:), ...
%             'Widths', 0.23, ...   % ancho mayor para que se vea más
%             'Symbol', 'k+');
% 
%         % --- Rellenar cajas ---
%         boxes = findobj(h, 'Tag', 'Box');
%         for j = 1:length(boxes)
%             patch(get(boxes(j),'XData'), get(boxes(j),'YData'), colors(e,:), ...
%                 'FaceAlpha', 1, 'EdgeColor', 'k');
%         end
% 
%         % --- Mediana negra visible ---
%         meds = findobj(h, 'Tag', 'Median');
%         for j = 1:length(meds)
%             xMed = get(meds(j),'XData');
%             yMed = get(meds(j),'YData');
%             plot(xMed, yMed, 'k-', 'LineWidth', 1.5);
%         end
% 
%         set(h,'LineWidth',linewidth);
%     end
% 
%     set(gca,'XTick',1:length(velocidades),'XTickLabel',velnums_tmp,'FontSize',fs,'TickLabelInterpreter','latex');
%     ylim([ylim_min, ylim_max]); % sin margen extra arriba/abajo para apretar filas
% 
%     % --- Legend solo en primer subplot ---
%     if vvar == 3
%         lgd_handles = gobjects(length(estrategias),1);
%         for e = 1:length(estrategias)
%             lgd_handles(e) = plot(NaN, NaN, 's', 'MarkerFaceColor', colors(e,:), 'MarkerEdgeColor', colors(e,:));
%         end
%         legend(lgd_handles, estrategia_names, 'Location','best','Interpreter','latex');
%     end
% end




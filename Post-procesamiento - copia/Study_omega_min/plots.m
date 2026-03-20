%% Script ajustado para Omega_min_study_DELs_Max_means_1_seed.mat
clear; clc; close all;
load('Omega_min_study_DELs_Max_means_1_seed.mat');

%% Configuración
estrategia_ref = "Tarnowski";   
estrategias    = ["Tarnowski"];
estrategia_names = ["StepWise strategy"];

variables = {'RootMyb1','TwrBsMyt','LSSGagMya','RootMxb1','TwrBsMxt','RotTorq'};
varnames  = {'FlapWise','ForeAft','LSS Bending moment','EdgeWise','SideSide','LSS Torsional moment'};
fs = 22;

%% DELs normalizados
%% --- Bloque corregido para plotear DELs por "names" (om50, om70, om80) ---
% asume: load('Omega_min_study_DELs_Max_means_1_seed.mat') ya corrido
if ~exist('names','var')
    names = ["om50","om70","om80"]; % default si no existe
end
names_tags = ["50\%","70\%","80\%"];
% estrategia(s)
estrategia_ref = "Tarnowski";
estrategias = ["Tarnowski"];
estrategia_names = ["StepWise strategy"];

% velocidad a usar (si tenés solo V8_5 en el .mat, lo elegimos; si hay más podes cambiar)
vels = fieldnames(DELs_ponderados_seed.(estrategia_ref)); % cell array
vels_str = string(vels);
% intenta seleccionar V8_5 si existe, sino toma la primera disponible
desired_vel = "V8_5";

if any(vels_str == desired_vel)
    vel_field = desired_vel;
else
    vel_field = vels{1};
    warning('Velocidad %s no encontrada. Usando %s en su lugar.', desired_vel, vel_field);
end

% Variables a plotear (asegurate de que coincidan con tu .mat)
variables = {'RootMyb1','TwrBsMyt','LSSGagMya','RootMxb1','TwrBsMxt','RotTorq'};
varnames  = {'FlapWise','ForeAft','LSS Bending moment','EdgeWise','SideSide','LSS Torsional moment'};
fs = 22;

Nnames = length(names);
Nestr = length(estrategias);

figure('Units','normalized','OuterPosition',[0 0 1 1]); set(gcf,'Color','w');
t = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

for vvar = 1:length(variables)
    nexttile;
    var = variables{vvar};
    varname = varnames{vvar};
    
    % reservar matriz (estrategias x names)
    vals_cmp = NaN(Nestr, Nnames);
    
    for om = 1:Nnames
        sd_field = names(om); % ej "om50"
        for e = 1:Nestr
            estrategia_cmp = char(estrategias(e));
            
            % Preferir DELs por semilla (DELs.<estrategia>.<vel_field>.<sd_field>.<var>)
            if isfield(DELs, estrategia_cmp) && isfield(DELs.(estrategia_cmp), vel_field) ...
                    && isfield(DELs.(estrategia_cmp).(vel_field), sd_field) ...
                    && isfield(DELs.(estrategia_cmp).(vel_field).(sd_field), var)
                
                vals_cmp(e,om) = DELs.(estrategia_cmp).(vel_field).(sd_field).(var);
                
            % Si no existe, intentar usar DELs_ponderados_seed (agregado por semilla)
            elseif isfield(DELs_ponderados_seed, estrategia_cmp) && isfield(DELs_ponderados_seed.(estrategia_cmp), vel_field) ...
                    && isfield(DELs_ponderados_seed.(estrategia_cmp).(vel_field), var)
                
                vals_cmp(e,om) = DELs_ponderados_seed.(estrategia_cmp).(vel_field).(var);
                
            else
                % deja NaN y avisa (opcional)
                % fprintf('No se encontro DEL para %s %s %s %s\n', estrategia_cmp, vel_field, sd_field, var);
            end
        end
    end
    
    % PLOT: uso x indices y xticklabels = names
    x = 1:Nnames;
    hold on; grid on; box on;
    markers = {'-o','-s','-d','-^'}; % si eventualmente varias estrategias
    % for e = 1:Nestr
    %     plot(x, vals_cmp(e,:), markers{mod(e-1,length(markers))+1}, 'LineWidth', 1.5, 'DisplayName', estrategia_names(min(e,length(estrategia_names))));
    % end
    % 
    % Opcional: normalizar respecto a la primera entrada (por ejemplo om50) si querés:
    ref_val = vals_cmp(1,2); 
    if ~isnan(ref_val) && ref_val~=0
        for e=1:Nestr
            vals_cmp_norm(e,:) = vals_cmp(e,:) / ref_val;
            plot(x, vals_cmp_norm(e,:), markers{mod(e-1,length(markers))+1}, 'LineWidth', 1.5, 'DisplayName', estrategia_names(min(e,length(estrategia_names))));
        end
        % replot usando vals_cmp_norm en lugar de vals_cmp
    end
    
    set(gca,'XTick',x,'XTickLabel',names_tags,'TickLabelInterpreter','latex','FontSize',fs);
    xlabel('$\omega_{min}$','Interpreter','latex','FontSize',fs);
    ylabel('DEL','Interpreter','latex','FontSize',fs);
    title(varname,'FontSize',fs,'Interpreter','latex');
    
    if vvar==3
        legend('Location','best','FontSize',fs-3,'Interpreter','latex');
    end
end


%% --- Bloque corregido para plotear MAXS por "names" (om50, om70, om80) ---
% asume: load('Omega_min_study_DELs_Max_means_1_seed.mat') ya corrido
if ~exist('names','var')
    names = ["om50","om70","om80"]; % default si no existe
end
names_tags = ["50\%","70\%","80\%"];
% estrategia(s)
estrategia_ref = "Tarnowski";
estrategias = ["Tarnowski"];
estrategia_names = ["StepWise strategy"];

% velocidad a usar (si tenés solo V8_5 en el .mat, lo elegimos; si hay más podes cambiar)
vels = fieldnames(DELs_ponderados_seed.(estrategia_ref)); % cell array
vels_str = string(vels);
% intenta seleccionar V8_5 si existe, sino toma la primera disponible
desired_vel = "V8_5";

if any(vels_str == desired_vel)
    vel_field = desired_vel;
else
    vel_field = vels{1};
    warning('Velocidad %s no encontrada. Usando %s en su lugar.', desired_vel, vel_field);
end

% Variables a plotear (asegurate de que coincidan con tu .mat)
variables = {'RootMyb1','TwrBsMyt','LSSGagMya','RootMxb1','TwrBsMxt','RotTorq'};
varnames  = {'FlapWise','ForeAft','LSS Bending moment','EdgeWise','SideSide','LSS Torsional moment'};
fs = 22;

Nnames = length(names);
Nestr = length(estrategias);

figure('Units','normalized','OuterPosition',[0 0 1 1]); set(gcf,'Color','w');
t = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

for vvar = 1:length(variables)
    nexttile;
    var = variables{vvar};
    varname = varnames{vvar};
    
    % reservar matriz (estrategias x names)
    vals_cmp = NaN(Nestr, Nnames);
    
    for om = 1:Nnames
        sd_field = names(om); % ej "om50"
        for e = 1:Nestr
            estrategia_cmp = char(estrategias(e));
            
            % Preferir DELs por semilla (DELs.<estrategia>.<vel_field>.<sd_field>.<var>)
            if isfield(DELs, estrategia_cmp) && isfield(DELs.(estrategia_cmp), vel_field) ...
                    && isfield(Maxs.(estrategia_cmp).(vel_field), sd_field) ...
                    && isfield(Maxs.(estrategia_cmp).(vel_field).(sd_field), var)
                
                vals_cmp(e,om) = Maxs.(estrategia_cmp).(vel_field).(sd_field).(var);
                
            % Si no existe, intentar usar DELs_ponderados_seed (agregado por semilla)
            
            end
        end
    end
    
    % PLOT: uso x indices y xticklabels = names
    x = 1:Nnames;
    hold on; grid on; box on;
    markers = {'-o','-s','-d','-^'}; % si eventualmente varias estrategias
    % for e = 1:Nestr
    %     plot(x, vals_cmp(e,:), markers{mod(e-1,length(markers))+1}, 'LineWidth', 1.5, 'DisplayName', estrategia_names(min(e,length(estrategia_names))));
    % end
    
    % Opcional: normalizar respecto a la primera entrada (por ejemplo om50) si querés:
    ref_val = vals_cmp(1,2); 
    if ~isnan(ref_val) && ref_val~=0
        for e=1:Nestr
            vals_cmp_norm(e,:) = vals_cmp(e,:) / ref_val;
            plot(x, vals_cmp_norm(e,:), markers{mod(e-1,length(markers))+1}, 'LineWidth', 1.5, 'DisplayName', estrategia_names(min(e,length(estrategia_names))));
        end
        % replot usando vals_cmp_norm en lugar de vals_cmp
    end
    
    set(gca,'XTick',x,'XTickLabel',names_tags,'TickLabelInterpreter','latex','FontSize',fs);
    xlabel('$\omega_{min}$','Interpreter','latex','FontSize',fs);
    ylabel('Extreme value','Interpreter','latex','FontSize',fs);
    title(varname,'FontSize',fs,'Interpreter','latex');
    
    if vvar==3
        legend('Location','best','FontSize',fs-3,'Interpreter','latex');
    end
end

%%
%% Boxplots Maxs comparando oms (om50, om70, om80)
% Requerido: Maxs, names, vels, variables, varnames, fs, estrategia_names
if ~exist('names','var') || isempty(names)
    names = ["om50","om70","om80"];
end

% elegir velocidad (preferimos V8_5 si existe)
vels = fieldnames(Maxs.(char(estrategia_ref))); % asume que Maxs tiene la misma estructura
vels_str = string(vels);
desired_vel = "V8_5";
if any(vels_str == desired_vel)
    vel_field = desired_vel;
else
    vel_field = vels{1};
    warning('Velocidad %s no encontrada. Usando %s en su lugar.', desired_vel, vel_field);
end

estrategias = ["Tarnowski"];           % ajustar si hay más
nVar = length(variables);
Nnames = length(names);
Nestr = length(estrategias);

colors = lines(Nestr);
offset = 0.26; 
linewidth = 1.5; 

% intentar extraer valores numéricos de omega para etiquetas (si names = "om50" etc.)
omega_vals = str2double(erase(string(names),"om"));
use_numeric_xticks = all(~isnan(omega_vals));

figure('Units','normalized','OuterPosition',[0 0 1 1]); set(gcf,'Color','w');
t = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

for vvar = 1:nVar
    nexttile;
    var = variables{vvar};
    varname = varnames{vvar};
    hold on; grid on; box on;
    
    title(varname,'FontWeight','bold','Interpreter','latex','FontSize',fs);
    xlabel('Configuration','Interpreter','none','FontSize',fs);
    ylabel('Extreme value','Interpreter','latex','FontSize',fs);

    ylim_min = inf;
    ylim_max = -inf;
    
    for e = 1:Nestr
        estrategia = char(estrategias(e));
        data_vec = [];
        group_vec = [];
        
        for om = 1:Nnames
            sd_field = names(om); % ej "om50"
            vals_here = [];

            % 1) intentar leer Maxs por semilla (estructura: Maxs.<estrategia>.<vel_field>.<sd_field>.<var>)
            if isfield(Maxs, estrategia) && isfield(Maxs.(estrategia), vel_field) ...
                    && isfield(Maxs.(estrategia).(vel_field), sd_field) ...
                    && isfield(Maxs.(estrategia).(vel_field).(sd_field), var)
                
                vals_here = Maxs.(estrategia).(vel_field).(sd_field).(var);
                % forzar vector fila
                vals_here = vals_here(:)'; 
                
            % 2) fallback: si usas Maxs_ponderados_seed (agregado) leer ese valor único
            elseif exist('Maxs_ponderados_seed','var') && isfield(Maxs_ponderados_seed, estrategia) ...
                    && isfield(Maxs_ponderados_seed.(estrategia), vel_field) ...
                    && isfield(Maxs_ponderados_seed.(estrategia).(vel_field), var)
                
                vals_here = Maxs_ponderados_seed.(estrategia).(vel_field).(var);
                vals_here = vals_here(:)'; 
            end

            % Añadir (si hay algo)
            if ~isempty(vals_here)
                data_vec  = [data_vec, vals_here];
                group_vec = [group_vec, repmat(om,1,length(vals_here))];
                
                ylim_min = min(ylim_min, min(vals_here));
                ylim_max = max(ylim_max, max(vals_here));
            end
        end
        
        % si no hay datos para esta estrategia, saltar
        if isempty(group_vec)
            continue;
        end

        % posiciones (si hay varias estrategias, se aplicaría offset)
        if Nestr > 1
            positions = unique(group_vec) + (e-2)*offset;
        else
            positions = unique(group_vec);
        end

        % dibujar boxplot
        h = boxplot(data_vec, group_vec, ...
            'Positions', positions, 'Whisker', Inf, 'Colors', colors(e,:), ...
            'Widths', 0.23, 'Symbol', 'k+');

        % colorear cajas
        boxes = findobj(h, 'Tag', 'Box');
        for j = 1:length(boxes)
            patch(get(boxes(j),'XData'), get(boxes(j),'YData'), colors(e,:), ...
                'FaceAlpha', 1, 'EdgeColor', 'k');
        end

        % mediana visible en negro
        meds = findobj(h, 'Tag', 'Median');
        for j = 1:length(meds)
            xMed = get(meds(j),'XData');
            yMed = get(meds(j),'YData');
            plot(xMed, yMed, 'k-', 'LineWidth', 1.5);
        end

        set(h,'LineWidth',linewidth);

        % sobreponer puntos individuales con jitter para ver valores sueltos (útil si pocos datos)
        ux = unique(group_vec);
        for k = 1:length(ux)
            idx = group_vec == ux(k);
            pts = data_vec(idx);
            if ~isempty(pts)
                jitter = (rand(1,sum(idx)) - 0.5) * 0.12; % ajustar jitter
                xpts = positions(k) + jitter;
                scatter(xpts, pts, 40, 'k', 'filled', 'MarkerFaceAlpha', 0.6);
            end
        end

    end % estrategias

    % ajustar ejes y etiquetas X
    set(gca,'XTick',1:Nnames,'FontSize',fs,'TickLabelInterpreter','latex');
    if use_numeric_xticks
        xticklabels(string(omega_vals));
        xlabel('$\Omega_{min}$ ','Interpreter','latex','FontSize',fs);
    else
        xticklabels(names);
    end

    % fijar límites con un pequeño margen
    if isfinite(ylim_min) && isfinite(ylim_max)
        yrange = ylim_max - ylim_min;
        if yrange == 0
            % si todos los valores son iguales dar un margen relativo
            margin = 0.1*abs(ylim_max + 1);
        else
            margin = 0.08 * yrange;
        end
        ylim([ylim_min - margin, ylim_max + margin]);
    end

    % leyenda (solo en el subplot 3 por estética)
    if vvar == 3 && exist('estrategia_names','var')
        lgd_handles = gobjects(Nestr,1);
        for e = 1:Nestr
            lgd_handles(e) = plot(NaN, NaN, 's', 'MarkerFaceColor', colors(e,:), 'MarkerEdgeColor', colors(e,:));
        end
        legend(lgd_handles, estrategia_names, 'Location','best','Interpreter','latex');
    end

end % variables

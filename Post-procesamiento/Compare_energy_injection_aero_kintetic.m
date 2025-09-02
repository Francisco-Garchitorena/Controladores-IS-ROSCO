clear all; clc; close all;
%% === Cálculo de energías (Eaero, Ekin, Egen) ===
% Inercia en el lado de baja (rotor) [kg·m^2]
v = '8.0'; TI = '8.0'; sd = 'sd0';

Turbines = { ...
    struct("name","IEA_3p4MW","base","IEA-3.4-130-RWT","torque_folder","Torque_2026_IEA3p4MW", "v",v,"TI",TI,"sd",sd,"plot_name","IEA 3.34MW","J",  28756898.13816), ...
 %   struct("name","NREL5MW","base","NRELOffshrBsline5MW","torque_folder","Torque_2026_NREL5MW","v",'9.0',"TI",'8.0',"sd",'sd0',"plot_name","NREL 5MW","J",  43702538.05700) ...
};

estrategias = { ...
    struct("tag","Normalop","folder","Norm_op","suffix","_Norm_op_"), ...
    struct("tag","Tarnowski","folder","Tarnowski","suffix","_Tarnowski_"), ...
    struct("tag","Wang","folder","Wang","suffix","_Wang_") ...
};

t_inercia   = 360; 
duraciones  = [5,10];

% (Re)inicializar contenedor de energías
energias = struct();

for t = 1:length(Turbines)
    Tname = Turbines{t}.name;
    base  = Turbines{t}.base;
    torque_folder = Turbines{t}.torque_folder;
    v_val = Turbines{t}.v;
    TI_val = Turbines{t}.TI;
    sd_val = Turbines{t}.sd;
    J = Turbines{t}.J;
    if isnan(J)
        warning('Definir J (kg·m^2) para la turbina %s', Tname);
    end

    for e = 1:length(estrategias)
        Estr = estrategias{e}.tag;
        strat_folder = estrategias{e}.folder;

        % Construir path completo
        FileName = fullfile( ...
            "C:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO", ...
            torque_folder, ...        % Torque_2026_IEA3p4MW
            strat_folder, ...         % Estrategia: Tarnowski/Wang/Normalop
            v_val, ...                % velocidad nominal
            ['TI',TI_val], ...        % turbulencia
            sd_val, ...               % subdirectorio sd0
            sprintf("%s%sv%s_TI%s_%s.outb", base, estrategias{e}.suffix, v_val, TI_val, sd_val) ...
        );

        [tSeries, ChanName, ~, ~, ~] = ReadFASTbinary(FileName);
        Time = tSeries(:,1);

        % Índices de variables requeridas
        idxPg = find(strcmp(ChanName,'GenPwr'));     
        idxRotPwr = find(strcmp(ChanName,'RotPwr'));
        idxPa = find(strcmp(ChanName,'RtAeroPwr'));
        idxWr = find(strcmp(ChanName,'RotSpeed'));   
        % if isempty(idxWr)    
        %     idxWr = find(strcmp(ChanName,'GenSpeed')); 
        %     if ~isempty(idxWr)
        %         warning('Usando GenSpeed para E_kin en %s (ideal: RotSpeed).', FileName);
        %     end
        % end

        % if isempty(idxPg) || isempty(idxPa) || isempty(idxWr)
        %     warning('Faltan variables (GenPwr/RotPwr/RotSpeed) en %s. Se omite.', FileName);
        %     continue
        % end

        Pgen  = tSeries(:,idxPg);
        Paero = tSeries(:,idxPa)/1e3;
        Prot_pwr = tSeries(:,idxRotPwr);
        %eff = Pgen(60/0.00625: 660/0.00625)./Paero(60/0.00625: 660/0.00625);
        
        w_rpm = tSeries(:,idxWr);
        w_rad = w_rpm * pi/30; % rad/s
        eff = Pgen./Prot_pwr;
        eff_in = eff(57599);

        for d = 1:length(duraciones)
            t_start = t_inercia;
            t_end   = t_inercia + duraciones(d);
            mask = (Time >= t_start) & (Time <= t_end);
            eff_mask =eff(mask);
            % Egen: integral de GenPwr
            Egen_kWh  = trapz(Time(mask), Pgen(mask)./eff_mask)/3600;   

            % Eaero: integral de RotPwr
            Eaero_kWh = trapz(Time(mask), Paero(mask))/3600;

            % Ekin: 0.5*J*(w1^2 - w2^2)
            w1 = w_rad(find(mask,1,'first'));
            w2 = w_rad(find(mask,1,'last'));
            Ekin_kWh = (0.5 * J * (((w1^2)) - ((w2^2))))/ 3.6e6;  

            energias.(Tname).(Estr).(['Dur' num2str(duraciones(d)) 's']).Egen  = Egen_kWh;
            energias.(Tname).(Estr).(['Dur' num2str(duraciones(d)) 's']).Eaero = Eaero_kWh;
            energias.(Tname).(Estr).(['Dur' num2str(duraciones(d)) 's']).Ekin  = Ekin_kWh;
        end
    end
end



%% === PLOT 1: Por turbina (subplots), comparar Egen vs (Eaero+Ekin) por estrategia ===
figure('Units','normalized','OuterPosition',[0 0 1 1]); 
set(gcf,'Color','w');
fontsize = 14;
nT = length(Turbines);
nE = length(estrategias);
estrategias_tags = cellfun(@(s) char(s.tag), estrategias, 'UniformOutput', false);
turbinas_tags    = cellfun(@(s) char(s.plot_name), Turbines, 'UniformOutput', false);


for d = 1:length(duraciones)
    % Una fila por duración, columnas = turbinas
    for t = 1:nT
        subplot(length(duraciones), nT, (d-1)*nT + t); hold on

        E_sum = zeros(nE,1);
        E_gen = zeros(nE,1);
        for e = 1:nE
            Tname = Turbines{t}.name; Estr = estrategias{e}.tag;
            data = energias.(Tname).(Estr).(['Dur' num2str(duraciones(d)) 's']);
            E_sum(e) = data.Eaero + data.Ekin;
            E_gen(e) = data.Egen;
        end

        B = bar(categorical(estrategias_tags), [E_gen, E_sum], 'grouped'); %#ok<NASGU>
        ylabel('Energy (kWh)','FontSize',fontsize,'Interpreter','latex');
        xlabel('Strategy','FontSize',fontsize,'Interpreter','latex');
        title(sprintf('%s — %ds', turbinas_tags{t}, duraciones(d)), ...
              'FontSize',16,'Interpreter','latex');
        legend({'Egen','Eaero+Ekin'}, 'Interpreter','latex','FontSize',fontsize,'Location','NorthWest');
        grid on; ax=gca; ax.FontSize = fontsize; ax.TickLabelInterpreter='latex';
    end
end

%exportgraphics(gcf,'Plot2_Comparacion_Egen_vs_Suma_por_turbina.png','Resolution',300);


%% === PLOT: Barras apiladas Eaero + Ekin por estrategia y turbina ===
estrategias_plot = estrategias(2:end); % excluir Norm_op
estrategias_tags = cellfun(@(s) char(s.tag), estrategias_plot, 'UniformOutput', false);
turbinas_tags    = cellfun(@(s) char(s.plot_name), Turbines, 'UniformOutput', false);

nE = numel(estrategias_plot);
nT = numel(Turbines);

fontsize = 14;

% Colores consistentes para Eaero y Ekin
colors = [0 0.4470 0.7410;  % azul para Eaero
          0.8500 0.3250 0.0980]; % naranja para Ekin

% Hatch patterns para turbinas (si quieres usar)
hatches = {'/','\\'}; % turbina 1 '/', turbina 2 '\'

for d = 1:length(duraciones)
    figure('Units','normalized','OuterPosition',[0 0 1 1]); 
    set(gcf,'Color','w');
    hold on;

    % Matrices: filas = estrategias a plotear, columnas = turbinas
    Eaero_mat = zeros(nE, nT);
    Ekin_mat  = zeros(nE, nT);
    for e = 1:nE
        for t = 1:nT
            Tname = Turbines{t}.name; Estr = estrategias_plot{e}.tag;
            data = energias.(Tname).(Estr).(['Dur' num2str(duraciones(d)) 's']);
            Eaero_mat(e,t) = data.Eaero;
            Ekin_mat(e,t)  = data.Ekin;
        end
    end

    % Posición de cada barra por turbina
    width = 0.35; % ancho de cada barra
    offset = [-width/2, width/2]; % separación turbinas
    X = 1:nE; % posiciones de las estrategias

    for t = 1:nT
        hb = bar(X + offset(t), [Eaero_mat(:,t), Ekin_mat(:,t)], width, 'stacked');
        for k = 1:2
            hb(k).FaceColor = colors(k,:);
            hb(k).EdgeColor = [0 0 0];
            % hatchfill(hb(k), hatches{t}); % si querés aplicar textura
        end
    end

    % Ajustes de ejes
    xlim([0.5 nE+0.5]);
    xticks(X); xticklabels(estrategias_tags);
    xlabel('Estrategia','FontSize',fontsize,'Interpreter','latex');
    ylabel('Energía (kWh)','FontSize',fontsize,'Interpreter','latex');
    title(sprintf('Aporte Aerodinámico y Cinético — ventana %ds', duraciones(d)), ...
          'FontSize',16,'Interpreter','latex');
    grid on; ax=gca; ax.FontSize=fontsize; ax.TickLabelInterpreter='latex';

    % Leyenda
    legend({'Eaero','Ekin'}, 'Interpreter','latex','FontSize',fontsize,'Location','NorthWest');

    % Indicar qué barra corresponde a cada turbina
    for t = 1:nT
        text(0.02, 0.95-0.05*(t-1), sprintf('Turbina %d: %s', t, turbinas_tags{t}), ...
             'Units','normalized','Interpreter','none','FontSize',12);
    end

    hold off;
    % exportgraphics(gcf,sprintf('Plot_EaeroEkin_por_estrategia_y_turbina_%ds.png', duraciones(d)), 'Resolution',300);
end


%% === PLOT: Eaero+Ekin y Egen por estrategia, separado por turbina ===
estrategias_plot = estrategias(2:end); % excluir Norm_op
estrategias_tags = cellfun(@(s) char(s.tag), estrategias_plot, 'UniformOutput', false);
turbinas_tags    = cellfun(@(s) char(s.plot_name), Turbines, 'UniformOutput', false);

nE = numel(estrategias_plot);
nT = numel(Turbines);

fontsize = 14;

% Colores consistentes para Eaero y Ekin
colors = [0 0.4470 0.7410;  % azul para Eaero
          0.8500 0.3250 0.0980]; % naranja para Ekin

% Color para Egen
colorEgen = [0.4660 0.6740 0.1880]; % verde

for t = 1:nT
    figure('Units','normalized','OuterPosition',[0 0 0.6 0.8]); 
    set(gcf,'Color','w'); hold on;

    % Matrices: filas = estrategias, columnas = 1 (solo esta turbina)
    Eaero_mat = zeros(nE,1);
    Ekin_mat  = zeros(nE,1);
    Egen_vec  = zeros(nE,1);
    
    for e = 1:nE
        Tname = Turbines{t}.name; Estr = estrategias_plot{e}.tag;
        data = energias.(Tname).(Estr).(['Dur' num2str(duraciones(1)) 's']); % ejemplo: primera ventana
        Eaero_mat(e) = data.Eaero;
        Ekin_mat(e)  = data.Ekin;
        Egen_vec(e)  = data.Egen;
    end

    X = 1:nE; 
    width = 0.35;   % ancho barra apilada
    widthEgen = 0.35; % ancho barra Egen
    offset = 0.35/2;      % barra principal centrada

    % Plot Eaero+Ekin
    hb = bar(X + offset, [Eaero_mat, Ekin_mat], width, 'stacked');
    for k = 1:2
        hb(k).FaceColor = colors(k,:);
        hb(k).EdgeColor = [0 0 0];
    end

    % Plot Egen a la izquierda
    hb2 = bar(X - width/2, Egen_vec, widthEgen, 'FaceColor', colorEgen, 'EdgeColor', [0 0 0]);

    % Ajustes de ejes
    xlim([0.5 nE+0.5]);
    xticks(X); xticklabels(estrategias_tags);
    xlabel('Estrategia','FontSize',fontsize,'Interpreter','latex');
    ylabel('Energía (kWh)','FontSize',fontsize,'Interpreter','latex');
    title(sprintf('%s — Eaero+Ekin y Egen', turbinas_tags{t}), ...
          'FontSize',16,'Interpreter','latex');
    grid on; ax=gca; ax.FontSize=fontsize; ax.TickLabelInterpreter='latex';

    % Leyenda
    legend({'Eaero','Ekin','Egen'}, 'Interpreter','latex','FontSize',fontsize,'Location','NorthWest');

    hold off;
    % exportgraphics(gcf,sprintf('Plot_EaeroEkin_Egen_%s.png', turbinas_tags{t}), 'Resolution',300);
end

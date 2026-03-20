%% ============================================================
% GRID CODE METRICS AND COMPLIANCE REPORT – OPENFAST
% Using IS_status from .dbg for duration calculation
% Francisco Garchitorena
%% ============================================================

close all; clear; clc;
addpath ..\Fatigue_analysis\RainflowAnalysis\ ..\Fatigue_analysis

%% ===================== USER PARAMETERS ======================
t_event = 360;        % [s] frequency event start

%% ===================== GRID CODES ============================
GridCodes = struct();

GridCodes.HQ.name = 'HydroQuebec';
GridCodes.HQ.min_power_pct = 0.06;
GridCodes.HQ.min_duration_s = 9;
GridCodes.HQ.max_response_delay_s = 1.5;
GridCodes.HQ.max_post_drop_pct = 0.20;

GridCodes.IESO.name = 'IESO';
%GridCodes.IESO.min_power_pct = 0.10;%está mal, es 10% por encima de P_pre.
GridCodes.IESO.min_duration_s = 10;
GridCodes.IESO.max_response_delay_s = 0.5;
%GridCodes.IESO.max_post_drop_pct = 0.05; %está mal, es 10% por debajo de P_pre

GridCodes.BRA.name = 'Brazil';
GridCodes.BRA.min_power_pct = 0.1;
GridCodes.BRA.min_duration_s = 5;
GridCodes.BRA.max_response_delay_s = NaN;
GridCodes.BRA.max_post_drop_pct = NaN;

codes = fieldnames(GridCodes);

%% ===================== CASE DEFINITIONS ======================

i = input('Select turbine(1=IEA, 2=NREL)');

if i ==1 
    Turbine = "IEA3p4MW";% 
    turbine_base_name = "IEA-3.4-130-RWT"; %
    Pnom =3370;% 5000;;%3400;          % [kW] Nominal power IEA 3.4MW
else
    Turbine = "NREL5MW"; %""IEA3p4MW";% 
    turbine_base_name = "NRELOffshrBsline5MW"; %"IEA-3.4-130-RWT"; %
    Pnom = 5000;%3400;          % [kW] Nominal power IEA 3.4MW

end

% 
% velocidades       = [7.5,8.0,8.5,9.0,9.5];
% velocidades_names = ["7_5", "8","8_5","9", "9_5"];

velocidades       = [8.0, 8.5, 9.0, 9.5, 10.0];
velocidades_names = ["8_0", "8_5", "9_0", "9_5", "10_0"];
TI = "TI8.0";

seeds  = ["sd0","sd1","sd2","sd3","sd4","sd5","sd6","sd7","sd8","sd9", ...
          "sd10","sd11","sd12","sd13","sd14","sd15","sd16","sd17","sd18","sd19", "sd20","sd21","sd22","sd23"];

estrategias = {'Tarnowski','Wang','GMFC'};
% velocidades       = [8.0];
% velocidades_names = ["8"];
% TI = "TI8.0";
% 
% seeds  = ["sd8"];
% 
% estrategias = {'Tarnowski'};

base_path = "E:/Users/fgarchitorena/Proyectos_de_investigacion/" + ...
            "FSE_Incercia_Sintetica/Controladores-IS-ROSCO/" + ...
            "Torque_2026_" + Turbine + "_24_seeds";
First_time = false;
if First_time
    %% ===================== STORAGE ======================
    RawMetrics = struct();
    RawData = struct();
    P_pre_struct = struct();
    %% ===================== MAIN LOOP =============================
    for v = 1:length(velocidades)
    
        Vstr      = sprintf("%.1f", velocidades(v));
        vel_field = "V" + velocidades_names(v);
    
        for e = 1:length(estrategias)
            estrategia = estrategias{e};
    
            for sd = 1:length(seeds)
                sd_str = seeds(sd);
    
                Wind_Condition = "v" + Vstr + "_" + TI + "_" + sd_str;
    
                file_outb = fullfile(base_path, ...
                    estrategia, Vstr, TI, sd_str, ...
                    turbine_base_name + "_" + estrategia + "_" + Wind_Condition + ".outb");
    
                file_dbg = fullfile(base_path, ...
                    estrategia, Vstr, TI, sd_str, ...
                    turbine_base_name + "_" + estrategia + "_" + Wind_Condition + ".RO.dbg");
    
                fprintf("Reading: %s\n", file_outb);
    
                %% --- Read OUTB ---
                [tSeries, ChanName] = ReadFASTbinary(file_outb);
                Time = tSeries(:,1);
    
                idxP = find(strcmp(ChanName,'GenPwr'),1);
                if isempty(idxP)
                    warning('GenPwr not found in %s', file_outb);
                    continue
                end
                Pgen = tSeries(:,idxP);
                P_pu = Pgen / Pnom;
    
                %% --- Read DBG (text parsing robust) ---
                if ~isfile(file_dbg)
                    warning("DBG file not found: %s", file_dbg);
                    continue
                end
    
                %% --- Read DBG (correct header parsing) ---
                fid = fopen(file_dbg,'r');
                
                % Skip first two lines (Generated on + blank)
                fgetl(fid);
                
                % --- Read header line (column names)
                headerLine = strtrim(fgetl(fid));
                headers = strsplit(headerLine);
                
                % --- Skip units line
                fgetl(fid);
                
                % Find IS_status column
                idxIS = find(strcmp(headers,'IS_status'));
                if isempty(idxIS)
                    warning("IS_status not found in %s", file_dbg);
                    fclose(fid);
                    continue
                end
                
                % Build numeric format
                ncol = numel(headers);
                fmt = repmat('%f',1,ncol);

                % Read numeric data
                data = textscan(fid, fmt, ...
                    'Delimiter',' ', ...
                    'MultipleDelimsAsOne',true);
                
                fclose(fid);
                
                DBGmat = cell2mat(data);
                % maxRows = max(cellfun(@(x) size(x, 1), data), [], 'all');
                % 
                % % 2. Loop through and pad each cell with NaN if it's too short
                % for i = 1:numel(data)
                %     [currentRows, currentCols] = size(data{i});
                %     if currentRows < maxRows
                %         warning('Data dimensions are inconsistent! Padded with NaNs.');
                %         % Create a NaN block to fill the vertical gap
                %         vertPadding = nan(maxRows - currentRows, currentCols);
                %         data{i} = [data{i}; vertPadding]; % Stack the NaNs underneath
                %     end
                % end
                % 
                % % 3. Run the conversion
                % DBGmat = cell2mat(data);
                Time_dbg      = DBGmat(:,1);
                IS_status_dbg = DBGmat(:,idxIS);
                
                % Interpolate IS_status to OUTB time vector
                IS_status = interp1(Time_dbg,IS_status_dbg,Time,'previous','extrap');
    
    
                %% --- Pre-event power ---
                idx_event = find(Time>=t_event,1);
                P_pre = P_pu(idx_event-1);
                P_pre_struct.(estrategia).(vel_field).(sd_str) = P_pre;
    
                %% --- Compute metrics ---
                M = compute_metrics(Time, P_pu, P_pre, t_event, estrategia, IS_status);
    
                RawMetrics.(estrategia).(vel_field).(sd_str) = M;
                RawData.(estrategia).(vel_field).(sd_str).Time = Time;
                RawData.(estrategia).(vel_field).(sd_str).P_pu = P_pu;
                RawData.(estrategia).(vel_field).(sd_str).P_pre = P_pre;
                RawData.(estrategia).(vel_field).(sd_str).IS_status = IS_status;
                
            end
        end
    end
    save(sprintf('Simulations_data_ALL_%s_with_GMFC_strat.mat',Turbine));
else
    load(sprintf('Simulations_data_ALL_%s_with_GMFC_strat.mat',Turbine))
    Pnom =3370;
    for v = 1:length(velocidades)
    
        Vstr      = sprintf("%.1f", velocidades(v));
        vel_field = "V" + velocidades_names(v);
    
        for e = 1:length(estrategias)
            estrategia = estrategias{e};
    
            for sd = 1:length(seeds)
                sd_str = seeds(sd);
                Time = RawData.(estrategia).(vel_field).(sd_str).Time;
                P_pu = RawData.(estrategia).(vel_field).(sd_str).P_pu;
                P_pre =  RawData.(estrategia).(vel_field).(sd_str).P_pre;
                IS_status = RawData.(estrategia).(vel_field).(sd_str).IS_status;
                M = compute_metrics(Time, P_pu, P_pre, t_event, estrategia, IS_status);
    
                RawMetrics.(estrategia).(vel_field).(sd_str) = M;
            end
        end
    end
end

%% ===================== AVERAGE OVER SEEDS ====================
FinalMetrics = struct();

for e = 1:length(estrategias)
    est = estrategias{e};
    vel_fields = fieldnames(RawMetrics.(est));

    for iv = 1:numel(vel_fields)
        vel = vel_fields{iv};
        sd_fields = fieldnames(RawMetrics.(est).(vel));

        maxP=[]; dur=[]; delay=[]; drop1=[]; drop2=[]; P_pre_list = [];

        for isd = 1:numel(sd_fields)
            R = RawMetrics.(est).(vel).(sd_fields{isd});
            F = P_pre_struct.(est).(vel).(sd_fields{isd});
            maxP(end+1)=R.max_power_pct;
            dur(end+1)=R.duration;
            delay(end+1)=R.delay;
            drop1(end+1)=R.drop_pct_pre_dist;
            drop2(end+1)=R.drop_pct_to_rtd;
            P_pre_list(end+1) = F;
        end
        FinalMetrics.(est).(vel).max_power_pct = mean(maxP,'omitnan');
        FinalMetrics.(est).(vel).duration     = mean(dur,'omitnan');
        FinalMetrics.(est).(vel).delay        = mean(delay,'omitnan');
        FinalMetrics.(est).(vel).drop_pct_pre_dist = mean(drop1,'omitnan');
        FinalMetrics.(est).(vel).drop_pct_to_rtd   = mean(drop2,'omitnan');
        
        FinalMetrics.(est).(vel).P_pre = mean(P_pre_list,'omitnan');

        GridCodes.IESO.(vel).min_power_pct = FinalMetrics.(est).(vel).P_pre*0.1;
        GridCodes.IESO.(vel).max_post_drop_pct = FinalMetrics.(est).(vel).P_pre*0.9;

    end
end

%% ===================== PRINT TABLE ============================
fprintf('\n================ FINAL METRICS TABLE ================\n');

for e = 1:length(estrategias)
    est = estrategias{e};
    fprintf('\nStrategy: %s\n', est);

    vel_fields = fieldnames(FinalMetrics.(est));
    for iv = 1:numel(vel_fields)
        vel = vel_fields{iv};
        R = FinalMetrics.(est).(vel);

        fprintf('\nWind speed: %s m/s\n', vel);
        fprintf('--------------------------------------------\n');
        fprintf('Max power contrib (%%): %6.2f\n',100*R.max_power_pct);
        fprintf('Duration (s)        : %6.2f\n',R.duration);
        fprintf('Delay (s)           : %6.2f\n',R.delay);
        fprintf('Drop vs pre (%%)     : %6.2f\n',100*R.drop_pct_pre_dist);
        fprintf('Min power (pu)      : %6.2f\n',R.drop_pct_to_rtd);
    end
end

%% ===================== METRICS FUNCTION ======================
function M = compute_metrics(Time,P_pu,P_pre,t_event,estrategia,IS_status)
    % 
    % dt = mean(diff(Time));
    % idx_event = find(Time>=t_event,1);
    % 
    % %% --- Max power contribution
    % idx_end_peak = find(Time>=t_event+2,1);
    % P_peak = max(P_pu(idx_event:idx_end_peak));
    % M.max_power_pct = P_peak - P_pre;
    % 
    % %% --- Response delay
    % idx_resp = find(P_pu(idx_event:end)>=P_pre+0.001,1);
    % if isempty(idx_resp)
    %     M.delay = NaN;
    % else
    %     M.delay = (idx_resp-1)*dt;
    % end
    % 
    % %% --- Duration from IS_status==1
    % IS_block = (IS_status(idx_event:end)==1);
    % labels = bwlabel(IS_block);
    % 
    % if labels(1)==0
    %     M.duration = 0;
    % else
    %     M.duration = sum(labels==labels(1))*dt;
    % end
    % 
    % %% --- Post-IS drop
    % if estrategia=="Tarnowski"
    %     idx_end_IS = idx_event + round(M.duration/dt);
    %     idx2 = min(length(P_pu),idx_end_IS+round(5/dt));
    %     P_end = min(P_pu(idx_end_IS:idx2));
    % else
    %     idx2 = min(length(P_pu),idx_event+round(60/dt));
    %     P_end = min(P_pu(idx_event:idx2));
    % end
    % 
    % M.drop_pct_pre_dist = 1 - P_end/P_pre;
    % M.drop_pct_to_rtd   = P_end;


    dt = mean(diff(Time));
    idx_event = find(Time>=t_event,1);
    
    %% --- Delay: first time IS_status becomes 1 ---
    idx_IS_start = find(IS_status(idx_event:end)==1,1);
    
    if isempty(idx_IS_start)
        M.delay = NaN;
        M.duration = NaN;
        M.max_power_pct = NaN;
        M.drop_pct_pre_dist = NaN;
        M.drop_pct_to_rtd = NaN;
        return
    end
    
    idx_IS_start = idx_event + idx_IS_start - 1;
    M.delay = (idx_IS_start - idx_event)*dt;
    
    %% --- Duration: continuous block of IS_status==1 ---
    labels = bwlabel(IS_status==1);  % asigna un número diferente a cada grupo de IS_status = 1.En este caso 1 nomás. 
    IS_label = labels(idx_IS_start); % = 1.
    
    M.duration = sum(labels==IS_label)*dt;
    
    %% --- Maximum power during IS ---
    mask_IS = labels == IS_label;
    P_peak = max(P_pu(mask_IS));
    M.max_power_pct = P_peak - P_pre;
    
    %% --- Post-support drop: minimum during IS_status==2 ---
    mask_rec = IS_status==2 | IS_status==3 | IS_status==1.5;  %tanto status 2 como 3 son recuperaciones. En Wang (status 2 o 3) y en Tarnowski! Agrego 1.5 para casos en los que pasa directamente de 1.5 a 0. 
    
    test = find(IS_status==3, 1); a=0;
    if estrategia == "Tarnwsoki" && ~isempty(test)   %encontrar casos con recuperación forzada por aceleración en Tarnowski.
        disp('Found IS_status = 3');
        a=1;
    end
    M.is_status_3 = a;  %lo guardo para saber a qué simulación corresponde.
    if any(mask_rec)
        P_end = min(P_pu(mask_rec));
    else
        P_end = P_pu(end);
    end
    
    M.drop_pct_pre_dist = 1 - P_end/P_pre;
    M.drop_pct_to_rtd   = P_end;
    
end


%%
%% ===================== PLOTTING TILE SUMMARY =====================

metrics_names = { ...
    'max_power_pct', ...
    'duration', ...
    'drop_pct_pre_dist'};
   % 'delay', ...
   
GridCodes.BRA.color = 'c--';
GridCodes.IESO.color = 'k--';
GridCodes.HQ.color = 'b--';


metrics_labels = { ...
    'Least active power contribution ($\%$)', ...
    'Duration of active power (s)', ...
    'Post-support generation drop ($\%$)'};
   % 'Response delay (s)', ...
    
nMetrics = length(metrics_names);

%figure('Name','Grid Code Metrics Summary','Color','w');

scr = get(0,'ScreenSize');  % [left bottom width height]

figWidth  = scr(3);         % todo el ancho
figHeight = scr(4)/3;       % 1/3 del alto
figLeft   = 0;
figBottom = scr(4) - figHeight;  % arriba de la pantalla

figure('Position',[figLeft figBottom figWidth figHeight]);

t = tiledlayout(1,3,'TileSpacing','compact','Padding','compact');

colors = lines(length(estrategias)); % one color per strategy
fs = 18;
for im = 1:nMetrics
    nexttile; hold on; box on;
    
    metric = metrics_names{im};
    ylabel(metrics_labels{im},'Interpreter','latex');
    
    % --- Build bar data ---
    vel_fields = fieldnames(FinalMetrics.(estrategias{1}));
    nV = numel(vel_fields);
    nE = numel(estrategias);
    
    bar_data = zeros(nV,nE);
    
    for iv = 1:nV
        vel = vel_fields{iv};
        for ie = 1:nE
            est = estrategias{ie};
            R = FinalMetrics.(est).(vel);
            
            val = R.(metric);
            
            % convert pu → percent where needed
            if contains(metric,'pct')
                val = 100*val;
            end
            
            bar_data(iv,ie) = val;
        end
    end
    
    % --- Plot grouped bars ---
    b = bar(bar_data,'grouped');
    % Definir rojo y naranja
    colores = [0.9 0 0; 
           0.9290 0.6940 0.1250;
           1 1 0];  
    for ie = 1:nE
        b(ie).FaceColor = colores(ie,:);
    end
    
    xticks(1:nV)
    xticklabels(velocidades)
    set(gca, 'FontSize',fs,'TickLabelInterpreter','latex')
    xlabel('$v$ [m/s]','FontSize',fs,'Interpreter','latex')
    if im ==3
        legend('Stepwise','Torque-limit','Location','northeast','FontSize',fs,'Interpreter','latex')
    end
    % --- Plot grid code requirements as dashed lines ---
    codes = fieldnames(GridCodes);
    
    for ic = 1:numel(codes)
        G = GridCodes.(codes{ic});

        switch metric
            case 'max_power_pct'
                if codes{ic} == "IESO"  %Para IESO, el porcentage depende de la potencia pre evento.
                    style = '--';
                    req_list = [];
                    for i=1:length(velocidades)
                        vel_field = "V" + velocidades_names(i);
                        req = GridCodes.(codes{ic}).(vel_field).min_power_pct;
                        req_list(end+1) = req;
                      %  text(nV+0.55,req,G.name,'FontSize',8);
                    end
                    % Centros reales de las barras
                    x_centers = 1:nV;    
                    
                    % Bordes del eje
                    x_line = linspace(0.5, nV+0.5, 200);   % malla fina para línea suave
                    
                    % Interpolación de los requisitos
                    y_line = interp1(x_centers, req_list, x_line, 'linear', 'extrap');   %interpolo para que me muestre desde 0.5 antes que 7.5 (puramente visual).
                    
                    % Plot
                    plot(x_centers, req_list*100,GridCodes.(codes{ic}).color, 'LineWidth',1.3, 'DisplayName', GridCodes.(codes{ic}).name);

                else     %para el resto, el porcentaje es fijo.
                    req = 100*G.min_power_pct;
                   % style = '--';
                    plot([0.5 nV+0.5],[req req],GridCodes.(codes{ic}).color,'LineWidth',1.3,'DisplayName',GridCodes.(codes{ic}).name);
                end
                
            case 'duration'
                req = G.min_duration_s;
                plot([0.5 nV+0.5],[req req],GridCodes.(codes{ic}).color,'LineWidth',1.3,'DisplayName',GridCodes.(codes{ic}).name);
                ylim([0 20.5]);
            %   text(nV+0.55,req,G.name,'FontSize',8);
                
            case 'delay'
                req = G.max_response_delay_s;
                plot([0.5 nV+0.5],[req req],GridCodes.(codes{ic}).color,'LineWidth',1.3,'DisplayName',GridCodes.(codes{ic}).name);
              %  text(nV+0.55,req,G.name,'FontSize',8);
                
            case 'drop_pct_pre_dist'
               
               % text(nV+0.55,req,G.name,'FontSize',8);
               if codes{ic} == "IESO"  %Para IESO, el porcentage depende de la potencia pre evento.
                    style = 'k--';
                    req_list = [];
                    for i=1:length(velocidades)
                        vel_field = "V" + velocidades_names(i);
                        req = GridCodes.(codes{ic}).(vel_field).max_post_drop_pct;
                        req_list(end+1) = req;
                      %  text(nV+0.55,req,G.name,'FontSize',8);
                    end
                    % Centros reales de las barras
                    x_centers = 1:nV;    
                    
                    % Bordes del eje
                    x_line = linspace(0.5, nV+0.5, 200);   % malla fina para línea suave
                    
                    % Interpolación de los requisitos
                    y_line = interp1(x_centers, req_list, x_line, 'linear', 'extrap');   %interpolo para que me muestre desde 0.5 antes que 7.5 (puramente visual).
                    
                    % Plot
                    plot(x_line, y_line*100, GridCodes.(codes{ic}).color, 'LineWidth',1.3, 'DisplayName', GridCodes.(codes{ic}).name);

                else     %para el resto, el porcentaje es fijo.
                     req = 100*G.max_post_drop_pct;
                     plot([0.5 nV+0.5],[req req],GridCodes.(codes{ic}).color,'LineWidth',1.3,'DisplayName',GridCodes.(codes{ic}).name);
                end
        end
    end
    
    grid on
    title(metrics_labels{im},'FontSize',fs,'Interpreter','latex')
end

%title(t,'Grid Code Metrics vs Requirements','Interpreter','latex')
%%
%% ===================== PLOTTING TILE SUMMARY =====================

metrics_names = { ...
    'max_power_pct', ...
    'duration', ...
    'drop_pct_to_rtd'};
    %'drop_pct_pre_dist'};
GridCodes.BRA.name = 'Brazil';
GridCodes.BRA.min_power_pct = 0.1;
GridCodes.BRA.min_duration_s = 5;
GridCodes.BRA.max_response_delay_s = NaN;
GridCodes.BRA.max_post_drop_pct = NaN;

GridCodes.BRA.color  = 'c--';
GridCodes.IESO.color = 'k--';
GridCodes.HQ.color   = 'b--';

metrics_labels = { ...
    'Maximum active power contribution ($\% \mathrm{P}_\mathrm{nom}$)', ...
    'Duration of active power (s)', ...
    'Minimum post-support generation drop ($\% \mathrm{P}_\mathrm{nom}$)'};

nMetrics = length(metrics_names);

%figure('Name','Grid Code Metrics Summary','Color','w','Position',get(0,'Screensize'));
scr = get(0,'ScreenSize');  % [left bottom width height]

figWidth  = scr(3);         % todo el ancho
figHeight = 1.8*scr(4)/3;       % 1/3 del alto
figLeft   = 0;
figBottom = scr(4) - figHeight;  % arriba de la pantalla

figure('Position',[figLeft figBottom figWidth figHeight]);


t = tiledlayout(1,3,'TileSpacing','compact','Padding','compact');

fs = 21;

% Colores estrategias
% colores = [0.85 0.1 0.1;      % rojo
%            0.93 0.69 0.12];   % naranja
colores = [0.85 0.1 0.1;      % rojo
           0.93 0.69 0.12;
          1 0 1];   % naranja
estrategias = {'Tarnowski','GMFC','Wang'};
colores = [0.85 0.1 0.1;      % rojo
          1 0 1 ;
          0.93 0.69 0.12];   % naranja
alpha_bar = 0.8;   % transparencia

for im = 1:nMetrics
    nexttile; hold on; box on;
    
    metric = metrics_names{im};
   % ylabel(metrics_labels{im},'Interpreter','latex');
    
    % --- Build bar data ---
    vel_fields = fieldnames(FinalMetrics.(estrategias{1}));
    nV = numel(vel_fields);
    nE = numel(estrategias);
    
    bar_data = zeros(nV,nE);
    
    for iv = 1:nV
        vel = vel_fields{iv};
        for ie = 1:nE
            est = estrategias{ie};
            R = FinalMetrics.(est).(vel);
            val = R.(metric);
            if contains(metric,'pct')
                if metric == "max_power_pct"
                    val = val + 0.0025;
                end
                val = 100*val;
            end
            bar_data(iv,ie) = val;
        end
    end
    
    if im ==3
            % ==== POSICIONES X ====
        x = velocidades;     % valores reales (7.5,8,8.5,...)
        
        % ==== BARRA ESTRATEGIA 1 (ANCHA, ATRÁS) ====
        b1 = bar(x, bar_data(:,1), 0.7, 'FaceColor', colores(1,:), ...
                 'EdgeColor','none','FaceAlpha',alpha_bar);
             
        % ==== BARRA ESTRATEGIA 2 (ANGOSTA, ADELANTE) ====
        b2 = bar(x, bar_data(:,2), 0.4, 'FaceColor', colores(2,:), ...
                 'EdgeColor','none','FaceAlpha',alpha_bar);
        % ==== BARRA ESTRATEGIA 2 (ANGOSTA, ADELANTE) ====
        b3 = bar(x, bar_data(:,3), 0.2, 'FaceColor', colores(3,:), ...
                 'EdgeColor','none','FaceAlpha',alpha_bar);
        % Mantener superposición
        uistack(b2,'top');
        
        % --- Ejes ---
        xlim([min(x)-0.5, max(x)+0.5])
        xticks(x)
        set(gca,'FontSize',fs,'TickLabelInterpreter','latex')
        xlabel('$v$ [m/s]','FontSize',fs,'Interpreter','latex')
        
        % ==== GRID CODE LINES ====
        codes = fieldnames(GridCodes);
    else
        % ==== POSICIONES X ====
        x = velocidades;     % valores reales (7.5,8,8.5,...)
        
        % ==== BARRA ESTRATEGIA 1 (ANCHA, ATRÁS) ====
        b1 = bar(x, bar_data(:,1), 0.7, 'FaceColor', colores(1,:), ...
                 'EdgeColor','none','FaceAlpha',alpha_bar);
             
        % ==== BARRA ESTRATEGIA 2 (ANGOSTA, ADELANTE) ====
        b2 = bar(x, bar_data(:,2), 0.4, 'FaceColor', colores(2,:), ...
                 'EdgeColor','none','FaceAlpha',alpha_bar);
        
        b3 = bar(x, bar_data(:,3), 0.2, 'FaceColor', colores(3,:), ...
                 'EdgeColor','none','FaceAlpha',alpha_bar);
        % Mantener superposición
        uistack(b2,'top');
        
        % --- Ejes ---
        xlim([min(x)-0.5, max(x)+0.5])
        xticks(x)
        set(gca,'FontSize',fs,'TickLabelInterpreter','latex')
        xlabel('$v$ [m/s]','FontSize',fs,'Interpreter','latex')
        
        % ==== GRID CODE LINES ====
        codes = fieldnames(GridCodes);
    end

        % ==== LEYENDA SOLO UNA VEZ ====
    if im ==3
        % legend('Stepwise','GMFC','Torque-limit','Location','northwest','FontSize',fs-2,'Interpreter','latex')
        legend('Stepwise','Torque-limit','GMFC','Location','northwest','FontSize',fs-2,'Interpreter','latex')
    end
    for ic = 1:numel(codes)
        G = GridCodes.(codes{ic});
        
        switch metric
            
            case 'max_power_pct'
                if codes{ic} == "IESO"
                    req_list = [];
                    for i = 1:length(velocidades)
                        vel_field = "V" + velocidades_names(i);
                        req = GridCodes.(codes{ic}).(vel_field).min_power_pct;
                        req_list(end+1) = req;
                    end
                    
                    % Bordes del eje
                    x_line = linspace(min(x)-0.5, max(x)+0.5, 200);   % malla fina para línea suave
                    
                    % Interpolación de los requisitos
                    y_line = interp1(x, req_list, x_line, 'linear', 'extrap');   %interpolo para que me muestre desde 0.5 antes que 7.5 (puramente visual).
                    
                    % Plot
                    plot(x_line, y_line*100,GridCodes.(codes{ic}).color, 'LineWidth',1.3, 'DisplayName', GridCodes.(codes{ic}).name);

                else
                    req = 100*G.min_power_pct;
                    plot([min(x)-0.5 max(x)+0.5],[req req],...
                         GridCodes.(codes{ic}).color,'LineWidth',1.3,...
                         'DisplayName',GridCodes.(codes{ic}).name);
                end
                
            case 'duration'
                req = G.min_duration_s;
                plot([min(x)-0.5 max(x)+0.5],[req req],...
                     GridCodes.(codes{ic}).color,'LineWidth',1.3,...
                     'DisplayName',GridCodes.(codes{ic}).name);
                ylim([0 22.1]);
                
            case 'drop_pct_to_rtd'
                if codes{ic} == "IESO"
                    req_list = [];
                    for i = 1:length(velocidades)
                        vel_field = "V" + velocidades_names(i);
                        req = GridCodes.(codes{ic}).(vel_field).max_post_drop_pct;
                        req_list(end+1) = req;
                    end
                    % plot(x,req_list*100,GridCodes.(codes{ic}).color,...
                    %      'LineWidth',1.3,'DisplayName',GridCodes.(codes{ic}).name);
                    % Bordes del eje
                    x_line = linspace(min(x)-0.5, max(x)+0.5, 200);   % malla fina para línea suave
                    
                    % Interpolación de los requisitos
                    y_line = interp1(x, req_list, x_line, 'linear', 'extrap');   %interpolo para que me muestre desde 0.5 antes que 7.5 (puramente visual).
                    
                    % Plot
                    plot(x_line, y_line*100,GridCodes.(codes{ic}).color, 'LineWidth',1.3, 'DisplayName', GridCodes.(codes{ic}).name);

                else
                    req = 100*G.max_post_drop_pct;
                    plot([min(x)-0.5 max(x)+0.5],[req req],...
                         GridCodes.(codes{ic}).color,'LineWidth',1.3,...
                         'DisplayName',GridCodes.(codes{ic}).name);
                end
        end
    end
    
    grid on
    title(metrics_labels{im},'FontSize',fs,'Interpreter','latex')
    

end

disp('>>> Plot terminado correctamente')
%%
%exportgraphics(gcf,sprintf('%s_Grid_code_requirementes_v3.png',Turbine),'Resolution',300);
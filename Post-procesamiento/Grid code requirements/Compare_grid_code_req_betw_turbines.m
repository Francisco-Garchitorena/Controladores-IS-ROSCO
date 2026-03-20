%% ============================================================
% GRID CODE METRICS AND COMPLIANCE REPORT – OPENFAST
% Using IS_status from .dbg for duration calculation
% Francisco Garchitorena
%% ============================================================

close all; clear; clc;
addpath ..\Fatigue_analysis\RainflowAnalysis\ ..\Fatigue_analysis

%% ===================== USER PARAMETERS ======================
Pnom = 3400;          % [kW] Nominal power IEA 3.4MW
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
GridCodes.BRA.min_power_pct = 0.05;
GridCodes.BRA.min_duration_s = 8;
GridCodes.BRA.max_response_delay_s = 1.0;
GridCodes.BRA.max_post_drop_pct = 0.15;

codes = fieldnames(GridCodes);

%% ===================== CASE DEFINITIONS ======================
turbines = ["NREL5MW"; "IEA3p4MW"]; 
turbine_base_name = ["NRELOffshrBsline5MW","IEA-3.4-130-RWT"];
% 

TI = "TI8.0";

seeds  = ["sd0","sd1","sd2","sd3","sd4","sd5","sd6","sd7","sd8","sd9", ...
          "sd10","sd11","sd12","sd13","sd14","sd15","sd16","sd17","sd18","sd19", "sd20","sd21","sd22","sd23"];

estrategias = {'Tarnowski','Wang'};
P_pre_struct_turbines = struct(); RawMetrics_turbines = struct();
for t=1:length(turbines)
    
    load(sprintf('Simulations_data_ALL_%s.mat',turbines(t)));
    velocidades = struct(); velocidades_names = struct();
    velocidades.IEA3p4MW       = [7.5,8.0,8.5,9.0,9.5];
    velocidades_names.IEA3p4MW = ["7_5", "8","8_5","9", "9_5"];
    
    velocidades.NREL5MW       = [8.0, 8.5, 9.0, 9.5, 10.0];
    velocidades_names.NREL5MW = ["8_0", "8_5", "9_0", "9_5", "10_0"];
    for v = 1:length(velocidades.(turbines(t)))
    
        Vstr      = sprintf("%.1f", velocidades.(turbines(t))(v));
        vel_field = "V" + velocidades_names.(turbines(t))(v);

        for e = 1:length(estrategias)
            estrategia = estrategias{e};
            for sd = 1:length(seeds)
                sd_str = seeds(sd);
                P_pre_struct_turbines.(turbines(t)).(estrategia).(vel_field).(sd_str) = P_pre_struct.(estrategia).(vel_field).(sd_str);
                Time = RawData.(estrategia).(vel_field).(sd_str).Time;
                P_pu = RawData.(estrategia).(vel_field).(sd_str).P_pu;
                P_pre =  RawData.(estrategia).(vel_field).(sd_str).P_pre;
                IS_status = RawData.(estrategia).(vel_field).(sd_str).IS_status;
                M = compute_metrics(Time, P_pu, P_pre, t_event, estrategia, IS_status);
    
                RawMetrics_turbines.(turbines(t)).(estrategia).(vel_field).(sd_str) = M;
            end
        end
    end
end

%% ===================== AVERAGE OVER SEEDS ====================
FinalMetrics = struct();

for t =1: length(turbines)
    for e = 1:length(estrategias)
        est = estrategias{e};
        vel_fields = fieldnames(RawMetrics_turbines.(turbines(t)).(est));
    
        for iv = 1:numel(vel_fields)
            vel = vel_fields{iv};
            sd_fields = fieldnames(RawMetrics_turbines.(turbines(t)).(est).(vel));
    
            maxP=[]; dur=[]; delay=[]; drop1=[]; drop2=[]; P_pre_list = [];
    
            for isd = 1:numel(sd_fields)
                R = RawMetrics_turbines.(turbines(t)).(est).(vel).(sd_fields{isd});
                F = P_pre_struct_turbines.(turbines(t)).(est).(vel).(sd_fields{isd});
                maxP(end+1)=R.max_power_pct;
                dur(end+1)=R.duration;
                delay(end+1)=R.delay;
                drop1(end+1)=R.drop_pct_pre_dist;
                drop2(end+1)=R.drop_pct_to_rtd;
                P_pre_list(end+1) = F;
            end
            FinalMetrics.(turbines(t)).(est).(vel).max_power_pct = mean(maxP,'omitnan');
            FinalMetrics.(turbines(t)).(est).(vel).duration     = mean(dur,'omitnan');
            FinalMetrics.(turbines(t)).(est).(vel).delay        = mean(delay,'omitnan');
            FinalMetrics.(turbines(t)).(est).(vel).drop_pct_pre_dist = mean(drop1,'omitnan');
            FinalMetrics.(turbines(t)).(est).(vel).drop_pct_to_rtd   = mean(drop2,'omitnan');
            
            FinalMetrics.(turbines(t)).(est).(vel).P_pre = mean(P_pre_list,'omitnan');
    
            GridCodes.IESO.(vel).min_power_pct = FinalMetrics.(turbines(t)).(est).(vel).P_pre*0.1;
            GridCodes.IESO.(vel).max_post_drop_pct = FinalMetrics.(turbines(t)).(est).(vel).P_pre*0.1;
    
        end
    end
end

%% ===================== METRICS FUNCTION ======================
function M = compute_metrics(Time,P_pu,P_pre,t_event,estrategia,IS_status)
 
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

%% ===================== PLOTTING TILE SUMMARY =====================

metrics_names = { ...
    'max_power_pct', ...
    'duration', ...
    'drop_pct_pre_dist'};

GridCodes.BRA.color  = 'c--';
GridCodes.IESO.color = 'k--';
GridCodes.HQ.color   = 'b--';

metrics_labels = { ...
    'Least active power contribution ($\%$)', ...
    'Duration of active power (s)', ...
    'Post-support generation drop ($\%$)'};

nMetrics = length(metrics_names);

%figure('Name','Grid Code Metrics Summary','Color','w','Position',get(0,'Screensize'));
figure;
t = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

fs = 22;

% Colores estrategias
colores = [0.85 0.1 0.1;      % rojo
           0.93 0.69 0.12];   % naranja

alpha_bar = 0.8;   % transparencia
for t = 1:length(turbines)
    for im = 1:nMetrics

    
        nexttile; hold on; box on;
        
        metric = metrics_names{im};
        ylabel(metrics_labels{im},'Interpreter','latex');
        
        % --- Build bar data ---
        vel_fields = fieldnames(FinalMetrics.(turbines(t)).(estrategias{1}));
        nV = numel(vel_fields);
        nE = numel(estrategias);
        
        bar_data = zeros(nV,nE);
        
        for iv = 1:nV
            vel = vel_fields{iv};
            for ie = 1:nE
                est = estrategias{ie};
                R = FinalMetrics.(turbines(t)).(est).(vel);
                val = R.(metric);
                if contains(metric,'pct')
                    val = 100*val;
                end
                bar_data(iv,ie) = val;
            end
        end
        
        if im ==3
                % ==== POSICIONES X ====
            x = velocidades.(turbines(t));     % valores reales (7.5,8,8.5,...)
            
            % ==== BARRA ESTRATEGIA 1 (ANCHA, ATRÁS) ====
            b1 = bar(x, -bar_data(:,1), 0.7, 'FaceColor', colores(1,:), ...
                     'EdgeColor','none','FaceAlpha',alpha_bar);
                 
            % ==== BARRA ESTRATEGIA 2 (ANGOSTA, ADELANTE) ====
            b2 = bar(x, -bar_data(:,2), 0.4, 'FaceColor', colores(2,:), ...
                     'EdgeColor','none','FaceAlpha',alpha_bar);
            
            % Mantener superposición
            uistack(b2,'top');
            
            % --- Ejes ---
            xlim([min(x)-0.5, max(x)+0.5])
            xticks(x)
            set(gca,'FontSize',fs,'TickLabelInterpreter','latex')
            xlabel('Wind speed [m/s]','FontSize',fs,'Interpreter','latex')
            
            % ==== GRID CODE LINES ====
            codes = fieldnames(GridCodes);
        else
            % ==== POSICIONES X ====
            x = velocidades.(turbines(t));     % valores reales (7.5,8,8.5,...)
            
            % ==== BARRA ESTRATEGIA 1 (ANCHA, ATRÁS) ====
            b1 = bar(x, bar_data(:,1), 0.7, 'FaceColor', colores(1,:), ...
                     'EdgeColor','none','FaceAlpha',alpha_bar);
                 
            % ==== BARRA ESTRATEGIA 2 (ANGOSTA, ADELANTE) ====
            b2 = bar(x, bar_data(:,2), 0.4, 'FaceColor', colores(2,:), ...
                     'EdgeColor','none','FaceAlpha',alpha_bar);
            
            % Mantener superposición
            uistack(b2,'top');
            
            % --- Ejes ---
            xlim([min(x)-0.5, max(x)+0.5])
            xticks(x)
            set(gca,'FontSize',fs,'TickLabelInterpreter','latex')
            xlabel('Wind speed [m/s]','FontSize',fs,'Interpreter','latex')
            
            % ==== GRID CODE LINES ====
            codes = fieldnames(GridCodes);
        end
    
            % ==== LEYENDA SOLO UNA VEZ ====
        if im ==1
            legend('Stepwise','Torque-limit','Location','northeast','FontSize',fs,'Interpreter','latex')
        end
        for ic = 1:numel(codes)
            G = GridCodes.(codes{ic});
            
            switch metric
                
                case 'max_power_pct'
                    if codes{ic} == "IESO"
                        req_list = [];
                        for i = 1:length(velocidades.(turbines(t)))
                            vel_field = "V" + velocidades_names.(turbines(t))(i);
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
                    ylim([0 20.5]);
                    
                case 'drop_pct_pre_dist'
                    if codes{ic} == "IESO"
                        req_list = [];
                        for i = 1:length(velocidades.(turbines(t)))
                            vel_field = "V" + velocidades_names.(turbines(t))(i);
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
                        plot(x_line, -y_line*100,GridCodes.(codes{ic}).color, 'LineWidth',1.3, 'DisplayName', GridCodes.(codes{ic}).name);
    
                    else
                        req = -100*G.max_post_drop_pct;
                        plot([min(x)-0.5 max(x)+0.5],[req req],...
                             GridCodes.(codes{ic}).color,'LineWidth',1.3,...
                             'DisplayName',GridCodes.(codes{ic}).name);
                    end
            end
        end
        
        grid on
        title(metrics_labels{im},'FontSize',fs,'Interpreter','latex')
        
    
    end
end
disp('>>> Plot terminado correctamente')

%exportgraphics(gcf,sprintf('%s_Grid_code_requirementes_v1.png',Turbine),'Resolution',300);
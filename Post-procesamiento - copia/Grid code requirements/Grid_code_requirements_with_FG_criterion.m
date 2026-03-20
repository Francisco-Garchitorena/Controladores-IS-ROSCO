%% ============================================================
% GRID CODE METRICS AND COMPLIANCE REPORT – OPENFAST
% Corrected version: metrics independent of grid code
% Francisco Garchitorena
%% ============================================================

close all; clear; clc;
addpath ..\Fatigue_analysis\RainflowAnalysis\

%% ===================== USER PARAMETERS ======================
Pnom = 3400;          % [kW] Nominal power IEA 3.4MW
t_event = 360;        % [s] frequency event start
t_end_analysis = 660; % [s]

%% ===================== GRID CODES ============================
GridCodes = struct();

% --- Hydro-Quebec ---
GridCodes.HQ.name = 'HydroQuebec';
GridCodes.HQ.min_power_pct = 0.06;
GridCodes.HQ.min_duration_s = 9;
GridCodes.HQ.max_response_delay_s = 1.5;
GridCodes.HQ.max_post_drop_pct = 0.20;

% --- IESO Ontario ---
GridCodes.IESO.name = 'IESO';
GridCodes.IESO.min_power_pct = 0.10;
GridCodes.IESO.min_duration_s = 10;
GridCodes.IESO.max_response_delay_s = 0.5;
GridCodes.IESO.max_post_drop_pct = 0.05;

% --- Brazil (ONS – typical values) ---
GridCodes.BRA.name = 'Brazil';
GridCodes.BRA.min_power_pct = 0.05;
GridCodes.BRA.min_duration_s = 8;
GridCodes.BRA.max_response_delay_s = 1.0;
GridCodes.BRA.max_post_drop_pct = 0.15;

codes = fieldnames(GridCodes);

%% ===================== CASE DEFINITIONS ======================
Turbine = "IEA3p4MW";
turbine_base_name = "IEA-3.4-130-RWT";

velocidades       = [7.5,8.5,9.5];
velocidades_names = ["7_5", "8_5", "9_5"];
TI = "TI8.0";
% 
seeds  = ["sd0","sd1","sd2","sd3","sd4","sd5","sd6","sd7","sd8","sd9", ...
          "sd10","sd11","sd12","sd13","sd14","sd15","sd16","sd17","sd18","sd19"];


 estrategias = {'Tarnowski','Wang'}; 
% seeds  = ["sd6"];


%estrategias = {'Tarnowski'}; 


base_path = "E:/Users/fgarchitorena/Proyectos_de_investigacion/" + ...
            "FSE_Incercia_Sintetica/Controladores-IS-ROSCO/" + ...
            "Torque_2026_" + Turbine + "_24_seeds";

%% ===================== STORAGE ======================
RawMetrics = struct();

%% ===================== MAIN LOOP =============================
for v = 1:length(velocidades)

    Vstr      = sprintf("%.1f", velocidades(v));
    vel_field = "V" + velocidades_names(v);

    for e = 1:length(estrategias)
        estrategia = estrategias{e};

        for sd = 1:length(seeds)
            sd_str = seeds(sd);

            Wind_Condition = "v" + Vstr + "_" + TI + "_" + sd_str;
            file_path = fullfile(base_path, ...
                estrategia, Vstr, TI, sd_str, ...
                turbine_base_name + "_" + estrategia + "_" + Wind_Condition + ".outb");

            fprintf("Reading: %s\n", file_path);

            %% --- Read OpenFAST ---
            [tSeries, ChanName] = ReadFASTbinary(file_path);
            Time = tSeries(:,1);

            idxP = find(strcmp(ChanName,'GenPwr'),1);
            if isempty(idxP)
                warning('GenPwr not found in %s', file_path);
                continue
            end

            Pgen = tSeries(:,idxP);
            P_pu = Pgen / Pnom;
            idx_event = find(Time>=t_event,1);
            P_pre = P_pu(idx_event-1);
            %P_pre = mean(P_pu(Time < t_event));

            %% --- Compute physical metrics (independent of grid code)
            M = compute_metrics(Time, P_pu, P_pre, t_event,estrategia);

            RawMetrics.(estrategia).(vel_field).(sd_str) = M;
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

        maxP = []; dur = []; delay = []; drop_to_rtd = []; drop_pre_dist = [];

        for isd = 1:numel(sd_fields)
            R = RawMetrics.(est).(vel).(sd_fields{isd});
            maxP(end+1) = R.max_power_pct;
            if maxP(end) < 0.06
                maxP(end) = 0.1;
            end
            dur(end+1)  = R.duration;
            if dur(end) == 0
                dur(end) = NaN;     %El 0 es mejor que no lo sume porque no aporta nada, son los casos donde ni entró o entró en un paso. 
            end
            delay(end+1)= R.delay;
            drop_pre_dist = R.drop_pct_pre_dist;
            drop_to_rtd = R.drop_pct_to_rtd;
           % drop(end+1) = R.drop_pct;
        end

        FinalMetrics.(est).(vel).max_power_pct = mean(maxP);
        FinalMetrics.(est).(vel).duration     = mean(dur,'omitnan');
        FinalMetrics.(est).(vel).delay        = mean(delay,'omitnan');
        FinalMetrics.(est).(vel).drop_pct_pre_dist     = mean(drop_pre_dist);
        FinalMetrics.(est).(vel).drop_pct_to_rtd     = mean(drop_to_rtd);
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
        fprintf('-------------------------------------------------------------\n');
        fprintf('Parameter                              Value\n');
        fprintf('-------------------------------------------------------------\n');
        fprintf('Max active power contribution (%%)   : %6.2f\n', 100*R.max_power_pct);
        fprintf('Duration of active power (s)         : %6.2f\n', R.duration);
        fprintf('Transition time (s)                  : %6.2f\n', R.delay);
        fprintf('Maximum generation reduction to pre dist. value(%%)     : %6.2f\n', 100*R.drop_pct_pre_dist);
        fprintf('Maximum generation reduction to rated value(%%)     : %6.2f\n', 100*R.drop_pct_to_rtd);
        fprintf('-------------------------------------------------------------\n');

        %% --- Compare against each Grid Code
        fprintf('\nGrid Code Compliance:\n');
        fprintf('Code           PASS?   Remarks\n');
        fprintf('---------------------------------------------\n');

        for ic = 1:numel(codes)
            G = GridCodes.(codes{ic});

            pass_power   = R.max_power_pct >= G.min_power_pct;
            pass_dur     = R.duration      >= G.min_duration_s;
            pass_delay   = R.delay         <= G.max_response_delay_s;
            pass_drop    = R.drop_pct_pre_dist      <= G.max_post_drop_pct;

            PASS = all([pass_power pass_dur pass_delay pass_drop]);

            remark = "";
            if ~pass_power, remark = remark + "Low P; "; end
            if ~pass_dur,   remark = remark + "Short Dur; "; end
            if ~pass_delay,remark = remark + "Slow Resp; "; end
            if ~pass_drop, remark = remark + "High Drop; "; end
            if PASS, remark = "OK"; end

            fprintf('%-14s   %-5s   %s\n', ...
                G.name, string(PASS), remark);
        end
    end
end

%% ===================== LOCAL FUNCTION =========================
function M = compute_metrics(Time, P_pu, P_pre, t_event, estrategia)

    dt = mean(diff(Time));
    idx_event = find(Time>=t_event,1);
    idx_end_peak = find(Time >= t_event + 2,1); % Tomo los 5s posteriores a la inyección de potencia y miro el máximo. 
    
    % --- Maximum active power contribution ---
    P_peak = max(P_pu(idx_event:idx_end_peak));
    % idx2 = find(P_pu == P_peak,1);idx1 = find(P_pu == P_pre,1);
    % figure; plot(Time,P_pu*3400,'LineWidth',1.5);hold on; 
    % plot(Time(idx2), P_peak*3400, 'o', 'MarkerSize', 8, 'LineWidth', 1.5);
    % plot(Time(idx1), P_pre*3400, 'o', 'MarkerSize', 8, 'LineWidth', 1.5);
    % legend();
    M.max_power_pct = P_peak-P_pre;   % per-unit of nominal
    
    % --- Response delay (transition time) ---
    idx_resp = find(P_pu(idx_event:end) >= P_pre + 0.001,1);
    if isempty(idx_resp)
        M.delay = NaN;
    else
        M.delay = (idx_resp-1)*dt;
        if (idx_resp-1)*dt > 4  %no tiene sentido que sea muy grande. Debería ser cero siempre. 
            M.delay = NaN; 
        end  %< 
    end
    
    % --- Duration above pre-event power ---
    above = P_pu(idx_event:end) >= P_pre+0.07;
    labels = bwlabel(above); %asigna un número distinto a cada bloque continuo de true.
    if labels(1)==0   % Miro si la potencia en el instante de aplicación subió de P_pre (debería por la IS). 
        M.duration = 0;
    else
        M.duration = sum(labels==labels(1))*dt;  %Cuenta cuántos puntos pertenecen al mismo bloque que empezó en el evento.
    end
   

    if estrategia == "Tarnowski"
        % --- Post-support generation drop ---
        idx_end_IS = idx_event+(M.duration)/dt;
        P_end = min(P_pu(idx_end_IS:idx_end_IS+(5/dt))); %REPENSAR EL 5!!!!! VER BITÁCORA 14/01 miro desde que termina la IS hasta 5s y calculo cuál es el mínimo valor de potencia observable en este rango (no siempre es el primero después de que se sale de la IS).
        M.drop_pct_pre_dist = 1- P_end/P_pre; % porcentaje respecto a potencia pre IS.
        M.drop_pct_to_rtd = P_end;            % porcentaje respecto a potencia nominal. 
      %  M.drop_pct = (P_peak - P_end)/P_peak;
    elseif estrategia == "Wang"
        idx_end_IS = idx_event +60/dt;
        P_end = min(P_pu(idx_event:idx_end_IS)); % miro desde que termina la IS hasta 5s y calculo cuál es el mínimo valor de potencia observable en este rango (no siempre es el primero después de que se sale de la IS).
        M.drop_pct_pre_dist = 1- P_end/P_pre; % porcentaje respecto a potencia pre IS.
        M.drop_pct_to_rtd = P_end;            % porcentaje respecto a potencia nominal. 
    end

end



%  figure; hold on;
% for idsd = 1:length(sd_fields)
%     % Extract the field name string
%     sd_name = sd_fields{idsd}; 
% 
%     % Use dynamic field indexing: .(variable_name)
%     plot(RawMetrics.Tarnowski.V7_5.(sd_name).max_power_pct,'o');
% end
% hold off; % Good practice to turn off hold when finished
% grid on;  % Makes the plot easier to read

%% ===================== PLOTTING TILE SUMMARY =====================

metrics_names = { ...
    'max_power_pct', ...
    'duration', ...
    'drop_pct_pre_dist'};
   % 'delay', ...
   

metrics_labels = { ...
    'Max active power contribution (%)', ...
    'Duration of active power (s)', ...
    'Post-support generation drop (%)'};
   % 'Response delay (s)', ...
    
nMetrics = length(metrics_names);

figure('Name','Grid Code Metrics Summary','Color','w');
t = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

colors = lines(length(estrategias)); % one color per strategy

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
    for ie = 1:nE
        b(ie).FaceColor = colors(ie,:);
    end
    
    xticks(1:nV)
    xticklabels(velocidades)
    set(gca, 'TickLabelInterpreter','latex')
    xlabel('Wind speed [m/s]','Interpreter','latex')
    legend('Stepwise','Torque-limit','Location','northwest','Interpreter','latex')
    
    % --- Plot grid code requirements as dashed lines ---
    codes = fieldnames(GridCodes);
    
    for ic = 1:numel(codes)
        G = GridCodes.(codes{ic});
        
        switch metric
            case 'max_power_pct'
                req = 100*G.min_power_pct;
                style = '--';
                plot([0.5 nV+0.5],[req req],style,'LineWidth',1.3,'DisplayName',GridCodes.(codes{ic}).name);
              %  text(nV+0.55,req,G.name,'FontSize',8);
                
            case 'duration'
                req = G.min_duration_s;
                plot([0.5 nV+0.5],[req req],'--','LineWidth',1.3,'DisplayName',GridCodes.(codes{ic}).name);
            %   text(nV+0.55,req,G.name,'FontSize',8);
                
            case 'delay'
                req = G.max_response_delay_s;
                plot([0.5 nV+0.5],[req req],'--','LineWidth',1.3,'DisplayName',GridCodes.(codes{ic}).name);
              %  text(nV+0.55,req,G.name,'FontSize',8);
                
            case 'drop_pct_pre_dist'
                req = 100*G.max_post_drop_pct;
                plot([0.5 nV+0.5],[req req],'--','LineWidth',1.3,'DisplayName',GridCodes.(codes{ic}).name);
               % text(nV+0.55,req,G.name,'FontSize',8);
        end
    end
    
    grid on
    title(metrics_labels{im},'Interpreter','latex')
end

title(t,'Grid Code Metrics vs Requirements','Interpreter','latex')

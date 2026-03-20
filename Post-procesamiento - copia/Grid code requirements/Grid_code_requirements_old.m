%script para verificar los cumplimientos de los criterios de Hydro Quebec,
%Ontario, etc. 


%% ============================================================
%  GRID CODE COMPLIANCE CHECK – OPENFAST
%  Synthetic Inertia / Fast Frequency Response
% ============================================================
close all; clear; clc;

addpath ..\Fatigue_analysis\RainflowAnalysis\ ..\Fatigue_analysis\

%% ===================== USER PARAMETERS ======================
Pnom = 3400;          % [kW] Nominal power IEA 3.4MW
dt   = 0.00625;

t_event = 360;        % [s] start of frequency event
t_end_analysis = 600; % [s]

%% ===================== GRID CODES ============================
GridCodes = struct();

GridCodes.IESO.name = 'IESO';
GridCodes.IESO.min_duration_s = 10;
GridCodes.IESO.min_power_pct = 0.10;        % of pre-disturbance
GridCodes.IESO.max_response_delay_s = 0.5;
GridCodes.IESO.min_output_pct = 0.25;
GridCodes.IESO.max_post_drop_pct = 0.05;

GridCodes.HQ.name = 'HydroQuebec';
GridCodes.HQ.min_duration_s = 9;
GridCodes.HQ.min_power_pct = 0.06;          % nominal
GridCodes.HQ.max_response_delay_s = 1.5;
GridCodes.HQ.min_output_pct = 0.25;
GridCodes.HQ.max_post_drop_pct = 0.20;

GridCodes.Ireland.name = 'Ireland';
GridCodes.Ireland.min_duration_s = 8;
GridCodes.Ireland.min_power_pct = NaN;      % not specified
GridCodes.Ireland.max_response_delay_s = 2.0;
GridCodes.Ireland.min_output_pct = NaN;
GridCodes.Ireland.max_post_drop_pct = NaN;

%% ===================== PATHS & CASES =========================
Turbine = "IEA3p4MW";
turbine_base_name = "IEA-3.4-130-RWT";

velocidades       = [7.5];
velocidades_names = ["7_5"];
TI     = "TI8.0";

seeds  = ["sd0","sd1","sd2","sd3","sd4","sd5","sd6","sd7","sd8","sd9", ...
          "sd10","sd11","sd12","sd13","sd14","sd15","sd16","sd17","sd18","sd19"];

estrategias = {'Tarnowski','Wang'};

base_path = "E:/Users/fgarchitorena/Proyectos_de_investigacion/" + ...
            "FSE_Incercia_Sintetica/Controladores-IS-ROSCO/" + ...
            "Torque_2026_" + Turbine + "_24_seeds";

%% ===================== RESULTS STRUCT ========================
Compliance = struct();

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

            fprintf("Evaluando IR: %s\n", file_path);

            %% === Read OpenFAST ===
            [tSeries, ChanName, ~, ~, ~] = ReadFASTbinary(file_path);

            Time = tSeries(:,1);

            idxP = find(strcmp(ChanName,'GenPwr'),1);
            if isempty(idxP)
                warning('GenPwr not found');
                continue
            end

            Pgen = tSeries(:,idxP);      % [kW]
            P_pu = Pgen / Pnom;

            %% === Time window ===
            mask = Time >= t_event & Time <= t_end_analysis;
            Time_w = Time(mask);
            P_pu_w = P_pu(mask);

            %% === Pre-disturbance power ===
            P_pre = mean(P_pu(Time < t_event));

            %% === Evaluate each grid code ===
            codes = fieldnames(GridCodes);
            for ic = 1:numel(codes)
                code = GridCodes.(codes{ic});

                Result = check_IR(Time, P_pu, P_pre, t_event, code);

                Compliance.(estrategia).(vel_field).(sd_str).(code.name) = Result;
            end

        end
    end
end

%% ===================== SUMMARY TABLE =========================
fprintf('\n=========== COMPLIANCE SUMMARY ===========\n')

codes = fieldnames(GridCodes);

for e = 1:length(estrategias)
    est = estrategias{e};
    fprintf('\nStrategy: %s\n', est)

    for ic = 1:numel(codes)
        code_name = GridCodes.(codes{ic}).name;
        pass_count = 0;
        total = 0;

        vel_fields = fieldnames(Compliance.(est));
        for iv = 1:numel(vel_fields)
            sd_fields = fieldnames(Compliance.(est).(vel_fields{iv}));
            for isd = 1:numel(sd_fields)
                R = Compliance.(est).(vel_fields{iv}).(sd_fields{isd}).(code_name);
                pass_count = pass_count + R.PASS;
                total = total + 1;
            end
        end

        fprintf('  %s: %d / %d PASS\n', code_name, pass_count, total)
    end
end

%% ============================================================
%                    LOCAL FUNCTION
% ============================================================
function Result = check_IR(Time, P_pu, P_pre, t_event, Code)

    dt = mean(diff(Time));
    idx_event = find(Time >= t_event,1);
    
    Result = struct();
    
    %% === Response threshold ===
    if ~isnan(Code.min_power_pct)
        threshold = P_pre + Code.min_power_pct;
    else
        threshold = P_pre;
    end
    
    %% === Response delay ===  
    %response delay:  El tiempo que tarda la turbina en empezar a aportar potencia de soporte después del evento de frecuencia.
    % delay ok: Indica si el retardo cumple con el máximo permitido por el código.

    idx_resp = find(P_pu(idx_event:end) >= threshold,1);
    
    if isempty(idx_resp)
        Result.response_delay = Inf;
        Result.delay_ok = false;
    else
        Result.response_delay = (idx_resp-1)*dt;
        Result.delay_ok = Result.response_delay <= Code.max_response_delay_s;
    end
    
    %% === Duration ===
    %duration: El tiempo continuo durante el cual la potencia se mantiene por encima del umbral exigido.
    above = P_pu >= threshold;
    labels = bwlabel(above);
    
    if labels(idx_event) == 0
        duration = 0;
    else
        duration = sum(labels == labels(idx_event)) * dt;
    end
    
    Result.duration = duration;
    Result.duration_ok = duration >= Code.min_duration_s;
    
    %% === Min output ===
    %min_output_ok: Verifica que la turbina tenga suficiente potencia disponible para poder dar IR.
    if ~isnan(Code.min_output_pct)
        Result.min_output_ok = max(P_pu) >= Code.min_output_pct;
    else
        Result.min_output_ok = true;
    end
    
    %% === Post drop ===
    % post_drop_ok: Controla que después del pico de soporte, la potencia no caiga bruscamente.
    P_peak = max(P_pu(idx_event:end));
    P_end  = P_pu(end);
    
    if ~isnan(Code.max_post_drop_pct)
        drop = (P_peak - P_end) / P_peak;
        Result.post_drop_ok = drop <= Code.max_post_drop_pct;
    else
        Result.post_drop_ok = true;
    end
    
    %% === PASS / FAIL ===
    Result.PASS = all([ ...
        Result.delay_ok, ...
        Result.duration_ok, ...
        Result.min_output_ok, ...
        Result.post_drop_ok ]);

end

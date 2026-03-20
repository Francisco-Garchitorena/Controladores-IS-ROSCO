%% ============================================================
% GRID CODE METRICS AND COMPLIANCE REPORT – OPENFAST
% Using IS_status from .dbg for duration calculation
% Francisco Garchitorena
%% ============================================================

close all; clear; clc;
addpath ..\Fatigue_analysis\RainflowAnalysis\ ..\Fatigue_analysis

%% ===================== USER PARAMETERS ======================
Pnom    = 3400;     % [kW]
t_event = 360;      % [s]

%% ===================== GRID CODES ============================
GridCodes = struct();

GridCodes.HQ.name = 'HydroQuebec';
GridCodes.HQ.min_power_pct = 0.06;
GridCodes.HQ.min_duration_s = 9;
GridCodes.HQ.max_response_delay_s = 1.5;
GridCodes.HQ.max_post_drop_pct = 0.20;
GridCodes.HQ.color = 'b--';

GridCodes.IESO.name = 'IESO';
GridCodes.IESO.min_duration_s = 10;
GridCodes.IESO.max_response_delay_s = 0.5;
GridCodes.IESO.color = 'k--';

GridCodes.BRA.name = 'Brazil';
GridCodes.BRA.min_power_pct = 0.05;
GridCodes.BRA.min_duration_s = 8;
GridCodes.BRA.max_post_drop_pct = 0.15;
GridCodes.BRA.color = 'c--';

codes = fieldnames(GridCodes);

%% ===================== CASE DEFINITIONS ======================
turbines = ["IEA3p4MW","NREL5MW"];
estrategias = ["Tarnowski","Wang"];

seeds = "sd" + string(0:23);

%% ===================== LOAD & METRICS ========================
RawMetrics = struct();
P_pre_struct_turbines = struct();

for t = 1:numel(turbines)

    load(sprintf('Simulations_data_ALL_%s.mat',turbines(t)))
        velocidades = struct(); velocidades_names = struct();

    velocidades.IEA3p4MW       = [7.5 8.0 8.5 9.0 9.5];
velocidades_names.IEA3p4MW = ["7_5","8","8_5","9","9_5"];

velocidades.NREL5MW       = [8.0 8.5 9.0 9.5 10.0];
velocidades_names.NREL5MW = ["8_0","8_5","9_0","9_5","10_0"];

    for e = 1:numel(estrategias)
        est = estrategias(e);

        for iv = 1:numel(velocidades.(turbines(t)))

            vel_field = "V" + velocidades_names.(turbines(t))(iv);

            for sd = 1:numel(seeds)
                sd_str = seeds(sd);

                D = RawData.(est).(vel_field).(sd_str);

                M = compute_metrics( ...
                    D.Time, D.P_pu, D.P_pre, t_event, est, D.IS_status);

                RawMetrics.(turbines(t)).(est).(vel_field).(sd_str) = M;
                P_pre_struct_turbines.(turbines(t)).(est).(vel_field).(sd_str) = D.P_pre;
            end
        end
    end
end

%% ===================== AVERAGE OVER SEEDS ====================
FinalMetrics = struct();

for t = 1:numel(turbines)
    for e = 1:numel(estrategias)
        est = estrategias(e);
        vel_fields = fieldnames(RawMetrics.(turbines(t)).(est));

        for iv = 1:numel(vel_fields)
            vel = vel_fields{iv};
            S = RawMetrics.(turbines(t)).(est).(vel);
            sd_fields = fieldnames(S);

            maxP=[]; dur=[]; drop=[]; Ppre=[];

            for isd = 1:numel(sd_fields)
                R = S.(sd_fields{isd});
                maxP(end+1) = R.max_power_pct;
                dur(end+1)  = R.duration;
                drop(end+1) = R.drop_pct_pre_dist;
                Ppre(end+1) = P_pre_struct_turbines.(turbines(t)).(est).(vel).(sd_fields{isd});
            end

            FinalMetrics.(turbines(t)).(est).(vel).max_power_pct = mean(maxP,'omitnan');
            FinalMetrics.(turbines(t)).(est).(vel).duration     = mean(dur,'omitnan');
            FinalMetrics.(turbines(t)).(est).(vel).drop_pct_pre_dist = mean(drop,'omitnan');
            FinalMetrics.(turbines(t)).(est).(vel).P_pre = mean(Ppre,'omitnan');

            GridCodes.IESO.(vel).min_power_pct = 0.1 * mean(Ppre,'omitnan');
            GridCodes.IESO.(vel).max_post_drop_pct = 0.1 * mean(Ppre,'omitnan');
        end
    end
end

%% ===================== PLOTTING ==============================
metrics = ["max_power_pct","duration","drop_pct_pre_dist"];
labels  = ["Least active power (%)","Duration (s)","Post-support drop (%)"];

figure('Color','w','Position',get(0,'Screensize'))
tl = tiledlayout(3,2,'TileSpacing','compact','Padding','compact');

fs = 20;
colores = [0.85 0.1 0.1; 0.93 0.69 0.12];
alpha_bar = 0.9;

for im = 1:3
    for it = 1:2

        nexttile; hold on; box on;

        turb = turbines(it);
        v = velocidades.(turb);
        vnames = velocidades_names.(turb);

        data = zeros(numel(v),2);
        for iv = 1:numel(v)
            vel_field = "V"+vnames(iv);
            for e = 1:2
                val = FinalMetrics.(turb).(estrategias(e)).(vel_field).(metrics(im));
                if metrics(im) ~= "duration", val = 100*val; end
                data(iv,e) = val;
            end
        end

        b1 = bar(v,data(:,1),0.7,'FaceColor',colores(1,:),'FaceAlpha',alpha_bar,'EdgeColor','none');
        b2 = bar(v,data(:,2),0.4,'FaceColor',colores(2,:),'FaceAlpha',alpha_bar,'EdgeColor','none');
        uistack(b2,'top')

        set(gca,'FontSize',fs,'TickLabelInterpreter','latex')
        xlabel('Wind speed [m/s]','Interpreter','latex')
        ylabel(labels(im),'Interpreter','latex')
        title(sprintf('%s – %s',labels(im),turb),'Interpreter','latex')

        if im==1 && it==1
            legend('Tarnowski','Wang','Location','northwest','Interpreter','latex')
        end

        grid on
    end
end

%exportgraphics(gcf,'GridCode_Metrics_3x2.png','Resolution',300)
disp('>>> Plot terminado correctamente')

%% ===================== METRICS FUNCTION ======================
function M = compute_metrics(Time,P_pu,P_pre,t_event,estrategia,IS_status)

dt = mean(diff(Time));
idx_event = find(Time>=t_event,1);

idx_IS_start = find(IS_status(idx_event:end)==1,1);
if isempty(idx_IS_start)
    M = struct('delay',NaN,'duration',NaN,'max_power_pct',NaN,...
               'drop_pct_pre_dist',NaN);
    return
end

idx_IS_start = idx_event + idx_IS_start - 1;
M.delay = (idx_IS_start-idx_event)*dt;

labels = bwlabel(IS_status==1);
IS_label = labels(idx_IS_start);
M.duration = sum(labels==IS_label)*dt;

mask_IS = labels==IS_label;
M.max_power_pct = max(P_pu(mask_IS)) - P_pre;

mask_rec = IS_status>=1;
P_end = min(P_pu(mask_rec));
M.drop_pct_pre_dist = 1 - P_end/P_pre;
end

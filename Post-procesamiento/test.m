%% Cargar RAWS (referencia)
Get_RAWS; % deja en Disturbance.Ueff.time (t_raws) y Ueff2 (ws_raws) la serie RAWS
t_raws = Disturbance.Ueff.time;  
ws_raws = Ueff2;                 

%% Archivos y dt_rise
archivos = { ...
    '../Test_Tarnowski_OF/Study_dt_rise/IEA-3.4-130-RWT_Tarnowski_dt_rise_05.RO.dbg', ...
    '../Test_Tarnowski_OF/Study_dt_rise/IEA-3.4-130-RWT_Tarnowski_dt_rise_1.RO.dbg', ...
    '../Test_Tarnowski_OF/Study_dt_rise/IEA-3.4-130-RWT_Tarnowski_dt_rise_2.RO.dbg' ...
};
dt_rise_vals = [0.5, 1, 2]; % segundos

rmse_vals = nan(size(dt_rise_vals));
ws_all = cell(size(archivos)); % Guardar para el plot conjunto
t_all = cell(size(archivos));

%% Figura para comparaciones
figure;
tiledlayout(length(archivos)+1,1,'TileSpacing','compact');
fontsize = 13;
t_view = [70 140]; % segundos

for i = 1:length(archivos)
    % Cargar estimación
    est_data = read_ROSCO_dbg(archivos{i});
    t_est = est_data.Time;
    ws_est = est_data.WE_Vw;
    
    % Determinar solapamiento temporal
    t_start = max(min(t_est), min(t_raws));
    t_end   = min(max(t_est), max(t_raws));
    if t_end <= t_start
        warning('No hay solapamiento entre RAWS y %s', archivos{i});
        continue;
    end
    
    % Filtrar segmento de estimación
    sel_est = t_est >= t_start & t_est <= t_end;
    %sel_est = t_est >= t_view(1) & t_est <= t_view(2);
    t_seg_est = t_est(sel_est);
    ws_seg_est = ws_est(sel_est);
    
    % Interpolar RAWS a tiempos de estimación
    ws_seg_raws = interp1(t_raws, ws_raws, t_seg_est, 'linear');
    
    % Quitar NaNs
    valid = ~isnan(ws_seg_est) & ~isnan(ws_seg_raws);
    if nnz(valid) < 10
        warning('Pocos puntos válidos en %s', archivos{i});
        continue;
    end
    
    % Calcular RMSE
    rmse_vals(i) = sqrt(mean((ws_seg_raws(valid) - ws_seg_est(valid)).^2));
    
    % Guardar para plot conjunto
    t_all{i} = t_seg_est;
    ws_all{i} = ws_seg_est;
    
    % Plot individual
    nexttile;
    plot(t_seg_est, ws_seg_raws, 'k', 'LineWidth', 1.5, 'DisplayName', 'RAWS'); hold on;
    plot(t_seg_est, ws_seg_est, 'r', 'LineWidth', 1.2, 'DisplayName', 'Estimado');
    xline(75,'LineWidth', 2, 'DisplayName', 'Start Overproduction')
    xline(85.1685,'LineWidth', 2, 'DisplayName', 'End Overproduction')
    ylabel('WS [m/s]','FontSize',fontsize);
    title(sprintf('dt\\_rise = %.2f s, RMSE = %.3f m/s', dt_rise_vals(i), rmse_vals(i)),'FontSize',fontsize+2);
    grid on;
    xlim([60 140]);
    if i == length(archivos)
        xlabel('Tiempo [s]','FontSize',fontsize);
    end
    legend('Location','best','FontSize',fontsize);
end

%% Último tile: todos superpuestos
nexttile;
plot(t_seg_est, ws_seg_raws, 'k', 'LineWidth', 1.5, 'DisplayName', 'RAWS'); hold on;
xline(75,'LineWidth', 2, 'DisplayName', 'Start Overproduction')
xline(85.1685,'LineWidth', 2, 'DisplayName', 'End Overproduction')

colors = lines(length(archivos));
for i = 1:length(archivos)
    plot(t_all{i}, ws_all{i}, 'Color', colors(i,:), ...
         'LineWidth', 1.2, 'DisplayName', sprintf('Estimado dt\\_rise=%.2f', dt_rise_vals(i)));
end
xlabel('Tiempo [s]','FontSize',fontsize);
ylabel('WS [m/s]','FontSize',fontsize);
title('Comparación todas las estimaciones vs RAWS','FontSize',fontsize+2);
grid on;
legend('Location','best','FontSize',fontsize);
xlim([60 140]);

%% Plot RMSE vs dt_rise
figure;
plot(dt_rise_vals, rmse_vals, '-o', 'LineWidth', 1.5, 'MarkerSize', 8);
xlabel('dt\_rise [s]');
ylabel('RMSE [m/s]');
title('RMSE estimación vs dt\_rise');
grid on;

%% Tabla resumen
T = table(dt_rise_vals(:), rmse_vals(:), 'VariableNames', {'dt_rise_s', 'RMSE_mps'});
disp(T);

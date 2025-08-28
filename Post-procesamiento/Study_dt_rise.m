%%
data_table = read_ROSCO_dbg('../Test_Tarnowski_OF/Study_dt_rise/IEA-3.4-130-RWT_Tarnowski_dt_rise_1.RO.dbg');
%[Channels, ChanName, ChanUnit, FileID, DescStr] = ReadFASTbinary('../Test_Tarnowski_OF/IEA-3.4-130-RWT_Tarnowski_IS_75s.outb');

%% Ueff TurbSim
Get_RAWS;
%% Compare EWS to RAWS
idx_trans = 30/0.00625;

%% Calcular RMSE
% Alinear longitudes si es necesario (por si hay desfases o tamaños distintos)
N = min(length(data_table.WE_Vw), length(Ueff2));
WS_real = data_table.WE_Vw(1:N);
WS_est  = Ueff2(1:N);
% Calcular RMSE
rmse = sqrt(mean((WS_real - WS_est).^2));

% Mostrar RMSE en consola
fprintf('RMSE entre estimación y RAWS: %.4f m/s\n', rmse);
%%
%% Cargar RAWS
Get_RAWS; % Esto debería dejar en data_table.WE_Vw la medición real

% Lista de archivos .RO y valores de dt_rise
archivos = { ...
    '../Test_Tarnowski_OF/Study_dt_rise/IEA-3.4-130-RWT_Tarnowski_dt_rise_05.RO.dbg', ...
    '../Test_Tarnowski_OF/Study_dt_rise/IEA-3.4-130-RWT_Tarnowski_dt_rise_1.RO.dbg', ...
    '../Test_Tarnowski_OF/Study_dt_rise/IEA-3.4-130-RWT_Tarnowski_dt_rise_2.RO.dbg' ...
};
dt_rise_vals = [0.5, 1, 2]; % segundos, para el eje X del plot

% Inicializar vector para RMSE
rmse_vals = zeros(size(dt_rise_vals));

%% Loop sobre cada archivo
for i = 1:length(archivos)
    % Cargar la estimación de ese caso
    data_table = read_ROSCO_dbg(archivos{i});
    
    % Alinear longitudes (por si no coinciden)
    %N = min(length(data_table.WE_Vw), length(Ueff2));
    WS_real = data_table.WE_Vw(1:N);
    WS_est  = Ueff2(1:N);
    
    % Calcular RMSE
    rmse_vals(i) = sqrt(mean((WS_real - WS_est).^2));
end

%% Plot RMSE vs dt_rise
figure;
plot(dt_rise_vals, rmse_vals, '-o', 'LineWidth', 1.5, 'MarkerSize', 8);
xlabel('dt\_rise [s]');
ylabel('RMSE [m/s]');
title('Error estimación vs dt\_rise');
grid on;

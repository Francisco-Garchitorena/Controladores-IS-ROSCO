%%
filename = '../Test_Tarnowski_OF/IEA-3.4-130-RWT_Tarnowski_IS_75s.RO.dbg';
data_table = read_ROSCO_dbg(filename);
[Channels, ChanName, ChanUnit, FileID, DescStr] = ReadFASTbinary('../Test_Tarnowski_OF/IEA-3.4-130-RWT_Tarnowski_IS_75s.outb');

%% Ueff TurbSim
Get_RAWS;
%% Compare EWS to RAWS
idx_trans = 30/0.00625;
figure;
plot(data_table.Time, data_table.WE_Vw, 'LineWidth', 1.2); hold on;
plot(Disturbance.Ueff.time, Ueff2,  'LineWidth', 1.2); hold on;
xlabel('Tiempo [s]');
legend ('estimated','RAWS')
ylabel('WS [m/s]');
title('Estimated WS vs RAWS');
xlim([60 data_table.Time(end)]);

%%
% Definir tamaño de fuente a elección del usuario
fontsize = 14;  % Cambia este valor según quieras

%%

% Encontrar índice de la variable 'RotTorq'
idx = find(strcmp(ChanName, 'RotTorq'));
% Plot
figure;
plot(Channels(idx_trans:end, 1), Channels(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
plot(data_table.Time(idx_trans:end), data_table.Tau_r(idx_trans:end)/1e3, 'LineWidth', 1.5);
ylabel('Torque aerodinamico estimado [Nm]', 'Interpreter', 'latex', 'FontSize', fontsize);
xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
legend('Real', 'Estimado', 'Interpreter', 'latex', 'FontSize', fontsize)
grid on;
title('Torque aerodinamico estimado vs real', 'Interpreter', 'latex', 'FontSize', fontsize);
xlim([30 200])
%%
% Velocidad de giro
% Extraer tiempo
time = data_table.Time;
% Encontrar índice de la variable 'GenSpeed'
idx = find(strcmp(ChanName, 'GenSpeed'));
% Plot
figure;
plot(Channels(idx_trans:end, 1), Channels(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
yline(0.7*118.1754100000*30/pi, 'LineWidth', 1.5);   %1rpm = pi/30 rad/s
ylabel('Gen Speed [rad/s]', 'Interpreter', 'latex', 'FontSize', fontsize);
xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
legend('Serie temporal', '$70 \% \Omega_{rated}$', 'Interpreter', 'latex', 'FontSize', fontsize)
grid on;
title('Velocidad de giro', 'Interpreter', 'latex', 'FontSize', fontsize);
xlim([30 200])

%% Potencia generada


% Encontrar índice de la variable 'RotTorq'
idx = find(strcmp(ChanName, 'GenPwr'));
% Plot
figure;
plot(Channels(idx_trans:end, 1), Channels(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
ylabel('Potencia generada [kW]', 'Interpreter', 'latex', 'FontSize', fontsize);
xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
%legend('Real', 'Estimado', 'Interpreter', 'latex', 'FontSize', fontsize)
grid on;
title('Potencia generada', 'Interpreter', 'latex', 'FontSize', fontsize);
xlim([30 200])

%% Parámetros
[Channels, ChanName, ChanUnit, FileID, DescStr] = ReadFASTbinary('../Test_Tarnowski_OF/IEA-3.4-130-RWT_Tarnowski_IS_75s.outb');

% Velocidad nominal en rpm (tú la definiste así)
omega_rated = 118.1754100000*30/pi; % rpm, directamente de tu dato

%% Extraer señales de interés

% Velocidad rotacional en rpm
idx_omega = find(strcmp(ChanName, 'GenSpeed'));
omega_gen = Channels(:, idx_omega);

% Torque (ejemplo, ajustá si querés otro)
idx_torque = find(strcmp(ChanName, 'RotTorq'));
torque = Channels(:, idx_torque);

% Aceleración Fore-Aft (ejemplo para análisis de frecuencias)
idx_acc = find(strcmp(ChanName, 'QD2_TFA1'));
acc_FA = Channels(:, idx_acc);

% Tiempo: lo calculamos asumiendo paso uniforme con base en data_table (si tenés)
dt = mean(diff(data_table.Time)); % tiempo entre muestras [s]
N = size(Channels, 1);
time = (0:N-1)' * dt;

%% Índices para velocidades bajas y altas (70% omega_rated)
idx_baja = omega_gen < 0.7*omega_rated;
idx_alta = omega_gen >= 0.7*omega_rated;

%% Función auxiliar para calcular FFT y magnitud
function [f, P] = compute_fft(signal, Fs)
    Nsig = length(signal);
    Y = fft(signal - mean(signal));
    P_full = abs(Y/Nsig);
    f = Fs*(0:(Nsig/2))/Nsig;
    P = P_full(1:Nsig/2+1);
end

Fs = 1/dt; % frecuencia de muestreo [Hz]

%% FFT para aceleración Fore-Aft a bajas velocidades
[f_baja_acc, P_baja_acc] = compute_fft(acc_FA(idx_baja), Fs);

%% FFT para aceleración Fore-Aft a altas velocidades
[f_alta_acc, P_alta_acc] = compute_fft(acc_FA(idx_alta), Fs);

%% Plot comparativo aceleración Fore-Aft
figure;
plot(f_baja_acc, P_baja_acc, 'b', 'DisplayName', 'Vel < 0.7 \omega_{rated}');
hold on;
plot(f_alta_acc, P_alta_acc, 'r', 'DisplayName', 'Vel \geq 0.7 \omega_{rated}');
xlabel('Frecuencia [Hz]');
ylabel('Magnitud FFT');
title('Comparación espectral aceleración Fore-Aft');
legend;
grid on;
xlim([0 5]); % ajustar según interés

%% (Opcional) Repetir para torque

% FFT torque bajas velocidades
[f_baja_tq, P_baja_tq] = compute_fft(torque(idx_baja), Fs);

% FFT torque altas velocidades
[f_alta_tq, P_alta_tq] = compute_fft(torque(idx_alta), Fs);

% Plot torque
figure;
plot(f_baja_tq, P_baja_tq, 'b', 'DisplayName', 'Torque Vel < 0.7 \omega_{rated}');
hold on;
plot(f_alta_tq, P_alta_tq, 'r', 'DisplayName', 'Torque Vel \geq 0.7 \omega_{rated}');
xlabel('Frecuencia [Hz]');
ylabel('Magnitud FFT');
title('Comparación espectral torque');
legend;
grid on;
xlim([0 5]);

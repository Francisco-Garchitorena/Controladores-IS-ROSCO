close all; clear all; clc;
Wind_condition = "v9_TI5";

file_norm = "../Test_Wang_OF/NREL5MW/" + Wind_condition + "/NRELOffshrBsline5MW_norm_op_" + Wind_condition + ".outb";
file_wang = "../Test_Wang_OF/NREL5MW/" + Wind_condition + "/NRELOffshrBsline5MW_Wang_"    + Wind_condition + ".outb";

[Channels_norm_op, ChanName_norm_op, ChanUnit, FileID, DescStr] = ReadFASTbinary(file_norm);
[Channels_Wang,    ChanName_Wang,    ChanUnit, FileID, DescStr] = ReadFASTbinary(file_wang);

start_end = [360 400];
%start_end = [60 660];
idx_trans = 60/0.00625;
fontsize =14;

%% Edgewise
figure; subplot(5,1,1);
idx = find(strcmp(ChanName_norm_op, 'RootMxb1'));
idx_Wang = find(strcmp(ChanName_Wang, 'RootMxb1'));

% Plot
plot(Channels_norm_op(idx_trans:end, 1), Channels_norm_op(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
plot(Channels_Wang(idx_trans:end, 1), Channels_Wang(idx_trans:end, idx_Wang), 'LineWidth', 1.5); hold on;
ylabel('Edgewise', 'Interpreter', 'latex', 'FontSize', fontsize);
xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
legend('Operacion normal', 'Wang', 'Interpreter', 'latex', 'FontSize', fontsize)
grid on;
%title('Torque aerodinamico estimado vs real', 'Interpreter', 'latex', 'FontSize', fontsize);
xlim(start_end)
title('Variables analizadas por Wang 2017: NREL5MW', 'Interpreter', 'latex', 'FontSize', fontsize);


%% FlapWise
idx = find(strcmp(ChanName_norm_op, 'RootMyb1'));

% Plot
subplot(5,1,2); fontsize =14;
plot(Channels_norm_op(idx_trans:end, 1), Channels_norm_op(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
plot(Channels_Wang(idx_trans:end, 1), Channels_Wang(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
ylabel('FlapWise [kNm]', 'Interpreter', 'latex', 'FontSize', fontsize);
xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
%legend('Real', 'Estimado', 'Interpreter', 'latex', 'FontSize', fontsize)
grid on;
%title('Torque aerodinamico estimado vs real', 'Interpreter', 'latex', 'FontSize', fontsize);
xlim(start_end)
%% ForeAft
idx = find(strcmp(ChanName_norm_op, 'TwrBsMyt'));

% Plot
subplot(5,1,3); fontsize =14;
plot(Channels_norm_op(idx_trans:end, 1), Channels_norm_op(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
plot(Channels_Wang(idx_trans:end, 1), Channels_Wang(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
ylabel('ForeAft', 'Interpreter', 'latex', 'FontSize', fontsize);
xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
%legend('Real', 'Estimado', 'Interpreter', 'latex', 'FontSize', fontsize)
grid on;
%title('Torque aerodinamico estimado vs real', 'Interpreter', 'latex', 'FontSize', fontsize);
xlim(start_end)
%% SideSide
idx = find(strcmp(ChanName_norm_op, 'TwrBsMxt'));

% Plot
subplot(5,1,4); fontsize =14;
plot(Channels_norm_op(idx_trans:end, 1), Channels_norm_op(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
plot(Channels_Wang(idx_trans:end, 1), Channels_Wang(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
ylabel('SideSide', 'Interpreter', 'latex', 'FontSize', fontsize);
xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
%legend('Real', 'Estimado', 'Interpreter', 'latex', 'FontSize', fontsize)
grid on;
%title('Torque aerodinamico estimado vs real', 'Interpreter', 'latex', 'FontSize', fontsize);
xlim(start_end)

%% Torque gen
idx = find(strcmp(ChanName_norm_op, 'LSSGagMya'));

% Plot
subplot(5,1,5); fontsize =14;
plot(Channels_norm_op(idx_trans:end, 1), Channels_norm_op(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
plot(Channels_Wang(idx_trans:end, 1), Channels_Wang(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
ylabel('LSSGagMya', 'Interpreter', 'latex', 'FontSize', fontsize);
xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
%legend('Real', 'Estimado', 'Interpreter', 'latex', 'FontSize', fontsize)
grid on;
%title('Torque aerodinamico estimado vs real', 'Interpreter', 'latex', 'FontSize', fontsize);
xlim(start_end)

%% Validate Wang OpenFast
Wind_condition = "v9_TI5";

file_norm = "../Test_Wang_OF/NREL5MW/" + Wind_condition + "/NRELOffshrBsline5MW_norm_op_" + Wind_condition + ".outb";
file_wang = "../Test_Wang_OF/NREL5MW/" + Wind_condition + "/NRELOffshrBsline5MW_Wang_"    + Wind_condition + ".outb";

[Channels_norm_op, ChanName_norm_op, ChanUnit, FileID, DescStr] = ReadFASTbinary(file_norm);
[Channels_Wang,    ChanName_Wang,    ChanUnit, FileID, DescStr] = ReadFASTbinary(file_wang);

idx = find(strcmp(ChanName_norm_op, 'GenPwr'));
idx_Wang = find(strcmp(ChanName_Wang, 'GenPwr'));
start_end = [345 450];


figure; subplot(2,1,1);
plot(Channels_norm_op(idx_trans:end, 1), Channels_norm_op(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
plot(Channels_Wang(idx_trans:end, 1), Channels_Wang(idx_trans:end, idx_Wang), 'LineWidth', 1.5); hold on;
ylabel('Potencia Generada [kW]', 'Interpreter', 'latex', 'FontSize', fontsize);
xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
legend('normal op', 'Wang', 'Interpreter', 'latex', 'FontSize', fontsize)
grid on;
title('Wang vs normal Operation: v=8m/s, TI= 5\%', 'Interpreter', 'latex', 'FontSize', fontsize);
xlim(start_end)

idx = find(strcmp(ChanName_norm_op, 'GenSpeed'));
idx_Wang = find(strcmp(ChanName_Wang, 'GenSpeed'));

subplot(2,1,2); plot(Channels_norm_op(idx_trans:end, 1), Channels_norm_op(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
plot(Channels_Wang(idx_trans:end, 1), Channels_Wang(idx_trans:end, idx_Wang), 'LineWidth', 1.5); hold on;
ylabel('Gen Speed [rpm]', 'Interpreter', 'latex', 'FontSize', fontsize);
xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
grid on;
xlim(start_end)

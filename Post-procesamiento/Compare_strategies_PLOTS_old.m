% close all; clear all; clc;
% Wind_condition = "v9_TI10";
% 
% file_norm = "../Test_Wang_OF/NREL5MW/" + Wind_condition + "/NRELOffshrBsline5MW_norm_op_" + Wind_condition + ".outb";
% file_wang = "../Test_Wang_OF/NREL5MW/" + Wind_condition + "/NRELOffshrBsline5MW_Wang_"    + Wind_condition + ".outb";
% file_tarnowski = "../Test_Tarnowski_OF/NREL5MW/" + Wind_condition + "/NRELOffshrBsline5MW_Tarnowski_"    + Wind_condition + ".outb";
% 
% [Channels_norm_op, ChanName_norm_op, ChanUnit, FileID, DescStr] = ReadFASTbinary(file_norm);
% [Channels_Wang,    ChanName_Wang,    ChanUnit, FileID, DescStr] = ReadFASTbinary(file_wang);
% [Channels_Tarnowski, ChanName_Tarnowski, ChanUnit, FileID, DescStr] = ReadFASTbinary(file_tarnowski);
% 
% %start_end = [360 400];
% start_end = [60 660];
% idx_trans = 60/0.00625;
% fontsize =14;
% 
% %% Edgewise
% figure; subplot(5,1,1);
% idx = find(strcmp(ChanName_norm_op, 'RootMxb1'));
% 
% % Plot
% plot(Channels_norm_op(idx_trans:end, 1), Channels_norm_op(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% plot(Channels_Tarnowski(idx_trans:end, 1), Channels_Tarnowski(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% %plot(Channels_Ontario(idx_trans:end, 1), Channels_Ontario(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% plot(Channels_Wang(idx_trans:end, 1), Channels_Wang(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% ylabel('Edgewise [kNm]', 'Interpreter', 'latex', 'FontSize', fontsize);
% xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
% legend('Operacion normal', 'Tarnowski', 'Ontario', 'Wang', 'Interpreter', 'latex', 'FontSize', fontsize)
% grid on;
% %title('Torque aerodinamico estimado vs real', 'Interpreter', 'latex', 'FontSize', fontsize);
% xlim(start_end)
% 
% 
% %% FlapWise
% idx = find(strcmp(ChanName_norm_op, 'RootMyb1'));
% 
% % Plot
% subplot(5,1,2); fontsize =14;
% plot(Channels_norm_op(idx_trans:end, 1), Channels_norm_op(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% plot(Channels_Tarnowski(idx_trans:end, 1), Channels_Tarnowski(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% %plot(Channels_Ontario(idx_trans:end, 1), Channels_Ontario(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% plot(Channels_Wang(idx_trans:end, 1), Channels_Wang(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% ylabel('FlapWise [kNm]', 'Interpreter', 'latex', 'FontSize', fontsize);
% xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
% %legend('Real', 'Estimado', 'Interpreter', 'latex', 'FontSize', fontsize)
% grid on;
% %title('Torque aerodinamico estimado vs real', 'Interpreter', 'latex', 'FontSize', fontsize);
% xlim(start_end)
% %% ForeAft
% idx = find(strcmp(ChanName_norm_op, 'TwrBsMyt'));
% %idx_Ontario = find(strcmp(ChanName_Ontario, 'TwrBsMyt'));
% 
% % Plot
% subplot(5,1,3); fontsize =14;
% plot(Channels_norm_op(idx_trans:end, 1), Channels_norm_op(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% plot(Channels_Tarnowski(idx_trans:end, 1), Channels_Tarnowski(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% %plot(Channels_Ontario(idx_trans:end, 1), Channels_Ontario(idx_trans:end, idx_Ontario), 'LineWidth', 1.5); hold on;
% plot(Channels_Wang(idx_trans:end, 1), Channels_Wang(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% ylabel('ForeAft [kNm]', 'Interpreter', 'latex', 'FontSize', fontsize);
% xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
% %legend('Real', 'Estimado', 'Interpreter', 'latex', 'FontSize', fontsize)
% grid on;
% %title('Torque aerodinamico estimado vs real', 'Interpreter', 'latex', 'FontSize', fontsize);
% xlim(start_end)
% %% SideSide
% idx = find(strcmp(ChanName_norm_op, 'TwrBsMxt'));
% 
% % Plot
% subplot(5,1,4); fontsize =14;
% plot(Channels_Wang(idx_trans:end, 1), Channels_Wang(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% plot(Channels_norm_op(idx_trans:end, 1), Channels_norm_op(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% ylabel('SideSide [kNm]', 'Interpreter', 'latex', 'FontSize', fontsize);
% xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
% %legend('Real', 'Estimado', 'Interpreter', 'latex', 'FontSize', fontsize)
% grid on;
% %title('Torque aerodinamico estimado vs real', 'Interpreter', 'latex', 'FontSize', fontsize);
% xlim(start_end)
% 
% %% LSSGagMya
% %idx_Ontario = find(strcmp(ChanName_Ontario, 'GenTq'));
% idx = find(strcmp(ChanName_norm_op, 'GenTq'));
% 
% % Plot
% subplot(5,1,5); fontsize =14;
% plot(Channels_norm_op(idx_trans:end, 1), Channels_norm_op(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% plot(Channels_Tarnowski(idx_trans:end, 1), Channels_Tarnowski(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% %plot(Channels_Ontario(idx_trans:end, 1), Channels_Ontario(idx_trans:end, idx_Ontario), 'LineWidth', 1.5); hold on;
% plot(Channels_Wang(idx_trans:end, 1), Channels_Wang(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% ylabel('Torque Gen [kNm]', 'Interpreter', 'latex', 'FontSize', fontsize);
% xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
% %legend('Real', 'Estimado', 'Interpreter', 'latex', 'FontSize', fontsize)
% grid on;
% %title('Torque aerodinamico estimado vs real', 'Interpreter', 'latex', 'FontSize', fontsize);
% xlim(start_end)
% 
% 
% %% Gen power
% idx = find(strcmp(ChanName_norm_op, 'GenPwr'));
% idx_Ontario = find(strcmp(ChanName_Ontario, 'GenPwr'));
% 
% % Plot
% figure; fontsize =14;
% plot(Channels_norm_op(idx_trans:end, 1), Channels_norm_op(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% plot(Channels_Tarnowski(idx_trans:end, 1), Channels_Tarnowski(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% %plot(Channels_Ontario(idx_trans:end, 1), Channels_Ontario(idx_trans:end, idx_Ontario), 'LineWidth', 1.5); hold on;
% plot(Channels_Wang(idx_trans:end, 1), Channels_Wang(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
% ylabel('Gen Power [kW]', 'Interpreter', 'latex', 'FontSize', fontsize);
% xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
% %legend('Real', 'Estimado', 'Interpreter', 'latex', 'FontSize', fontsize)
% grid on;
% legend('Operacion normal', 'Tarnowski', 'Ontario', 'Wang', 'Interpreter', 'latex', 'FontSize', fontsize)
% 
% %title('Torque aerodinamico estimado vs real', 'Interpreter', 'latex', 'FontSize', fontsize);
% xlim(start_end)
close all; clear; clc;

%% Parámetros
Turbine = "IEA_3p4MW"; %"NREL5MW";%"IEA_3p4MW"; %
Wind_Condition = "v8_TI10";
turbine_base_name = "IEA-3.4-130-RWT"; %"NRELOffshrBsline5MW"; %"IEA-3.4-130-RWT"; %

simulations = {
    fullfile("../Operacion_normal", Turbine, Wind_Condition, turbine_base_name + "_norm_op_" + Wind_Condition + ".outb")
    fullfile("../Test_Tarnowski_OF", Turbine, Wind_Condition, turbine_base_name + "_Tarnowski_" + Wind_Condition + ".outb")
    fullfile("../Test_Wang_OF", Turbine, Wind_Condition, turbine_base_name + "_Wang_" + Wind_Condition + ".outb")
};

simulations_names = {'Operacion normal','Tarnowski','Wang'};

variables = {'RootMyb1','RootMxb1','TwrBsMyt','TwrBsMxt'}; %,'GenPwr'
varnames  = {'FlapWise','EdgeWise','ForeAft','SideSide'}; %,'Gen Power'
ylabels   = {'[kNm]','[kNm]','[kNm]','[kNm]'}; %,'[kW]'

other_variables = {'GenPwr','GenTq','GenSpeed','RotPwr'}; %,
other_varnames  = {'Gen Power','Gen Torque','Gen Speed','Rotor Power'}; %,
other_ylabels   = {'[kW]','[kNm]','[rpm]','[kW]'}; %,'[kW]'

start_end = [300 550];
idx_trans = start_end(1)/0.00625;
fontsize = 14;

%% Leer todos los archivos
Channels = cell(1,length(simulations));
ChanName = cell(1,length(simulations));

for s = 1:length(simulations)
    [Channels{s}, ChanName{s}, ~, ~, ~] = ReadFASTbinary(simulations{s});
end

%% Graficar cargas
figure('Units','normalized','OuterPosition',[0 0 1 1]); 
set(gcf,'Color','w');
sgtitle(sprintf('Structural Loads: comparison between strategies: %s',Turbine), 'Interpreter','latex', 'FontSize',16);

for v = 1:length(variables)
    subplot(length(variables)-2,2,v); hold on;
    
    for s = 1:length(simulations)
        idx = find(strcmp(ChanName{s}, variables{v}));
        plot(Channels{s}(idx_trans:end,1), Channels{s}(idx_trans:end,idx), 'LineWidth', 1.5, 'DisplayName',simulations_names{s});
    end
    xline(360,'LineWidth',1.5, 'LineStyle','--', 'DisplayName','Start IS');
    
    ylabel([varnames{v} ' ' ylabels{v}], 'Interpreter','latex','FontSize',fontsize);
    xlabel('Tiempo [s]', 'Interpreter','latex','FontSize',fontsize);
    grid on; xlim(start_end);
    set(gca,'TickLabelInterpreter','latex','FontSize',fontsize);
end
legend('Interpreter','latex','FontSize',fontsize,'Location','NorthEast');
exportgraphics(gcf, sprintf('Fatigue_analysis/Imagenes/%s/Cargas_comp_estrategias.png', Turbine), 'Resolution', 300);



%% Graficar series no cargas
figure('Units','normalized','OuterPosition',[0 0 1 1]); 
set(gcf,'Color','w');
sgtitle(sprintf('Other variables: comparison between strategies: %s',Turbine), 'Interpreter','latex', 'FontSize',16);

for v = 1:length(other_variables)
    subplot(length(other_variables)-2,2,v); hold on;
    
    idx = find(strcmp(ChanName{1}, other_variables{v}));
    
    for s = 1:length(simulations)
        plot(Channels{s}(idx_trans:end,1), Channels{s}(idx_trans:end,idx), 'LineWidth', 1.5, 'DisplayName',simulations_names{s});
    end
    xline(360,'LineWidth',1.5, 'LineStyle','--', 'DisplayName','Start IS');
    
    ylabel([other_varnames{v} ' ' other_ylabels{v}], 'Interpreter','latex','FontSize',fontsize);
    xlabel('Tiempo [s]', 'Interpreter','latex','FontSize',fontsize);
    grid on; xlim(start_end);
    set(gca,'TickLabelInterpreter','latex','FontSize',fontsize);
end
legend('Interpreter','latex','FontSize',fontsize,'Location','NorthEast');

exportgraphics(gcf, sprintf('Fatigue_analysis/Imagenes/%s/Otras_variables_comp_estrategias.png', Turbine), 'Resolution', 300);

%close all
clear; clc;
addpath Fatigue_analysis\
% SCRIPT USADO PARA COMPARAR SERIES TEMPORALES ENTRE ESTRATEGIAS Y SEMILLAS
% ULTIMO USO: 29/09/25

%% Parámetros
Turbine = "IEA3p4MW_24_seeds";
turbine_base_name = "IEA-3.4-130-RWT";

% Velocidad y TI fijos
Vstr  = "8.0"; 
TI    = "TI8.0";

% Estrategias a comparar
estrategias = {'Norm_op','Tarnowski', 'Wang','GMFC'};
estrategia_names = {'Normal operation','Stepwise','Torque-limit','Proposed strategy'};

% Variable a graficar (solo potencia)
op_variable = "GenPwr";   % Potencia generada "RotSpeed";
op_varname  = "$P_\mathrm{gen}$"; %"$\Omega$";
op_ylabel   = "[kW]"; %"[rpm]";

% Intervalo de tiempo para mostrar
start_end = [340 550]; % [s]
idx_trans = start_end(1)/0.00625;
fontsize = 14;
colores = [0.4660 0.6740 0.1880; 0.9 0 0; 
           0.9290 0.6940 0.1250;
           0 0.4470 0.7410]; 
%% Paths de simulación
base_path = "E:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO/Torque_2026_" + Turbine;

%% Selección de semillas
% Puedes elegir manualmente
selectedSeeds = [0 4 6 8 13 20];   % Ejemplo
%selectedSeeds = 0:23;             % Todas las 24 semillas
%selectedSeeds = [0];
nSeeds = numel(selectedSeeds);

Channels = cell(length(estrategias), nSeeds);
ChanName = cell(length(estrategias), nSeeds);

for i = 1:nSeeds
    sd = selectedSeeds(i);
    seed = "sd" + string(sd);
    Wind_Condition = "v" + Vstr + "_" + TI + "_" + seed;

    for e = 1:length(estrategias)
        estrategia = estrategias{e};
        file = fullfile(base_path, estrategia, Vstr, TI, seed, ...
            turbine_base_name + "_" + estrategia + "_" + Wind_Condition + ".outb");
        [Channels{e,i}, ChanName{e,i}, ~, ~, ~] = ReadFASTbinary(file);
    end
end

%% Graficar potencia en subplots
%close all;
figure('Units','normalized','OuterPosition',[0 0 1 1], 'Color','w');

% 2 filas, columnas = ceil(nSeeds/2)
nRows = 2; fs =26;
nCols = ceil(nSeeds/nRows);
t = tiledlayout(nRows,nCols,'TileSpacing','compact','Padding','compact'); 

for i = 1:nSeeds
    sd = selectedSeeds(i);
    nexttile; hold on;
    for e = 1:length(estrategias)
        idx = find(strcmp(ChanName{e,i}, op_variable));
        plot(Channels{e,i}(idx_trans:end,1), Channels{e,i}(idx_trans:end,idx), ...
            'Color',colores(e,:),'LineWidth', 2, 'DisplayName',estrategia_names{e});
    end
    xline(360,'LineWidth',1.5,'LineStyle','--','HandleVisibility','off');
    title(sprintf('Seed %d',sd+1),'Interpreter','latex','FontSize',fs-4);
    grid on; xlim(start_end); ylim([500 3200])
    set(gca,'TickLabelInterpreter','latex','FontSize',fs-4);
    if i==1
        legend('Interpreter','latex','FontSize',fs-6,'Location','NorthEast');
    end
end

xlabel(t,'Time [s]','Interpreter','latex','FontSize',fs);
ylabel(t, sprintf('%s %s',op_varname,op_ylabel),'Interpreter','latex','FontSize',fs);
%set(gca,'FontSize',fs)
%title(t, sprintf('Comparación de Potencia - %s, v=%s m/s, %s',Turbine,Vstr,TI), ...
 %   'Interpreter','latex','FontSize',16);
 
%%
%exportgraphics(gcf, sprintf('Fatigue_analysis/Imagenes/Torque_2026_FINAL/Comparacion_Potencia_v%s_%s_komega2.png',Vstr,TI), 'Resolution', 300);
exportgraphics(gcf, sprintf('Fatigue_analysis/Imagenes/Journal_final/Comparacion_Potencia_v%s_%s_komega2.png',Vstr,TI), 'Resolution', 300);

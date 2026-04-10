addpath ../
%% Parámetros
Turbine = "IEA3p4MW"; %         
turbine_base_name = "IEA-3.4-130-RWT"; %  
base_path = "E:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO/Torque_2026_" + Turbine + "_24_seeds";

% Velocidades, TI y semilla
velocidades = [7.0, 8.0, 9.0]; velocidades = [7.5, 8.5, 9.5];
TI = "TI8.0";
sd = "sd0";

% Estrategias
estrategias = {'GMFC','Tarnowski','Wang'};

% Variables a analizar
variables = {'GenTq','GenSpeed','RotPwr'};
varnames  = {'GenTq','GenSpeed','RotPwr'};

% Inicializar estructura para guardar resultados
Data = struct();

for v = 1:length(velocidades)
    Vstr = sprintf('V%.1f', velocidades(v));
    Vstr = strrep(Vstr, '.', '_');   % "7.0" -> "7_0"    
    Wind_Condition = "v" + sprintf("%.1f", velocidades(v)) + "_" + TI + "_sd0";
    
    for e = 1:length(estrategias)
        estrategia = estrategias{e};
        
        % Construir path
        file_path = fullfile(base_path, ...
            estrategia, sprintf("%.1f", velocidades(v)), TI, sd, ...
            turbine_base_name + "_" + lower(estrategia) + "_" + Wind_Condition + ".outb");
        
        fprintf("Procesando: %s\n", file_path);
        
        % Leer archivo
        [tSeries, ChanName, ~, ~, ~] = ReadFASTbinary(file_path);
        
        % Guardar en estructura
        Data.(Vstr).(estrategia).tSeries   = tSeries;
        Data.(Vstr).(estrategia).ChanName  = ChanName;
    end
end


%% Curvas de referencia
OmegaAll = linspace(118.1754100000/97*0.4, 118.1754100000/97, 200); % rad/s

% Cp curves
Cp_lambda = xlsread('Cp_IEA_34.xlsx');
R = 65; % [m]
rho = 1.225;

P_ref = struct();
for v = velocidades
    TSR = OmegaAll .* R ./ v;
    Cp = interp1(Cp_lambda(:,1), Cp_lambda(:,2), TSR, 'linear', 'extrap');
    Vstr = strrep(sprintf("V%.1f",v),'.','_');  % "V7.0" -> "V7_0"
P_ref.(Vstr) = 0.5*rho*pi*R^2*v^3 .* Cp;
end

% KgOmega³
Kg = 2.305910000000e6; %1.825346e6; %2.305910000000
PKgOmega3 = Kg.*OmegaAll.^3;


%% Plot
figure; hold on;
set(gcf,'color','white')
set(groot, 'DefaultTextInterpreter', 'latex'); 
set(groot, 'DefaultAxesTickLabelInterpreter', 'latex'); 
set(groot, 'defaultLegendInterpreter','latex'); 

% 1) Curvas teóricas
cols = {'g','r','b'};
for i = 1:length(velocidades)
    v = velocidades(i);
    Vstr = sprintf('V%.1f',v); Vstr = strrep(Vstr,'.','_');
    plot(OmegaAll*30/pi, P_ref.(Vstr)/1e6, [cols{i} '--'], 'LineWidth', 1.5);
end
plot(OmegaAll*30/pi, PKgOmega3/1e6,'k','LineWidth',1.5);
%%
figure
% 2) Simulaciones OpenFAST
start_IS = 359/0.00625;
end_IS = 500/0.00625;
for i = 1:length(velocidades)
    v = velocidades(i);
    Vstr = sprintf('V%.1f',v); Vstr = strrep(Vstr,'.','_');
    for e = 1:length(estrategias)
        estrategia = estrategias{e};
        ChanName = Data.(Vstr).(estrategia).ChanName;
        tSeries  = Data.(Vstr).(estrategia).tSeries;
        
        % indices de variables
        idxOmega = find(strcmp(ChanName,'GenSpeed'));   % [rad/s]
        idxGenTq   = find(strcmp(ChanName,'GenTq'));     % [W] (o RotPwr si usas eso)
        
        OmegaSim = tSeries(:,idxOmega);  % rad/s
        GenTq     = tSeries(:,idxGenTq);    % W
        
        plot(OmegaSim(start_IS:end_IS)/97, GenTq(start_IS:end_IS).*OmegaSim(start_IS:end_IS)*pi/30/97/1e3, cols{i}, 'LineWidth',1.5); hold on;
    end
end

xlabel('$Rotor Speed$ [RPM]')
ylabel('$Power$ [MW]')
legend({'P-7m/s','P-8m/s','P-9m/s','$K_g\Omega^3$', ...
        'Sim-7m/s','Sim-8m/s','Sim-9m/s'},'Location','northwest')
grid on; box on
title('\textbf{Potencia vs RPM}','FontSize',14)

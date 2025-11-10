addpath ../
%% Parámetros
Turbine = "IEA3p4MW"; %         
turbine_base_name = "IEA-3.4-130-RWT"; %  
base_path = "C:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO/Torque_2026_" + Turbine;

% Velocidades, TI y semilla
velocidades = [8.0];

uBEM_Tarnowski = load('../uBEM/Tarnowski_U-8ms_uniform_start-100s_step-1.1_recovery-0.04.mat','uBEM');
%uBEM_Wang = load('../uBEM/Wang_U-8ms_uniform_start-100s_OmegaMin-0.4Rated.mat','uBEM');
uBEM_Wang = load('../uBEM/Wang_U-8ms_uniform_start-100s_OmegaMin-0.4Rated.mat','uBEM');

% Estrategias
estrategias = {'Wang','Tarnowski'};

% Variables a analizar
variables = {'GenTq','GenSpeed','RotPwr'};
varnames  = {'GenTq','GenSpeed','RotPwr'};

%% Curvas de referencia
OmegaAll = linspace(118.1754100000/97*0.4, 118.1754100000/97, 200); % rad/s
OmegaAll = [uBEM_Tarnowski.uBEM.RotorSpeed ; uBEM_Wang.uBEM.RotorSpeed];
OmRated = 11.667*2*pi/60;
OmegaMin = OmRated*0.4;
OmegaAll = [OmegaMin:0.01:OmRated]; 
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
Kg = 1.825346e6; %Kg = 2.305910000000e6; %1.825346e6; %2.305910000000
PKgOmega3 = Kg.*OmegaAll.^3;

%%
% load('C:\Users\fgarchitorena\OneDrive - Facultad de Ingeniería\Inercia Sintética - Colab David\ubem-matlab-desafiosUTE 1\Test_cp_lambda_SIon_thin.mat')
% figure; plot(lambda_reg2,c_P_reg2)
% v= 8;
% 
% 
% R = 65; % [m]
% rho = 1.225;
% OmRated = 11.667*2*pi/60;
% OmegaMin = OmRated*0.4;
% OmegaAll = [OmegaMin:0.01:OmRated]; 
% TSR = OmegaAll .* R ./ v;
% Cp2 = interp1(lambda_reg2(1,:), c_P_reg2(1,:), TSR, 'linear', 'extrap');
% P_ref2= 0.5*rho*pi*R^2*v^3 .* Cp2;
% 
%    figure;  plot(OmegaAll*30/pi, P_ref2/1e6, 'LineWidth', 1.5);
% plot(OmegaAll*30/pi, P_ref2/1e6, 'b--','LineWidth', 1.5);

%% Plot
figure('Units','normalized','OuterPosition',[0 0 0.65 0.65]); % ventana cuadrada
%axis square   % fuerza a que los ejes tengan la misma escala
hold on;

titlesize = 20; % Title Size
sizenumaxis = 20; % Size num axis
sizeXlabelaxis = 20; % Size Xlabel
sizeYlabelaxis = 23; % Size Ylabel
linesize = 1.5; % Line size figure
mediansize = 1; % Median
sizelegend = 18;

min_power = 0;
max_power = 2.5;

set(groot, 'DefaultTextInterpreter', 'latex'); % Fig Latex
set(groot, 'DefaultAxesTickLabelInterpreter', 'latex'); % Axis Latex
set(groot, 'defaultLegendInterpreter','latex'); % Legend Latex 

set(gcf,'color','white') 

% 1) Curvas teóricas
cols = {'g','r','b'};
for i = 1:length(velocidades)
    v = velocidades(i);
    Vstr = sprintf('V%.1f',v); Vstr = strrep(Vstr,'.','_');
    plot(OmegaAll*30/pi, P_ref.(Vstr)/1e6, [cols{i} '--'], 'LineWidth', 1.5);
end

plot(OmegaAll*30/pi, PKgOmega3/1e6,'k','LineWidth',1.5);
%%


Prated = 3.438776e6;    % Rated Power [W]

Mgen_rated = Prated / OmRated; % Rated generator torque [Nm]
Mgen_max   = Mgen_rated * 1.09; % Maximum generator torque [Nm]


Mgen_prime = 10 * 15000.0  * 97;  % Maximum torque rate operation [Nm/s] -> Increase by x10 (= not used) 
plot(uBEM_Tarnowski.uBEM.RotorSpeed(499:1000).*30./pi,uBEM_Tarnowski.uBEM.GeneratorTorque(499:1000).*uBEM_Tarnowski.uBEM.RotorSpeed(499:1000)./(1e6),'g', 'LineWidth', linesize)
plot(uBEM_Wang.uBEM.RotorSpeed(499:1000).*30./pi,uBEM_Wang.uBEM.GeneratorTorque(499:1000).*uBEM_Wang.uBEM.RotorSpeed(499:1000)./(1e6),'r', 'LineWidth', linesize)
plot([OmegaMin*30/pi OmegaMin*30/pi],[0 4],'k--', 'LineWidth', linesize)
plot([OmRated*0.703*30/pi OmRated*0.703*30/pi],[0 4],'b--', 'LineWidth', linesize)
plot(OmegaAll*30/pi, OmegaAll.*Mgen_max/1e6, 'LineWidth', linesize)
%plot([time3(Itim_SI) time3(Itim_SI)],[min_power max_power],'k--', 'LineWidth', linesize)

xlabel('Rotor Speed (RPM)','interpreter','latex')
ylabel('$P_{\mathrm{gen}}$ (MW)','interpreter','latex')
ax = gca; % Size Axis
set(gca,'TickLabelInterpreter','latex')
ax.FontSize = sizenumaxis; % Size Axis 2.0
ax.XLabel.FontSize = sizeXlabelaxis;
ax.YLabel.FontSize = sizeYlabelaxis;
% axis([30 time1(end) 0.5 3.7]);
%xticks(120:20:200) % Adjust the scale of the axes
  
legend({'P($\Omega$) $8$ m/s','MPPT curve','StepWise strategy','Torque-Limit Strategy','$\Omega_{\mathrm{min}}$','$70\% \Omega_{\mathrm{rated}}$','$\mathrm{T}_{\mathrm{max}}$'},'FontSize',sizelegend,'Location','northwest')

colormap(prism);
grid on;
box on
hold off
title({'$\textbf{IC strategies}$'},'FontSize',titlesize,'interpreter','latex')
exportgraphics(gcf,'../Fatigue_analysis/Imagenes/Torque_2026/P_omega_strategies.png','Resolution',300);


% xlabel('$Rotor Speed$ [RPM]')
% ylabel('$Power$ [MW]')
% legend({'P-7m/s','P-8m/s','P-9m/s','$K_g\Omega^3$', ...
%         'Sim-7m/s','Sim-8m/s','Sim-9m/s'},'Location','northwest')
% grid on; box on
% title('\textbf{Potencia vs RPM}','FontSize',14)

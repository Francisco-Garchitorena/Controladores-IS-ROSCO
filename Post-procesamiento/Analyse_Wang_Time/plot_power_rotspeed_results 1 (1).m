clear all

%% Load data

Folder = 'Pruebas_iniciales';

Case0 = 7; % Casos base sin turbulencia
Case1 = 8; % La variación es la velocidad de viento
Case2 = 9; % Case_1 = 7ms, Case_2 = 8ms, Case_3 = 9ms

dt = 0.2; % [s] 
Itim_SI = 500; % Time step where synthetic inertia begins
Ftim_SI = 6000; % Time step where the synthetic inertia ends

% Case 0
load(['./' Folder '/U-' num2str(Case0) 'ms_n-0.mat']);
uBEM0 = uBEM;
% Case 1
load(['./' Folder '/U-' num2str(Case1) 'ms_n-0.mat']);
uBEM1 = uBEM;
% Case 2
load(['./' Folder '/U-' num2str(Case2) 'ms_n-0.mat']);
uBEM2 = uBEM;


time1 = [dt:dt:length(uBEM1.Power)*0.2];
time2 = [dt:dt:length(uBEM2.Power)*0.2];


%% Power
% s_d  = ['Salome, media: ', num2str(mean(Cd(:,1)))];
% c_d = ['caffa, media: ', num2str(mean(Cd(:,2)))];
% 
% s_l  = ['Salome, media: ', num2str(mean(Cl(:,1)))];
% c_l = ['caffa, media: ', num2str(mean(Cl(:,2)))];
figure;

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

subplot(2,2,1) % 

hold on; 

plot(time1,uBEM0.Power./(1e6),'g', 'LineWidth', linesize)
plot(time1,uBEM1.Power./(1e6),'r', 'LineWidth', linesize)
plot(time2,uBEM2.Power./(1e6),'b', 'LineWidth', linesize)

%plot([time3(Itim_SI) time3(Itim_SI)],[min_power max_power],'k--', 'LineWidth', linesize)

xlabel('$t(s)$','interpreter','latex')
ylabel('$Aero Power (MW)$','interpreter','latex')
ax = gca; % Size Axis
ax.FontSize = sizenumaxis; % Size Axis 2.0
ax.XLabel.FontSize = sizeXlabelaxis;
ax.YLabel.FontSize = sizeYlabelaxis;
axis([30 time1(end) 0.5 3.7]);
%xticks(120:20:200) % Adjust the scale of the axes
  
legend({'$7$ m/s','$8$ m/s','$9$ m/s'},'FontSize',sizelegend,'Location','southwest')

colormap(prism);
grid on;
box on
hold off
title({'\textbf{Aero Power}'},'FontSize',titlesize)

subplot(2,2,2) 

hold on; 

plot(time1,uBEM0.GeneratorTorque.*uBEM0.RotorSpeed./(1e6),'g', 'LineWidth', linesize)
plot(time1,uBEM1.GeneratorTorque.*uBEM1.RotorSpeed./(1e6),'r', 'LineWidth', linesize)
plot(time2,uBEM2.GeneratorTorque.*uBEM2.RotorSpeed./(1e6),'b', 'LineWidth', linesize)

%plot(t(:,2),Cl(:,2),'b')

xlabel('$t(s)$','interpreter','latex')
ylabel('$Power Gen (MW)$','interpreter','latex')
ax = gca; % Size Axis
ax.FontSize = sizenumaxis; % Size Axis 2.0
ax.XLabel.FontSize = sizeXlabelaxis;
ax.YLabel.FontSize = sizeYlabelaxis;
axis([30 time1(end) 0.5 3.7]);
%xticks(0:1000:10000) % Adjust the scale of the axes
  
legend({'$7$ m/s','$8$ m/s','$9$ m/s'},'FontSize',sizelegend,'Location','southwest')

colormap(prism);
grid on;
box on
hold off
title({'\textbf{Power Generator}'},'FontSize',titlesize)

subplot(2,2,3)

min_speed = 0;
max_speed = 10;

hold on; 

plot(time1,uBEM0.RotorSpeed.*(30/pi),'g', 'LineWidth', linesize)
plot(time1,uBEM1.RotorSpeed.*(30/pi),'r', 'LineWidth', linesize)
plot(time2,uBEM2.RotorSpeed.*(30/pi),'b', 'LineWidth', linesize)

%plot([time3(Itim_SI) time3(Itim_SI)],[min_speed max_speed],'k--', 'LineWidth', linesize)


xlabel('$t(s)$','interpreter','latex')
ylabel('$Rotor Speed (RPM)$','interpreter','latex')
ax = gca; % Size Axis
ax.FontSize = sizenumaxis; % Size Axis 2.0
ax.XLabel.FontSize = sizeXlabelaxis;
ax.YLabel.FontSize = sizeYlabelaxis;
axis([30 time1(end) 4 12]);
%yticks(0:1:10) % Adjust the scale of the axes
  
legend({'$7$ m/s','$8$ m/s','$9$ m/s'},'FontSize',sizelegend,'Location','southwest')

colormap(prism);
grid on;
box on
hold off
title({'\textbf{Rotor Speed}'},'FontSize',titlesize)

subplot(2,2,4)

hold on; 

plot(time1,uBEM0.HubWindSpeed,'g', 'LineWidth', linesize)
plot(time1,uBEM1.HubWindSpeed,'r', 'LineWidth', linesize)
plot(time1,uBEM2.HubWindSpeed,'b', 'LineWidth', linesize)

%plot(t(:,2),Cl(:,2),'b')

xlabel('$t(s)$','interpreter','latex')
ylabel('$Wind Speed (m/s)$','interpreter','latex')
ax = gca; % Size Axis
ax.FontSize = sizenumaxis; % Size Axis 2.0
ax.XLabel.FontSize = sizeXlabelaxis;
ax.YLabel.FontSize = sizeYlabelaxis;
axis([30 time1(end) 6 10]);
%xticks(0:1000:10000) % Adjust the scale of the axes
  
%legend({'Uref = 8m/s, IT = 0\%, n = 0'},'FontSize',sizelegend,'Location','southeast')

colormap(prism);
grid on;
box on
hold off
title({'\textbf{Hub Wind Speed}'},'FontSize',titlesize)



% Título general
h = suptitle('\textbf{Synthetic Inertia with an overpower of 10\%}');
h = suptitle('\textbf{Synthetic Inertia Stepwise Wang 2017}');
set(h, 'Interpreter', 'latex', 'FontSize', titlesize);

%% Control schem
% Omega in simultion
OmegaAll = [uBEM0.RotorSpeed ; uBEM1.RotorSpeed ; uBEM2.RotorSpeed];
OmRated = 11.667*2*pi/60;
OmegaMin = OmRated*0.4;
OmegaAll = [OmegaMin:0.01:OmRated]; 

% Curva P-Omega
Cp_lambda = xlsread('Cp_IEA_34.xlsx');

% 7m/s Cp interpolation
R = 65; % Radio [m]
TSR7 = OmegaAll.*R./7;
Cp7 = interp1(Cp_lambda(:,1),Cp_lambda(:,2), TSR7);
P7 = 0.5.*Cp7.*1.225.*pi.*R.*R.*7*7*7; % Power on 7m/s
% 8m/s Cp interpolation
TSR8 = OmegaAll.*R./8;
Cp8 = interp1(Cp_lambda(:,1),Cp_lambda(:,2), TSR8);
P8 = 0.5.*Cp8.*1.225.*pi.*R.*R.*8*8*8; % Power on 7m/s
% 9m/s Cp interpolation
TSR9 = OmegaAll.*R./9;
Cp9 = interp1(Cp_lambda(:,1),Cp_lambda(:,2), TSR9);
P9 = 0.5.*Cp9.*1.225.*pi.*R.*R.*9*9*9; % Power on 7m/s

% KgOmega2
Kg = 1.825346e6;
PKgOmega3 = Kg.*OmegaAll.^3;

% Plot
figure;


set(groot, 'DefaultTextInterpreter', 'latex'); % Fig Latex
set(groot, 'DefaultAxesTickLabelInterpreter', 'latex'); % Axis Latex
set(groot, 'defaultLegendInterpreter','latex'); % Legend Latex 

set(gcf,'color','white')

%subplot(2,2,1) % 

hold on; 

plot(OmegaAll.*30./pi,P7./(1e6),'g--', 'LineWidth', linesize)
plot(OmegaAll.*30./pi,P8./(1e6),'r--', 'LineWidth', linesize)
plot(OmegaAll.*30./pi,P9./(1e6),'b--', 'LineWidth', linesize)
plot(OmegaAll.*30./pi,PKgOmega3./(1e6),'k', 'LineWidth', linesize)
plot(uBEM0.RotorSpeed(499:1000).*30./pi,uBEM0.GeneratorTorque(499:1000).*uBEM0.RotorSpeed(499:1000)./(1e6),'g', 'LineWidth', linesize)
plot(uBEM1.RotorSpeed(499:1000).*30./pi,uBEM1.GeneratorTorque(499:1000).*uBEM1.RotorSpeed(499:1000)./(1e6),'r', 'LineWidth', linesize)
plot(uBEM2.RotorSpeed(499:1000).*30./pi,uBEM2.GeneratorTorque(499:1000).*uBEM2.RotorSpeed(499:1000)./(1e6),'b', 'LineWidth', linesize)
plot([OmegaMin*30/pi OmegaMin*30/pi],[0 4],'k--', 'LineWidth', linesize)

%plot([time3(Itim_SI) time3(Itim_SI)],[min_power max_power],'k--', 'LineWidth', linesize)

xlabel('$Rotor Speed (RPM)$','interpreter','latex')
ylabel('$Power Generator (MW)$','interpreter','latex')
ax = gca; % Size Axis
ax.FontSize = sizenumaxis; % Size Axis 2.0
ax.XLabel.FontSize = sizeXlabelaxis;
ax.YLabel.FontSize = sizeYlabelaxis;
% axis([30 time1(end) 0.5 3.7]);
%xticks(120:20:200) % Adjust the scale of the axes
  
legend({'P($\Omega$) $7$ m/s','P($\Omega$) $8$ m/s','P($\Omega$) $9$ m/s','$K_g\Omega^3$','A-B-C-D-E $7$ m/s','A-B-C-D-E $8$ m/s','A-B-C-D-E $9$ m/s','$\Omega_{min}$'},'FontSize',sizelegend,'Location','northwest')

colormap(prism);
grid on;
box on
hold off
title({'\textbf{Control Scheme}'},'FontSize',titlesize)



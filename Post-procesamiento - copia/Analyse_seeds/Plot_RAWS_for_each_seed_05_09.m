clear; close all;
addpath ../Main_functions/
% %%
% 
% %%
function [Ueff2]=ComputeRotorEffective2(U,Yt,Zt,Hubpos,Diam, nz, ny, nt)
    % [nt, Nx,Ny,Nz]=size(U);
    Ueff2 = zeros(nt,1);
    for i=1:nt
        Count = 0;
        for j=1:ny
            for k=1:nz
                Dist2rot = sqrt((Yt(j)-Hubpos(2))^2+(Zt(k)-Hubpos(3))^2);
                if Dist2rot <= Diam/2
                    Ueff2(i) = Ueff2(i) + U(i,1,j,k);
                    Count = Count + 1;
                end
            end
        end

        Ueff2(i) = (Ueff2(i)/Count);
    end
end
% 
% %%
% addpath ../Main_functions/
% 
% %% Parámetros
% addpath ../Main_functions/
% 
% %% Parámetros
% root_dir = 'C:\Users\fgarchitorena\Proyectos_de_investigacion\FSE_Incercia_Sintetica\Controladores-IS-ROSCO\Torque_2026_IEA3p4MW_24_seeds\Wind\SPW\v8.5\TI8.0';
% nSeeds = 12; % sd0 ... sd11
% Uref = 8.5;  % velocidad de referencia
% Diam = 120;  % diámetro rotor [m] (ajustar a tu turbina)
% HubHeight = 90; % hub height [m] (ajustar a tu turbina)
% useSubplots = true; % <<< cambiar a true para subplots
% 
% %% Inicializar
% RAWS_all = {};
% time_all = {};
% 
% for sd = 1:nSeeds-1
%     % Construir path al archivo .bts
%     wind_file = fullfile(root_dir, sprintf('sd%d',sd), ...
%         sprintf('IEAonshore_%.1f_sh0.2_TI8.0_sd%d.bts', Uref, sd));
% 
%     % Leer campo de viento
%     [velocity, twrVelocity, y, z, zTwr, nz, ny, dz, dy, dt, zHub, z1,mffws] = readfile_BTS(wind_file);
%     nt = size(velocity,1);
%     time = (0:nt-1)*dt;
% 
%     % Calcular RAWS
%     Ueff = ComputeRotorEffective2(velocity, y, z, [0 0 HubHeight], Diam, nz, ny, nt);
% 
%     % Guardar
%     RAWS_all{sd+1} = Ueff;
%     time_all{sd+1} = time;
% end
% 
% %% Plot
% nSeeds = 12;
% if useSubplots
%     figure('Units','normalized','OuterPosition',[0 0 1 1]);
%     for sd = 1:nSeeds
%         subplot(ceil(nSeeds/3),3,sd); % distribuye en grilla 3 columnas
%         t = time_all{sd};
%         Ueff = RAWS_all{sd};
% 
%         idx = (t >= 350) & (t <= 500);
%         plot(t(idx), Ueff(idx), 'b', 'LineWidth', 1.2); hold on;
% 
%         % Línea vertical en t = 360s
%         xline(360, '--k','LineWidth', 2, 'DisplayName','Start IS');
% 
%         xlabel('Time [s]','FontSize',14)
%         ylabel('RAWS [m/s]','FontSize',14)
%         title(sprintf('Seed sd%d', sd-1),'FontSize',16)
%         set(gca,'FontSize',14)
%         grid on; box on;
%         xlim([350 500])
%         if sd == 1
%            legend('RAWS','Start SI','FontSize',12,'Location','NorthEast','Interpreter','latex')
%         end
% 
%     end
% else
%     figure('Units','normalized','OuterPosition',[0 0 1 1]); hold on;
%     for sd = 1:nSeeds
%         t = time_all{sd};
%         Ueff = RAWS_all{sd};
% 
%         idx = t >= 350;
%         plot(t(idx), Ueff(idx), 'DisplayName', sprintf('sd%d',sd-1));
%     end
%     % Línea vertical en t = 360s
%     xline(360, '--k', 'DisplayName','Start IS');
% 
%     xlabel('Time [s]')
%     ylabel('RAWS [m/s]')
%     title(sprintf('Rotor-Averaged Wind Speed (Uref = %.1f m/s)', Uref))
%     legend show
%     grid on; box on;
% end
% 
% %exportgraphics(gcf,'RAWS_per_seed_from_IS_start.png','Resolution',300)

%% Parámetros
root_dir = 'C:\Users\fgarchitorena\Proyectos_de_investigacion\FSE_Incercia_Sintetica\Controladores-IS-ROSCO\Torque_2026_IEA3p4MW_24_seeds\Wind\SPW\v8.5\TI8.0';

Uref = 8.5;   % velocidad de referencia
Diam = 120;   % diámetro rotor [m]
HubHeight = 90; % hub height [m]
useSubplots = true; % <<< cambiar a true para subplots

% Seeds que quiero mostrar:
selectedSeeds = [0, 1, 2, 5, 6, 9, 11,  14 ,15, 17 ,20, 21];  % <--- AQUÍ eliges las que quieras

%% Inicializar
RAWS_all = cell(1, numel(selectedSeeds));
time_all = cell(1, numel(selectedSeeds));

for i = 1:numel(selectedSeeds)
    sd = selectedSeeds(i);
    
    % Construir path al archivo .bts
    wind_file = fullfile(root_dir, sprintf('sd%d',sd), ...
        sprintf('IEAonshore_%.1f_sh0.2_TI8.0_sd%d.bts', Uref, sd));
    
    % Leer campo de viento
    [velocity, twrVelocity, y, z, zTwr, nz, ny, dz, dy, dt, zHub, z1,mffws] = readfile_BTS(wind_file);
    nt = size(velocity,1);
    time = (0:nt-1)*dt;

    % Calcular RAWS
    Ueff = ComputeRotorEffective2(velocity, y, z, [0 0 HubHeight], Diam, nz, ny, nt);

    % Guardar
    RAWS_all{i} = Ueff;
    time_all{i} = time;
end

%% Plot
if useSubplots
    figure('Units','normalized','OuterPosition',[0 0 1 1]);
    for i = 1:numel(selectedSeeds)
        sd = selectedSeeds(i);
        subplot(ceil(numel(selectedSeeds)/3),3,i);
        
        t = time_all{i};
        Ueff = RAWS_all{i};
        
        idx = (t >= 350) & (t <= 500);
        plot(t(idx), Ueff(idx), 'b', 'LineWidth', 1.2); hold on;
        xline(360, '--k','LineWidth', 2, 'DisplayName','Start IS');
        
        xlabel('Time [s]','FontSize',14,'Interpreter','latex')
        ylabel('RAWS [m/s]','FontSize',14,'Interpreter','latex')
        title(sprintf('Seed sd%d', sd),'FontSize',16,'Interpreter','latex')
        set(gca,'FontSize',14,'TickLabelInterpreter','latex')
        grid on; box on;
        xlim([350 500])
        if i == 1
           legend('RAWS','Start IS','FontSize',12,'Location','NorthEast','Interpreter','latex')
        end
    end
else
    figure('Units','normalized','OuterPosition',[0 0 1 1]); hold on;
    for i = 1:numel(selectedSeeds)
        sd = selectedSeeds(i);
        t = time_all{i};
        Ueff = RAWS_all{i};
        
        idx = t >= 350;
        plot(t(idx), Ueff(idx), 'DisplayName', sprintf('sd%d',sd));
    end
    xline(360, '--k', 'DisplayName','Start IS');
    
    xlabel('Time [s]')
    ylabel('RAWS [m/s]')
    title(sprintf('Rotor-Averaged Wind Speed (Uref = %.1f m/s)', Uref))
    legend show
    grid on; box on;
end
%%
exportgraphics(gcf,'RAWS_per_seed_from_IS_start_selected_seeds.png','Resolution',300)

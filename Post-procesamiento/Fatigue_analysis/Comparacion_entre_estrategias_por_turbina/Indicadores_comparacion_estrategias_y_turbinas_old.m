%close all
clc
addpath RainflowAnalysis\

%% Parámetros
Turbines = { ...
    struct("name","IEA_3p4MW","base","IEA-3.4-130-RWT","wind_condition", "v8_TI10","plot_name","IEA 3.34MW"), ...
    struct("name","NREL5MW","base","NRELOffshrBsline5MW","wind_condition", "v9_TI10","plot_name","NREL 5MW") ...
    };

%Wind_Condition = "v8_TI10";

estrategias = { ...
    struct("tag","Normalop","folder","Operacion_normal","suffix","_norm_op_"), ...
    struct("tag","Tarnowski","folder","Test_Tarnowski_OF","suffix","_Tarnowski_"), ...
    struct("tag","Wang","folder","Test_Wang_OF","suffix","_Wang_") ...
    };

% Variables a analizar
variables = {'RootMyb1','RootMxb1','TwrBsMyt','TwrBsMxt','LSSGagMya','LSSGagMza'};
varnames  = {'FlapWise','EdgeWise','ForeAft','SideSide','LSSGagMya','LSSGagMza'};
m_values  = [10, 10, 4, 4, 4, 4];  

% Rango de análisis
iStart = 60/0.00625;
iEnd   = 660/0.00625;
EqvFreq = 1;

t_inercia   = 360; 
duraciones  = [5,10];

%% Resultados
DELs = struct();
maximos = struct();
energias = struct();

for t = 1:length(Turbines)
    Tname = Turbines{t}.name;
    base  = Turbines{t}.base;
    wind_condition = Turbines{t}.wind_condition;

    for e = 1:length(estrategias)
        Estr = estrategias{e}.tag;
        FileName = fullfile( ...
            "C:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO", ...
            estrategias{e}.folder, ...
            Tname, wind_condition, ...
            base + estrategias{e}.suffix + wind_condition + ".outb");
        % if Estr=="Wang" && Tname=="IEA_3p4MW"
        %     FileName = fullfile( ...
        %     "C:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO", ...
        %     estrategias{e}.folder, ...
        %     Tname, wind_condition, ...
        %     base + estrategias{e}.suffix + wind_condition + "_PITorque.outb")
        % end
        % Leer archivo
        [tSeries, ChanName, ~, ~, ~] = ReadFASTbinary(FileName);

        % --- DELs y máximos ---
        for v = 1:length(variables)
            var = variables{v};
            SN_Slope = m_values(v);

            idx = find(strcmp(ChanName, var));
            if isempty(idx)
                error(['Variable ', var, ' no encontrada en: ', FileName]);
            end

            Time = tSeries(iStart:iEnd,1);
            Sensor = tSeries(iStart:iEnd,idx);

            RainFlowStruct = RunRainFlowAnalysis(Time, Sensor, SN_Slope, EqvFreq);
            DEL = cell2mat(RainFlowStruct.EqvLoads);

            DELs.(Tname).(Estr).(var) = DEL;
            maximos.(Tname).(Estr).(var) = max(Sensor);
        end

        % --- Energía inyectada ---
        idxP = find(strcmp(ChanName,'GenPwr'));
        if isempty(idxP)
            warning('GenPwr no encontrada en %s', FileName);
        else
            Time = tSeries(:,1);
            Pgen = tSeries(:,idxP);

            for d = 1:length(duraciones)
                t_start = t_inercia;
                t_end   = t_inercia + duraciones(d);
                mask = (Time >= t_start) & (Time <= t_end);

                E_kWs = trapz(Time(mask), Pgen(mask));
                E_kWh = E_kWs/3600.0;

                energias.(Tname).(Estr).(['Dur' num2str(duraciones(d)) 's']) = E_kWh;
            end
        end
    end
end

%% === Graficar Energía entre turbinas y estrategias ===
figure('Units','normalized','OuterPosition',[0 0 1 1]); 
set(gcf,'Color','w');
fontsize = 14;

for d = 1:length(duraciones)
    subplot(1,length(duraciones),d)
    hold on

    % Construir matriz: filas = estrategias, columnas = turbinas
   E_matrix = zeros(length(estrategias), length(Turbines));
    for e = 1:length(estrategias)
        for t = 1:length(Turbines)
            Tname = Turbines{t}.name;
            Estr  = estrategias{e}.tag;
            E_matrix(e,t) = energias.(Tname).(Estr).(['Dur' num2str(duraciones(d)) 's']);
        end
    end
    
    estrategias_tags = cellfun(@(s) char(s.tag), estrategias, 'UniformOutput', false);
    turbinas_tags    = cellfun(@(s) char(s.plot_name), Turbines, 'UniformOutput', false);
    
    bar(categorical(estrategias_tags), E_matrix,'grouped');
    legend(turbinas_tags,'FontSize',fontsize, 'Interpreter','latex','Location','NorthWest');


    ylabel('Energy injected (kWh)','FontSize',fontsize,'Interpreter','latex');
    xlabel('Strategy','FontSize',fontsize,'Interpreter','latex');
    title(sprintf('Energy %ds window', duraciones(d)),'FontSize',16,'Interpreter','latex');
    grid on
           ax=gca;
    set(gca,"Ticklabelinterpreter","latex");
    ax.FontSize = fontsize;
end

exportgraphics(gcf,'Comparacion_Energia_Turbinas_update.png','Resolution',300);

%% === Ejemplo de DEL comparación ===
figure('Units','normalized','OuterPosition',[0 0 1 1]); 
set(gcf,'Color','w');

turbinas_tags = cellfun(@(x) x.plot_name, Turbines, 'UniformOutput', false);

for v = 1:length(variables)
    subplot(2,3,v)
    
    % Construir matriz: filas = estrategias, columnas = turbinas
    DEL_matrix = zeros(length(estrategias), length(Turbines));
    for e = 1:length(estrategias)
        for t = 1:length(Turbines)
            DEL_matrix(e,t) = DELs.(Turbines{t}.name).(estrategias{e}.tag).(variables{v});
        end
    end
    
    % Etiquetas de estrategias
    estr_tags = cellfun(@(s) char(s.tag), estrategias, 'UniformOutput', false);
    
    % Graficar barras agrupadas
    bar(categorical(estr_tags), DEL_matrix, 'grouped');
    
    % Leyenda por turbina
    legend(turbinas_tags,'FontSize',fontsize,'Interpreter','latex','Location','NorthWest');
    
    ylabel('DEL','FontSize',fontsize,'Interpreter','latex');
    title(varnames{v},'FontSize',16,'Interpreter','latex');
    grid on
    
    ax = gca;
    set(gca,'TickLabelInterpreter','latex');
    ax.FontSize = fontsize;
end

exportgraphics(gcf,'Comparacion_DEL_Turbinas_update.png','Resolution',300);


%% === Incremento relativo de DELs respecto a Normalop ===
figure('Units','normalized','OuterPosition',[0 0 1 1]); 
set(gcf,'Color','w');

ref = 'Normalop';  % estrategia de referencia

for v = 1:length(variables)
    subplot(2,3,v)
    DEL_matrix = zeros(length(estrategias)-1, length(Turbines)); % excluimos Normalop

    for t = 1:length(Turbines)
        Tname = Turbines{t}.name;
        DEL_ref = DELs.(Tname).(ref).(variables{v});  % DEL Normalop para esta turbina

        cnt = 1;
        for e = 1:length(estrategias)
            Estr = estrategias{e}.tag;
            if strcmp(Estr, ref)
                continue; % saltamos la estrategia de referencia
            end
            DEL_curr = DELs.(Tname).(Estr).(variables{v});
            % incremento relativo %
            DEL_matrix(cnt,t) = 100*(DEL_curr - DEL_ref)/DEL_ref;
            cnt = cnt + 1;
        end
    end

    % etiquetas de estrategias excluyendo Normalop
    tags = cellfun(@(s) char(s.tag), estrategias, 'UniformOutput', false); 
    tags(strcmp(tags, ref)) = [];  % eliminar Normalop

    bar(categorical(tags), DEL_matrix, 'grouped');
    ax=gca;
    set(gca,"Ticklabelinterpreter","latex");
    ax.FontSize = fontsize;
    % nombres de turbinas
    turbinas_tags = cellfun(@(x) x.plot_name, Turbines, 'UniformOutput', false);
    legend(turbinas_tags,'FontSize',fontsize,'Interpreter','latex','Location','NorthWest');

    ylabel('Increase in DEL [\%]','FontSize',fontsize,'Interpreter','latex');
    title(varnames{v},'FontSize',16,'Interpreter','latex');
    grid on
end

exportgraphics(gcf,'Comparacion_DEL_Turbinas_Increase_update.png','Resolution',300);



%% === Incremento relativo de Maximos respecto a Normalop ===
figure('Units','normalized','OuterPosition',[0 0 1 1]); 
set(gcf,'Color','w');

ref = 'Normalop';  % estrategia de referencia

for v = 1:length(variables)
    subplot(2,3,v)
   Max_matrix = zeros(length(estrategias)-1, length(Turbines)); % excluimos Normalop

    for t = 1:length(Turbines)
        Tname = Turbines{t}.name;
        max_ref = maximos.(Tname).(ref).(variables{v});  % DEL Normalop para esta turbina

        cnt = 1;
        for e = 1:length(estrategias)
            Estr = estrategias{e}.tag;
            if strcmp(Estr, ref)
                continue; % saltamos la estrategia de referencia
            end
            Max_curr = maximos.(Tname).(Estr).(variables{v});
            % incremento relativo %
            Max_matrix(cnt,t) = 100*(Max_curr - max_ref)/max_ref;
            cnt = cnt + 1;
        end
    end

    % etiquetas de estrategias excluyendo Normalop
    tags = cellfun(@(s) char(s.tag), estrategias, 'UniformOutput', false); 
    tags(strcmp(tags, ref)) = [];  % eliminar Normalop

    bar(categorical(tags), Max_matrix, 'grouped');
    ax=gca;
    set(gca,"Ticklabelinterpreter","latex");
    ax.FontSize = fontsize;
    % nombres de turbinas
    turbinas_tags = cellfun(@(x) x.plot_name, Turbines, 'UniformOutput', false);
    legend(turbinas_tags,'FontSize',fontsize,'Interpreter','latex','Location','NorthWest');

    ylabel('Increase in Max [\%]','FontSize',fontsize,'Interpreter','latex');
    title(varnames{v},'FontSize',16,'Interpreter','latex');
    grid on
end

exportgraphics(gcf,'Comparacion_Max_Turbinas_Increase_update.png','Resolution',300);

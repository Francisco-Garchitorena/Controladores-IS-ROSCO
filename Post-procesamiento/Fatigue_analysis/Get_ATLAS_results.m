
%% Extraer máximos y DELs ponderados por velocidad y variable
% Fecha: 2025-10-14
% Descripción:
% Lee un archivo CSV con resultados de cargas y extrae:
%  1) El máximo Max_individual entre semillas por velocidad (Uref)
%  2) El máximo global entre velocidades para cada Variable
%  3) Los SeedWeightedDEL promedio por velocidad
%  4) Los Seed-speed weighted DEL (de filas separadas)
%  5) Los máximos globales de esos DEL ponderados

clear; clc; close all;

%% === CONFIGURACIÓN ===
archivo = 'ATLAS_IEA3p4MW/Results_summary_IEA_3p4_24seeds.csv'; % <-- cambiar por tu archivo

%% === LECTURA DE DATOS ===
opts = detectImportOptions(archivo, 'Delimiter', ',');
opts = setvartype(opts, 'char'); % evita problemas con celdas mixtas
T = readtable(archivo, opts);

% Limpieza de nombres de columnas
T.Properties.VariableNames = strrep(T.Properties.VariableNames, ' ', '_');
T.Properties.VariableNames = strrep(T.Properties.VariableNames, '.', '_');
T.Properties.VariableNames = strrep(T.Properties.VariableNames, '-', '_');

%% === VERIFICACIÓN DE COLUMNAS NECESARIAS ===
reqCols = {'Variable','Uref','Seed','Max_individual','SeedWeightedDEL','Seed_speedWeightedDEL'};
faltan = setdiff(reqCols, T.Properties.VariableNames);
if ~isempty(faltan)
    warning('Faltan columnas esperadas en el archivo CSV: %s', strjoin(faltan, ', '));
end

%% === SEPARAR TIPOS DE FILAS ===
% Filas con resultados individuales (por semilla)
mask_seeds = ~cellfun(@isempty, T.Variable) & ~cellfun(@isempty, T.Uref) & ~cellfun(@isempty, T.Seed);
datos = T(mask_seeds, :);

% Filas con resultados ponderados (Seed-speed weighted DEL)
mask_speedWeighted = ~cellfun(@isempty, T.Variable) & ~cellfun(@isempty, T.Seed_speedWeightedDEL);
datos_speedWeighted = T(mask_speedWeighted, :);

% Convertir columnas numéricas
varsNum = intersect({'Uref','Max_individual','SeedWeightedDEL'}, datos.Properties.VariableNames);
for i = 1:numel(varsNum)
    datos.(varsNum{i}) = str2double(datos.(varsNum{i}));
end
if ismember('Seed_speedWeightedDEL', datos_speedWeighted.Properties.VariableNames)
    datos_speedWeighted.Seed_speedWeightedDEL = str2double(datos_speedWeighted.Seed_speedWeightedDEL);
end

%% === AGRUPAR POR VARIABLE Y VELOCIDAD ===
vars = unique(datos.Variable);
resultados = table();
resumen = table();

for i = 1:numel(vars)
    varName = vars{i};
    subset = datos(strcmp(datos.Variable, varName), :);
    velocidades = unique(subset.Uref(~isnan(subset.Uref)));

    for j = 1:numel(velocidades)
        v = velocidades(j);
        filas = subset(subset.Uref == v, :);

        % Paso 1: obtener el máximo entre seeds para esa velocidad
        valorMax = max(filas.Max_individual, [], 'omitnan');  %maximo entre semillas

        % Paso 2: calcular promedios de DELs
        del_seed_weighted = mean(filas.SeedWeightedDEL, 'omitnan');

        % Paso 3: obtener valor ponderado por velocidad si existe
        fila_sw = datos_speedWeighted(strcmp(datos_speedWeighted.Variable, varName), :);
        if ~isempty(fila_sw)
            del_seed_speed_weighted = mean(fila_sw.Seed_speedWeightedDEL, 'omitnan');
        else
            del_seed_speed_weighted = NaN;
        end

        nuevaFila = table({varName}, v, valorMax, del_seed_weighted, del_seed_speed_weighted, ...
            'VariableNames', {'Variable','Uref','MaxIndividual_porVel','SeedWeightedDEL','SeedSpeedWeightedDEL'});
        resultados = [resultados; nuevaFila];
    end

    % Paso 4: obtener máximos globales entre velocidades
    maskVar = strcmp(resultados.Variable, varName);
    [maxGlobal, idxMax] = max(resultados.MaxIndividual_porVel(maskVar), [], 'omitnan');  %maximo entre velocidades

    velMax = resultados.Uref(maskVar);
    resumen = [resumen; table({varName}, ...
        velMax(idxMax), maxGlobal, ...
        'VariableNames', {'Variable','Uref_Max','MaxIndividual_Global'})];
end

%% === MOSTRAR RESULTADOS ===
disp('===== Máximos y DELs por velocidad =====');
disp(resultados);
disp('===== Resumen global por variable =====');
disp(resumen);

%% === OPCIONAL: GUARDAR A CSV ===
%writetable(resultados, 'ATLAS_IEA3p4MW_resultados_para_torque26.csv');
% writetable(resumen, 'Resumen_Global_por_Variable.csv');
% fprintf('Archivos guardados:\n - Resultados_por_Velocidad.csv\n - Resumen_Global_por_Variable.csv\n');


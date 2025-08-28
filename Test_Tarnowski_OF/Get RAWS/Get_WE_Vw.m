% Ruta del archivo
filename = 'OF_case/IEA-3.4-130-RWT_1p1_8.0_sd0.RO.dbg';

% Abrir archivo
fid = fopen(filename, 'r');
assert(fid ~= -1, 'No se pudo abrir el archivo');

% Leer líneas hasta encontrar la línea con los nombres de variables
line = '';
while ~contains(line, 'Time')
    line = fgetl(fid);
end

% Guardar la línea con nombres de variables
var_names_line = strtrim(line);

% Leer la siguiente línea (unidades, la ignoramos)
units_line = fgetl(fid);

% Parsear nombres de variables (puede haber múltiples espacios entre ellas)
var_names = regexp(var_names_line, '\s+', 'split');

% Convertir los nombres a válidos en MATLAB
var_names = matlab.lang.makeValidName(var_names);

% Leer el resto de los datos
format_spec = repmat('%f', 1, numel(var_names));  % Formato numérico para todas las columnas
data = textscan(fid, format_spec, 'CollectOutput', true);
fclose(fid);

% Crear tabla
data_table = array2table(data{1}, 'VariableNames', var_names);

% Agregar más gráficos si lo necesitás

%% Ueff TurbSim
Get_RAWS;

%% WindVelX OpenFast
vars = {'Wind1VelX'};
        % Leer las variables
[Channels, ChanName, ChanUnit, FileID, DescStr] = ReadFASTbinary('OF_case/IEA-3.4-130-RWT_1p1_8.0_sd0.outb');

%%
% Ejemplo de gráficos
figure;
plot(data_table.Time, data_table.WE_Vw, 'LineWidth', 1.2); hold on;
plot(Disturbance.Ueff.time, Ueff2,  'LineWidth', 1.2); hold on;
%plot(Channels(:,1), Channels(:,2),  'LineWidth', 1.2); hold on;
xlabel('Tiempo [s]');
legend ('estimated','RAWS', 'Velocidad horizontal góndola (OF)')
ylabel('WS [m/s]');
title('Estimated WS vs RAWS vs OF WindVel1X');
xlim([60 data_table.Time(end)]);
%%
% Suponiendo que tenés los tiempos de cada uno
t_data = data_table.Time;        % tiempo de WE_Vw
t_ueff = Disturbance.Ueff.time;             % tiempo de Ueff2 (por ejemplo del Kalman)
% Interpolás Ueff2 a los tiempos de WE_Vw
Ueff2_interp = interp1(t_ueff, Ueff2, t_data, 'linear', 'extrap');
% Ahora sí podés comparar
figure;
plot(t_data, data_table.WE_Vw, 'b',  'LineWidth', 1.2); hold on
plot(t_data, Ueff2_interp, 'r',  'LineWidth', 1.2); legend('WE Vw', 'Ueff2 interpolado');

%% velocidad en altura de buje con turbsim y con openfast
figure;
y_target = 0;
z_target = 110;
vec_c1_interp = zeros(size(velocity, 1), 1);

for it = 1:size(velocity, 1) % loop en el tiempo
    % extraer el plano (componente 1) en este instante de tiempo
    slice_t = squeeze(velocity(it, 1, :, :)); % matriz (y, z)

    % interp2 necesita y en filas y z en columnas
    vec_c1_interp(it) = interp2(z, y, slice_t, z_target, y_target, 'linear');
end

dt_turbsim = 0.05;     % paso temporal turbsim
dt_OF      = 0.00625;  % paso temporal OpenFAST (OF)

t_turbsim = (0:length(vec_c1_interp)-1) * dt_turbsim;
t_OF      = (0:length(Channels(:,2))-1) * dt_OF;

%% plot
plot(t_turbsim, vec_c1_interp, 'LineWidth', 1.2); hold on;
plot(t_OF, Channels(:,2), 'LineWidth', 1.2); hold on;

xlabel('Tiempo [s]');
ylabel('WS [m/s]');
legend('turbsim', 'OF');
title('turbsim vs OF');
xlim([60 600])
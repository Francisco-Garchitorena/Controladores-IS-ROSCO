function data_table = read_ROSCO_dbg(filename)
    
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

end

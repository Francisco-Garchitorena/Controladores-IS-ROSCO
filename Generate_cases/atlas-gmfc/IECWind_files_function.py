def IECWind_files_function(MyDir, OriginalDir_OF,DLC_folder_name, root_folder, cut_in,cut_out,v_rated,Time_init_transient,Class,Wind_Turb_cat, H_buje, D_rot):
    import os
    import shutil
    import glob
    import subprocess
    
   # Sobreescribir IECWind si ya existe
    dest_IECWind = f'{root_folder}/{DLC_folder_name}/Wind/IECWind'
    if os.path.exists(dest_IECWind):
        shutil.rmtree(dest_IECWind)  # Elimina el folder existente
    shutil.copytree(f'{MyDir}/IECWind', dest_IECWind)    # Copia IECWind

    Wind_folder = f"{root_folder}/{DLC_folder_name}/Wind/"    #Create a Wind folder 
    os.makedirs(Wind_folder, exist_ok=True)

    IEC_file_original = glob.glob(f"{Wind_folder}/IECWind/IEC.ipt") #Get original IECWind input file from the IECWind Folder--- this will be the edited file
    IECWind_exe = glob.glob(f"{Wind_folder}/IECWind/IECWind_exe") # Get the executable from the IECWind folder
    if IEC_file_original:
    # Copiar el archivo al directorio Wind_folder
        shutil.copy(IEC_file_original[0], Wind_folder)
        shutil.copy(IECWind_exe[0], Wind_folder)
    else:
        print("ORIGINAL IEC WIND FILE NOT FOUND")
    # Lista de archivos que coinciden con el patrón
    archivos_IEC = glob.glob(f"{Wind_folder}/IEC.ipt")    # Searches for the IEC input file in my Wind folder. Can be programmed differently ;)

    # List of values I wish to change from the IECWind input file. They all depend on the wind turbine
    replace_map = {
        '40.': str(Time_init_transient),   # Cambiar tiempo de inicio de condición transitoria
        '3': str(Class),       # Cambiar clase de turbina eólica IEC
        'A': Wind_Turb_cat,       # Cambiar categoría de turbulencia del viento
        '110': str(H_buje),   # Cambiar altura del buje de la turbina eólica
        '130': str(D_rot),   # Cambiar diámetro del rotor de la turbina eólica
        '4.0': f'{str(cut_in)}.0',   # Cambiar velocidad de corte (cut-in)
        '9.8': str(v_rated),   # Cambiar velocidad nominal
        '25.0': f'{str(cut_out)}.0'  # Cambiar velocidad de corte (cut-out)
    }

    # Agregar entradas adicionales al diccionario usando un bucle
    new_lines_to_add = []
    for n in range(cut_in, cut_out + 1):
        new_lines_to_add.append(f'NWP{n}.0\n')          # Lista de condiciones de viento con NWP a agregar (depende de los valores de las velocidades cut-in y cut-out, y por ende de la turbina)
            
    if archivos_IEC:                         # Verifica que la lista no está vacía
        IEC_file = archivos_IEC[0]        #Se queda con el nombre de archivo
        print(IEC_file)
        with open(IEC_file, 'r') as file:           #Opens IECWind input files, for editing.
            lines = file.readlines()                # Obtains the lines from the file.

        # Modificar las líneas según el mapa de reemplazo
        new_lines = []  
        for line in lines:
            new_line = line                                            # If nothing changes, new line will be equal to the old file line
            for old_value, new_value in replace_map.items():
                if old_value in line:
                    new_line = line.replace(old_value, new_value)       # Replaces the old value from the new value, corresponding to the present turbine (function inputs)
                    break  # Opcional: parar después del primer reemplazo
            new_lines.append(new_line)                                  # Adds new line to the edited file              
        new_lines.extend(new_lines_to_add)                              # Adds NWPn.n conditions to the file


        # Guardar el archivo modificado (puede ser el mismo archivo o uno nuevo)
        with open(IEC_file, 'w') as f:
            f.writelines(new_lines)                                     # Writes new file
        
    # Execute IECWind.exe
    iecwind_exe_path = os.path.join(Wind_folder, "IECWind_exe")           # Gets executable path
    if os.path.exists(iecwind_exe_path):
        try:
            import subprocess
            subprocess.run([iecwind_exe_path], check=True, cwd=Wind_folder)     # Runs IECWind in Wind Folder. The input file will be the previously edited.
            print("IECWind.exe successfully executed")
        except subprocess.CalledProcessError as e:
            print(f"Error while executing IECWind.exe: {e}")                        # If there is an error, it describes it.
    else:
        print(f"Could not find {iecwind_exe_path}")

# CREAR UNA CARPETA POR TIPO DE VIENTO CREADO CON IECWIND. POR EJEMPLO: CARPETA NWP, CARPETA EOG, etc. 
    # Obtains the list with the Wind folder files. 

    files = [f for f in os.listdir(Wind_folder) if os.path.isfile(os.path.join(Wind_folder, f))] # List with files in Wind directory
    exclude_files = ['IEC.ipt','IECWind_exe', 'IECWind','NTM','xETM','xEWM1','xEWM50']
    # Procesa cada archivo
    for file in files:
        if not(file in exclude_files):
            # Obtén el nombre raíz del archivo (antes del primer número o símbolo)
            root_name = ''                                      # Defines root_name string (empty for now)  
            for char in file:
                if char.isalpha():  # Incluye solo caracteres alfabéticos en el nombre raíz
                    root_name += char           # Gets file root name for distributing in wind type folders (NWP, EWM,EOG...).
                else:
                    break
            # Define el nombre del directorio de destino basado en el nombre raíz
            dest_directory = os.path.join(Wind_folder, root_name)       

            # Crea el directorio si no existe
            os.makedirs(dest_directory, exist_ok=True)          # Creats a folder for each wind type.

            # Moves each wind type file, to its specific folder
            src_file = os.path.join(Wind_folder, file)
            dest_file = os.path.join(dest_directory, file)
            if os.path.exists(dest_file):
                os.remove(dest_file)

            shutil.move(src_file, dest_file)
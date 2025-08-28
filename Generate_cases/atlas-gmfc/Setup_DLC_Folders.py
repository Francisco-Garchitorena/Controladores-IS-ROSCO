import os
import shutil
import sys
import glob
import sys
sys.path.append('C:/Users/fgarchitorena/OpenFast/Design Load Cases/openfast_toolbox-main')
from openfast_toolbox.io import FASTInputFile    # Set to where these files are
sys.path.append('../')
from TurbSim_files_function import * #TurbSim_files_function
from IECWind_files_function import IECWind_files_function
import subprocess

def find_and_copy_file(base_name, src_dir, dst_dir, standard_name,root_name):
    """
    Busca un archivo que contenga base_name en src_dir (directorio fuente) y lo copia a dst_dir (directorio de destino) con el nombre standard_name.
    La idea es poder utilizar el programa, sin importar el nombre con el vengan los archivos de entrada de OpenFast de la turbina seleccionada.
    """
    # Usar glob para buscar archivos que contengan el nombre base (ignorando diferencias como AeroDyn14, AeroDyn15)
    file_pattern = os.path.join(src_dir, f"*{base_name}*")
    matching_files = glob.glob(file_pattern)
    
    # Filtrar el archivo deseado
    desired_file = next((f for f in matching_files if 'lade' not in os.path.basename(f)), None)

    if matching_files:
        if standard_name == f'{root_name}_AeroDyn.dat':                     #Edito los archivos AeroDyn y BeamDyn para que llamen correctamente a los _blade.
            AERODFilename = os.path.join(src_dir, desired_file)
            dst_file = os.path.join(dst_dir, standard_name)
            print('Adapting to standard name:', AERODFilename)
            AEROD = FASTInputFile(AERODFilename)
            AEROD['ADBlFile(1)'] = f"\"{root_name}_AeroDyn_blade.dat\" "
            AEROD['ADBlFile(2)'] = AEROD['ADBlFile(1)']
            AEROD['ADBlFile(3)'] = AEROD['ADBlFile(1)']
            AEROD.write(standard_name)
            # Muevo y sobreescribo si existe
            if os.path.exists(dst_file):
                os.remove(dst_file)
            shutil.move(standard_name, dst_dir)
        elif standard_name == f'{root_name}_BeamDyn.dat':
            BeamDFilename = os.path.join(src_dir,desired_file)
            dst_file = os.path.join(dst_dir, standard_name)
            print('Adapting to standard name:', BeamDFilename)
            BeamD = FASTInputFile(BeamDFilename)
            BeamD['BldFile'] = f"\"{root_name}_BeamDyn_blade.dat\" "
            BeamD.write(standard_name)
            # Muevo y sobreescribo si existe
            if os.path.exists(dst_file):
                os.remove(dst_file)
            shutil.move(standard_name, dst_dir)
        else:
            # Seleccionar el primer archivo coincidente y copiarlo con el nombre estándar
            # Esta sección copia el resto de los archivos generales (elatodyn_blade, etc.), cuyos nombres no cambian (por ahora).
            src_file = matching_files[0]
            dst_file = os.path.join(dst_dir, standard_name)
            # Muevo y sobreescribo si existe
            if os.path.exists(dst_file):
                os.remove(dst_file)
            shutil.copy2(src_file, dst_file)
            print(f"Copied {src_file} as {dst_file}")            
        
        return True
    else:
        print(f"Could not find file with pattern: {base_name}")
        return False
        

def create_main_folders(root_folder, root_name, DLC_folder_name, OriginalDir_OF):
    """
    Crea las carpetas necesarias para los casos de DLC, copia archivos de airfoils, ejecutables y otros archivos compartidos.
    Busca archivos por su 'base' y los renombra con un formato estándar.
    """
    # Crear carpetas principales para DLCs
    print('---------------------------CREATING MAIN FOLDERS---------------------------')
    os.makedirs(f'{root_folder}/{DLC_folder_name}', exist_ok=True)  # Carpeta principal de DLCs
    print(f'Created main folder: {root_folder}/{DLC_folder_name}')
    os.makedirs(f'{root_folder}/{DLC_folder_name}/General', exist_ok=True)  # Carpeta general de datos compartidos
    
    # Eliminar y copiar los datos de perfiles aerodinámicos
    airfoils_path = f'{root_folder}/{DLC_folder_name}/General/Airfoils'
    if os.path.exists(airfoils_path):
        shutil.rmtree(airfoils_path)
    shutil.copytree(f'{OriginalDir_OF}/Airfoils', airfoils_path)

    # Diccionario con los patrones base de los archivos y los nombres estándar
    file_patterns = {
        "AeroDyn": f"{root_name}_AeroDyn.dat",
        f"AeroDyn*lade": f"{root_name}_AeroDyn_blade.dat",
        f"BeamDyn": f"{root_name}_BeamDyn.dat",
        f"BeamDyn*lade": f"{root_name}_BeamDyn_blade.dat",
        f"ElastoDyn*ower": f"{root_name}_ElastoDyn_tower.dat",
        f"ElastoDyn*lade": f"{root_name}_ElastoDyn_blade.dat",
    }

    # Buscar y copiar cada archivo, renombrándolo con el nombre estándar
    for base_name, standard_name in file_patterns.items():
        find_and_copy_file(base_name, OriginalDir_OF, f'{root_folder}/{DLC_folder_name}/General', standard_name,root_name)

def create_wind_folders_and_files(Site_specific_wind, interp_TI, interp_sh, Wind_user_choice, Same_seed, DLCs,root_folder, DLC_folder_name, OriginalDir_OF, MyDir, Copy_Wind_folder, Sim_Time, 
                                TM, turb_sel, cut_in, cut_out,Speed_step,shear_values, TI_values, v_rated,Class, Time_init_transient, seeds, 
                                Wind_Turb_cat, HubHt, D_rot, An_Time_long, Created_Wind_folder_path, Wind_file_root_name, partition, VFlowAngle, HFlowAngle, Vref):
    """
    Crea las carpetas y archivos de viento necesarios para los casos de DLC.
    """
    wind_folder_path = f'{root_folder}/{DLC_folder_name}/Wind'
    
    if not Copy_Wind_folder:  # Si es la primera vez que se genera la carpeta Wind
        os.makedirs(wind_folder_path, exist_ok=True)

        # Llamada a la función que genera los archivos de entrada de TurbSim.
        print('---------------------------CREATING TURBSIM INPUT FILES---------------------------')
        TurbSim_files_function(Site_specific_wind, interp_TI, interp_sh, Wind_user_choice, Same_seed, root_folder, DLC_folder_name, DLCs, OriginalDir_OF, Sim_Time, TM,
                           turb_sel, cut_in, cut_out, Speed_step, shear_values, TI_values,
                           seeds, Wind_Turb_cat, HubHt, An_Time_long, Wind_file_root_name,
                           partition, VFlowAngle, HFlowAngle, Vref)

        # Crear archivos IECWind
        if DLCs in ['3p1', '4p1']:
            print('---------------------------CREATING IECWIND FILES---------------------------')
            IECWind_files_function(MyDir, OriginalDir_OF, DLC_folder_name, root_folder, cut_in, cut_out, v_rated, Time_init_transient, Class, Wind_Turb_cat, HubHt, D_rot)
    else:
        # Copiar carpeta de viento existente
        if not os.path.exists(wind_folder_path):
            shutil.copytree(Created_Wind_folder_path, wind_folder_path)

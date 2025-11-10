import os
import numpy as np
from openfast_toolbox.io import FASTInputFile       #Set to where these files are.
import shutil
import glob
import re
import yaml

def generar_archivo_entrada(tipo_archivo,root_name, root_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref, variables, nombre_salida, YawAngle, variation_name = None, sh = None, TI = None,
                            seed = None):
    """
    Función genérica para generar un archivo de entrada de OpenFAST.
    Inputs:
    :param tipo_archivo: Nombre del archivo base (InflowFile, ElastoDyn, ServoDyn, FST)
    :param root_folder: Carpeta raíz donde se guardan los resultados
    :param DLC_folder_name: Nombre de la carpeta del DLC
    :param DLC_choice: Nombre del DLC (ej. '1p2', '3p1', etc.)
    :param Uref: Velocidad del viento incidente media
    :param variables: Diccionario con los parámetros específicos a modificar. Aqui entran todos los cambios que se le hace al archivo de OF base.
    :param nombre_salida: Nombre del archivo de salida
    :return: None
    """
    # Directorio de entrada
    MyDir = os.getcwd()
    if tipo_archivo == 'fst':
        OriginalFilename = f'{root_name}.fst'
    else:
        OriginalFilename = f'{root_name}_{tipo_archivo}.dat'

    Filename = os.path.join(MyDir, OriginalDir_OF, OriginalFilename)

    # Leer el archivo original
    input_file = FASTInputFile(Filename)                                                                # Función que toma el archivo de entrada de OF y permite cambiarle parámetros. 

    # Modificar las variables según el tipo de archivo
    for key, value in variables.items():                                                                # Cambia todo lo que se le pide en el archivo de entrada. El variables es una entrada de la función que se define para cada archivo en las funciones más abajo.
        input_file[key] = value

    if DLC_choice not in TurbSim_DLCs:
        TI_str = ""                   # if the DLC being created is not within the TurbSim ones, the TI and sh do not make sense
        sh_str = ""
    else:
        sh_str = f"_sh{sh}" if Wind_user_choice else ""
        TI_str = f"_TI{TI}" if Wind_user_choice or Site_specific_wind else ""
    
    Uref_str = f'v{str(Uref)}'
    # Preparar el nombre del archivo de salida
    if seed is not None:
        # if tipo_archivo == 'fst':
        #     output_filename = f'{root_name}_{DLC_choice}_Yaw{YawAngle}_{Uref_str}{sh_str}{TI_str}_sd{seed}.fst'         #Cambiar este nombre implica que cambie en post_processing simulations.
        # else:
        #     output_filename = f'{root_name}_{nombre_salida}_{DLC_choice}_Yaw{YawAngle}_{Uref_str}{sh_str}{TI_str}_sd{seed}.dat'
        if tipo_archivo == 'fst':
            output_filename = f'{root_name}_{DLC_choice}_{Uref_str}{sh_str}{TI_str}_sd{seed}.fst'         #Cambiar este nombre implica que cambie en post_processing simulations.
        else:
            output_filename = f'{root_name}_{nombre_salida}_{DLC_choice}_{Uref_str}{sh_str}{TI_str}_sd{seed}.dat'
    else:
        if tipo_archivo == 'fst':
            output_filename = f'{root_name}_{DLC_choice}_Yaw{YawAngle}_{Uref_str}{sh_str}{TI_str}.fst'
        else:
            output_filename = f'{root_name}_{nombre_salida}_{DLC_choice}_Yaw{YawAngle}_{Uref_str}{sh_str}{TI_str}.dat'
            
    input_file.write(output_filename)                                                                   # Escribe el archivo de salida

    TI_str = f"/TI{TI}/" if Wind_user_choice or Site_specific_wind else ""        # For folder generation. if there combinatios of TI and shear values, a folder for each should be created.
    sh_str = f"/shear{sh}/" if Wind_user_choice else ""

    # Determinar el directorio de destino
    if seed is not None:
        if variation_name:  # Variaciones solo para DLC 4p1
            destination_dir_Uref = f'{root_folder}/{DLC_folder_name}/{DLC_choice}_{variation_name}/Yaw_{YawAngle}/{Uref}{sh_str}{TI_str}/sd{seed}'  #Cambiar este nombre implica que cambie en el Generate slurm files y en el getSimRes (parte del post_process)
        else:
            #destination_dir_Uref = f'{root_folder}/{DLC_folder_name}/{DLC_choice}/Yaw_{YawAngle}/{Uref}{sh_str}{TI_str}/sd{seed}'
            destination_dir_Uref = f'{root_folder}/{DLC_folder_name}/{DLC_choice}/{Uref}{sh_str}{TI_str}/sd{seed}'   
    else:
        if variation_name:
            destination_dir_Uref = f'{root_folder}/{DLC_folder_name}/{DLC_choice}_{variation_name}/Yaw_{YawAngle}/{Uref}{sh_str}{TI_str}'
        else:
            destination_dir_Uref = f'{root_folder}/{DLC_folder_name}/{DLC_choice}/Yaw_{YawAngle}/{Uref}{sh_str}{TI_str}' #DLC_{DLC_choice[0]}/

    os.makedirs(destination_dir_Uref, exist_ok=True)     # Create the destination folder (DLC case folder (+variation if flagged))
    # If file already exists overwrite it
    dest_file = os.path.join(destination_dir_Uref, os.path.basename(output_filename))
    if os.path.exists(dest_file):
        os.remove(dest_file)
    
    shutil.move(output_filename, destination_dir_Uref)

    
     
    
    return output_filename, destination_dir_Uref 

def generar_inflow_file(root_name,root_folder, DLC_folder_name, OriginalDir_OF, DLC_choice, TurbSim_DLCs, Uref, IECWind_Type, Wind_file_root_name, Site_specific_wind, Wind_user_choice, TM, YawAngle, variation_name = None, sh = None, TI = None, seed =None):
    
    sh_str = f"/shear{sh}/" if Wind_user_choice else ""
    TI_str = f"/TI{TI}" if Wind_user_choice or Site_specific_wind else ""        # For folder generation. if there combinatios of TI and shear values, a folder for each should be created.
    seed_str = f"/sd{seed}" if seed is not None else ""

    if Site_specific_wind:
        Wind_folder = f"Wind/SPW/v{Uref}{sh_str}{TI_str}{seed_str}"
    else:
        Wind_folder = f"Wind/{TM}/v{Uref}{sh_str}{TI_str}{seed_str}"
    sh_str_file = f"_sh{sh}_" if Wind_user_choice or Site_specific_wind else ""
    TI_str_file = f"TI{TI}" if Wind_user_choice or Site_specific_wind else ""
    seed_str_file = f"_sd{seed}" if seed is not None else ""
    Turb_filename = f"{Wind_file_root_name}_{Uref}{sh_str_file}{TI_str_file}{seed_str_file}.bts"

    variables = {
        'WindType': 3 if DLC_choice in TurbSim_DLCs else 2,
        'Filename_BTS': f"\"{root_folder}/{DLC_folder_name}/{Wind_folder}/{Turb_filename}\"" if DLC_choice in TurbSim_DLCs else "",             #If users decide to run a shtdown with turbulent wind, they will be able to 
        'Filename_Uni': f"\"{root_folder}/{DLC_folder_name}/Wind/{IECWind_Type}/{IECWind_Type}{Uref}.wnd\"" if DLC_choice in ['3p1', '4p1'] else ""
    }
    output_filename, destination_dir_Uref = generar_archivo_entrada("InflowFile",root_name, root_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref, variables, "InflowFile", YawAngle, variation_name, sh, TI, seed)
    return output_filename

def generar_elastodyn_file(root_name,root_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs,  Uref, RotorSpeed, Pitch, i, YawAngle, variation_name = None, sh = None, TI = None, seed = None):

    variables = {
        "GenDOF": True, #if DLC_choice in ['1p2', '2p4l', '2p4y','3p1','4p1'] else False, #True: 1p2, 2p4l, '2p4y', 4p1. False: 6.4
        "YawDOF": True,
        "BldFile1": f'"{root_folder}/{DLC_folder_name}/General/{root_name}_ElastoDyn_blade.dat" ',
        "BldFile2": f'"{root_folder}/{DLC_folder_name}/General/{root_name}_ElastoDyn_blade.dat" ',
        "BldFile3": f'"{root_folder}/{DLC_folder_name}/General/{root_name}_ElastoDyn_blade.dat" ',
        "BldFile(1)": f'"{root_folder}/{DLC_folder_name}/General/{root_name}_ElastoDyn_blade.dat" ',
        "BldFile(2)": f'"{root_folder}/{DLC_folder_name}/General/{root_name}_ElastoDyn_blade.dat" ',
        "BldFile(3)": f'"{root_folder}/{DLC_folder_name}/General/{root_name}_ElastoDyn_blade.dat" ',
        'TwrFile': f'"{root_folder}/{DLC_folder_name}/General/{root_name}_ElastoDyn_tower.dat" ',
        'RotSpeed': RotorSpeed[i], #if DLC_choice in ['1p2', '2p4l','2p4y', '4p1'] else 0,    #For DLC 3.1 or DLC 6.4: Initial RSp = 0rpm.
        'BlPitch(1)': Pitch[i], #if DLC_choice in ['1p2', '2p4l', '2p4y','4p1'] else 90,  #90°: feather position: for 3.1 and 6.4
        'BlPitch(2)': Pitch[i], #if DLC_choice in ['1p2', '2p4l', '2p4y', '4p1'] else 90,
        'BlPitch(3)': Pitch[i], #if DLC_choice in ['1p2', '2p4l', '2p4y','4p1'] else 90,
        'NacYaw': YawAngle
    }
    output_filename, destination_dir_Uref = generar_archivo_entrada("ElastoDyn",root_name, root_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref,  variables, "ElastoDyn", YawAngle, variation_name, sh, TI, seed)
    return output_filename

def generar_servodyn_file(root_name, root_folder, controller_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref,Min_Gen_Speed, Time_event_Start, Max_Pitch_rate, Pitch_rate, Pitch, RotorSpeed, i, YawAngle,
                          variation_name = None, sh = None, TI = None, seed = None):
    variables = {
        'PCMode': 5, #if DLC_choice in ['1p2', '2p4l', '2p4y'] or variation_name == 'ROSCO_SDTime' else 0, #VER ESTO! LO DE VARIATION NAME: la idea es que sea 5 si se usa 4p1_ROSCOSDTime
        'DLL_FileName': f'"{controller_folder}/libdiscon.dll"\t',      #Este controlador hay que darlo con el programa, porque lo creé yo (FG). Es el que tiene la opcion de SDTime.
        'DLL_INFile': f'"{root_name}_DISCON_{DLC_choice}.IN"\t',
        'GenTiStr': False if DLC_choice == '3p1' else True,
        'GenTiStp': True, #if DLC_choice == '2p4l' else True,
        'SpdGenOn': Min_Gen_Speed if DLC_choice == '3p1' else 99999.0,
        'TimGenOf': Time_event_Start if DLC_choice == '2p4l' else 99999.0,
        'TPitManS(1)': Time_event_Start if DLC_choice == '3p1' or variation_name == 'PitchMan' else (Time_event_Start+0.2 if DLC_choice == '2p4l' else 9999.9),
        'TPitManS(2)': Time_event_Start if DLC_choice =='3p1' else (Time_event_Start+0.2 if DLC_choice == '2p4l' else 9999.9),  # 2.1l: Simulo un apagado de emergencia 0.2s después de la pérdida de red
        'TPitManS(3)': Time_event_Start if DLC_choice == '3p1' else (Time_event_Start+0.2 if DLC_choice == '2p4l' else 9999.9), # Inicio de la maniobra.
        'PitManRat(1)': Pitch_rate if DLC_choice in ['4p1', '3p1'] else Max_Pitch_rate, # DEPENDE DE LA TURBINA. AGREGAR INPUT.
        'PitManRat(2)': Pitch_rate if DLC_choice in ['4p1', '3p1'] else Max_Pitch_rate,
        'PitManRat(3)': Pitch_rate if DLC_choice in ['4p1', '3p1'] else Max_Pitch_rate,
        'BlPitchF(1)': Pitch[i] if DLC_choice == '3p1' else 90,     
        'BlPitchF(2)': Pitch[i] if DLC_choice == '3p1' else 90,
        'BlPitchF(3)': Pitch[i] if DLC_choice == '3p1' else 90,
        'YawNeut': YawAngle
    }
    output_filename, destination_dir_Uref = generar_archivo_entrada("ServoDyn",root_name, root_folder, DLC_folder_name,  OriginalDir_OF, Wind_user_choice, Site_specific_wind,  DLC_choice, TurbSim_DLCs,  Uref, variables, "ServoDyn", YawAngle, variation_name, sh, TI,seed)
    return output_filename, destination_dir_Uref

def generar_fst_file(root_name, root_folder, DLC_folder_name,OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref, output_filename_ED, output_filename_IN, output_filename_SD, turb_sel, Sim_Time, YawAngle,
                     variation_name = None, sh = None, TI = None, seed = None):
    variables = {
        'EDFile': f'"{output_filename_ED}" ',
        'BDBldFile(1)': f'"{root_folder}/{DLC_folder_name}/General/{root_name}_BeamDyn.dat" ', #BeamDyn files
        'BDBldFile(2)': f'"{root_folder}/{DLC_folder_name}/General/{root_name}_BeamDyn.dat" ',
        'BDBldFile(3)': f'"{root_folder}/{DLC_folder_name}/General/{root_name}_BeamDyn.dat" ',
        'AeroFile': f'"{root_folder}/{DLC_folder_name}/General/{root_name}_AeroDyn.dat" ', 
        'InflowFile': f'"{output_filename_IN}" ',
        'ServoFile': f'"{output_filename_SD}" ',
        'OutFileFmt': 2,
        'TMax': Sim_Time #if turb_sel == 1 else 3660      #Simulation time based on turb_sel flag
    }
    output_filename, destination_dir_Uref = generar_archivo_entrada("fst", root_name,root_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref, variables, "", YawAngle, variation_name, sh, TI, seed)
    return output_filename

def editar_discon_file(DLC_choice, root_name, destination_dir_Uref, Time_event_Start, OriginalDir_OF, Pacc, Itim_SI, Delta_T_over):
    # Modificar el archivo DISCON.in
    # Copy ROSCO input files, into the folder.
    pattern = f"{OriginalDir_OF}/{root_name}_DISCON.*"
    matching_files = glob.glob(pattern)
    shutil.copy2(matching_files[0], destination_dir_Uref)
    pattern_Cp_Ct_Cq = f"{OriginalDir_OF}/*Cp_Ct_Cq*"
    matching_files_Cp_Ct = glob.glob(pattern_Cp_Ct_Cq)
    shutil.copy2(f"{matching_files_Cp_Ct[0]}", destination_dir_Uref)
    

    archivos_DISCON = glob.glob(f"{destination_dir_Uref}/{root_name}_DISCON.*")
    DISCON_file_name = f"{destination_dir_Uref}/{root_name}_DISCON_{DLC_choice}.IN"

    if archivos_DISCON:
        DISCON_file = archivos_DISCON[0]
        
        pattern_Cp_Ct_Cq = f"{destination_dir_Uref}/*Cp_Ct_Cq*"
        matching_files_Cp_Ct = glob.glob(pattern_Cp_Ct_Cq)
        NewPars = [f'"{matching_files_Cp_Ct[0]}"']
        ModVars = ['PerfFileName']
        
        # Read the original content of the file
        with open(DISCON_file, 'r') as original_file:
            lines = original_file.readlines()
        
        # Open the file for writing (overwriting it with modifications)
        with open(DISCON_file, 'w') as new_file:
            for line in lines:
                newline = line
                for index, tmpVar in enumerate(ModVars):
                    if tmpVar in line:
                        # Replace the line with the new parameter and a comment
                        newline = f"{NewPars[index]}\t ! {ModVars[index]}\n"
                new_file.write(newline)
        
        if DLC_choice == '4p1':
            NewPars = [1, Time_event_Start]
            ModVars = ['SD_Mode', 'SD_Time']
            
            # Read the original content of the file
            with open(DISCON_file, 'r') as original_file:
                lines = original_file.readlines()
            
            # Open the file for writing (overwriting it with modifications)
            with open(DISCON_file, 'w') as new_file:
                for line in lines:
                    newline = line
                    for index, tmpVar in enumerate(ModVars):
                        if tmpVar in line:
                            # Replace the line with the new parameter and a comment
                            newline = f"{NewPars[index]}\t ! {ModVars[index]}\n"
                    new_file.write(newline)
        if DLC_choice == 'Wang':
            NewPars = [4, Itim_SI, Pacc]#,, 1]
            ModVars = ['IS_ControlMode', 'Itim_SI', 'Frecovery']#,'VS_ControlMode']
            
            # Read the original content of the file
            with open(DISCON_file, 'r') as original_file:
                lines = original_file.readlines()
            
            # Open the file for writing (overwriting it with modifications)
            with open(DISCON_file, 'w') as new_file:
                for line in lines:
                    newline = line
                    for index, tmpVar in enumerate(ModVars):
                        if tmpVar in line:
                            # Replace the line with the new parameter and a comment
                            newline = f"{NewPars[index]}\t ! {ModVars[index]}\n"
                    new_file.write(newline)
        elif DLC_choice == 'Tarnowski':
            NewPars = [1, Itim_SI, Pacc]#,, 1]
            ModVars = ['IS_ControlMode', 'Itim_SI', 'Frecovery']#,, 'VS_ControlMode']
            
            # Read the original content of the file
            with open(DISCON_file, 'r') as original_file:
                lines = original_file.readlines()
            
            # Open the file for writing (overwriting it with modifications)
            with open(DISCON_file, 'w') as new_file:
                for line in lines:
                    newline = line
                    for index, tmpVar in enumerate(ModVars):
                        if tmpVar in line:
                            # Replace the line with the new parameter and a comment
                            newline = f"{NewPars[index]}\t ! {ModVars[index]}\n"
                    new_file.write(newline)
        elif DLC_choice == 'Norm_op':
            NewPars = [0, 9999999999]#,, 1]
            ModVars = ['IS_ControlMode', 'Itim_SI']#,, 'VS_ControlMode']
            
            # Read the original content of the file
            with open(DISCON_file, 'r') as original_file:
                lines = original_file.readlines()
            
            # Open the file for writing (overwriting it with modifications)
            with open(DISCON_file, 'w') as new_file:
                for line in lines:
                    newline = line
                    for index, tmpVar in enumerate(ModVars):
                        if tmpVar in line:
                            # Replace the line with the new parameter and a comment
                            newline = f"{NewPars[index]}\t ! {ModVars[index]}\n"
                    new_file.write(newline)
        elif DLC_choice == 'GMFC':
            NewPars = [5, Itim_SI, Pacc, Delta_T_over]#,, 1]
            ModVars = ['IS_ControlMode', 'Itim_SI', 'Frecovery', 'Delta_T_over']#,, 'VS_ControlMode']
            
            # Read the original content of the file
            with open(DISCON_file, 'r') as original_file:
                lines = original_file.readlines()
            
            # Open the file for writing (overwriting it with modifications)
            with open(DISCON_file, 'w') as new_file:
                for line in lines:
                    newline = line
                    for index, tmpVar in enumerate(ModVars):
                        if tmpVar in line:
                            # Replace the line with the new parameter and a comment
                            newline = f"{NewPars[index]}\t ! {ModVars[index]}\n"
                    new_file.write(newline)
        os.rename(DISCON_file, DISCON_file_name)


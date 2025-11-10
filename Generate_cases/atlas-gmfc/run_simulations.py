import os
import subprocess
from concurrent.futures import ThreadPoolExecutor

def run_openfast_cases(root_folder, DLC_folder_name, root_name, velocidades, DLCs, seeds,seeds_names, TI_SSW, sel_nucleos, turb_sel, TurbSim_DLCs, variation_name, openfast_exe, TI):
    """
    Función para correr las simulaciones de OpenFAST en paralelo.
    
    Args:
        root_folder (str): Carpeta raíz donde están ubicados los archivos.
        DLC_folder_name (str): Nombre de la carpeta de DLCs.
        root_name (str): Nombre base del archivo .fst.
        velocidades (list): Lista de velocidades incidentales.
        DLCs (list): Lista de DLCs a simular.
        seeds (list): Lista de semillas para las simulaciones.
        sel_nucleos (int): Número de núcleos de CPU a usar en la paralelización.
        turb_sel (int): Selección de caso turbulento (1 = con semillas, 0 = sin semillas).
        TurbSim_DLCs (list): DLCs que requieren usar TurbSim.
        variation_name (str): Nombre de la variación para DLC específico.
        openfast_exe (str): Ruta del ejecutable de OpenFAST.

    """

    base_dlc_path = f'{root_folder}/{DLC_folder_name}'                      # DLC folder path

    def run_simulation(fst_path):                                           # Function that runs the simulation for a given fst file path
        print(f"Ejecutando simulación para: {fst_path}")
        if os.path.exists(fst_path):
            print('entre')
            cmd = [openfast_exe, fst_path]                                  # Simulation input: OpenFAST executable + fst file path
            try:
                # Ejecuta el comando sin abrir una nueva consola y captura salida y errores
                process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)     # Run simulations, with the cmd inputs. Write the standard output and error output to stdout and stderr.
                stdout, stderr = process.communicate()                      # Contains the output and error data. Useful for "else" term (communicates errors through stderr).
                
                if process.returncode == 0:                                 # 0 means successful simulation.
                    print(f"Simulación completada para {fst_path}")
                else:
                    print(f"Error en la simulación para {fst_path}: {stderr.decode('utf-8')}")
                    print(stdout.decode('utf-8'))
            except Exception as e:
                print(f"Error al ejecutar la simulación para {fst_path}: {e}")
        else:
            print(f"Archivo .fst no encontrado: {fst_path}")
    #TI = 8
    # Preparar la lista de argumentos sd{seeds.index(sd)}
    if turb_sel == 1:
        args_list = [
            (f'{base_dlc_path}/{dlc}/{vel}/TI{TI}.0/{seeds_names[seeds.index(sd)]}/{root_name}_{dlc}_v{vel}_TI{TI}.0_{seeds_names[seeds.index(sd)]}.fst' if dlc in TurbSim_DLCs else
            f'{base_dlc_path}/{dlc}_{variation_name if dlc == "4p1" else ""}/{vel}/{root_name}_{dlc}_{vel}.fst')
            for dlc in DLCs for vel in velocidades for sd in (seeds if dlc in TurbSim_DLCs else [None])
        ]
        print(args_list)
    else:
        args_list = [
            f'{base_dlc_path}/DLC_{dlc[0]}/{dlc}/{vel}/{root_name}_{dlc}_{vel}.fst' 
            for dlc in DLCs for vel in velocidades
        ]

    # Eliminar rutas no existentes
    args_list = [fst_path for fst_path in args_list if os.path.exists(fst_path)]
    print(args_list)
    # Paralelización de las simulaciones
    with ThreadPoolExecutor(max_workers=sel_nucleos) as executor:
        futures = [executor.submit(run_simulation, fst_path) for fst_path in args_list] #Runs "run_simulation", paralelizing it into diff cores.

        for future in futures:
            try:
                future.result()
            except Exception as e:
                print(f"Error en la simulación: {e}")
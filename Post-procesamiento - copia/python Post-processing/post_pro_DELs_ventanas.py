import numpy as np
import pandas as pd
import os
from getSimRes_old import getSimRes_old
import matplotlib.pyplot as plt

import sys
sys.path.append('C:/Users/fgarchitorena/Desktop/OpenFast/openfast_toolbox-main')
from openfast_toolbox.io import FASTOutputFile

#----------------------DATOS DE ENTRADA------------------------------------------#

# Definición de los exponentes de Wöhler para diferentes variables
m_values = {
    'LSSGagMya_[kN-m]': 4, 
    'LSSGagMza_[kN-m]': 4, 
    'TwrBsMxt_[kN-m]': 4, 
    'TwrBsMyt_[kN-m]': 4
}

for i in range(1, 3):
    m_values[f'RootMxb{i}_[kN-m]'] = 10
    m_values[f'RootMyb{i}_[kN-m]'] = 10

# Lista de variables a analizar
variables = ['RootMxb1_[kN-m]','RootMyb1_[kN-m]', 'TwrBsMyt_[kN-m]', 'TwrBsMxt_[kN-m]']
varnames = ['EdgeWise','FlapWise', 'ForeAft', 'SideSide']
DLCs = ['1p1', '3p1', '4p1'] #'2p1'
DLCs_names = ['DLC 1.2','DLC 3.1','DLC 4.1']
TurbSim_DLCs = ['1p1','2p1'] 
dt = 0.00625                                                                # Paso temporal de las simulaciones.

# ENTRADAS DEL USUARIO
DLCs = ['3p1','4p1']                                                          # DLC a analizar                                                            # Nombre del DLC a analizar
variation =''#'_ROSCO_SDTime' #'_TurbS'#'_ROSCO_SDTime'#                    # Variación: para el 4.1 sobre todo (para el resto pueden analizarse casos con turbSim)
root_name = 'IEA-3.4-130-RWT_'                                              # Nombre de la turbina de referencia utilizada
seeds = [13426, 13427, 13428, 13429, 13430, 13431]                          # Seeds for turbsim
DLC_folder = 'DLCs_post_pro' #DLCs_2                                        # Carpeta donde se encuentran los DLCs a analizar.
vel = [8.0,20.0]                                                            # Velocidades a analizar
directorio_save_root = 'C:/Users/fgarchitorena/Proyectos de investigacion/FSE_Incercia Sintética/Informe_UTE_DLCs/Imagenes_DLCs_2/post_pro'

# Parámetros constantes para la función getSimRes
Teq = 1
bins = 100  # Puede ser int o list
nbins = bins if isinstance(bins, int) else len(bins) - 1*(len(bins) > 1)
seeds_index = 0

 
largo_ventana = '200s'

for DLC_choice in DLCs:
    if DLC_choice == '3p1':
        variation =''
        DLC_name = '3.1'
    else:
        variation ='_ROSCO_SDTime'
        DLC_name = '4.1'
        
    # VENTANAS TEMPORALES A UTILIZAR
    ventanas = [int(320/dt),int(520/dt), int(340/dt),int(540/dt), int(460/dt),int(660/dt)] if DLC_choice == '3p1' else [int(320/dt),int(520/dt), int(340/dt),int(540/dt), int(150/dt),int(350/dt)]        # Ventanas de 200s para cada DLC.
    ventanas_legend = [f'Ventana 1: {ventanas[0]*dt-60}s a {ventanas[1]*dt-60}s',f'Ventana 2: {ventanas[2]*dt-60}s a {ventanas[3]*dt-60}s', f'Ventana 3: {ventanas[4]*dt-60}s a {ventanas[5]*dt-60}s']    #Nombres de las ventanas.

    #----------------------------SCRIPT PARA SACAR EN UN DATA FRAME LOS DELS DE CADA VARIABLE DE INTERES POR VENTANA TEMPORAL PARA CADA VELOCIDAD------------------------------#
    # Columnas para el DataFrame (En caso de no querer sacar alguno de los datos, se pueden sacar de aqui las columnas)
    columns = ["Simulation Name", "Leq"]+ \
        [f"S_{i}" for i in range(1, nbins + 1)] + \
        [f"N_{i}" for i in range(1, nbins + 1)] + \
        [f"bins_{i}" for i in range(1, nbins + 2)] + \
        [f"DELi_{i}" for i in range(1, nbins + 1)]    
        

    # Diccionario para almacenar los resultados organizados por velocidad, ventana y variable
    resultados = {v: {f'ventana_{i+1}': {var: [] for var in variables} for i in range(len(ventanas)//2)} for v in vel}

    # Procesamiento de cada variable
    for var in variables:
        m = m_values[var]
        
        # Simulaciones para diferentes velocidades de viento
        for v in vel:
            simName = f'{root_name}{DLC_choice}_{v}.outb'
            for i in range(0, len(ventanas), 2):
                
                #Defino ventanas temporales a utilizar
                start_index = ventanas[i]
                end_index = ventanas[i+1]
                
                #Obtengo los datos de post procesamiento para la variable de estudio, utilizando la función getSimRes.
                Leq, S, N, bins_ed, DELi, T  = getSimRes_old(simName, DLC_folder, var, m, Teq, bins, DLC_choice, start_index, end_index, variation, v, seeds_index=None, seeds=None)
                resultados[v][f'ventana_{i//2 + 1}'][var].append([simName, Leq]+ S.tolist() + N.tolist()+ bins_ed.tolist()+ DELi.tolist())  #Guardo datos en un diccionario

    # Convertir resultados a DataFrames para análisis o gráficos: Data frame adentro de diccionario, adentro de dict, adentro de dict. (Esto no es necesario pero facilita a la hora de hacer los plots.)
    #ver con type()
    resultados_df = {
        v: {
            ventana: {
                var: pd.DataFrame(data, columns=columns) for var, data in vars_data.items()
                }
                for ventana, vars_data in ventanas_data.items()
            }
            for v, ventanas_data in resultados.items()
        }

                
                

    #################################################################################################################
    #################################################################################################################
    ####################################### GRÁFICAS ################################################################
    #################################################################################################################
    #################################################################################################################



    #-----------------------GRAFICOS DE BARRA DE LOS DELS POR MOMENTO PARA CADA VELOCIDAD PARA CADA VENTANA----------------------------------#
    #--------------------FIGURE SETTINGS------------------------------------------------------------#
    plt.figure(figsize=(10, 5))
    plt.rcParams.update({
        "text.usetex": False,
        "font.family": 'serif',
        "font.serif": ['Times New Roman'],
        "text.latex.preamble": r"\usepackage{amsmath}",
        "font.size": 12,            # Tamaño general de la fuente
        "axes.titlesize": 16,       # Tamaño de la fuente para el título de los ejes
        "axes.labelsize": 14,       # Tamaño de la fuente para las etiquetas de los ejes
        "xtick.labelsize": 12,      # Tamaño de la fuente para las etiquetas de los ticks en el eje x
        "ytick.labelsize": 12,      # Tamaño de la fuente para las etiquetas de los ticks en el eje y
        "legend.fontsize": 12,      # Tamaño de la fuente para la leyenda
        "figure.titlesize": 16      # Tamaño de la fuente para el título de la figura
    })
    #Obtengo el valor maximo para definir el limite en el eje y
    leq_all_values = []
    # Define el número de ventanas y variables
    num_ventanas = len(ventanas) // 2
    num_vars = len(variables)

    # Para cada velocidad
    vels = [8.0,20.0]
    for v in vels:
        print(v)
        # Define un offset para las barras de cada velocidad
        for i, ventana in enumerate([f'ventana_{j+1}' for j in range(num_ventanas)]):
            leq_values = []
            for var in variables:
                leq_mean = np.mean(resultados_df[v][ventana][var]['Leq'])
                leq_values.append(leq_mean)
                leq_all_values.append(leq_mean)
    max_value = max(leq_all_values)
    

    # Define el ancho de las barras
    bar_width = 0.2

    # Define las posiciones de las barras en el eje x
    index = np.arange(num_vars)

    # Colores para diferenciar las ventanas
    colors = ['b', 'g', 'r','m']

    # Para cada velocidad
    vels = [8.0, 20.0]
    for v in vels:
        # Crea una figura y ejes
        fig, ax = plt.subplots(figsize=(8, 6))
        # Define un offset para las barras de cada velocidad
        for i, ventana in enumerate([f'ventana_{j+1}' for j in range(num_ventanas)]):
            leq_values = []
            for var in variables:
                # Obtiene el valor medio de Leq para la ventana y variable
                leq_mean = np.mean(resultados_df[v][ventana][var]['Leq'])
                leq_values.append(leq_mean)
            
            # Crea las barras para cada ventana
            ax.bar(index + i * bar_width, leq_values, bar_width, label=f'{ventanas_legend[i]}', color=colors[i])

        # Ajusta las etiquetas y el layout del gráfico
        ax.set_xlabel('Momento')
        ax.set_ylabel('DEL (kNm)')
        ax.set_title(f'DLC {DLC_name}: Comparación de DEL por Ventana y Momento para U={v}m/s.')
        ax.set_xticks(index + bar_width)
        ax.set_xticklabels(varnames)
        ax.legend()
        plt.grid(alpha=0.3)
        plt.ylim(0,max_value+1000)
        
        # Muestra el gráfico para cada velocidad
        plt.tight_layout()
        filename = f'DELs_{DLC_choice}_ventanas_conysin_evento_{v}.png'
        directorio_save = f'{directorio_save_root}/{DLC_choice}/N_vs_S/ventanas/{v}'# Cambia esto a la ruta deseada
        file_path = os.path.join(directorio_save, filename)
        plt.savefig(file_path, bbox_inches='tight', pad_inches=0.05)
    
    ############################## NUBES DE PUNTOS N VS S PARA TODAS LAS VENTANAS #####################
    plt.figure(figsize=(12, 6))  # Aumentar el tamaño de la figura
    plt.rcParams.update({
        "text.usetex": False,
        "font.family": 'serif',
        "font.serif": ['Times New Roman'],
        "text.latex.preamble": r"\usepackage{amsmath}",
        "font.size": 20,            # Aumentar el tamaño general de la fuente
        "axes.titlesize": 26,       # Tamaño de la fuente para el título de los ejes
        "axes.labelsize": 24,       # Tamaño de la fuente para las etiquetas de los ejes
        "xtick.labelsize": 22,      # Tamaño de la fuente para las etiquetas de los ticks en el eje x
        "ytick.labelsize": 22,      # Tamaño de la fuente para las etiquetas de los ticks en el eje y
        "legend.fontsize": 22,      # Tamaño de la fuente para la leyenda
        "figure.titlesize": 26      # Tamaño de la fuente para el título de la figura
    })

    markers=['o', 'X', 's' ]
    colors = ['b', 'y', 'm']

    # Generar gráficas para todas las cargas (variables) y velocidades, combinando datos de ventanas 1, 2 y 3
    j = 0
    for var in variables:
        for v, ventanas_data in resultados_df.items():
            plt.figure(figsize=(10, 6))  # Crear una sola figura por velocidad y variable
            i = 0
            for ventana, vars_data in ventanas_data.items():
                if ventana == '':
                    continue  
                else:
                    print(f'Procesando {ventana}, Velocidad: {v}, Variable: {var}') 
                    df = vars_data[var]

                    # Verifica que el DataFrame tiene las columnas esperadas
                    S_columns = [col for col in df.columns if col.startswith('S_')]
                    N_columns = [col for col in df.columns if col.startswith('N_')]

                    S_values = df[S_columns].values.flatten()
                    N_values = df[N_columns].values.flatten()

                    plt.scatter(S_values, N_values, label=f'{ventanas_legend[i]}', marker=markers[i], color = colors[i], s=100)
                    i += 1

            # Configurar las etiquetas y el título del gráfico
            plt.xlabel('S_i (Rango de Carga)')
            plt.ylabel('N_i (Número de Ciclos)')
            plt.title(f'N vs S para {varnames[j]} con U = {v} m/s.')
            plt.grid(True)
            plt.legend()

            # Guardar y mostrar el gráfico
            filename = f'N_vs_S_{varnames[j]}_velocidad_{v}_comp_ventanas.png'
            directorio_save = f'{directorio_save_root}/{DLC_choice}/N_vs_S/ventanas/{v}'# Cambia esto a la ruta deseada
            file_path = os.path.join(directorio_save, filename)
            plt.savefig(file_path, bbox_inches='tight', pad_inches=0.05)
        j += 1
        
    ##################################### NUBES DE PUNTOS DE DELi VS S ##########################################################
    j = 0
    for var in variables:
        for v, ventanas_data in resultados_df.items():
            plt.figure(figsize=(10, 6))  # Crear una sola figura por velocidad y variable
            i = 0
            for ventana, vars_data in ventanas_data.items():
                if ventana == '':
                    continue  
                else:
                    print(f'Procesando {ventana}, Velocidad: {v}, Variable: {var}') 
                    df = vars_data[var]

                    # Verifica que el DataFrame tiene las columnas esperadas
                    DELi_columns = [col for col in df.columns if col.startswith('DELi_')]
                    S_columns = [col for col in df.columns if col.startswith('S_')]

                    DELi_values = df[DELi_columns].values.flatten()
                    S_values = df[S_columns].values.flatten()

                    plt.scatter(S_values, DELi_values, label=f'{ventanas_legend[i]}', marker=markers[i], color = colors[i], s=100)

                    i += 1


            # Configurar las etiquetas y el título del gráfico
            plt.xlabel('S_i (Rango de Carga)')
            plt.ylabel('DELi (DEL por bin)')
            plt.title(f'DELi vs S para {varnames[j]} con U = {v} m/s.')
            plt.grid(True)
            plt.legend()

            # Guardar y mostrar el gráfico
            filename = f'N_vs_DELi_{varnames[j]}_velocidad_{v}_comp_ventanas.png'
            directorio_save = f'{directorio_save_root}/{DLC_choice}/N_vs_DELi/{v}'# Cambia esto a la ruta deseada
            file_path = os.path.join(directorio_save, filename)
            plt.savefig(file_path, bbox_inches='tight', pad_inches=0.05)
        j += 1


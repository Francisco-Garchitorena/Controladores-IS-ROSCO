#Últimas versión!! 08/07/25 -- saca DELs por semilla, por velocidad y LWT. Genera plots de interés y guarda los resultados en un pickle. -- AHORA CON YAW
import os
import numpy as np
import pandas as pd
import pickle
import matplotlib.pyplot as plt
from pathlib import Path
from openfast_toolbox.io import FASTOutputFile
from openfast_toolbox.tools.fatigue import equivalent_load

# Clase que representa una única simulación de OpenFAST y calcula DELs y máximos para cada variable
class SimulationResult:
    def __init__(self, filepath, variables, del_variables, m_values, Teq, bins, start_idx, end_idx, buscar_semillas):
        self.filepath = filepath                        # Ruta del archivo de salida .outb
        self.variables = variables                      # Lista de variables a analizar (e.g. RootMyb1, RotSpeed)
        self.m_values = m_values                        # Diccionario con valores m para cada variable (exponente S-N)
        self.Teq = Teq                                  # Tiempo equivalente para cálculo DEL
        self.bins = bins                                # Cantidad de bins para histograma de ciclos
        self.start_idx = start_idx                      # Índice inicial para recorte temporal (ignorar transitorios)
        self.end_idx = end_idx                          # Índice final para recorte temporal
        self.df = None                                  # DataFrame para almacenar datos cargados
        self.results = {}                               # Diccionario donde se guardan DEL y máximos por variable
        self.mean_power = None                          # Potencia media en segmento analizado
        self.uref = self._extract_uref()                # Extrae velocidad de viento desde el path del archivo
        self.seed = self._extract_seed()                # Extrae semilla (seed) desde el path del archivo
        self.yaw_angle = self._extract_yaw_angle()      # Extrae el ángulo de yaw desde el path del archivo
        self.del_variables = del_variables
        self.buscar_semillas = buscar_semillas       # Indica si el DEL proviene de un DLC con semillas

    # Extrae la velocidad de viento del nombre de alguna carpeta en el path (asume que alguna carpeta es la velocidad). Intenta hasta que se encuentra con un numero (REVISAR!! puede fallar si hay un número antes en el nombre de la carpeta)
    def _extract_uref(self):
        parts = self.filepath.split(os.sep)
        for p in parts:
            try:
                val = float(p)
                # Aceptar solo si tiene decimal (ej: '5.0' no '5')
                if '.' in p and 2 <= val <= 40:
                    return val
            except ValueError:
                continue
        return None

    # Extrae el nombre de la semilla (seed) del path (carpeta que empieza con 'Seed' o 'sd')
    def _extract_seed(self):
        parts = self.filepath.split(os.sep)
        for p in parts[::-1]:
            if p.startswith("Seed") or p.startswith("sd"):
                return p
        return "no seeds"
    
    # Extrae el ángulo de yaw desde el path, buscando carpeta que comience con 'Yaw_'
    def _extract_yaw_angle(self):
        parts = self.filepath.split(os.sep)
        for p in parts:
            if p.startswith("Yaw_"):
                try:
                    return int(p.split("Yaw_")[1])
                except:
                    pass
        return 0  # Asume yaw 0 si no se encuentra

    # Carga el archivo de salida OpenFAST a un DataFrame pandas
    def load(self):
        self.df = FASTOutputFile(self.filepath).toDataFrame()

    # Calcula el DEL y valor máximo para cada variable en el rango temporal definido para una única simulación
    def compute(self):
        if self.df is None:
            self.load()

        # Recorte temporal para análisis
        time = self.df['Time_[s]'][self.start_idx:self.end_idx]
        power_segment = self.df['GenPwr_[kW]'][self.start_idx:self.end_idx]
        self.mean_power = power_segment.mean()  # Guarda potencia media de la señal --esta debería guardarla en el dit de resultados?  FG: 29/07/25: Creo que esto no lo estoy usando para nada

        # Calcula DEL y máximo para cada variable solicitada 
        for var in self.variables:
            m = self.m_values.get(var, 10)   # Si no hay m definido, usa 10 por defecto
            values_segment = self.df[var][self.start_idx:self.end_idx]
            if var in self.del_variables:
                max_value_1 = values_segment.max()
                max_value_2 = abs(values_segment.min())
                max_value   = max_value_1 if max_value_1 > abs(max_value_2) else max_value_2  # Elijo el máximo absoluto entre ambos
            else: 
                max_value = values_segment.mean()   #para variables como el pitch o la velocidad de giro me importa más la media--creo: consultar y revisar.
            if var in self.del_variables:
                del_value = equivalent_load(
                    time,
                    values_segment,
                    m=m,
                    Teq=self.Teq,
                    bins=self.bins
                )
            else:
                del_value = None  # No calcular DEL para variables no relevantes (ej: Pitch, RotSpeed)
            # Guarda los resultados para esa variable -- el diccionario me guarda DEL y maximo para cada simulación y cada variable: esto podría ser una salida también
            self.results[var] = {
                'DEL': del_value,
                'max_value': max_value
            }
# NUEVA CLASE: agrupa simulaciones con mismo yaw dentro de un DLCGroup
class YawGroup:
    def __init__(self, yaw_angle):
        self.yaw_angle = yaw_angle                      # Ángulo de yaw (clave)
        self.simulations = []                           # Lista con instancias de SimulationResult

    def add_simulation(self, sim_result):               # Agrega una simulación al grupo de yaw
        self.simulations.append(sim_result)

    def run_all(self):
        for sim in self.simulations:
            sim.compute()

    def get_seed_del_and_max(self, variable):
        seed_dict = {}
        for sim in self.simulations:  # CORREGIDO
            key = (sim.uref, sim.seed, sim.yaw_angle)
            #print('sim.uref:',sim.uref)
            if key not in seed_dict:
                seed_dict[key] = {'DEL': [], 'max': []}
            if variable in sim.del_variables and sim.results[variable]['DEL'] is not None:    #Solo quiero que me guarde el DEL en los casos que está calculado
                seed_dict[key]['DEL'].append(sim.results[variable]['DEL'])
            seed_dict[key]['max'].append(sim.results[variable]['max_value'])
        return seed_dict

    
    # Calcula resumen por velocidad, ponderando por semillas con la ecuación de David (sum(DEL^m) / n)^1/m
    def get_summary_by_speed(self, variable, buscar_semillas, mode='mean'):
        seed_data = self.get_seed_del_and_max(variable)
        speed_summary = {}

        for (uref, seed, yaw), values in seed_data.items():  #Esta primer parte es igual a la función anterior (guardo DEL y max por velocidad y semilla)
            if uref not in speed_summary:
                speed_summary[uref] = {'DEL': [], 'max': []}
            speed_summary[uref]['DEL'].extend(values['DEL'])    #agrupo todos los valores, el yaw no entra en juego porque va a ser siempre igual acá
            speed_summary[uref]['max'].extend(values['max'])

        result = {}
        for uref, values in speed_summary.items():
            m = self.simulations[0].m_values.get(variable, 10)
            dels = [d for d in values['DEL'] if d is not None]    #solo quiero el del de las cargas
            if dels:
                if buscar_semillas:      # Con esta flag separo los casos a ponderar por semilla y los que no lo requieren (DLC 4.1, 3.1)
                    del_value = (np.sum(np.power(dels, m)) / len(dels)) ** (1 / m)
                else: 
                    del_value = dels[0]
            else:
                del_value = None
            result[uref] = {
                'DEL': del_value,                                # Promedio DEL entre semillas ponderado con el m
                'max': np.mean(values['max']) if mode == 'mean' else np.max(values['max'])  # Promedio o máximo de los máximos
            }
        return result
    
# Clase que agrupa todas las simulaciones que pertenecen a un mismo DLC (Design Load Case)
class DLCGroup:
    def __init__(self, name):
        self.name = name
        self.yaw_groups = {}  # Diccionario: yaw_angle -> YawGroup

    def add_simulation(self, sim_result):
        yaw = sim_result.yaw_angle # Extrae el ángulo de yaw de la simulación
        if yaw not in self.yaw_groups:
            self.yaw_groups[yaw] = YawGroup(yaw)        #Aqui DLCGroup crea una instancia de YawGroup si no existe
        self.yaw_groups[yaw].add_simulation(sim_result)

    def run_all(self):
        for group in self.yaw_groups.values():
            group.run_all()

    def get_all_yaws(self):
        return list(self.yaw_groups.keys())
    
    # Obtiene DEL y máximos por semilla y velocidad (clave: (velocidad, semilla))
    #Recopila para cada simulación individual el DEL y el valor máximo de la variable dada, y los agrupa por pareja (velocidad, semilla).
    #Es decir, para cada combinación única de velocidad y semilla, devuelve listas con los DELs y máximos encontrados en las simulaciones correspondientes.
    def get_seed_del_and_max(self, variable):
        seed_dict = {}
        for yaw_group in self.yaw_groups.values():
            for sim in yaw_group.simulations:       # Itera sobre las simulaciones correspondientes a este yaw group, que están luego separadas por semilla, uref. 
                key = (sim.uref, sim.seed, sim.yaw_angle)  # AGREGADO yaw en clave
                if key not in seed_dict:
                    seed_dict[key] = {'DEL': [], 'max': []}
                if variable in sim.del_variables and sim.results[variable]['DEL'] is not None:
                    seed_dict[key]['DEL'].append(sim.results[variable]['DEL'])
                seed_dict[key]['max'].append(sim.results[variable]['max_value'])
        return seed_dict

    
# Clase central para manejar todos los DLCs y realizar el post procesamiento completo
class PostProcessor:
    def __init__(self):
        self.dlc_groups = {}  # Diccionario con nombre DLC : instancia DLCGroup

    # Agrega simulación al grupo DLC correspondiente (crea el grupo si no existe)
    def add_simulation(self, dlc_name, sim_result):     #El sim_result es una instancia de SimulationResult
        if dlc_name not in self.dlc_groups:
            self.dlc_groups[dlc_name] = DLCGroup(dlc_name)   #Aqui PostProcessor crea una instancia de DLCGroup si no existe
        self.dlc_groups[dlc_name].add_simulation(sim_result)
        print(f"Agregada simulación: {sim_result.filepath} al DLC {dlc_name} con yaw {sim_result.yaw_angle}")

    # Ejecuta el cálculo para todas las simulaciones de todos los DLCs
    def compute_all(self):
        for dlc_group in self.dlc_groups.values():
            dlc_group.run_all()  #Llama a la funció run_all() de la clase DLCGroup, que a su vez llama a compute() de cada SimulationResult---en conclusión: corre todo el postpresamiento

    # Exporta toda la instancia del postprocesador (con resultados) a un archivo pickle
    def export_to_pickle(self, filepath):
        with open(filepath, 'wb') as f:
            pickle.dump(self, f)  # Serializa toda la instancia del postprocesador

    # Genera un resumen con datos clave para cada simulación, útil para inspección rápida de los resultados
    # def summarize(self):
    #     summary = {}
    #     for dlc_name, group in self.dlc_groups.items():
    #         summary[dlc_name] = []
    #         for yaw_group in group.yaw_groups.values():
    #             for sim in yaw_group.simulations:
    #                 entry = {
    #                     'filepath': sim.filepath,
    #                     'uref': sim.uref,
    #                     'seed': sim.seed,
    #                     'yaw': sim.yaw_angle,
    #                     'mean_power': sim.mean_power,
    #                     'variables': sim.results
    #                 }
    #                 summary[dlc_name].append(entry)
    #     return summary

    # Calcula el DEL ponderado por la distribución Weibull (lifetime weighted DEL)-- DEL PONDERADO POR VELOCIDAD -- Lo corre una vez por variable
    def lifetime_weighted_del(self, dlc_name, variable, A, k, yaw_weights, buscar_semillas, Use_Weibull, pdf = None):
        group = self.dlc_groups[dlc_name]
        del_total = 0
        total_weight = 0

        for yaw, weight in yaw_weights[dlc_name].items():
            if yaw not in group.yaw_groups:
                continue
            summary = group.yaw_groups[yaw].get_summary_by_speed(variable, buscar_semillas)    # El summary.values es: dict_values([{'DEL': 2553.5393667185826, 'max': 5386.469063399067}, {'DEL': 3934.193090914738, 'max': 8923.456244604371}, ... tiene el DEL y max ponderado por semilla
            speeds = np.array(list(summary.keys()))
            DELs = np.array([v['DEL'] for v in summary.values()])   #guardo un array con los DELs ponderado por semilla (uno por velocidad)
            if Use_Weibull:
                pdf = (k / A) * (speeds / A)**(k - 1) * np.exp(-(speeds / A)**k)   #Weibull 
                pdf /= pdf.sum()
            del_yaw = np.sum(DELs * pdf)
            del_total += weight * del_yaw   #sumo weight*DEL para obtener el DEL poderado por yaw
            total_weight += weight

        return del_total / total_weight if total_weight > 0 else None
    
    def lifetime_weighted_del_with_occ(self, dlc_name, variable, A, k, cut_in, cut_out, Vref, yaw_weights, buscar_semillas, Use_Weibull=True, pdf=None, dlc_with_events=None, n_occ_dlcs=None, sim_time=None, n_years=20):
        """
        Calcula el DEL ponderado por tiempo de vida.
        
        - Si dlc_name ∈ dlc_with_events y n_occ_dlcs[dlc_name] es dict:
            pondera DELs solo en esas velocidades y multiplica por n_occ * sim_time / lifetime.
        - Si dlc_name ∈ dlc_with_events y n_occ_dlcs[dlc_name] es int:
            aplica pdf y luego multiplica por n_occ * sim_time / lifetime.
        - Sino: pondera solo con pdf normal.
        """

       # print(dlc_name)
        group = self.dlc_groups[dlc_name]
        del_total = 0
        total_weight = 0
        lifetime_sec = n_years * 365.25 * 24 * 3600

        is_event_dlc = dlc_with_events and dlc_name in dlc_with_events

        for yaw, weight in yaw_weights[dlc_name].items():
            if yaw not in group.yaw_groups:
                print('entre')
                continue

            summary = group.yaw_groups[yaw].get_summary_by_speed(variable, buscar_semillas)
            speeds = np.array(list(summary.keys()))
            DELs = np.array([v['DEL'] for v in summary.values()])

            if is_event_dlc and n_occ_dlcs:
                n_occ_info = n_occ_dlcs.get(dlc_name)
              #  print( 'n_occ_info:', n_occ_info)

                if isinstance(n_occ_info, dict):       #Si es un diccionario, como en el caso de 3.1, 4.1, debo realizar un filtrado por velocidades de los DELs
                    # caso: n_occ por velocidad (dict)
                    filtered_DELs = []                  # Para los DLCs que requieren solo algunas velocidades, filtro estas velocidades.
                    time_factors = []
                    filtered_speeds = []

                    for v, n_occ in n_occ_info.items():
                        if v in speeds:
                            idx = np.where(speeds == v)[0][0]
                            filtered_DELs.append(DELs[idx])
                            filtered_speeds.append(v)      #Guardo las velocidades de interés (las que vienen en el diccionario de n_occ)
                            total_time_v = n_occ * sim_time
                            print(dlc_name, sim_time)
                            time_factors.append(total_time_v / lifetime_sec)   #el factor de ponderación es el tiempo total de ocurrencia dividido por el tiempo de vida

                    filtered_DELs = np.array(filtered_DELs)
                    time_factors = np.array(time_factors)
                    #print('filtered_DELs:', filtered_DELs, 'time_f', time_factors)
                    filtered_speeds = np.array(filtered_speeds)

                    # if Use_Weibull:
                    #     pdf = (k / A) * (filtered_speeds / A)**(k - 1) * np.exp(-(filtered_speeds / A)**k)
                    #     pdf /= pdf.sum()
                    # else:
                    #     pdf = np.ones_like(filtered_DELs)    #Por ahora lo dejo así.
                #    print('n_occ per speed:',dlc_name)
                    del_yaw = np.sum(filtered_DELs * time_factors)

                else:
                    # caso: n_occ único para todo el DLC----- ej 2.4l
                   # print('n_occ unico:',dlc_name)
                    n_occ = n_occ_info
                    total_time_dlc = n_occ * sim_time
                    time_factor = total_time_dlc / lifetime_sec

                    if Use_Weibull:
                        pdf = (k / A) * (speeds / A)**(k - 1) * np.exp(-(speeds / A)**k)
                        pdf /= pdf.sum()
                    
                    del_yaw = np.sum(DELs * pdf) * time_factor
                    
            else:
                # DLC que no está en dlc_with_events → normal: solo pdf
                if Use_Weibull:
                    pdf = (k / A) * (speeds / A)**(k - 1) * np.exp(-(speeds / A)**k)
                    pdf /= pdf.sum()

                del_yaw = np.sum(DELs * pdf) 

                if dlc_name == '6p4':       #Para el DLC 6.4, quiero que considere una probabilidad de ocurrencia de 0.025 para velocidades entre cut_in y cut_out, y 1 para velocidades entre cut_out y Vref.
                    # Definir rangos de velocidades específicos
                    v_6p4_cutin_cutout = np.arange(cut_in, cut_out + 0.1, 2)  # cada 2 m/s
                    v_6p4_cut_out_Vref = np.arange(cut_out, Vref + 0.1, 2)

                    # Extraer los DELs correspondientes a esas velocidades
                    # speeds = np.array([...]) y DELs = np.array([...]) ya vienen de antes
                    filtered_DELs_ci_co = [DELs[np.where(speeds == v)[0][0]] for v in v_6p4_cutin_cutout if v in speeds]
                    filtered_DELs_co_vref = [DELs[np.where(speeds == v)[0][0]] for v in v_6p4_cut_out_Vref if v in speeds]

                    filtered_speeds_ci_co = [v for v in v_6p4_cutin_cutout if v in speeds]
                    filtered_speeds_co_vref = [v for v in v_6p4_cut_out_Vref if v in speeds]

                    # Calcular pdfs si se usa Weibull
                    if Use_Weibull:
                        pdf_1 = (k / A) * (np.array(filtered_speeds_ci_co) / A)**(k - 1) * np.exp(-(np.array(filtered_speeds_ci_co) / A)**k)
                        pdf_1 /= pdf_1.sum() if pdf_1.sum() > 0 else 1  # evitar div/0
                        pdf_2 = (k / A) * (np.array(filtered_speeds_co_vref) / A)**(k - 1) * np.exp(-(np.array(filtered_speeds_co_vref) / A)**k)
                        print(pdf_2)
                        pdf_2 /= pdf_2.sum() if pdf_2.sum() > 0 else 1
                    else:
                        pdf_1 = np.ones(len(filtered_DELs_ci_co)) / len(filtered_DELs_ci_co)
                        pdf_2 = np.ones(len(filtered_DELs_co_vref)) / len(filtered_DELs_co_vref)

                    # Calcular el DEL ponderado
                    del_part1 = np.sum(np.array(filtered_DELs_ci_co) * pdf_1) * 0.025
                    del_part2 = np.sum(np.array(filtered_DELs_co_vref) * pdf_2) * 1
                    print(del_part1, del_part2, pdf_1, pdf_2)

                    del_yaw = del_part1 + del_part2

            del_total += weight * del_yaw
            total_weight += weight

        return del_total / total_weight if total_weight > 0 else None


    # --------------------- NUEVA FUNCIÓN: Calcular AEP para DLC 1.2 ------------------------
    def compute_aep(self, dlc_name, Use_Weibull, A, k, pdf = None, mode='mean'):
        """
        Calcula el AEP para el DLC dado usando la distribución de Weibull (A,k)
        mode: 'mean' o 'max' para la potencia media por velocidad.
        """
        if dlc_name != '1p2':
            print(f"AEP solo implementado para DLC 1.2, se ignorará {dlc_name}")
            return None

        group = self.dlc_groups.get(dlc_name)
        if not group:
            print(f"DLC {dlc_name} no encontrado")
            return None

        total_power = 0
        total_weight = 0

        # Recorrer yaws
        for yaw, yaw_group in group.yaw_groups.items():
            # Agrupar mean_power por velocidad
            speed_dict = {}
            for sim in yaw_group.simulations:
                speed_dict.setdefault(sim.uref, []).append(sim.mean_power)  #speed_dict is a dictionary where each key represents a wind speed, setdefault(sim.uref, []) hecks if the wind speed (sim.uref) is already a key in speed_dict.

            speeds = np.array(list(speed_dict.keys()))
            if Use_Weibull:
                pdf = (k / A) * (speeds / A)**(k - 1) * np.exp(-(speeds / A)**k)
                pdf /= pdf.sum()

            power_list = []
            for uref in speeds:
                vals = speed_dict[uref]
                if mode == 'mean':
                    p = np.mean(vals)
                else:
                    p = np.max(vals)
                power_list.append(p)

            power_list = np.array(power_list)
            aep_yaw = np.sum(power_list * pdf) * 8760  # horas/año
            total_power += aep_yaw
            total_weight += 1

        # Promedio entre todos los yaw
        return total_power / total_weight if total_weight > 0 else None

#------------------------------------------ PLOTS ----------------------------------------------#
    # Genera gráfico DEL vs velocidad con puntos por semilla y línea promedio: tiene como entrada la variable y el yaw
    def plot_del_vs_speed(self, dlc_name, variable, varname, TurbSim_DLCs, buscar_semillas, output_folder, yaw_weights, Use_Weibull, A, k, pdf =None):
        dlc = self.dlc_groups[dlc_name]
        for yaw, group in dlc.yaw_groups.items():
            summary = group.get_summary_by_speed(variable, buscar_semillas)    # Obtiene el DEL ponderado por semilla
            speeds = sorted(summary.keys())
            dels = [summary[s]['DEL'] for s in speeds]

            plt.figure()
            plt.plot(speeds, dels, marker='o', label='Seed Weighted DEL')   # Puntos azules del DEL ponderado por semilla

            # También grafica puntos individuales de cada semilla
            if dlc_name in TurbSim_DLCs:  # Si es un DLC con TurbSim, plotea los DELs individuales por semilla
                seed_data = dlc.get_seed_del_and_max(variable)
                used_labels = set()
                for (uref, seed, yaw_value), values in seed_data.items():
                    if yaw_value != yaw:
                        continue
                    label = f'{seed}' if seed not in used_labels else None
                    plt.scatter([uref]*len(values['DEL']), values['DEL'], alpha=0.5, label=label)    # Aqui se plotean todos los DELs individuales por semilla
                    used_labels.add(seed)
            
            #QUIERO AGREGAR EL LIFETIME WEIGHTED DEL COMO UNA LINEA HORIZONTAL EN EL GRAFICO
            lifetime_del = self.lifetime_weighted_del(dlc_name, variable, A, k, yaw_weights, buscar_semillas, Use_Weibull, pdf)
            if lifetime_del is not None:
                plt.axhline(y=lifetime_del, color='r', linestyle='--', label='Speed Weighted DEL')

            plt.xlabel("Wind Speed [m/s]")
            plt.ylabel(f"DEL [{variable}]")
            plt.title(f"{dlc_name} - DEL vs Speed - {varname} - Yaw {yaw}")
            plt.legend()
            out_dir = f"{output_folder}/{variable}/{dlc_name}/Yaw_{yaw}"
            os.makedirs(out_dir, exist_ok=True)
            plt.savefig(f"{out_dir}/DEL_vs_speed.png")
            plt.close()


    # Genera gráfico de DEL ponderado por Weibull (lifetime weighted DEL) en barra
    def plot_lifetime_del(self, dlc_name, variable, varname, Use_Weibull, A, k, pdf, yaw_weights, output_folder, buscar_semillas):
        lifetime_del = self.lifetime_weighted_del(dlc_name, variable, A, k, yaw_weights, buscar_semillas, Use_Weibull, pdf)
        plt.figure()
        plt.bar(["Lifetime Weighted DEL"], [lifetime_del])
        plt.title(f"Lifetime Weighted DEL - {varname} - {dlc_name}")
        out_dir = f"{output_folder}/{variable}/{dlc_name}"
        os.makedirs(out_dir, exist_ok=True)
        plt.savefig(f"{out_dir}/Lifetime_DEL.png")
        plt.close()


    # Genera gráfico de valor máximo vs velocidad, con opción a usar media o máximo de semillas (ej: media de los valores máximos del Fore-Aft entre semillas o máximo entre los máximos. )
    def plot_max_vs_speed(self, dlc_name, variable, varname, TurbSim_DLCs, buscar_semillas, output_folder, mode='mean'):
        dlc = self.dlc_groups[dlc_name]
        for yaw, group in dlc.yaw_groups.items():
            summary = group.get_summary_by_speed(variable, buscar_semillas, mode=mode)
            speeds = sorted(summary.keys())
            max_vals = [summary[s]['max'] for s in speeds]

            plt.figure()
            plt.plot(speeds, max_vals, marker='o', label=f'Max ponderado - {mode}')

            if dlc_name in TurbSim_DLCs:
                seed_data = dlc.get_seed_del_and_max(variable)
                used_labels = set()  # Para evitar etiquetas repetidas
                for (uref, seed, yaw_seed), values in seed_data.items():
                    if yaw_seed != yaw:
                        continue
                    label = f'{seed}' if seed not in used_labels else None
                    plt.scatter([uref]*len(values['max']), values['max'], alpha=0.5, label=label)
                    used_labels.add(seed)

            plt.xlabel("Wind Speed [m/s]")
            plt.ylabel(f"Max var [{variable}]")              #11/07/25: Revisar esto: para rotspeed y pitch no hago máximo, hago media
            plt.title(f"{dlc_name} - Max value vs Speed - {varname} - Yaw {yaw}")
            plt.legend()
            out_dir = f"{output_folder}/{variable}/{dlc_name}/Yaw_{yaw}"
            os.makedirs(out_dir, exist_ok=True)
            plt.savefig(f"{out_dir}/Max_{mode}_vs_speed.png")
            plt.close()
    
    # --------------------- Plot Potencia vs Velocidad ------------------------
    def plot_power_vs_speed(self, dlc_name, output_folder, mode='mean'):
        """
        Genera gráfico Potencia vs Velocidad para cada yaw, con puntos por semilla
        y línea media o máximo.
        """
        dlc = self.dlc_groups.get(dlc_name)
        if not dlc:
            print(f"DLC {dlc_name} no encontrado")
            return

        for yaw, group in dlc.yaw_groups.items():
            # Agrupar mean_power por velocidad
            speed_seed_dict = {}
            for sim in group.simulations:
                speed_seed_dict.setdefault(sim.uref, []).append(sim.mean_power)

            speeds_seeds = sorted(speed_seed_dict.keys())
            if mode == 'mean':
                summary_power = [np.mean(speed_seed_dict[s]) for s in speeds_seeds]
            else:
                summary_power = [np.max(speed_seed_dict[s]) for s in speeds_seeds]

            plt.figure()
            # Línea resumen
            plt.plot(speeds_seeds, summary_power, marker='o', label=f'Yaw={yaw} (mode: {mode})')

            # Puntos individuales por semilla
            # used_labels = set()  # Para evitar etiquetas repetidas
            # for uref in speeds_seeds:
            #     vals = speed_seed_dict[uref]
            #     labels = f'{sim.seed}' if sim.seed not in used_labels else None
            #     plt.scatter([uref]*len(vals), vals, alpha=0.5, label=labels)
            #     used_labels.add(sim.seed)
            # Scatter: agrupar por seed
            seeds = set(sim.seed for sim in group.simulations)
            for seed in seeds:
                xs = [sim.uref for sim in group.simulations if sim.seed == seed]
                ys = [sim.mean_power for sim in group.simulations if sim.seed == seed]
                plt.scatter(xs, ys, alpha=0.5, label=seed)

            plt.xlabel("Wind speed [m/s]")
            plt.ylabel("Mean power [kW]")
            plt.title(f"Mean power vs Speed - {dlc_name} - Yaw {yaw}")
            plt.legend()
            out_dir = f"{output_folder}/Potencia/{dlc_name}/Yaw_{yaw}"
            os.makedirs(out_dir, exist_ok=True)
            plt.savefig(f"{out_dir}/Potencia_vs_speed_{mode}.png")
            plt.close()

    # --------------------- Plot LWT de cada variable y cada DLC ------------------------

    def plot_lifetime_del_comparison(self, dlc_names, TurbSim_DLCs, turb_sel, variables, varnames, Use_Weibull, A, k, pdf, yaw_weights, output_folder):
        """
        Genera un gráfico de barras que compara los Lifetime Weighted DELs
        de varias variables y varios DLCs.
        
        Cada grupo de barras representa un DLC, y cada barra dentro del grupo es una variable.
        """

        num_dlcs = len(dlc_names)
        num_vars = len(variables)

        # Preparamos los datos: para cada DLC, lista de DELs por variable
        data = []
        for dlc_name in dlc_names:
            buscar_semillas = False
            if dlc_name in TurbSim_DLCs and turb_sel == 1:
                buscar_semillas = True
            elif dlc_name not in TurbSim_DLCs:
                buscar_semillas = False
            else:
                # DLC turbulento pero turb_sel==0 → no se usan semillas
                buscar_semillas = False
            
            dlc_dels = []
            for var in variables:
                lw_del = self.lifetime_weighted_del(dlc_name, var, A, k, yaw_weights, buscar_semillas, Use_Weibull, pdf)
                dlc_dels.append(lw_del if lw_del is not None else 0)
            data.append(dlc_dels)

        data = np.array(data)  # shape: (num_dlcs, num_vars)

        # Setup gráfico
        x = np.arange(num_dlcs)  # Posiciones de los grupos (DLCs)
        bar_width = 0.8 / num_vars  # ancho de cada barra

        plt.figure(figsize=(10, 6))
        
        for i, var in enumerate(variables):
            plt.bar(x + i * bar_width, data[:, i], width=bar_width, label=varnames.get(var, var))
        
        plt.xlabel("DLC")
        plt.ylabel("Speed Weighted DEL")
        plt.title("Speed Weighted DEL comparison by DLC and variable")
        plt.xticks(x + bar_width * (num_vars-1) / 2, dlc_names)
        plt.legend()
        plt.tight_layout()

        out_dir =f"{output_folder}/Lifetime_Comparison"
        os.makedirs(out_dir, exist_ok=True)
        plt.savefig(f"{out_dir}/Lifetime_DEL_comparison.png")
        plt.close()

    
    def plot_lifetime_del_comparison_with_occ(self, dlc_names, TurbSim_DLCs, turb_sel, variables, varnames, A, k, cut_in, cut_out, Vref, yaw_weights, dlc_with_events, n_occ_dlcs, del_analysis_window_dlc, output_folder, pdf, Use_Weibull=True, n_years=20):

            # Datos para el gráfico: lista de listas
            data = []
            for dlc_name in dlc_names:
                buscar_semillas = False
                if dlc_name in TurbSim_DLCs and turb_sel == 1:
                    buscar_semillas = True
                elif dlc_name not in TurbSim_DLCs:
                    buscar_semillas = False
                else:
                    # DLC turbulento pero turb_sel==0 → no se usan semillas
                    buscar_semillas = False
                
                del_list = []
                for var in variables:
                    sim_time = del_analysis_window_dlc.get(dlc_name, 600)  # default a 600s
                    lw_del = self.lifetime_weighted_del_with_occ(
                        dlc_name=dlc_name,
                        variable=var,
                        A=A, k=k, cut_in = cut_in, cut_out = cut_out, Vref = Vref,
                        yaw_weights=yaw_weights,
                        buscar_semillas = buscar_semillas,
                        Use_Weibull=Use_Weibull,
                        pdf = pdf,
                        dlc_with_events=dlc_with_events,
                        n_occ_dlcs=n_occ_dlcs,
                        sim_time=sim_time,
                        n_years=n_years
                    )
                    #print(dlc_name, var, lw_del)
                    del_list.append(lw_del if lw_del is not None else 0)
                data.append(del_list)

            data = np.array(data)  # shape: (num_dlcs, num_vars)

            # Plot
            num_dlcs = len(dlc_names)
            num_vars = len(variables)
            x = np.arange(num_dlcs)
            bar_width = 0.8 / num_vars

            plt.figure(figsize=(10, 6))

            for i, var in enumerate(variables):
                plt.bar(x + i * bar_width, data[:, i], width=bar_width, label=varnames.get(var,var))

            plt.xlabel("DLC")
            plt.ylabel("Lifetime Weighted DEL (with occurrences)")
            plt.title("Comparison of Lifetime Weighted DELs (speed & occurrences weighted)")
            plt.xticks(x + bar_width * (num_vars-1)/2, dlc_names)
            plt.legend()
            plt.tight_layout()

            os.makedirs(output_folder, exist_ok=True)
            plt.savefig(f"{output_folder}/Lifetime_Comparison/Lifetime_DEL_comparison_occ.png")
            plt.close()
        
#------------------------------------------- EXPORTS ----------------------------------------------#
    def export_seed_del_max_summary(self, filepath, TurbSim_DLCs, turb_sel, variables, del_variables, yaw_weights, Use_Weibull, A, k, pdf):
        """
        Exporta a CSV los valores DEL y máximos por simulación (semilla, velocidad, yaw)
        y los valores agregados por velocidad y yaw.
        """
        rows = []

        for dlc_name, dlc_group in self.dlc_groups.items():
            buscar_semillas = False
            if dlc_name in TurbSim_DLCs and turb_sel == 1:
                buscar_semillas = True
            elif dlc_name not in TurbSim_DLCs:
                buscar_semillas = False
            else:
                    # DLC turbulento pero turb_sel==0 → no se usan semillas
                    buscar_semillas = False
            if dlc_name == '1p2':
                    aep_mean = self.compute_aep(dlc_name, Use_Weibull, A, k, pdf, mode='mean')
                    aep_max = self.compute_aep(dlc_name, Use_Weibull, A, k, pdf, mode='max')

                    rows.append({
                        "DLC": dlc_name,
                        "Variable": "AEP_mean",
                        "Speed Weighted DEL": aep_mean,   #capaz queda raro porque queda el aep en la columna del lifetime weighted DEL
                        "Yaw": None,
                        "Uref": None,
                        "Seed": None,
                        "DEL_individual": None,
                        "Max_individual": None,
                        "Seed weighted DEL": None,
                        "Seed weighted Max": None,
                        "Mean_power": None,
                    })
                    rows.append({
                        "DLC": dlc_name,
                        "Variable": "AEP_max",
                        "Speed Weighted DEL": aep_max,
                        "Yaw": None,
                        "Uref": None,
                        "Seed": None,
                        "DEL_individual": None,
                        "Max_individual": None,
                        "Seed weighted DEL": None,
                        "Seed weighted Max": None,
                        "Mean_power": None,
                    })
            for variable in variables:
                if variable in del_variables:
                    total_lifetime_del = self.lifetime_weighted_del(dlc_name, variable, A, k, yaw_weights, buscar_semillas, Use_Weibull, pdf)
                    rows.append({
                        "DLC": dlc_name,
                        "Variable": variable,
                        "Speed Weighted DEL": total_lifetime_del,
                        "Yaw": None,
                        "Uref": None,
                        "Seed": None,
                        "DEL_individual": None,
                        "Max_individual": None,
                        "Seed weighted DEL": None,
                        "Seed weighted Max": None,
                        "Mean_power": None,
                    })
                for yaw, yaw_group in dlc_group.yaw_groups.items():
                    seed_data = yaw_group.get_seed_del_and_max(variable)
                    summary = yaw_group.get_summary_by_speed(variable, buscar_semillas)
                    
                    for (uref, seed, yaw_angle), values in seed_data.items():
                        if dlc_name == '1p2':   #Quiero el valor de potencia media de cada simulación del DLC 1.2
                            for sim in yaw_group.simulations:
                                if sim.uref == uref and sim.seed == seed and sim.yaw_angle == yaw_angle:
                                    mean_power_value = sim.mean_power
                                    break
                        if variable in del_variables:
                            for del_val, max_val in zip(values['DEL'], values['max']):   #Esto lo hace por las dudas de que haya más de una simulación por semilla y velocidad pero no va a pasar 
                                rows.append({
                                    "DLC": dlc_name,
                                    "Variable": variable,
                                    "Speed Weighted DEL": None,
                                    "Yaw": yaw_angle,
                                    "Uref": uref,
                                    "Seed": seed,
                                    "DEL_individual": del_val,
                                    "Max_individual": max_val,
                                    "Seed weighted DEL": summary[uref]['DEL'] if uref in summary else None,
                                    "Seed weighted Max": summary[uref]['max'] if uref in summary else None,
                                    "Mean_power": mean_power_value if dlc_name == '1p2' else None, 
                                })
                        else:   #variables cuyo del no es de interés
                            for max_val in values['max']:   #Esto lo hace por las dudas de que haya más de una simulación por semilla y velocidad pero no va a pasar 
                                rows.append({
                                    "DLC": dlc_name,
                                    "Variable": variable,
                                    "Speed Weighted DEL":None ,
                                    "Yaw": yaw_angle,
                                    "Uref": uref,
                                    "Seed": seed,
                                    "DEL_individual": None,
                                    "Max_individual": max_val,
                                    "Seed weighted DEL": None,
                                    "Seed weighted Max": summary[uref]['max'] if uref in summary else None,
                                    "Mean_power": mean_power_value if dlc_name == '1p2' else None, 
                                })
        df = pd.DataFrame(rows)
        df.to_csv(filepath, index=False)
        print(f"Resumen exportado a {filepath}")

    
# Función que recorre la estructura de carpetas y archivos para descubrir y cargar automáticamente todas las simulaciones
def auto_discover_simulations(root_folder, DLCs, DLC_folder_name, variables, del_variables, m_values, Teq, bins,
                              vel_dict, yaw_weights_by_dlc, turb_sel, dt, TurbSim_DLCs, del_analysis_window_dlc):
    """
    turb_sel=1: usa semillas para DLCs turbulentos.
    turb_sel=0: simulaciones largas, sin semillas.
    TurbSim_DLCs: usan semillas.
    """


    processor = PostProcessor()
    print(f"Procesando DLCs: {DLCs}")

    root_path = Path(root_folder) / DLC_folder_name

    for dlc in DLCs:
        
        if dlc in ['1p2', '6p4']:  
            start_idx = int(60/dt)
            if dlc in del_analysis_window_dlc.keys():
                end_idx = int(60/dt) + int(del_analysis_window_dlc[f'{dlc}']/dt)   # La elección de 280 a 480 sale de un estudio realizado del impacto de la ventana temporal en el valor del DEL (ver reporte)
            else:
                end_idx   = int(660/dt)
        else:
            start_idx = int(280/dt)
            if dlc in del_analysis_window_dlc.keys():
                end_idx = int(280/dt) + int(del_analysis_window_dlc[f'{dlc}']/dt)   # La elección de 280 a 480 sale de un estudio realizado del impacto de la ventana temporal en el valor del DEL (ver reporte)
            else:
                end_idx = int(480/dt)
                
        variation_name = ''
        if dlc == '4p1': #REVER ESTO!!!
            variation_name = '_ROSCO_SDTime'#'PitchMan'         # 4p1: ROSCO_SDTime or PitchMan

        dlc_number = dlc.split('p')[0]
        dlc_parent_folder = root_path / f"DLC_{dlc_number}"
        dlc_folder = dlc_parent_folder / f"{dlc}{variation_name}"

        if not dlc_folder.exists() or not dlc_folder.is_dir():
            print(f"Carpeta DLC no encontrada: {dlc_folder}")
            continue

        valid_yaws = yaw_weights_by_dlc.get(dlc, {}).keys()

        for yaw_angle in valid_yaws:
            yaw_folder = dlc_folder / f"Yaw_{yaw_angle}"
            if not yaw_folder.exists() or not yaw_folder.is_dir():
                print(f"Carpeta de yaw no encontrada: {yaw_folder}")
                continue

            vel = vel_dict['6p4'] if dlc == '6p4' else vel_dict['rest']

            for Uref in vel:
                case_folder = yaw_folder / f"{Uref:.1f}"
                if not case_folder.exists() or not case_folder.is_dir():
                    print(f"Carpeta de velocidad no encontrada: {case_folder}")
                    continue

                # Decidir si buscar semillas
                buscar_semillas = False
                if dlc in TurbSim_DLCs and turb_sel == 1:
                    buscar_semillas = True
                elif dlc not in TurbSim_DLCs:
                    buscar_semillas = False
                else:
                    # DLC turbulento pero turb_sel==0 → no se usan semillas
                    buscar_semillas = False

                if buscar_semillas:
                    for sd_folder in case_folder.iterdir():
                        if not sd_folder.is_dir():
                            continue
                        # Archivos .outb dentro de carpeta semilla
                        for file in sd_folder.glob("*.outb"):
                            sim = SimulationResult(
                                filepath=str(file),
                                variables=variables,
                                del_variables = del_variables,
                                m_values=m_values,
                                Teq=Teq,
                                bins=bins,
                                start_idx=start_idx,
                                end_idx=end_idx,
                                buscar_semillas = buscar_semillas
                            )
                            processor.add_simulation(dlc_name=dlc, sim_result=sim)
                else:
                    # No buscar semillas, leer directamente archivos .outb en case_folder
                    for file in case_folder.glob("*.outb"):
                        sim = SimulationResult(
                            filepath=str(file),
                            variables=variables,
                            del_variables = del_variables,
                            m_values=m_values,
                            Teq=Teq,
                            bins=bins,
                            start_idx=start_idx,
                            end_idx=end_idx,
                            buscar_semillas = buscar_semillas
                        )
                        processor.add_simulation(dlc_name=dlc, sim_result=sim)

    return processor
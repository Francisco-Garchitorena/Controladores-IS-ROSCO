import os
print("Directorio de trabajo actual:", os.getcwd())
import numpy as np
import sys
sys.path.append('C:/Users/fgarchitorena/OpenFast/Design Load Cases/openfast_toolbox-main')
from openfast_toolbox.io import FASTInputFile    # Set to where these files are
sys.path.append('/clusteruy/home/fgarchitorena/OpenFast/2025/ATLAS-GMFC')
sys.path.append('../../')
from scipy.interpolate import interp1d
from Setup_DLC_Folders import *
from Generate_input_files import *
#from post_processing_simulations_NREL_Yaw_actualization import *
from post_processing_simulations import auto_discover_simulations
from Generate_slurm_sbatch_files import *
#from python_run_dlcs import *
from run_simulations import *

import yaml

#-----SCRIPT THAT GENERATES DLC CASES 1.2, 6.4, 2.4, 3.1 & 4.1 AND RUNS THEM IN OPENFAST-----#

# Leer el archivo de entrada YAML
with open('../User_inputs.yaml', 'r') as file:
    input_data = yaml.safe_load(file)

root_name = input_data['RootNameWT']  # Turbine name

# Formatear la ruta usando el valor de RootNameWT
input_data['OriginalDir_OF'] = input_data['OriginalDir_OF'].format(RootNameWT=root_name)
OriginalDir_OF = input_data['OriginalDir_OF']

# Construir ruta al archivo Turbine_inputs.yaml
turbine_inputs_path = os.path.normpath(os.path.join(OriginalDir_OF, "..", "Turbine_inputs.yaml"))

with open(turbine_inputs_path, 'r') as file:
    turbine_data = yaml.safe_load(file)

# Turbine DATA
Wind_Turb_cat            = turbine_data['Wind_Turbine_category']
Class                    = turbine_data['Class']
DLC_folder_name          = input_data['DLC_folder_name']
IECWind_Model            = input_data['IECWind_Model']
cut_out                  = turbine_data['Cut_out_speed']
cut_in                   = turbine_data['Cut_in_speed']
v_rated                  = turbine_data['Rated_speed']
HubHt                    = turbine_data['H_buje']
D_rot                    = turbine_data['D_rot']
Pitch_rate               = turbine_data['Pitch_rate']                      # (deg/s) Rate of change of pitch controller for maneuvers.
Max_Pitch_rate           = turbine_data['Max_Pitch_rate']                  # (deg/s) Max value--- specific for each WT.
Min_Gen_Speed            = turbine_data['Min_Generator_Speed']
Pitch                    = turbine_data['Pitch']
RotorSpeed               = turbine_data['RotorSpeed']
WindSpeed                = turbine_data['WindSpeed']                        # Wind speed vector for the turbine. It is used to interpolate the Pitch and RotorSpeed vectors.  
# DLC Generator inputs
# Folders
root_folder                     = input_data['Root DLCs folder']                # Folder where to create the DLC study.
controller_folder                = input_data['Controller_folder']               # Folder where the controller is located. It will be accesed by the OF input files.

dt                               = input_data['Time Step']                       # Time step for the simulation.
if str(dt).lower() == 'default' and root_name == 'IEA-3.4-130-RWT':
    dt = 0.00625 
elif str(dt).lower() == 'default' and root_name == 'NREL-2p3-116':
    dt = 0.00625
elif str(dt).lower() == 'default' and root_name == 'NRELOffshrBsline5MW':
    dt = 0.01

# User selections
DLCs                             = input_data['DLCs']
Sim_Time                         = input_data['Simulation time']                 # Total time to be simulated.
First_time                       = input_data['First_time']                      # If true, the "General" and "Wind "Folder will be created.
Wind_user_choice                 = input_data['Wind_user_choice']                # Select whether to use IEC designed inflow wind (NTM, ETM) or user selected (TI, shear, Uref)
Same_seed                        = input_data['Same_seed']                       # If false, different seeds will be used for each simulation.   
Generate_Wind_files              = input_data['Generate_Wind_files']             # If true, the wind files will be generated. 
Site_specific_wind               = input_data['Site_specific_wind']                # If true, the user will be able to select the wind speed distribution -- combination of v-TI-sh.
TI_SSW                           = input_data['TI_SSW']
shear_SSW                        = input_data['shear_SSW']
WindSpeed_SPW                    = input_data['WindSpeed_SPW']
Copy_Wind_folder                 = input_data['Copy_Wind_folder']                # If user already has a DLCs Wind Folder created, copy it to present directory.
Created_Wind_folder_path         = input_data['Created_Wind_folder_path']        # Directory where user has the Wind Folder created.
TurbSim_DLCs                     = input_data['TurbSim_DLCs']
Wind_file_root_name              = input_data['Wind_file_root_name']             # Wind file root name.
Generate_input_files             = input_data['Generate_input_files']            # Flag to select whether to generate the OpenFast DLC input files.
turb_sel                         = input_data['Random turbulence selection']     # TURBSIM: Flag to select between changing seeds (=1) or making long simulations (=0) to eliminate the random factor in the incident wind.
save_results_pickle              = input_data['save_results_pickle']             # Save the post-processed results as a pickle file.
Gen_plot_pot_vs_speed            = input_data['Gen_plot_pot_vs_speed']           # If true, the mean power will be plotted against the wind speed.
Gen_plot_del_vs_speed            = input_data['Gen_plot_pot_vs_speed']            # If true, the DELs will be plotted against the wind speed.
Gen_plot_max_value_var_vs_speed  = input_data['Gen_plot_max_value_var_vs_speed']  # If true, the maximum value of the variable will be plotted against the wind speed.
Gen_plot_Lifetime_del_comparison = input_data['Gen_plot_Lifetime_del_comparison']  # If true, the lifetime DELs will be compared in a plot. 
TM                               = input_data['Turbulence model']                # Turbulence Model (IEC 61400).
TI_values                        = input_data['TI_values']                       # set of TI values for Wind generation--only used when Wind_user_choice = true.
shear_values                     = input_data['shear_values']                    # set of shear values for Wind generation--only used when Wind_user_choice = false.
VFlowAngle                       = input_data['Vertical Flow Angle']             # Vertical angle of the incident wind.
HFlowAngle                       = input_data['Horizontal Flow Angle']           # Horizontal angle of the incident wind.
An_Time_long                     = input_data['Turbulent wind long window']      # Analysis time for long simulations. UNNECESARY? COVERED BY SIM TIME??
Time_event_Start                 = input_data['Time_event_Start']                # Select the time for the transient event to start (i.e. Shutdown at 360s).
Time_init_transient              = input_data['Time to initiate transient (s)']  # For EOG select when to start the gust. 
speed_step                       = input_data['Speed_step']                      # Speed step for simulations. 10: cut_in:1:cut_out; 20: cut_in:2:cut_out
Run_DLCs                         = input_data['Run_DLCs']                        # Select whether to run DLCs or not.
max_job_slots                    = input_data['sel_nucleos']                     # Select how many cores to use for the running of simulations.
num_sd                           = input_data['Number of seeds']                 # Number of seeds to be used.
partition                        = input_data['partition']                       # Partition used to run the simulations: normal, besteffort, ute.
yaw_angles_and_weights_dlcs      = input_data['yaw_weights_by_dlc']         # Diccionario de pesos por DLC y ángulo de yaw
Pacc                             = input_data['Pacc']
# Post-process inputs
Use_Weibull                       = input_data['Use_Weibull']                     # If true, the Weibull distribution will be used to generate the wind speed distribution.
post_process                      = input_data['post_process']                    # Select whether to post-process results
m_values                          = input_data['m_values']                        # Wöhler exponents for different variables.                                 
output_folder                     = input_data['output_folder']                     # Folder where to save the post-processed results.
variables                         = input_data['variables']                       # Variables selected for post-processing (OpenFast names).
del_variables                     = input_data['del_variables']               # Variables selected to get DELs (OpenFast names).
nbins                             = input_data['bins']                            # Number of bins for DEL calculation
mean_or_max_sd_weigh_var          = input_data['mean_or_max_sd_weigh_var']        # Select weather to weigh the max values per seed by the mean(max) or by max(max).
k                                 = input_data['k_Weibull']                       # Weibull k coefficient.
A                                 = input_data['A_Weibull']                       # Weibull A coefficient.
pdf = input_data['probability_distribution_function']
Vref                              = 0.7 * turbine_data['Vref']
dlc_with_events                   = input_data['dlc_with_events']                   # Dictionary with the DLCs that have events.
n_occ_dlcs                        = input_data['n_occ_dlcs']                       # Dictionary with the number of occurrences for each DLC.
del_analysis_window_dlc                     = input_data['del_analysis_window_dlc']                         # Simulation time for the DLCs.


print(f"Running ATLAS-GMFC for WT: {root_name}")

#-------------------Speeds and seeds---------------#

# vel_dict = {'6p4': np.arange(int(cut_in), int(Vref + 1e-6), float(speed_step)),
#             'rest': np.arange(int(cut_in), int(cut_out + 1e-6), float(speed_step))}     #Probar para pasos chicos (ej: 0.5m/s) si funciona correctamente
vel_dict = {
    '6p4': np.arange(int(cut_in), Vref + 1e-6, float(speed_step)),
    'rest': np.arange(int(cut_in), cut_out + 1e-6, float(speed_step))
}
#pdf = pdf.values()    #Test--saco esto 05/08
#pdf = np.array(list(pdf))


seeds = [13426, 13427, 13428,13429,13430, 13431]                         # TURBSIM: seeds selection (num_sd seeds).
seeds_names = ['sd0', 'sd1', 'sd2','sd3','sd4', 'sd5']                    # Seeds names for folder creation.

# Adjust the vectors based on num_sd
seeds = seeds[:num_sd]
seeds_names = seeds_names[:num_sd]

#-------------------Interpolate pitch and rotor speed-------------------#

interp_Pitch = interp1d(WindSpeed, Pitch, kind='linear')  # O 'cubic' si querés más suavidad
interp_RotorSpeed = interp1d(WindSpeed, RotorSpeed, kind='linear')

#-------------------Interpolate TI and shear for Site_specific conditions-------------------#

interp_TI = interp1d(WindSpeed_SPW, TI_SSW, kind='linear')  # O 'cubic' si querés más suavidad
interp_sh = interp1d(WindSpeed_SPW, shear_SSW, kind='linear')  # O 'cubic' si querés más suavidad

# --------------Folder creation----------------#
MyDir=os.path.dirname(__file__)                   # Present directory
#-----------------------FIRST TIME START---------------------------#
if First_time:  # Si es la primera vez
    create_main_folders(root_folder, root_name, DLC_folder_name, OriginalDir_OF)


if Generate_Wind_files: 
    # Wind Folder setup and creation.
    create_wind_folders_and_files(
        Site_specific_wind = Site_specific_wind,
        interp_TI = interp_TI,
        interp_sh = interp_sh,
        Wind_user_choice = Wind_user_choice,
        Same_seed = Same_seed,
        DLCs = DLCs,
        root_folder=root_folder,
        DLC_folder_name=DLC_folder_name,
        OriginalDir_OF=OriginalDir_OF,
        MyDir=MyDir,
        Copy_Wind_folder=Copy_Wind_folder,
        Sim_Time = Sim_Time,
        TM=TM,
        turb_sel=turb_sel,
        cut_in=cut_in, cut_out=cut_out, Speed_step = speed_step, shear_values = shear_values, TI_values = TI_values, v_rated = v_rated, Class= Class,
        Time_init_transient = Time_init_transient, seeds=seeds,
        Wind_Turb_cat= Wind_Turb_cat, HubHt=HubHt, D_rot=D_rot,
        An_Time_long=An_Time_long,
        Created_Wind_folder_path=Created_Wind_folder_path,
        Wind_file_root_name = Wind_file_root_name,
        partition = partition,
        VFlowAngle = VFlowAngle, HFlowAngle =HFlowAngle, Vref =Vref
    ) 
#-------------------------------FIRST TIME END-------------------------#      
working_dir = f"{root_folder}/{DLC_folder_name}"

if Generate_input_files:
    print('---------------------------GENERATING INPUT FILES---------------------------') 

    for DLC_choice in DLCs:

            # Obtener los ángulos según el diccionario o default si no se encuentra
        YawAngles = yaw_angles_and_weights_dlcs.get(DLC_choice, [0])  # Por defecto [0] si no está

        for YawAngle in YawAngles:    
            
            variation_name = ''
            if DLC_choice == '4p1': #REVER ESTO!!!
                variation_name = 'ROSCO_SDTime'#'PitchMan'         # 4p1: ROSCO_SDTime or PitchMan

            #----------------------------------CASE FILE GENERATION-----------------------------------------------#    

            i=0
            #------------------Case File Generation for each wind speed------------------#
            if DLC_choice == '6p4':
                vel = vel_dict['6p4']   
                vel_CI = vel * np.cos(np.deg2rad(YawAngle)) # Velocidad del viento con yaw
                if vel_CI[0] < cut_in:
                    vel_CI[0] = cut_in            
            else:
                vel = vel_dict['rest']
                vel_CI = vel * np.cos(np.deg2rad(YawAngle))
                if vel_CI[0] < cut_in:
                    vel_CI[0] = cut_in
            
            # Interpolar -- CI cambian por velocidad de viento ajustada por Yaw.
            Pitch_interp = interp_Pitch(vel_CI)    #Esto hay que testearlo aún---- falta agregar más datos a las CI para incluir entre cut_out y 70%Vref
            RotorSpeed_interp = interp_RotorSpeed(vel_CI)
            print('velocidades corregidas por Yaw:',vel_CI, 'Pitch interpolado:', Pitch_interp, 'RotorSpeed interpolado:', RotorSpeed_interp)
            

            for Uref in vel:
                shear_interp = interp_sh(Uref)
                TI_interp = interp_TI(Uref)                
                # Options are:
                #    1) DLC choice is within TurbSim DLCs, short simulations with seeds required, User selected TI and Shear.
                #    2) DLC choice is within TurbSim DLCs, short simulations with seeds required, IEC Wind models (NTM, ETM) or site specific conditions.
                #    3) DLC choice is within TurbSim DLCs, long simulations, User selected TI and Shear.
                #    4) DLC choice is within TurbSim DLCs, long simulations, IEC Wind models (NTM, ETM).
                #    5) DLC choice is NOT within TurbSim DLCs.

                if DLC_choice in TurbSim_DLCs and turb_sel == 1:    
                    if Wind_user_choice:                            # Case 1.
                        print('Case 1: Generating DLC', DLC_choice, 'input files with USW and seeds')    
                        for sh in shear_values:
                            for TI in TI_values:
                                for sd in seeds:
                                    # Generate InflowFile per seed
                                    output_filename_IN = generar_inflow_file(root_name, root_folder, DLC_folder_name, OriginalDir_OF, DLC_choice, TurbSim_DLCs, Uref, IECWind_Model, Wind_file_root_name, Site_specific_wind, Wind_user_choice, 'USW', YawAngle, variation_name, sh = sh, TI= TI, seed=seeds.index(sd))
                                    # Generate ElastoDyn, ServoDyn, FST, etc. per seed
                                    output_filename_ED = generar_elastodyn_file(root_name, root_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice,Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref, RotorSpeed_interp, Pitch_interp, i, YawAngle, variation_name, sh = sh, TI= TI, seed=seeds.index(sd))
                                    output_filename_SD, destination_dir_Uref = generar_servodyn_file(root_name, root_folder,controller_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref, Min_Gen_Speed, Time_event_Start, Max_Pitch_rate, Pitch_rate, Pitch_interp, RotorSpeed_interp, i, YawAngle, variation_name, sh = sh, TI= TI, seed=seeds.index(sd))
                                    generar_fst_file(root_name, root_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref, output_filename_ED, output_filename_IN, output_filename_SD, turb_sel, Sim_Time, YawAngle, variation_name, sh = sh, TI= TI, seed=seeds.index(sd))
                                    editar_discon_file(DLC_choice, root_name, destination_dir_Uref, 360, OriginalDir_OF)
                                    Generate_slurm_sbatch_files(DLC_choice, Uref, root_folder,DLC_folder_name,YawAngle, variation_name, sh=sh, TI=TI, seed=seeds.index(sd))
                    else:
                        print('Case 2: Generating DLC', DLC_choice, 'input files for IEC61400 cases, with seeds')                                           # Case 2.
                        for sd in seeds:            
                            # Generate InflowFile per seed
                            output_filename_IN = generar_inflow_file(root_name, root_folder, DLC_folder_name, OriginalDir_OF, DLC_choice, TurbSim_DLCs, Uref, IECWind_Model, Wind_file_root_name, Site_specific_wind, Wind_user_choice, TM, YawAngle, variation_name, sh= shear_interp, TI= TI_interp, seed=seeds.index(sd))
                            # Generate ElastoDyn, ServoDyn, FST, etc. per seed
                            output_filename_ED = generar_elastodyn_file(root_name, root_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref, RotorSpeed_interp, Pitch_interp, i, YawAngle, variation_name, sh= shear_interp, TI= TI_interp, seed=seeds.index(sd))
                            output_filename_SD, destination_dir_Uref = generar_servodyn_file(root_name, root_folder, controller_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref, Min_Gen_Speed, Time_event_Start, Max_Pitch_rate, Pitch_rate, Pitch_interp, RotorSpeed_interp, i, YawAngle, variation_name, sh= shear_interp, TI= TI_interp, seed=seeds.index(sd))
                            generar_fst_file(root_name, root_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref, output_filename_ED, output_filename_IN, output_filename_SD, turb_sel, Sim_Time, YawAngle,variation_name, sh= shear_interp, TI= TI_interp,seed=seeds.index(sd))
                            editar_discon_file(DLC_choice, root_name, destination_dir_Uref, 360, OriginalDir_OF, Pacc)
                           # Generate_slurm_sbatch_files(DLC_choice, Uref, root_folder,DLC_folder_name,YawAngle,variation_name,seed=seeds.index(sd))
                else:                                               
                    if DLC_choice in TurbSim_DLCs and Wind_user_choice:         # Case 3.
                        print('Case 3: Generating DLC', DLC_choice, 'input files with USW -- long simulations')
                        for sh in shear_values:
                            for TI in TI_values:
                                # No seeds
                                output_filename_IN = generar_inflow_file(root_name, root_folder, DLC_folder_name, OriginalDir_OF, DLC_choice, TurbSim_DLCs, Uref, IECWind_Model, Wind_file_root_name, Site_specific_wind, Wind_user_choice, 'USW', YawAngle, variation_name, sh = sh, TI= TI)
                                output_filename_ED = generar_elastodyn_file(root_name, root_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref, RotorSpeed_interp, Pitch_interp, i, YawAngle, variation_name, sh = sh, TI= TI)
                                output_filename_SD, destination_dir_Uref = generar_servodyn_file(root_name, root_folder,controller_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice,TurbSim_DLCs,  Uref, Min_Gen_Speed, Time_event_Start, Max_Pitch_rate, Pitch_rate, Pitch_interp, RotorSpeed_interp, i, YawAngle, variation_name, sh = sh, TI= TI)
                                generar_fst_file(root_name, root_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref, output_filename_ED, output_filename_IN, output_filename_SD, turb_sel, Sim_Time, YawAngle, variation_name, sh = sh, TI= TI)
                                editar_discon_file(DLC_choice, root_name, destination_dir_Uref, 360, OriginalDir_OF)
                                Generate_slurm_sbatch_files(DLC_choice, Uref, root_folder,DLC_folder_name,YawAngle,variation_name,sh=sh, TI=TI, )
                    else:
                        if DLC_choice in TurbSim_DLCs:
                            print('Case 4: Generating DLC', DLC_choice, 'input files for IEC61400 cases -- long simulations')
                        else:
                            print('Case 5: Generating DLC', DLC_choice, 'input files for IEC61400 cases -- StartUp or Shutdown')                                                      # Case 4 and 5.
                        # No seeds
                        output_filename_IN = generar_inflow_file(root_name, root_folder, DLC_folder_name, OriginalDir_OF, DLC_choice,TurbSim_DLCs,  Uref, IECWind_Model, Wind_file_root_name, Site_specific_wind, Wind_user_choice, TM, YawAngle, variation_name)
                        output_filename_ED = generar_elastodyn_file(root_name, root_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref, RotorSpeed_interp, Pitch_interp, i, YawAngle, variation_name)
                        output_filename_SD, destination_dir_Uref = generar_servodyn_file(root_name, root_folder, controller_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref, Min_Gen_Speed, Time_event_Start, Max_Pitch_rate, Pitch_rate, Pitch_interp, RotorSpeed_interp, i, YawAngle, variation_name)
                        if DLC_choice in TurbSim_DLCs:    # Case 4
                            generar_fst_file(root_name, root_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref, output_filename_ED, output_filename_IN, output_filename_SD, turb_sel, An_Time_long, YawAngle, variation_name)
                        else:                             # Case 5
                            generar_fst_file(root_name, root_folder, DLC_folder_name, OriginalDir_OF, Wind_user_choice, Site_specific_wind, DLC_choice, TurbSim_DLCs, Uref, output_filename_ED, output_filename_IN, output_filename_SD, turb_sel, Sim_Time, YawAngle, variation_name)                            
                        editar_discon_file(DLC_choice, root_name, destination_dir_Uref, 360, OriginalDir_OF)
                        Generate_slurm_sbatch_files(DLC_choice, Uref, root_folder,DLC_folder_name,YawAngle,variation_name)

                
                i = i +1 #+ int(speed_step)
              

#-----------------RUN OPENFAST SIMULATIONS FOR DLCs--------------------------#
# if Run_DLCs:
#     #python_run_dlcs(working_dir, DLCs, seeds_names, vel, max_job_slots, TurbSim_DLCs, turb_sel)
    
#     import time

#     def main():
#         """Runs the python_run_dlcs.py script periodically."""
        
#         while True:
#             # Run the python_run_dlcs.py script and get the success flag
#             success = python_run_dlcs(working_dir, DLCs, Site_specific_wind, seeds_names, vel_dict, shear_values, TI_values, TM, yaw_angles_and_weights_dlcs, max_job_slots, TurbSim_DLCs, turb_sel, root_name, Wind_file_root_name, Wind_user_choice)

#             if not success:
#                 print("Some simulations are still running, continuing with next iteration.")
#             else:
#                 print("All simulations are complete! Breaking the loop.")
#                 break  # Exit the loop when all simulations are done

#             # Wait for a random time between 10 to 20 minutes before running the script again
#             wait_time = 720  # wait time between 10-20 minutes
#             print(f"Waiting for {wait_time} seconds before next execution.")
#             time.sleep(wait_time)  # Wait for a random time before re-running the script

#     if __name__ == "__main__":
#         main()
#         print("Todas las simulaciones han sido iniciadas.")
if Run_DLCs:
    openfast_exe = f'{root_folder}/{DLC_folder_name}/openfast_x64.exe'  # Folder where the OpenFAST executable is located
    velocidades = [f"{v}.0" for v in range(4, 26)]                      # Incident speeds selection, to run simulations
    
    run_openfast_cases(
        root_folder=root_folder, 
        DLC_folder_name=DLC_folder_name, 
        root_name=root_name, 
        velocidades=velocidades, 
        DLCs=DLCs, 
        seeds=seeds, 
        sel_nucleos=max_job_slots, 
        turb_sel=turb_sel, 
        TurbSim_DLCs=TurbSim_DLCs, 
        variation_name=variation_name, 
        openfast_exe=openfast_exe
    )

print("Todas las simulaciones han sido iniciadas.")
if post_process:

    if Run_DLCs:
        # Wait 20min for all simulations to be executed, then do post-process. REVISAR ESTO.
        wait_time = 1200  # wait time between 10-20 minutes
        print(f"Waiting for {wait_time} seconds until simulations are executed.")
        time.sleep(wait_time)  # Wait for a random time before re-running the script

    Teq = 1  # Tiempo equivalente para cálculo de DEL (puede ser 20*365*24*3600 para vida útil completa)


    # --- Descubrir y cargar simulaciones ---
    processor = auto_discover_simulations(
        root_folder=root_folder,
        DLCs=DLCs,
        DLC_folder_name=DLC_folder_name,
        variables=variables,
        del_variables = del_variables,
        m_values=m_values,
        Teq=Teq,
        bins=nbins,
        vel_dict = vel_dict,
        yaw_weights_by_dlc = yaw_angles_and_weights_dlcs,
        turb_sel = turb_sel, dt=dt,
        TurbSim_DLCs = TurbSim_DLCs,
        del_analysis_window_dlc = del_analysis_window_dlc
    )

    # --- Ejecutar análisis ---
    processor.compute_all()

    # --- Guardar como pickle ---
    if save_results_pickle:
            processor.export_to_pickle("resultados_postprocesados_con_yaw.pkl")

    varnames = {
    'RootMyb1_[kN-m]': 'FlapWise Root Moment',
    'RootMxb1_[kN-m]': 'EdgeWise Root Moment',
    'TwrBsMyt_[kN-m]': 'Tower Base Fore-Aft Moment',
    'TwrBsMxt_[kN-m]': 'Tower Base Side-Side Moment',
    'RotSpeed_[rpm]': 'Rotor Speed',
    'GenTq_[kN-m]': 'Generator Torque',
    'GenPwr_[kW]': 'Generator Power',
    'BldPitch1_[deg]': 'Blade 1 Pitch Angle',
    }



    if not Use_Weibull:
        # 1. Obtener velocidades y probabilidades desde el diccionario
        pdf_vels = np.array(list(pdf.keys()), dtype=float)
        pdf_probs = np.array(list(pdf.values()), dtype=float)

        # 2. Elegir el set de velocidades que estés usando (por ejemplo vel_dict['rest'])
        vels_to_use = vel_dict['6p4']

        # 3. Interpolación
        interpolated_probs = np.interp(vels_to_use, pdf_vels, pdf_probs)
        print('interp_prob:', interpolated_probs)

    dlc_labels = {
        "1p2": "DLC 1.2: Operación normal",
        "2p4y": "DLC 2.4y: Error extremo de yaw",
        "2p4l": "DLC 2.4l: Pérdida de red",
        "6p4": "DLC 6.4: Estacionada",
        "3p1": "DLC 3.1: Encendido (NWP)",
        "4p1": "DLC 4.1: Apagado (NWP)",
        "5p1": "DLC 2.4yeste no"}

    output_folder = f'{root_folder}/{DLC_folder_name}/{output_folder}'
        
    # --- Generar gráficos por DLC, variable y yaw ---
    if Gen_plot_del_vs_speed:
        for dlc_name in DLCs:
            buscar_semillas = False
            if dlc_name in TurbSim_DLCs and turb_sel == 1:
                buscar_semillas = True
            elif dlc_name not in TurbSim_DLCs:
                buscar_semillas = False
            else:
                # DLC turbulento pero turb_sel==0 → no se usan semillas
                buscar_semillas = False
            for var in variables:
                varname = varnames.get(var, var)  # Nombre legible de la variable
                if var in del_variables:
                    pdf = np.array(list(pdf))
                    m = m_values.get(var,10)
                    processor.plot_del_vs_speed(dlc_name, var, m, varname, TurbSim_DLCs, buscar_semillas, output_folder, yaw_angles_and_weights_dlcs, Use_Weibull, A, k, pdf)
                    processor.plot_lifetime_del(dlc_name, var, m, varname, Use_Weibull, A, k, pdf, yaw_angles_and_weights_dlcs, output_folder, buscar_semillas)

    if Gen_plot_max_value_var_vs_speed:
        for dlc_name in DLCs:
            buscar_semillas = False
            if dlc_name in TurbSim_DLCs and turb_sel == 1:
                buscar_semillas = True
            elif dlc_name not in TurbSim_DLCs:
                buscar_semillas = False
            else:
                # DLC turbulento pero turb_sel==0 → no se usan semillas
                buscar_semillas = False
            for var in variables:
                varname = varnames.get(var, var)
                if dlc_name == '1p2':           #Solo quiero que me saque el Pitch, RotSped vs v para el DLC 1.2 (op normal)
                    processor.plot_max_vs_speed(dlc_name, var, varname, TurbSim_DLCs, buscar_semillas, output_folder, mode=mean_or_max_sd_weigh_var) 
                else:
                    if var in del_variables:
                        processor.plot_max_vs_speed(dlc_name, var, varname, TurbSim_DLCs, buscar_semillas, output_folder, mode=mean_or_max_sd_weigh_var)

    # Graficar
    if Gen_plot_pot_vs_speed:
        processor.plot_power_vs_speed('1p2', output_folder, mode='mean') 
        processor.plot_power_vs_speed('1p2', output_folder, mode='max')

    if Gen_plot_Lifetime_del_comparison:
        # Graficar comparación de DELs por DLC y variable    
        processor.plot_Yaw_weighted_DEL_comparison(DLCs, TurbSim_DLCs, turb_sel, del_variables,m_values, varnames, Use_Weibull, A, k, pdf, yaw_angles_and_weights_dlcs, output_folder)
        processor.plot_lifetime_del_comparison_with_occ(DLCs, TurbSim_DLCs, turb_sel, del_variables, varnames, dlc_labels, m_values, A, k, cut_in, cut_out, speed_step, Vref, yaw_angles_and_weights_dlcs, dlc_with_events, n_occ_dlcs, del_analysis_window_dlc, output_folder, pdf, Use_Weibull=True, n_years=1)

    processor.export_seed_del_max_summary("Results_summary.csv", TurbSim_DLCs, turb_sel, variables,del_variables, m_values, yaw_angles_and_weights_dlcs, cut_in, cut_out, speed_step, Vref, Use_Weibull, A, k, pdf, dlc_with_events, n_occ_dlcs, del_analysis_window_dlc, 1)

    # Calcular AEP
    aep = processor.compute_aep('1p2', Use_Weibull, A, k, pdf, mode='mean')
    print(f"AEP estimado: {aep:.2f} kWh")

    print("Postprocesamiento y gráficos completados.")
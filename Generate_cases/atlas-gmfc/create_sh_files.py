
import os
print("Directorio de trabajo actual:", os.getcwd())
import numpy as np
import sys
sys.path.append('/clusteruy/home/fgarchitorena/OpenFast/openfast_toolbox-main')
from openfast_toolbox.io import FASTInputFile    # Set to where these files are
sys.path.append('../')
from Setup_DLC_Folders import *
from Generate_input_files import *
from post_processing_simulations_TEST import *
from Generate_slurm_sbatch_files import *
from python_run_dlcs import *
from Generate_TurbS_slurm_sbatch_files import *


import yaml

#-----SCRIPT THAT GENERATES DLC CASES 1.2, 2.1, 3.1 & 4.1 AND RUNS THEM IN OPENFAST-----#

# Leer el archivo de entrada YAML
with open('inputs_test.yaml', 'r') as file:
    input_data = yaml.safe_load(file)

# Turbine DATA
Wind_Turb_cat   = input_data['Wind_Turbine_category']
Class           = input_data['Class']
DLC_folder_name = input_data['DLC_folder_name']
IECWind_Model           = input_data['IECWind_Model']
cut_out         = input_data['Cut_out_speed']
cut_in          = input_data['Cut_in_speed']
v_rated         = input_data['Rated_speed']
HubHt          = input_data['H_buje']
D_rot           = input_data['D_rot']
Pitch_rate      = input_data['Pitch_rate']                               # (deg/s) Rate of change of pitch controller for maneuvers.
Max_Pitch_rate  = input_data['Max_Pitch_rate']                           # (deg/s) Max value--- specific for each WT.
Min_Gen_Speed   = input_data['Min_Generator_Speed']
Pitch           = input_data['Pitch']
RotorSpeed      = input_data['RotorSpeed']

# Folders
root_folder    = input_data['Root DLCs folder']                          # Folder where to create the DLC study.
root_name      = input_data['Root name for the WT']                      # Turbine name.
OriginalDir_OF = input_data['OriginalDir_OF']                            # Root folder for WT OpenFast model.

# User selections
DLCs                     = input_data['DLCs']
Sim_Time                 = input_data['Simulation time']                 # Total time to be simulated.
dt                       = input_data['Time Step']
First_time               = input_data['First_time']                      # If true, the "General" and "Wind "Folder will be created.
Wind_user_choice         = input_data['Wind_user_choice']                # Select whether to use IEC designed inflow wind (NTM, ETM) or user selected (TI, shear, Uref)
Copy_Wind_folder         = input_data['Copy_Wind_folder']                # If user already has a DLCs Wind Folder created, copy it to present directory.
Created_Wind_folder_path = input_data['Created_Wind_folder_path']        # Directory where user has the Wind Folder created.
TurbSim_DLCs             = input_data['TurbSim_DLCs']
Wind_file_root_name      = input_data['Wind_file_root_name']             # Wind file root name.
Generate_input_files     = input_data['Generate_input_files']            # Flag to select whether to generate the OpenFast DLC input files.
turb_sel                 = input_data['Random turbulence selection']     # TURBSIM: Flag to select between changing seeds (=1) or making long simulations (=0) to eliminate the random factor in the incident wind.
TM                       = input_data['Turbulence model']                # Turbulence Model (IEC 61400).
TI_values                = input_data['TI_values']                       # set of TI values for Wind generation--only used when Wind_user_choice = true.
shear_values             = input_data['shear_values']                    # set of shear values for Wind generation--only used when Wind_user_choice = false.
An_Time_long             = input_data['Turbulent wind long window']      # Analysis time for long simulations. UNNECESARY? COVERED BY SIM TIME??
Time_event_Start         = input_data['Time_event_Start']                # Select the time for the transient event to start (i.e. Shutdown at 360s).
Time_init_transient      = input_data['Time to initiate transient (s)']  # For EOG select when to start the gust. 
speed_step               = input_data['Speed_step']                      # Speed step for simulations. 10: cut_in:1:cut_out; 20: cut_in:2:cut_out
Run_DLCs                 = input_data['Run_DLCs']                        # Select whether to run DLCs or not.
max_job_slots            = input_data['sel_nucleos']                     # Select how many cores to use for the running of simulations.
num_sd                   = input_data['Number of seeds']                 # Number of seeds to be used.
partition                = input_data['partition']                       # Partition used to run the simulations: normal, besteffort, ute.

# Post-process inputs
post_process             = input_data['post_process']                    # Select whether to post-process results
variables                = input_data['variables']                       # Variables selected for post-processing (OpenFast names).
nbins                    = input_data['bins']                            # Number of bins for DEL calculation
k                        = input_data['k_Weibull']                       # Weibull k coefficient.
A                        = input_data['A_Weibull']                       # Weibull A coefficient.


print(f"Turbina: {root_name}, Modelo: {IECWind_Model}")

#-------------------Speeds and seeds---------------#
vel = np.arange(cut_in*10, (cut_out + 1)*10, speed_step)/10.0
seeds = [13426, 13427, 13428,13429,13430, 13431]                         # TURBSIM: seeds selection (num_sd seeds).
seeds_names = ['sd0', 'sd1', 'sd2','sd3','sd4', 'sd5']                    # Seeds names for folder creation.

# Adjust the vectors based on num_sd
seeds = seeds[:num_sd]
seeds_names = seeds_names[:num_sd]

# --------------Folder creation----------------#
MyDir=os.path.dirname(__file__)                   # Present directory
print(MyDir)

if Wind_user_choice:
        if turb_sel == 1:
            An_Time = Sim_Time
            i = 0
            for Uref in range(cut_in, cut_out+1):
                for sh in shear_values:
                    for TI in TI_values:
                        for sd in seeds:
                            vel_str = f"{Uref:.0f}"
                            Wind_folder = f"{root_folder}/{DLC_folder_name}/Wind/USW/v{vel_str}/shear{sh}/TI{TI}/sd{seeds.index(sd)}/"    # USW: User-selected-wind. Create a separate folder for each case
                            #os.makedirs(Wind_folder, exist_ok=True)
                            Generate_TurbS_slurm_sbatch_files(Uref, Wind_folder, partition, TI, sh, seed=seeds.index(sd))                      
                            Uref = vel[i]
                            Generate_slurm_sbatch_files('1p2', Uref, root_folder,DLC_folder_name,'', sh=sh, TI=TI, seed=seeds.index(sd))
                i = i+1
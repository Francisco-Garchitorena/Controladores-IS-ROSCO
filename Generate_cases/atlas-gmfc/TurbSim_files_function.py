import os
import shutil
import glob
import numpy as np
from pathlib import Path
from Generate_TurbS_slurm_sbatch_files import *

def create_wind_folder(base_folder):
    Path(base_folder).mkdir(parents=True, exist_ok=True)

def copy_and_rename_input_file(orig_pattern, dest_folder, new_filename):
    orig_files = glob.glob(orig_pattern)
    if not orig_files:
        print("Archivo de viento no encontrado.")
        return None
    shutil.copy(orig_files[0], dest_folder)
    orig_name = os.path.basename(orig_files[0])
    new_path = os.path.join(dest_folder, new_filename)
    os.rename(os.path.join(dest_folder, orig_name), new_path)
    if new_path ==None or orig_files[0] == None:
        print("Error at copying and renaming the wind file name---CHECK Wind_file_root_name in User_inputs.yaml")
        return None, None
    return new_path, orig_files[0]

def modify_turbsim_file(template_path, dest_path, mod_vars, new_vals):
    wt = 0
    if os.path.exists(dest_path):
        os.remove(dest_path)

    with open(dest_path, 'w+') as new_file, open(template_path) as old_file:
        for line in old_file:
            newline = line
            for idx, var in enumerate(mod_vars):
                if var in line:
                    newline = f"{new_vals[idx]}\t!!Orig is:  {line}"
            if '.fst' in line:
                newline = (
                    '{params.x[wt]:.3f}\t\t{params.y[wt]:.3f}\t\t{params.z[wt]:.3f}\t\t'
                    '{tpath}_WT{wt+1:d}.fst"\t{params.X0_High[wt]:.3f}\t\t'
                    '{params.Y0_High[wt]:.3f}\t\t{params.Z0_High:.3f}\t\t'
                    '{params.dX_High:.3f}\t\t{params.dY_High:.3f}\t\t{params.dZ_High:.3f}\n'
                )
                wt += 1
            new_file.write(newline)

def TurbSim_files_function(Site_specific_wind, interp_TI, interp_sh, Wind_user_choice, Same_seed, root_folder, DLC_folder_name, DLCs, OriginalDir_OF, Sim_Time, TM,
                           turb_sel, cut_in, cut_out, Speed_step, shear_values, TI_values,
                           seeds, Wind_Turb_cat, HubHt, An_Time_long, Wind_file_root_name,
                           partition, VFlowAngle, HFlowAngle, Vref):

    base_pattern = f"{OriginalDir_OF}/Wind/{Wind_file_root_name}_.in*"
    An_Time = Sim_Time
    if '6p4' in DLCs:
        Umax = int(Vref + Speed_step)
        vels = np.arange(cut_in, Umax, Speed_step)
        vels = vels[vels <= Vref]
    else:
        Umax = int(cut_out + Speed_step)
        vels = np.arange(cut_in, Umax, Speed_step)
        vels = vels[vels <= cut_out]
    #Speed_step = int(Speed_step/10)
    if Wind_user_choice:
        for Uref in vels:
            for sh in shear_values:
                for TI in TI_values:
                    if turb_sel == 1:
                        for sd in seeds:
                            seed_idx = seeds.index(sd)
                            Wind_folder = f"{root_folder}/{DLC_folder_name}/Wind/USW/v{Uref}/shear{sh}/TI{TI}/sd{seed_idx}/"
                            create_wind_folder(Wind_folder)

                            if not Same_seed:
                                sd = int(f"{Uref:02d}{int(0) if sh < 0 else int(sh*10)}{int(TI/5)}{seed_idx+1}")

                            Turb_filename = f"{Wind_file_root_name}_{Uref}_sh{sh}_TI{TI}_sd{seed_idx}.inp"
                            dest_path, template_path = copy_and_rename_input_file(base_pattern, Wind_folder, Turb_filename)
                            if not dest_path:
                                continue

                            new_vals = [sd, HubHt, An_Time, HubHt, Uref, TI, f'"{TM}"', sh, VFlowAngle, HFlowAngle]
                            mod_vars = ['RandSeed1','HubHt','AnalysisTime','RefHt','Mean (total) velocity','IECturbc','IEC_WindType','PLExp','VFlowAng','HFlowAng']
                            modify_turbsim_file(template_path, dest_path, mod_vars, new_vals)

                            Generate_TurbS_slurm_sbatch_files(Uref, Wind_folder, partition, TI, sh, seed=seed_idx)
                    else:
                        Wind_folder = f"{root_folder}/{DLC_folder_name}/Wind/USW/v{Uref}/shear{sh}/TI{TI}/"
                        create_wind_folder(Wind_folder)
                        Turb_filename = f"IEAonshore_{Uref}_sh{sh}_TI{TI}.inp"
                        dest_path, template_path = copy_and_rename_input_file(f"{OriginalDir_OF}/Wind/IEAonshore_.inp", Wind_folder, Turb_filename)
                        if not dest_path:
                            continue

                        new_vals = [HubHt, An_Time_long, HubHt, Uref, TI, f'"{TM}"', sh, VFlowAngle, HFlowAngle]
                        mod_vars = ['HubHt','AnalysisTime','RefHt','Mean (total) velocity','IECturbc','IEC_WindType','PLExp','VFlowAng','HFlowAng']
                        modify_turbsim_file(template_path, dest_path, mod_vars, new_vals)

                        Generate_TurbS_slurm_sbatch_files(Uref, Wind_folder, partition, TI, sh, seed=None)
    else:
        if turb_sel == 1:
            for Uref in vels:
                if Site_specific_wind:
                # If site specific wind, we need to interpolate the shear and TI values based on the wind speed
                    shear_interp = interp_sh(Uref)
                    TI_interp = interp_TI(Uref)
                    print(f"Interpolated shear: {shear_interp}, TI: {TI_interp} for wind speed: {Uref}")
                for sd in seeds:
                    seed_idx = seeds.index(sd)
                    if Site_specific_wind:
                        Wind_folder = f"{root_folder}/{DLC_folder_name}/Wind/SPW/v{Uref}/TI{TI_interp}/sd{seed_idx}/"
                        Turb_filename = f"{Wind_file_root_name}_{Uref}_sh{shear_interp}_TI{TI_interp}_sd{seed_idx}.inp"   #CFG:  Turb_filename = f"{Wind_file_root_name}_{Uref}_sd{seed_idx}.inp"
                        create_wind_folder(Wind_folder)
                    else:
                        Wind_folder = f"{root_folder}/{DLC_folder_name}/Wind/{TM}/v{Uref}/sd{seed_idx}/"
                        Turb_filename = f"{Wind_file_root_name}_{Uref}_sd{seed_idx}.inp"
                        create_wind_folder(Wind_folder)

                    dest_path, template_path = copy_and_rename_input_file(base_pattern, Wind_folder, Turb_filename)
                    if not dest_path:
                        continue
                    
                    if Site_specific_wind:  #If Site specific conditions are used, the wind file will be modified accordingly, using the TI and shear for that speed.
                        new_vals = [sd, HubHt, An_Time, HubHt, Uref, TI_interp, f'"{TM}"', shear_interp, VFlowAngle, HFlowAngle]
                        mod_vars = ['RandSeed1','HubHt','AnalysisTime','RefHt','Mean (total) velocity','IECturbc','IEC_WindType', 'PLExp','VFlowAng','HFlowAng']
                        modify_turbsim_file(template_path, dest_path, mod_vars, new_vals)
                    else:
                        new_vals = [sd, HubHt, An_Time, HubHt, Uref, f'"{Wind_Turb_cat}"', f'"{TM}"', VFlowAngle, HFlowAngle]
                        mod_vars = ['RandSeed1','HubHt','AnalysisTime','RefHt','Mean (total) velocity','IECturbc','IEC_WindType','VFlowAng','HFlowAng']
                        modify_turbsim_file(template_path, dest_path, mod_vars, new_vals)

                  #  Generate_TurbS_slurm_sbatch_files(Uref, Wind_folder, partition, None, None, seed=seed_idx)
        elif turb_sel == 0:
            for Uref in vels:
                if Site_specific_wind:
                # If site specific wind, we need to interpolate the shear and TI values based on the wind speed
                    shear_interp = interp_sh(Uref)
                    TI_interp = interp_TI(Uref)
                    print(f"Interpolated shear: {shear_interp}, TI: {TI_interp} for wind speed: {Uref}")

                if Site_specific_wind:
                    Wind_folder = f"{root_folder}/{DLC_folder_name}/Wind/SPC/v{Uref}/"
                    create_wind_folder(Wind_folder)
                else:
                    Wind_folder = f"{root_folder}/{DLC_folder_name}/Wind/{TM}/v{Uref}/"
                create_wind_folder(Wind_folder)

                Turb_filename = f"{Wind_file_root_name}_{Uref}.inp"
                dest_path, template_path = copy_and_rename_input_file(base_pattern, Wind_folder, Turb_filename)
                if not dest_path:
                    continue

                if Site_specific_wind: 
                    new_vals = [HubHt, An_Time_long, HubHt, Uref, TI_interp, f'"{TM}"', shear_interp, VFlowAngle, HFlowAngle]
                    mod_vars = ['HubHt','AnalysisTime','RefHt','Mean (total) velocity','IECturbc','IEC_WindType', 'PLExp','VFlowAng','HFlowAng']
                    modify_turbsim_file(template_path, dest_path, mod_vars, new_vals)
                else:
                    new_vals = [HubHt, An_Time_long, HubHt, Uref, f'"{Wind_Turb_cat}"', f'"{TM}"', VFlowAngle, HFlowAngle]
                    mod_vars = ['HubHt','AnalysisTime','RefHt','Mean (total) velocity','IECturbc','IEC_WindType','VFlowAng','HFlowAng']
                    modify_turbsim_file(template_path, dest_path, mod_vars, new_vals)

                Generate_TurbS_slurm_sbatch_files(Uref, Wind_folder, partition, None, None, None)

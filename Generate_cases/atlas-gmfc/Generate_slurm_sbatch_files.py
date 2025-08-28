import os

def Generate_slurm_sbatch_files(DLC_choice, Uref, root_folder,DLC_folder_name, YawAngle,variation_name=None, sh =None, TI = None, seed=None):
    
    TI_str = f"TI{TI}" if TI is not None else ""
    sh_str = f"/shear{sh}/" if sh is not None else ""

    if seed is not None:
        if variation_name:  # Variaciones solo para DLC 4p1
            destination_dir_Uref = f'{root_folder}/{DLC_folder_name}/DLC_{DLC_choice[0]}/{DLC_choice}_{variation_name}/Yaw_{YawAngle}/{Uref}{sh_str}{TI_str}/sd{seed}'
        else:
            destination_dir_Uref = f'{root_folder}/{DLC_folder_name}/DLC_{DLC_choice[0]}/{DLC_choice}/Yaw_{YawAngle}/{Uref}{sh_str}{TI_str}/sd{seed}'
    else:
        if variation_name:
            destination_dir_Uref = f'{root_folder}/{DLC_folder_name}/DLC_{DLC_choice[0]}/{DLC_choice}_{variation_name}/Yaw_{YawAngle}/{Uref}{sh_str}{TI_str}'
        else:
            destination_dir_Uref = f'{root_folder}/{DLC_folder_name}/DLC_{DLC_choice[0]}/{DLC_choice}/Yaw_{YawAngle}/{Uref}{sh_str}{TI_str}'

    vel_str = f"{Uref:.1f}"
    
    # Directorio del caso
    case_dir = destination_dir_Uref
    
    TI_str = f"TI{TI}" if TI is not None else ""
    sh_str = f"_sh{sh}_" if sh is not None else ""
    # Nombre del archivo SLURM
    if seed is not None:
        seed_str = f"sd{seed}"
        slurm_file_fst = os.path.join(case_dir, f"a.openfast.slurm_Yaw{YawAngle}_{vel_str}{sh_str}{TI_str}_{seed_str}.sh")
        print(slurm_file_fst)
        job_name = f'{DLC_choice}_Yaw{YawAngle}_v{Uref}_sh{sh_str}_TI{TI_str}_sd{seed}'
    else:
        slurm_file_fst = os.path.join(case_dir, f"a.openfast.slurm_Yaw{YawAngle}_{vel_str}{sh_str}{TI_str}.sh")
        job_name = f'{DLC_choice}_Yaw{YawAngle}_v{Uref}_sh{sh_str}_TI{TI_str}'
    
    # Contenido del archivo SLURM
    slurm_content = f"""#!/bin/bash
#SBATCH --job-name={job_name}
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=4096
#SBATCH --time=5:00:00
#SBATCH --partition=normal
#SBATCH --qos=normal
#SBATCH --output={destination_dir_Uref}/slurm-%j.out
#SBATCH --constraint="intel"
#SBATCH --no-requeue

source /etc/profile.d/modules.sh

export PATH=/clusteruy/home03/gmfc/opt/openfast-3.5.3/install/bin:$PATH
export LD_LIBRARY_PATH=/clusteruy/home05/brunolop/opt/gcc-13.2.0-install/lib64:$LD_LIBRARY_PATH
cd {destination_dir_Uref}

openfast *.fst
"""
    # Escribir el archivo SLURM
    with open(slurm_file_fst, "w") as f:
        f.write(slurm_content)

    print("Archivos SLURM generados exitosamente.")

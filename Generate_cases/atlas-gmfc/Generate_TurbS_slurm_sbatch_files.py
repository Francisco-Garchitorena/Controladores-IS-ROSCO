import os

def Generate_TurbS_slurm_sbatch_files(Uref,  Wind_folder, partition, TI = None, sh = None, seed=None):
    
    vel_str = f"v{Uref:.1f}"
    TI_str = f"_TI{TI}" if TI is not None else ""
    sh_str = f"_sh{sh}_" if sh is not None else ""
    
    # Directorio del caso
    case_dir = Wind_folder
    print('entered in slurm script')
    # Nombre del archivo SLURM
    if seed is not None:
        seed_str = f"sd{seed}"
        slurm_file = os.path.join(case_dir, f"a.openfast.slurm_turbsim_{vel_str}{sh_str}{TI_str}_{seed_str}.sh")
        job_name = f'turb_v{Uref}{sh_str}{TI_str}_sd{seed}'
    else:
        slurm_file = os.path.join(case_dir, f"a.openfast.slurm_turbsim_{vel_str}{sh_str}{TI_str}.sh")
        job_name = f'turb_v{Uref}{sh_str}{TI_str}' 
    
    # Contenido del archivo SLURM
    slurm_content = f"""#!/bin/bash
#SBATCH --job-name={job_name}
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=4096
#SBATCH --time=10:00:00
#SBATCH --partition={partition}
#SBATCH --qos=normal
#SBATCH --output={Wind_folder}/slurm-%j.out
#SBATCH --constraint="intel"
#SBATCH --no-requeue

source /etc/profile.d/modules.sh

export PATH=/clusteruy/home03/gmfc/opt/openfast-3.5.3/install/bin:$PATH
export LD_LIBRARY_PATH=/clusteruy/home05/brunolop/opt/gcc-13.2.0-install/lib64:$LD_LIBRARY_PATH
cd {Wind_folder}

turbsim *inp
"""
    # Escribir el archivo SLURM      #Agrega FG: 14/08
    if os.path.exists(slurm_file):
        os.remove(slurm_file)

    with open(slurm_file, "w") as f:
        f.write(slurm_content)

    if os.path.exists(slurm_file):
        print(f"Archivo SLURM creado exitosamente: {slurm_file}")
    else:
        print(f"Error: no se pudo crear el archivo SLURM en {slurm_file}")
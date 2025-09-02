#!/bin/bash
#SBATCH --job-name=turb_v8_sd0
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=4096
#SBATCH --time=10:00:00
#SBATCH --partition=normal
#SBATCH --qos=normal
#SBATCH --output=C:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO//Torque_2026/Wind/SPW/v8/TI8.0/sd0//slurm-%j.out
#SBATCH --constraint="intel"
#SBATCH --no-requeue

source /etc/profile.d/modules.sh

export PATH=/clusteruy/home03/gmfc/opt/openfast-3.5.3/install/bin:$PATH
export LD_LIBRARY_PATH=/clusteruy/home05/brunolop/opt/gcc-13.2.0-install/lib64:$LD_LIBRARY_PATH
cd C:/Users/fgarchitorena/Proyectos_de_investigacion/FSE_Incercia_Sintetica/Controladores-IS-ROSCO//Torque_2026/Wind/SPW/v8/TI8.0/sd0/

turbsim *inp

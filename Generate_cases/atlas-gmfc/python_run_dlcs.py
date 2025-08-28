import os
import re
from datetime import datetime
import subprocess
import sys

def python_run_dlcs(working_dir, DLCs, Site_specific_wind, seeds_names, vel_dict, shear_values, TI_values, TM, yaw_angles_and_weights_dlcs, max_job_slots, TurbSim_DLCs, turb_sel, root_name, Wind_file_root_name, Wind_user_choice):

    def check_file_content(file_path, search_string):
        """Check if a file contains a specific string."""
        try:
            with open(file_path, 'r') as f:
                content = f.read()
                return search_string in content
        except FileNotFoundError:
            return False

    def update_status_file(file_path, update_message):
        """Update the last updated date in the status file."""
        temp_file = file_path + ".tmp"
        search_string = "This file was last updated on:"
        try:
            with open(file_path, 'r') as infile, open(temp_file, 'w') as outfile:
                for line in infile:
                    if search_string in line:
                        outfile.write(f"{update_message}\n")
                    else:
                        outfile.write(line)
            os.replace(temp_file, file_path)
        except FileNotFoundError:
            print(f"Error: {file_path} not found.")
            sys.exit(1)


    # User Inputs
    slurm_user = os.getenv("USER", "unknown_user")

    status_sim_file = "OF_slurm_sim_status.txt"
    status_wind_file = "OF_slurm_wind_status.txt"
    status_rsync_file = "OF_slurm_rsync_status.txt"

    # Print execution details
    print(f"This script was last executed on: {datetime.now()} by {slurm_user}")

    #Change to working dir
    os.chdir(f"{working_dir}")
    current_directory = os.getcwd()
    print(f"You are in: {current_directory}")

    # Create or update status files
    if not (os.path.exists(status_sim_file) or os.path.exists(status_wind_file)):
        # Create files and add headers
        creation_date = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        header_sim = "This file resumes the state of each OpenFAST simulation."
        header_wind = "This file resumes the state of each Turbsim simulation."
        header_rsync = "This file resumes the state of each rsync execution."

        for file_path, header in [(status_sim_file, header_sim), 
                                (status_wind_file, header_wind), 
                                (status_rsync_file, header_rsync)]:
            with open(file_path, 'w') as f:
                f.write(f"{header}\n")
                f.write(f"The status file was created on: {creation_date}\n")
                f.write(f"This file was last updated on:  {creation_date}\n\n")

    elif os.path.exists(status_sim_file) and os.path.exists(status_wind_file):
        # Update last updated date
        update_message = f"This file was last updated on: {datetime.now()} by {slurm_user}"
        update_status_file(status_sim_file, update_message)
        update_status_file(status_wind_file, update_message)
        update_status_file(status_rsync_file, update_message)

    else:
        # Handle error if only one file exists
        print(f"Fatal error: Only one status file exists. Execution will terminate.")
        sys.exit(1)

    #####################

    def manage_job_execution(root_name, dir_name, job_name, available_cores, status_file, id_flag, max_num_excec=60):
        """
        Manages the execution of jobs, replicating the behavior of the Bash function.

        Args:
            dir_name (str): Directory of the job.
            job_name (str): Name of the job.
            available_cores (int): Number of available cores.
            status_file (str): Path to the status file.
            id_flag (int): 1 for wind, 2 for OpenFAST simulation.
            max_num_excec (int): Max allowed slurm output files.
        
        Returns:
            int: Execution status as per original function.
        """
        def check_file_content(file_path):
            """Check if the file contains the termination sentence."""
            try:
                with open(file_path, 'r') as file:
                    content = file.read()
                    return "terminated normally." in content
            except FileNotFoundError:
                print('No encontro el terminated normally.')
                return False

        try:
            with open(status_file, 'r') as file:
                status_lines = file.readlines()
        except FileNotFoundError:
            status_lines = []

        status_line = next((line for line in status_lines if job_name in line), None)

        if status_line:
            if "terminated normally." in status_line:
                return 3

            slurm_output_count = len([f for f in os.listdir(dir_name) if re.match(r"slurm-.*\.out", f)])  #Counts how many slurm files there are?

            if slurm_output_count > max_num_excec:
                if f"more than {max_num_excec} slurm output files" not in status_line:
                    new_status_line = f"{job_name}: It was found more than {max_num_excec} slurm output files in its directory. The case did not terminate normally, but it will not be executed again.\n"
                    with open(status_file, 'w') as file:
                        file.writelines([line if job_name not in line else new_status_line for line in status_lines])
                return 1

            job_status = subprocess.getoutput(f"squeue --format='%T' --noheader -n {job_name}").strip()
            print('job status', job_status)
            if job_status:
                if job_status == "RUNNING":
                    new_status_line = f"{job_name}: It is running (execution number {slurm_output_count}).\n"
                elif job_status == "PENDING":
                    new_status_line = f"{job_name}: It is pending (execution number {slurm_output_count}).\n"
                with open(status_file, 'w') as file:
                    print('New status line:',new_status_line)
                    file.writelines([line if job_name not in line else new_status_line for line in status_lines])
            else:
                slurm_files = sorted([f for f in os.listdir(dir_name) if re.match(r"slurm-.*\.out", f)], key=lambda x: os.path.getmtime(os.path.join(dir_name, x)), reverse=True)
                latest_slurm_out_file = os.path.join(dir_name, slurm_files[0]) if slurm_files else None
                print(latest_slurm_out_file)
                # Check if any ".outb" file exists in the directory
                outb_files = [f for f in os.listdir(dir_name) if f.endswith('.bts')]
                
                if (latest_slurm_out_file and check_file_content(latest_slurm_out_file)):
                    new_status_line = f"{job_name}: Terminated normally after {slurm_output_count} executions. Checked on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}.\n"
                    with open(status_file, 'w') as file:
                        file.writelines([line if job_name not in line else new_status_line for line in status_lines])
                    print('entered if that determines noraml ')
                    return 2

                if available_cores > 0:

                    if id_flag == 1:
                        os.system(f"rm -f {os.path.join(dir_name, job_name[5:])}.bts {os.path.join(dir_name, job_name[5:])}.sum")
                    elif id_flag == 2:
                        os.system(f"rm -f {os.path.join(dir_name, f'{root_name}_{job_name}.*ech')} {os.path.join(dir_name, f'{root_name}_{job_name}.*outb')} {os.path.join(dir_name, f'{root_name}_{job_name}.*sum')}")

                    new_status_line = f"{job_name}: Previous {slurm_output_count} executions did not terminate normally. The job has been sent to queue again.\n"
                    #contenido = os.listdir(dir_name)
                    #print(contenido)
                    subprocess.run([f"sbatch {os.path.join(dir_name, 'a.openfast.slurm*.sh')}"], shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                else:
                    new_status_line = f"{job_name}: Previous {slurm_output_count} executions did not terminate normally. Waiting for available cores to send it to queue again.\n"
                
                with open(status_file, 'w') as file:
                    file.writelines([line if job_name not in line else new_status_line for line in status_lines])
        else:
            if available_cores > 0:
                if id_flag == 1:
                    os.system(f"rm -f {os.path.join(dir_name, job_name[5:])}.bts {os.path.join(dir_name, job_name[5:])}.sum")
                elif id_flag == 2:
                    os.system(f"rm -f {os.path.join(dir_name, f'{root_name}_{job_name}.*ech')} {os.path.join(dir_name, f'{root_name}_{job_name}.*outb')} {os.path.join(dir_name, f'{root_name}_{job_name}.*sum')}")
                os.system(f"rm -f {os.path.join(dir_name, 'slurm-*.out')}")
                subprocess.run([f"sbatch {os.path.join(dir_name, 'a.openfast.slurm*.sh')}"], shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)   #cuidado que si el directorio no existe, igual te imprime que mandó la simulación cuando no lo hizo (no encontró el directorio)
                with open(status_file, 'a') as file:
                    file.write(f"{job_name}: It has been sent to queue for first time.\n")

        return 0

    def get_running_jobs_count(user):
        """Get the number of running jobs for the specified user."""
        try:
            result = subprocess.run(
                ["squeue", "-u", user, "-h"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            return len(result.stdout.splitlines())
        except Exception as e:
            print(f"Error checking running jobs: {e}")
            return 0

    def append_to_status_file(file_path, job_name, append_text):
        """Append a specific string to the end of a line in a file containing the job name."""
        try:
            with open(file_path, "r") as file:
                lines = file.readlines()
            with open(file_path, "w") as file:
                for line in lines:
                    if job_name in line:
                        line = line.strip() + " " + append_text + "\n"
                    file.write(line)
        except Exception as e:
            print(f"Error updating status file: {e}")

    def run_simulations(slurm_user, max_job_slots,root_name, dir_sim_name, job_sim_name, status_sim_file, all_simulations_done, id_flag):          #Function that sends the simualtions and obtains the result of each.
        running_jobs = get_running_jobs_count(slurm_user)
        available_cores = max_job_slots - running_jobs

        result = manage_job_execution(root_name, dir_sim_name, job_sim_name, available_cores, status_sim_file, id_flag)
        print('Simulation attempted - result:',result)
        
        if result <= 1:  # Job not terminated normally yet
            all_simulations_done = False  # At least one simulation isn't done

        elif result == 2:  # Job just terminated
            append_to_status_file(status_sim_file, job_sim_name, "OF output files created in respective folders.")
        
        return  result, all_simulations_done     
    
    all_simulations_done = True  # Flag to track if all simulations have finished
    for DLC_choice in DLCs:
        if DLC_choice == '6p4':
            vel = vel_dict['6p4']
            print(vel)
        else:
            vel = vel_dict['rest']

        YawAngles = yaw_angles_and_weights_dlcs.get(DLC_choice, [0])
        print(DLC_choice)
        for YawAngle in YawAngles:
            variation_name = ''
            if DLC_choice == '4p1': #REVER ESTO!!!
                variation_name = '_ROSCO_SDTime'#'PitchMan'         # 2p4: Different control error. 4p1: ROSCO_SDTime or PitchMan

            for iv in vel:  # Velocity iteration (4 to 25 with step 2)
                print("=" * 59)
                print(f"===== Iterating velocity {iv} at time {datetime.now().strftime('%H:%M:%S')} =====")

                all_dlcs_terminated = 1  # Flag to check if all imbalance jobs are done

                if Wind_user_choice:
                    if DLC_choice in TurbSim_DLCs and turb_sel == 1:                                 # Case 1
                        for sh in shear_values:
                            for TI in TI_values:
                                for ise in seeds_names:  # Seed iteration (0 to 5)
                                    dir_wind_name = f"./Wind/USW/v{int(iv)}/shear{sh}/TI{TI}/{ise}"       #Wind simulations.
                                    job_wind_name = f"{Wind_file_root_name}_{iv}_sh{sh}_TI{TI}_{ise}"

                                    result, all_simulations_done =  run_simulations(slurm_user, max_job_slots,root_name, dir_wind_name, job_wind_name, status_wind_file, all_simulations_done, 1) 
                                    if result <= 1:  # Job not terminated normally yet
                                        all_simulations_done = False  # At least one simulation isn't done
                                        all_dlcs_terminated = 0
                                        continue  # Skip to the next seed
                                        
                                    dir_sim_name = f"./DLC_{DLC_choice[0]}/{DLC_choice}{variation_name}/Yaw_{YawAngle}/{iv}/shear{sh}/TI{TI}/{ise}"
                                    job_sim_name = f"{DLC_choice}_Yaw{YawAngle}_{iv}_sh{sh}_TI{TI}_{ise}"
                                            
                                    result, all_simulations_done =  run_simulations(slurm_user, max_job_slots,root_name, dir_sim_name, job_sim_name, status_sim_file, all_simulations_done, 2) 

                                    if result <= 1:  # Job not terminated normally yet
                                        all_simulations_done = False  # At least one simulation isn't done
                                        all_dlcs_terminated = 0
                                        continue  # Skip to the next seed
                                    elif result == 2:  # Job just terminated
                                        append_to_status_file(status_sim_file, job_sim_name, "OF output files will be sent to medusa17.")
                                    
                #------------------------------------------------OPENFAST SIMULATIONS-----------------------------------------------------------#
                    
                    elif DLC_choice in TurbSim_DLCs and turb_sel == 0:                               # Case 3 
                        for sh in shear_values:
                            for TI in TI_values:
                                
                                dir_wind_name = f"./Wind/USW/v{int(iv)}/shear{sh}/TI{TI}"       #Wind simulations.
                                job_wind_name = f"{Wind_file_root_name}_{iv}_sh{sh}_TI{TI}"

                                result, all_simulations_done =  run_simulations(slurm_user, max_job_slots,root_name, dir_wind_name, job_wind_name, status_wind_file, all_simulations_done, 1) 
                                
                                if result <= 1:  # Job not terminated normally yet
                                    all_simulations_done = False  # At least one simulation isn't done
                                    all_dlcs_terminated = 0
                                    continue  # Skip to the next seed

                                dir_sim_name = f"./DLC_{DLC_choice[0]}/{DLC_choice}{variation_name}/Yaw_{YawAngle}/{iv}/shear{sh}/TI{TI}/"
                                job_sim_name = f"{DLC_choice}_Yaw{YawAngle}_{iv}_sh{sh}_TI{TI}"

                                result, all_simulations_done =  run_simulations(slurm_user, max_job_slots,root_name, dir_sim_name, job_sim_name, status_sim_file, all_simulations_done, 2) 
                                
                                if result <= 1:  # Job not terminated normally yet
                                    all_simulations_done = False  # At least one simulation isn't done
                                    all_dlcs_terminated = 0
                                    continue  # Skip to the next seed
                                elif result == 2:  # Job just terminated
                                    append_to_status_file(status_sim_file, job_sim_name, "OF output files will be sent to medusa17.")
                                
                    else:                                       # Case 5
                        dir_sim_name = f"./DLC_{DLC_choice[0]}/{DLC_choice}{variation_name}/Yaw_{YawAngle}/{iv}"
                        job_sim_name = f"{DLC_choice}_Yaw{YawAngle}_{iv}"
                        result, all_simulations_done =  run_simulations(slurm_user, max_job_slots,root_name, dir_sim_name, job_sim_name, status_sim_file, all_simulations_done, 2) 
                        
                        if result <= 1:  # Job not terminated normally yet
                            all_simulations_done = False  # At least one simulation isn't done
                            all_dlcs_terminated = 0
                            continue  # Skip to the next seed
                        elif result == 2:  # Job just terminated
                            append_to_status_file(status_sim_file, job_sim_name, "OF output files will be sent to medusa17.")
                        
                else:

                    if DLC_choice in TurbSim_DLCs and turb_sel == 1:

                        for ise in seeds_names:  # Seed iteration (0 to 5)
                            if Site_specific_wind:
                                dir_wind_name = f"./Wind/SPW/v{int(iv)}/{ise}"
                            else:
                                dir_wind_name = f"./Wind/{TM}/v{int(iv)}/{ise}"
                            job_wind_name = f"{Wind_file_root_name}_{iv:.1f}_{ise}"

                            result, all_simulations_done =  run_simulations(slurm_user, max_job_slots,root_name, dir_wind_name, job_wind_name, status_wind_file, all_simulations_done, 1) 
                                    
                            if result <= 1:  # Job not terminated normally yet
                                all_simulations_done = False  # At least one simulation isn't done
                                all_dlcs_terminated = 0
                                continue  # Skip to the next seed
                            elif result == 2:  # Job just terminated
                                append_to_status_file(status_wind_file, job_wind_name, "TS output files will be sent to medusa17.")
                            
                            dir_sim_name = f"./DLC_{DLC_choice[0]}/{DLC_choice}{variation_name}/Yaw_{YawAngle}/{iv:.1f}/{ise}"       #Case 2
                            job_sim_name = f"{DLC_choice}_Yaw{YawAngle}_{iv:.1f}_{ise}"
                            
                            running_jobs = get_running_jobs_count(slurm_user)
                            available_cores = max_job_slots - running_jobs

                            result, all_simulations_done =  run_simulations(slurm_user, max_job_slots,root_name, dir_sim_name, job_sim_name, status_sim_file, all_simulations_done, 2) 

                            if result <= 1:  # Job not terminated normally yet
                                all_simulations_done = False  # At least one simulation isn't done
                                all_dlcs_terminated = 0
                                continue  # Skip to the next seed
                            elif result == 2:  # Job just terminated
                                append_to_status_file(status_sim_file, job_sim_name, "OF output files will be sent to medusa17.")

                    else:
                        
                        if DLC_choice in TurbSim_DLCs:  #Case with turb_sel = 0
                            dir_wind_name = f"./Wind/{TM}/v{int(iv)}"
                            job_wind_name = f"{Wind_file_root_name}_{iv}"

                            result, all_simulations_done =  run_simulations(slurm_user, max_job_slots,root_name, dir_wind_name, job_wind_name, status_wind_file, all_simulations_done, 1) 
                                    
                            if result <= 1:  # Job not terminated normally yet
                                all_simulations_done = False  # At least one simulation isn't done
                                all_dlcs_terminated = 0
                                continue  # Skip to the next seed
                            elif result == 2:  # Job just terminated
                                append_to_status_file(status_wind_file, job_wind_name, "TS output files will be sent to medusa17.")
                        
                        print('here')
                        dir_sim_name = f"./DLC_{DLC_choice[0]}/{DLC_choice}{variation_name}/Yaw_{YawAngle}/{iv}"                # Case 4 and 5 
                        job_sim_name = f"{DLC_choice}_Yaw{YawAngle}_{iv}"
                        running_jobs = get_running_jobs_count(slurm_user)
                        available_cores = max_job_slots - running_jobs

                        result, all_simulations_done =  run_simulations(slurm_user, max_job_slots,root_name, dir_sim_name, job_sim_name, status_sim_file, all_simulations_done, 2) 
                        print('ALL SIM DONE',all_simulations_done, 'Result',result)                            
                        if result <= 1:  # Job not terminated normally yet
                            all_simulations_done = False  # At least one simulation isn't done
                            all_dlcs_terminated = 0
                            continue  # Skip to the next seed
                        elif result == 2:  # Job just terminated
                            append_to_status_file(status_sim_file, job_sim_name, "OF output files will be sent to medusa17.")

                # After iterating over all seeds
                if all_dlcs_terminated == 1:
                    append_to_status_file(
                        status_wind_file,
                        job_wind_name,
                        "All OF simulations have terminated normally."
                    )
# Break the outer loop if all simulations are done
    if all_simulations_done:
        print("All simulations have been completed successfully!")
        return True

    return False  # Return False if simulations are still running

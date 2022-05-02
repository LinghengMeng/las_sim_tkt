#!/bin/bash
#SBATCH --account=def-someuser
#SBATCH --gres=gpu:1             # Number of GPU(s) per node
#SBATCH --ntasks=4               # number of MPI processes
#SBATCH --mem-per-cpu=1024M      # memory; default unit is megabytes
#SBATCH --time=0-00:05           # time (DD-HH:MM)

# Load modules on host computer
module load python/3.7  # (Note: 1. the host is assumed to have python3-pip installed, so we can use pip to download python requirements. 2. python3.7 is required to match the python used within the container, as pip will download mismatched package wheels if the host computer’s python version is different from that in the container.)
module load singularity

######################################################################################
#                                   Define Variables                                 #
######################################################################################
# Define exp_run_time, which will be used by sleep command in exp_run.sh. Make sure to set it to the time 
# deducted by the time needed for all operations before running the experiment in order to neatly kill 
# the processes running different modules. For example, if the time for the job is 12 hours and the estimated 
# all other operations is 10 minutes, then we should set exp_run_time=(12*60-10)m
exp_run_time="0m"

# Setup related directories
las_sim_tkt_dir=./las_sim_tkt
las_sim_tkt_pkg_dir=./las_sim_tkt_pkg    # saving packages for offline installation
las_sim_tkt_dep_dir=./las_sim_tkt_dep    # saving installed shared softwares such as Processing, Node, Miniconda, Mujoco
las_sim_tkt_data_dir=./las_sim_tkt_data  # saving experiment data

# Define unique ID for the experiment run (add timestamp to name to make it unique)
resume_exp_run=true
if $resume_exp_run
then
    exp_run_uid=1_2022-04-24_22-16-53-80  # Provide exp_run_uid if resuming an experiment run
    echo "Resume experiment run: $exp_run_uid"
else
    exp_run_uid=1_"$(date +"%Y-%m-%d_%H-%M-%S-%2N")"   
    echo "Start new experiment run: $exp_run_uid" 
fi

##########################################################################################
#                     Note: No need to change the rest of the script                     #
##########################################################################################

online_instance_name=online_instance_$exp_run_uid    # 
offline_instance_name=offline_instance_$exp_run_uid  #
exp_run_name=exp_run_"$exp_run_uid"
exp_run_root_dir=$las_sim_tkt_data_dir/$exp_run_name # saving files related to the current experiment run 

if $resume_exp_run
then
    if [ ! -d $exp_run_root_dir ]; then
        echo "Resume directory: $exp_run_root_dir does not exist! Please double-check!" && exit
    fi
else
    mkdir -p $las_sim_tkt_dep_dir $las_sim_tkt_data_dir $exp_run_root_dir
    echo "Save experiment run data to '$exp_run_root_dir'" 
    cp -a $las_sim_tkt_dir/tool_scripts/exp_env.sh $exp_run_root_dir
    cp -a  "$0" $exp_run_root_dir                                 # Copy the current job script to $exp_run_root_dir
    cp -a $(dirname "$BASH_SOURCE")/exp_run.sh $exp_run_root_dir  # Copy the exp_run.sh within the same directory of the current job script to $exp_run_root_dir
    chmod +x $exp_run_root_dir/exp_env.sh
    chmod +x $exp_run_root_dir/exp_run.sh
fi

# Skip environment setup, if resuming experiment run
if [ ! resume_exp_run ]; then
    ######################################################################################
    #                    Download Requirements Shared by all Experiment Runs             #
    # The host has access to Internet, so download dependent softwares on host computer: #
    ######################################################################################
    if [ ! -d $las_sim_tkt_pkg_dir ]
    then
        mkdir -p $las_sim_tkt_pkg_dir && cp -a  $las_sim_tkt_dir/3rd_party/* $las_sim_tkt_pkg_dir
        wget -i $las_sim_tkt_pkg_dir/software_requirements.txt -P $las_sim_tkt_pkg_dir   # download software requirements: Processing, Node, Miniconda, and Mujoco
        singularity pull --arch amd64 $las_sim_tkt_pkg_dir/las_sim_tkt.sif  library://lingheng/las/las_sim_tkt:latest # download container
    fi
    
    ########################################################################################################################
    #                                             Install Nvidia Driver
    # TODO: modification may be needed for check driver version for different platform/High Performance Computation (HPC)
    ########################################################################################################################
    # Query nvidia driver version
    output_driver_version=($(nvidia-smi --query-gpu=driver_version --format=csv))    # Turn return as array with ()
    driver_version=${output_driver_version[1]}    # Retrieve driver version
    # driver_version=470.103.01    # If only login node has access to internet, manually set driver version
    
    
    # Download nvdriver
    if [ ! -f "$las_sim_tkt_pkg_dir/NVIDIA-Linux-x86_64-$driver_version.run" ]; then
        echo “Downloading nvidia-driver: NVIDIA-Linux-x86_64-$driver_version.run”
        wget -c https://us.download.nvidia.com/XFree86/Linux-x86_64/$driver_version/NVIDIA-Linux-x86_64-$driver_version.run -P $las_sim_tkt_pkg_dir
    fi
    
    # Extract nvdriver
    if [ ! -d $las_sim_tkt_dep_dir/nvdriver ]; then
        # Check if driver is downloaded
        if [ ! -f "$las_sim_tkt_pkg_dir/NVIDIA-Linux-x86_64-${NVID_VER}.run" ]; then
            echo "Driver installer file NVIDIA-Linux-x86_64-${NVID_VER}.run not found"
            exit 1
        fi
        
        # Create folder to save extracted driver
        if mkdir -p $las_sim_tkt_dep_dir/nvdriver ; then
            echo "Created directory at $las_sim_tkt_dep_dir/nvdriver"
        else
            echo "Could not create directory at $las_sim_tkt_dep_dir/nvdriver"
            exit 1
        fi
        
        chmod 755 $las_sim_tkt_pkg_dir/NVIDIA-Linux-x86_64-${NVID_VER}.run
        
        # extract nvidia files
        if $las_sim_tkt_pkg_dir/NVIDIA-Linux-x86_64-${NVID_VER}.run --extract-only ; then
          echo "Extracted driver"
        else
          echo "Could not extract driver"
          exit 1
        fi
        
        # move into place (overwrite old if exist)
        cd ..
        if mv $las_sim_tkt_pkg_dir/NVIDIA-Linux-x86_64-${NVID_VER}/* $las_sim_tkt_dep_dir/nvdriver ; then
          echo "Successfully installed to $las_sim_tkt_dep_dir/nvdriver"
        else
          echo "Cannot install drivers to $las_sim_tkt_dep_dir/nvdriver"
          exit 1
        fi
        
        # Make link within singularity instance
        cd $las_sim_tkt_dep_dir/nvdriver
        ln -s libGL.so.${driver_version}                 libGL.so.1
        ln -s libEGL_nvidia.so.${driver_version}         libEGL_nvidia.so.0
        ln -s libGLESv1_CM_nvidia.so.${driver_version}   libGLESv1_CM_nvidia.so.1
        ln -s libGLESv2_nvidia.so.${driver_version}      libGLESv2_nvidia.so.2
        ln -s libGLX_nvidia.so.${driver_version}         libGLX_indirect.so.0
        ln -s libGLX_nvidia.so.${driver_version}         libGLX_nvidia.so.0
        ln -s libnvidia-cfg.so.1                         libnvidia-cfg.so
        ln -s libnvidia-cfg.so.${driver_version}         libnvidia-cfg.so.1
        ln -s libnvidia-encode.so.1                      libnvidia-encode.so
        ln -s libnvidia-encode.so.${driver_version}      libnvidia-encode.so.1
        ln -s libnvidia-fbc.so.1                         libnvidia-fbc.so
        ln -s libnvidia-fbc.so.${driver_version}         libnvidia-fbc.so.1
        ln -s libnvidia-ifr.so.1                         libnvidia-ifr.so
        ln -s libnvidia-ifr.so.${driver_version}         libnvidia-ifr.so.1
        ln -s libnvidia-ml.so.1                          libnvidia-ml.so
        ln -s libnvidia-ml.so.${driver_version}          libnvidia-ml.so.1
        ln -s libnvidia-opencl.so.${driver_version}      libnvidia-opencl.so.1
        ln -s vdpau/libvdpau_nvidia.so.${driver_version} libvdpau_nvidia.so
        ln -s libcuda.so.${driver_version}               libcuda.so
        ln -s libcuda.so.${driver_version}               libcuda.so.1

    fi
    
    #######################################################################################
    #            Start Singularity Container Instance With Internet Access                #                                 
    #######################################################################################
    # Start singularity instance and run shell in the instance to prepare environment
    singularity instance start --bind $las_sim_tkt_dir:/las_sim_tkt,$las_sim_tkt_pkg_dir:/las_sim_tkt_pkg,$las_sim_tkt_dep_dir:/las_sim_tkt_dep,$exp_run_root_dir:/exp_run_root $las_sim_tkt_pkg_dir/las_sim_tkt.sif $online_instance_name
    
    # # For interactive command running (only used for testing)
    # singularity shell instance://$online_instance_name
    # For automatic command running: environment_setup_script.sh
    singularity exec instance://$online_instance_name bash /exp_run_root/exp_env.sh
fi

#######################################################################################
#            Start Singularity Container Instance Without Internet Access             #
# Since the communication among the Processing-Simulator, Gaslight-OSC-Server and     #
# Learning Agent are through the OSC message protocol based on UDP, if we want to run #
# multiple experiments with Singularity container on the same computer node, they can #
# only work with localhost within each container with the parameters                  #
# "--net --network=none".                                                             #
#######################################################################################
# Start container instance and run shell in the instance to run experiment
singularity instance start --net --network=none --bind $las_sim_tkt_dir:/las_sim_tkt,$las_sim_tkt_pkg_dir:/las_sim_tkt_pkg,$las_sim_tkt_dep_dir:/las_sim_tkt_dep,$exp_run_root_dir:/exp_run_root $las_sim_tkt_pkg_dir/las_sim_tkt.sif $offline_instance_name

# Run experiment script
# # For interactive command running (only used for testing)
# singularity shell instance://$offline_instance_name
# For automatic command running
singularity exec instance://$offline_instance_name bash /exp_run_root/exp_run.sh $exp_run_time 
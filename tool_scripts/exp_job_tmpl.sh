#!/bin/bash
#SBATCH --account=def-someuser
#SBATCH --gres=gpu:1             # Number of GPU(s) per node
#SBATCH --nodes=1                # When requesting GPUs per node the number of nodes must be specified.
#SBATCH --ntasks=4               # number of MPI processes
#SBATCH --mem-per-cpu=1024M      # memory; default unit is megabytes
#SBATCH --time=0-00:05           # time (DD-HH:MM)

# Define exp_run_time, which will be used by sleep command in exp_run.sh. Make sure to set it to the time 
# deducted by the time needed for all operations before running the experiment in order to neatly kill 
# the processes running different modules. For example, if the time for the job is 12 hours and the estimated 
# all other operations is 10 minutes, then we should set exp_run_time=(12*60-10)m
exp_run_time="0m"

# Setup related directories
# Note: '.' directory corresponds to the path where you will submit this job.
las_sim_tkt_dir=./las_sim_tkt
las_sim_tkt_pkg_dir=./las_sim_tkt_pkg    # saving packages for offline installation
las_sim_tkt_dep_dir=./las_sim_tkt_dep    # saving installed shared softwares such as Processing, Node, Miniconda, Mujoco
las_sim_tkt_data_dir=./las_sim_tkt_data  # saving experiment data

# Setup nvidia GPU driver version. To find the driver version, on a compute node, use nvidia-smi to query gpu deriver version:
#   output_nv_driver_version=($(nvidia-smi --query-gpu=driver_version --format=csv))    # Turn return as array with ()
#   nv_driver_version=${output_nv_driver_version[1]}    # Retrieve driver version
nv_driver_version=470.103.01             # 

##########################################################################################
#                     Note: No need to change the rest of the script                     #
##########################################################################################
# Load modules on host computer
module load python/3.7  # (Note: 1. the host is assumed to have python3-pip installed, so we can use pip to download python requirements. 2. python3.7 is required to match the python used within the container, as pip will download mismatched package wheels if the host computer’s python version is different from that in the container.)
module load singularity

# The exp_job script must be run with "bash exp_job.sh" on a login node, in case there is no Internet access on compute node. 
# Once the environment setup is done for a given job, either a new experiment after environment setup or a resumed experiment, 
# this script will recursively submit itself to compute node and setup the flag to stop recursive calling.
if [ $# -eq 0 ]
then
    exp_run_uid=1_"$(date +"%Y-%m-%d_%H-%M-%S-%2N")"    # Define unique ID for the experiment run (add timestamp to name to make it unique) 
    resume_exp_run=false
    stop_recursive_submission=false
    echo "Starting new experiment: $exp_run_uid"  
elif [ $# -eq 1 ]
then
    exp_run_uid=$1
    resume_exp_run=true
    stop_recursive_submission=false
    echo "Resuming the experiment: $1"                  # Provide exp_run_uid with format "1_2022-04-24_22-16-53-80" if resuming an experiment run
elif [ $# -eq 2 ]
then
    exp_run_uid=$1
    resume_exp_run=true
    stop_recursive_submission=true
    echo "Resuming the experiment: $1"                  # Provide exp_run_uid with format "1_2022-04-24_22-16-53-80" if resuming an experiment run
else
    echo "Error: Only one argument 'exp_run_uid' is required!"
    exit
fi
######################################################################################
#                                   Define Variables                                 #
######################################################################################
online_instance_name=online_instance_$exp_run_uid    # 
offline_instance_name=offline_instance_$exp_run_uid  #
exp_run_name=exp_run_"$exp_run_uid"
exp_run_root_dir=$las_sim_tkt_data_dir/$exp_run_name # saving files related to the current experiment run 

if $resume_exp_run
then
    if [ ! -d $exp_run_root_dir ]; then
        echo "Resume directory: $exp_run_root_dir does not exist! Please double-check!" && exit
    fi
    # If resume_exp_run and exists $exp_run_root_dir, this means environment setup is done.
    env_setup_done=true
    echo "Environment setup for the experiment $exp_run_uid is done!"
else
    mkdir -p $las_sim_tkt_dep_dir $las_sim_tkt_data_dir $exp_run_root_dir
    echo "Save experiment run data to '$exp_run_root_dir'" 
    cp -a $las_sim_tkt_dir/tool_scripts/exp_env.sh $exp_run_root_dir
    cp -a  "$0" $exp_run_root_dir                                 # Copy the current job script to $exp_run_root_dir
    cp -a $(dirname "$BASH_SOURCE")/exp_run.sh $exp_run_root_dir  # Copy the exp_run.sh within the same directory of the current job script to $exp_run_root_dir
    chmod +x $exp_run_root_dir/exp_env.sh
    chmod +x $exp_run_root_dir/exp_run.sh
    # If start a new experiment, environment setup is not done.
    env_setup_done=false
    echo "Environment setup for the experiment $exp_run_uid is ongoing!"
fi

# Skip environment setup, if environment setup is done.
if ! $env_setup_done 
then
    echo "I am setting up experiment environemnt on login node!"
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
    # Download nvdriver
    if [ ! -f "$las_sim_tkt_pkg_dir/NVIDIA-Linux-x86_64-$nv_driver_version.run" ]; then
        echo “Downloading nvidia-driver: NVIDIA-Linux-x86_64-${nv_driver_version}.run”
        wget -c https://us.download.nvidia.com/XFree86/Linux-x86_64/${nv_driver_version}/NVIDIA-Linux-x86_64-${nv_driver_version}.run -P $las_sim_tkt_pkg_dir
    fi
    
    # Extract nvdriver
    if [ ! -d $las_sim_tkt_dep_dir/nvdriver ]; then
        # Check if driver is downloaded
        if [ ! -f "$las_sim_tkt_pkg_dir/NVIDIA-Linux-x86_64-${nv_driver_version}.run" ]; then
            echo "Driver installer file NVIDIA-Linux-x86_64-${nv_driver_version}.run not found"
            exit 1
        fi
        
        # Create folder to save extracted driver
        if mkdir -p $las_sim_tkt_dep_dir/nvdriver ; then
            echo "Created directory at $las_sim_tkt_dep_dir/nvdriver"
        else
            echo "Could not create directory at $las_sim_tkt_dep_dir/nvdriver"
            exit 1
        fi
        
        chmod 755 $las_sim_tkt_pkg_dir/NVIDIA-Linux-x86_64-${nv_driver_version}.run
        
        # extract nvidia files
        if $las_sim_tkt_pkg_dir/NVIDIA-Linux-x86_64-${nv_driver_version}.run --extract-only --target $las_sim_tkt_pkg_dir/NVIDIA-Linux-x86_64-${nv_driver_version}; then
          echo "Extracted driver"
        else
          echo "Could not extract driver"
          exit 1
        fi
        
        # move into place (overwrite old if exist)
        if mv $las_sim_tkt_pkg_dir/NVIDIA-Linux-x86_64-${nv_driver_version}/* $las_sim_tkt_dep_dir/nvdriver ; then
          echo "Successfully installed to $las_sim_tkt_dep_dir/nvdriver"
        else
          echo "Cannot install drivers to $las_sim_tkt_dep_dir/nvdriver"
          exit 1
        fi
        
        # Make link within singularity instance
        cd $las_sim_tkt_dep_dir/nvdriver
        ln -s libGL.so.${nv_driver_version}                 libGL.so.1
        ln -s libEGL_nvidia.so.${nv_driver_version}         libEGL_nvidia.so.0
        ln -s libGLESv1_CM_nvidia.so.${nv_driver_version}   libGLESv1_CM_nvidia.so.1
        ln -s libGLESv2_nvidia.so.${nv_driver_version}      libGLESv2_nvidia.so.2
        ln -s libGLX_nvidia.so.${nv_driver_version}         libGLX_indirect.so.0
        ln -s libGLX_nvidia.so.${nv_driver_version}         libGLX_nvidia.so.0
        ln -s libnvidia-cfg.so.1                         libnvidia-cfg.so
        ln -s libnvidia-cfg.so.${nv_driver_version}         libnvidia-cfg.so.1
        ln -s libnvidia-encode.so.1                      libnvidia-encode.so
        ln -s libnvidia-encode.so.${nv_driver_version}      libnvidia-encode.so.1
        ln -s libnvidia-fbc.so.1                         libnvidia-fbc.so
        ln -s libnvidia-fbc.so.${nv_driver_version}         libnvidia-fbc.so.1
        ln -s libnvidia-ifr.so.1                         libnvidia-ifr.so
        ln -s libnvidia-ifr.so.${nv_driver_version}         libnvidia-ifr.so.1
        ln -s libnvidia-ml.so.1                          libnvidia-ml.so
        ln -s libnvidia-ml.so.${nv_driver_version}          libnvidia-ml.so.1
        ln -s libnvidia-opencl.so.${nv_driver_version}      libnvidia-opencl.so.1
        ln -s vdpau/libvdpau_nvidia.so.${nv_driver_version} libvdpau_nvidia.so
        ln -s libcuda.so.${nv_driver_version}               libcuda.so
        ln -s libcuda.so.${nv_driver_version}               libcuda.so.1

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

if ! $stop_recursive_submission
then
    echo "I am submitting myself to compute node!"
    stop_recursive_submission=true
    sbatch $0 $exp_run_uid $stop_recursive_submission
else
    echo "Finally! I am running experiment on compute node!"
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
fi
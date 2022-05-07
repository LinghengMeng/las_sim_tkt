#!/bin/bash
echo "Welcome! Running environment setup script within singularity container...";


# Add experiment run related variables
export exp_run_code_dir=/exp_run_root/exp_run_code    # Save experiment run related source code
export exp_run_dep_dir=/exp_run_root/exp_run_dep      # Save experiment run related dependencies
export exp_run_data_dir=/exp_run_root/exp_run_data    # Save experiment run related data
export exp_run_video_dir=/exp_run_root/exp_run_video  # Save experiment run related video data


#############################################################################
#         Prepare softwares shared among different experiment runs          #
#############################################################################
echo "Preparing environment ...";
# 3. Miniconda3 (optional, only for creating python environment)
if [ ! -d /las_sim_tkt_dep/miniconda3 ] 
then
    bash /las_sim_tkt_pkg/Miniconda3-latest-Linux-x86_64.sh -b -p /las_sim_tkt_dep/miniconda3
fi

# 4. mujoco (optional, only for OpenAI Gym tasks)
if [ ! -d /las_sim_tkt_dep/mujoco ] 
then
    mkdir -p /las_sim_tkt_dep/mujoco
    tar -xzvf /las_sim_tkt_pkg/mujoco210-linux-x86_64.tar.gz -C /las_sim_tkt_dep/mujoco
fi

#############################################################################
#                          Setup Experiment Run Code                        #
#############################################################################
if [ ! -d /exp_run_root ]
then
  echo "Error: Please bind exp_run_root!" && exit
else
  echo "Preparing experiment run code" 
  # Create folders to save data
  mkdir -p $exp_run_code_dir $exp_run_dep_dir $exp_run_data_dir $exp_run_video_dir
  # Copy 1. Processing-Simulator, 2. Gaslight-OSC-Server, and 3. PL-POMDP in exp_code_base into exp_run_#/exp_code
  cp -a  /las_sim_tkt/code_base/PL-POMDP $exp_run_code_dir
  echo "Preparing experiment run code done"
fi

#############################################################################
#                     Prepare python environment                            #
# Note: do not share python env among different experiment runs.            #  
#############################################################################
# Prepare python environment (Python environment needs to be installed for each experiment run. Otherwise, pip install -e . for PL-POMDP will change the package to the new code folder in exp_run_#/exp_run_code/PL-POMDP)
# Install python packages
echo "Preparing python environment"
if [ ! -d $exp_run_dep_dir/pl_env ]
then
    mkdir -p $exp_run_dep_dir/pl_env
    cd $exp_run_dep_dir
    tar -xzf /las_sim_tkt_pkg/pl_env.tar.gz -C pl_env
fi
# Activate the environment, which will add `/las_sim_tkt_dep/pl_env/bin` to your path
# TODO: consider download packages for offline installation
source $exp_run_dep_dir/pl_env/bin/activate
cd $exp_run_code_dir/PL-POMDP 
pip install -e .    # Install pl and its dependencies
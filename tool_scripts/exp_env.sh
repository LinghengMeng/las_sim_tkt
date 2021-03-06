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
# 1. Processing
if [ ! -d /las_sim_tkt_dep/processing-4.0b2 ] 
then
    # Extract to las_sim_tkt_dep
    tar -xzvf /las_sim_tkt_pkg/processing-4.0b2-linux64.tgz  -C /las_sim_tkt_dep
    # If not exist libraries, copy them to $HOME/sketchbook/libraries
    if [ ! -d  $HOME/sketchbook/libraries ]; then
        mkdir -p $HOME/sketchbook/libraries
    fi
    # ~/.config/processing/preferences.txt
    echo "Extracting Processing libraries to $HOME/sketchbook/libraries"
    tar -xvf /las_sim_tkt_pkg/processing_sketchbook_libs.tar.xz -C $HOME/sketchbook/libraries --strip-components=1
fi

# 2. Nodejs
if [ ! -d /las_sim_tkt_dep/node-v14.17.6-linux-x64 ] 
then
    tar -xvf /las_sim_tkt_pkg/node-v14.17.6-linux-x64.tar.xz -C /las_sim_tkt_dep
fi

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
  

  # Copy 1. Processing-Simulator, 2. Gaslight-OSC-Server
  cp -a  /las_sim_tkt/code_base/{Processing-Simulator,Gaslight-OSC-Server} $exp_run_code_dir
  echo "Preparing experiment run code done"
  # Important: make symbolic link within /exp_data/$exp_run_dir/exp_run_code/Gaslight-OSC-Server to target "$exp_run_code/Processing-Simulator/Control_World/data/Meander_AUG15" with linkename behaviour_settings_simulator
  # behaviour_settings_simulator
  cd $exp_run_code_dir/Gaslight-OSC-Server
  if [ -d ./behaviour_settings_simulator ]
  then
    rm -rf ./behaviour_settings_simulator
  fi
  ln -s $exp_run_code_dir/Processing-Simulator/Control_World/data/Meander_AUG15 behaviour_settings_simulator
  # Install required nodejs packages according to package-lock.json
  export PATH=/las_sim_tkt_dep/node-v14.17.6-linux-x64/bin:$PATH
  npm ci    # Install specific version of the packages
  npm i puppeteer
fi

#############################################################################
#                     Prepare python environment                            #
# Note: do not share python env among different experiment runs.            #  
#############################################################################
# Copy PL-POMDP in exp_code_base into las_sim_tkt_dep
cp -a  /las_sim_tkt/code_base/PL-POMDP /las_sim_tkt_dep
# Prepare python environment (Python environment is shared among experiment runs, so provide a las_intl_env_config file for each run to configurate its LAS internal environment.)
# Install python packages
echo "Preparing python environment"
if [ ! -d /las_sim_tkt_dep/pl_env ]
then
    mkdir -p /las_sim_tkt_dep/pl_env
    cd /las_sim_tkt_dep
    tar -xzf /las_sim_tkt_pkg/pl_env.tar.gz -C pl_env
fi
# Activate the environment, which will add `/las_sim_tkt_dep/pl_env/bin` to your path
# TODO: consider download packages for offline installation
source /las_sim_tkt_dep/pl_env/bin/activate
cd /las_sim_tkt_dep/PL-POMDP
pip install -e .    # Install pl and its dependencies
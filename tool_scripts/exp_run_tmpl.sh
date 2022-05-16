#!/bin/bash
echo "Welcome! Running experiment script within singularity container...";

# Add experiment run related variables (“/exp_run_root” is bound to the root folder for the current experiment run)
export exp_run_code_dir=/exp_run_root/exp_run_code
export exp_run_dep_dir=/exp_run_root/exp_run_dep
export exp_run_data_dir=/exp_run_root/exp_run_data
export exp_run_video_dir=/exp_run_root/exp_run_video
  
# Add softwares to environment variables
export PATH=/las_sim_tkt_dep/processing-4.0b2:$PATH   
export PATH=/las_sim_tkt_dep/node-v14.17.6-linux-x64/bin:$PATH
export PATH=/las_sim_tkt_dep/miniconda3/bin:$PATH
export PATH=/las_sim_tkt_dep/miniconda3/envs:$PATH
export MUJOCO_PY_MUJOCO_PATH=/las_sim_tkt_dep/mujoco/mujoco210
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/las_sim_tkt_dep/mujoco/mujoco210/bin

# Add nvdriver to PATH
# If run without physical GPU, do not added nvdriver to PATH and LD_LIBRARY_PATH

add_nvdriver=$1    # Indicate if add nvidia driver to path (true or false)
exp_run_time=$2    # Estimated experiment run time
save_processing_simulator_video=$3    # Indicate if save processing simulator video (true or false)
echo "add_nvdriver=$add_nvdriver, exp_run_time=$exp_run_time"

if [ $# -ne 3 ]
then
  echo "Error! Please provide three arguments to indicate (1) if add nvdriver: (true or false), (2) expriment run time, (3) if save processing simulator video (true or false)" & exit
else
  if [ "$add_nvdriver" == true ]
  then
    echo "Add nvdriver"
    export PATH=/las_sim_tkt_dep/nvdriver:$PATH
    export LD_LIBRARY_PATH=/las_sim_tkt_dep/nvdriver:$LD_LIBRARY_PATH
  else
    echo "Not add nvdriver"
  fi
fi

#############################################################################
#                       Start simulation components                         #
#############################################################################
# 1. Start Gaslight-OSC-Server
#     Note: (a) Run server.js in the code folder of Gaslight-OSC-Server, because gaslightdata.json is load with relative path. (b) Run Gaslight-OSC-Server with xvfb-run
#         as it defaultly opens a web-based GUI within a broswer. If not run with xvfb-run server.js, comment out line 124 “opn("http://" + masterClientIp + ":" + guiServerPort);” 

cd $exp_run_code_dir/Gaslight-OSC-Server   
nohup xvfb-run  --server-num 201  -e /dev/stdout -s '-nocursor -ac -screen 0 1200x800x24' node ./server.js &>$exp_run_data_dir/console_osc_server_$(date '+%Y-%m-%d_%H-%M-%S').out &
pid_osc_server=$!    # Save PID for later use
echo "Running Gaslight-OSC-Server";

# 2. Start Processing-Simulator
# Run Processing-Simulator within X virtual framebuffer using xvfb-run rather than Xvfb, as the xvfb-run closes the server once it's terminated.
nohup xvfb-run  --server-num 200  -e /dev/stdout -s '-nocursor -ac -screen 0 1200x800x24' processing-java --sketch=$exp_run_code_dir/Processing-Simulator/Control_World --run &>$exp_run_data_dir/console_pro_sim__$(date '+%Y-%m-%d_%H-%M-%S').out &
pid_pro_sim=$!    # Save PID for later use
echo "Running Processing-Simulator";
sleep 2m  # Sleep 2m to allow Processing-Simulator to initialize and start. Otherwise, Gaslight-OSC-Server will produce “Hm... seems like someone is sending a patchable command but doesn't exist yet”

# Save Processing-Simulator video
if $save_processing_simulator_video
then
  nohup ffmpeg -f x11grab -video_size 1200x800 -i :200 -draw_mouse 0 -codec:v libx264 -r 12 -y $exp_run_video_dir/processing_simulator_$(date '+%Y-%m-%d_%H-%M-%S').mp4 &>$exp_run_data_dir/console_pro_sim_ffmpeg_$(date '+%Y-%m-%d_%H-%M-%S').out &
  pid_pro_sim_ffmpeg=$!    # Save PID for later use
  echo "Running ffmpeg on Processing-Simulator to saving video";
fi

# 3. Start Learning
source /las_sim_tkt_dep/pl_env/bin/activate    # Activate python environment
ulimit -n 50000    # Set ulimit to avoid “Too many open files” error when using Multiprocessing Queue
# Run python script （Note: this is the part need to be changed for different experiment runs.）
# 
if [ -d "$exp_run_data_dir/PL-Teaching-Data" ]; then
  nohup python /las_sim_tkt_dep/PL-POMDP/pl/teach.py --resume_exp_dir $exp_run_data_dir/PL-Teaching-Data/exp_name --las_config $exp_run_data_dir/las_config.py &>$exp_run_data_dir/console_python_$(date '+%Y-%m-%d_%H-%M-%S').out &
else
  nohup python /las_sim_tkt_dep/PL-POMDP/pl/teach.py --env_id LAS-Meander --rl_reward_type hc_reward --las_config $exp_run_data_dir/las_config.py &>$exp_run_data_dir/console_python_$(date '+%Y-%m-%d_%H-%M-%S').out &
fi
pid_python=$!    # Save PID for later use

#############################################################################
#                        Stop simulation components                         #
#############################################################################
# Stop processes inversely with kill before the timeout of the allocated job time. 
# Check 'kill -l' to see kill signals.
# Setup timer
sleep $exp_run_time
# 1. Stop Learning
kill -2 $pid_python
# 2. Stop Gaslight-OSC-Server
kill -2 $pid_osc_server
# 3. Exit ffmpeg with kill -2(SIGINT). Otherwise the video will be broken.
#    Important: stop ffmepg before Processing-SimulatorS
kill -2 $pid_pro_sim_ffmpeg
# 4. Processing-Simulator
kill -2 $pid_pro_sim
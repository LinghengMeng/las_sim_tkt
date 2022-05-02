#!/bin/bash
echo "Welcome! Running experiment script within singularity container...";

# Add experiment run related variables (“/exp_run_root” is bound to the root folder for the current experiment run)
export exp_run_code_dir=/exp_run_root/exp_run_code
export exp_run_dep_dir=/exp_run_root/exp_run_dep
export exp_run_data_dir=/exp_run_root/exp_run_data
export exp_run_video_dir=/exp_run_root/exp_run_video
  
# Add softwares to environment variables
export PATH=/las_sim_tkt_dep/processing-4.0b2:$PATH   
export PATH=/las_sim_tkt_dep/node-v16.13.1-linux-x64/bin:$PATH
export PATH=/las_sim_tkt_dep/miniconda3/bin:$PATH
export PATH=/las_sim_tkt_dep/miniconda3/envs:$PATH
export MUJOCO_PY_MUJOCO_PATH=/las_sim_tkt_dep/mujoco/mujoco210
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/las_sim_tkt_dep/mujoco/mujoco210/bin
export PATH=/las_sim_tkt_dep/nvdriver:$PATH
export LD_LIBRARY_PATH=/las_sim_tkt_dep/nvdriver:$LD_LIBRARY_PATH
# Add nvdriver to PATH
export PATH=/las_sim_tkt_dep/nvdriver:$PATH
export LD_LIBRARY_PATH=/las_sim_tkt_dep/nvdriver:$LD_LIBRARY_PATH

#############################################################################
#                       Start simulation components                         #
#############################################################################
# 1. Start Gaslight-OSC-Server
#     Note: (a) Run server.js in the code folder of Gaslight-OSC-Server, because gaslightdata.json is load with relative path. (b) Run Gaslight-OSC-Server with xvfb-run
#         as it defaultly opens a web-based GUI within a broswer. If not run with xvfb-run server.js, comment out line 124 “opn("http://" + masterClientIp + ":" + guiServerPort);” 

cd $exp_run_code_dir/Gaslight-OSC-Server   
nohup xvfb-run  --server-num 201 --auth-file /tmp/xvfb.auth -s '-nocursor -ac -screen 0 1200x800x24' node ./server.js &>$exp_run_data_dir/console_osc_server_$(date '+%Y-%m-%d_%H-%M-%S').out &
pid_osc_server=$!    # Save PID for later use
echo "Running Gaslight-OSC-Server";

# 2. Start Processing-Simulator
# Run Processing-Simulator within X virtual framebuffer using xvfb-run rather than Xvfb, as the xvfb-run closes the server once it's terminated.
nohup xvfb-run  --server-num 200 --auth-file /tmp/xvfb.auth -s '-nocursor -ac -screen 0 1200x800x24' processing-java --sketch=$exp_run_code_dir/Processing-Simulator/Control_World --run &>$exp_run_data_dir/console_pro_sim__$(date '+%Y-%m-%d_%H-%M-%S').out &
pid_pro_sim=$!    # Save PID for later use
echo "Running Processing-Simulator";
sleep 2m  # Sleep 2m to allow Processing-Simulator to initialize and start. Otherwise, Gaslight-OSC-Server will produce “Hm... seems like someone is sending a patchable command but doesn't exist yet”

# Save Processing-Simulator video
save_processing_simulator_video=1
if [ $save_processing_simulator_video ]
then
  nohup ffmpeg -f x11grab -video_size 1200x800 -i :200 -draw_mouse 0 -codec:v libx264 -r 12 -y $exp_run_video_dir/processing_simulator_$(date '+%Y-%m-%d_%H-%M-%S').mp4 &>$exp_run_data_dir/console_pro_sim_ffmpeg_$(date '+%Y-%m-%d_%H-%M-%S').out &
  pid_pro_sim_ffmpeg=$!    # Save PID for later use
  echo "Running ffmpeg on Processing-Simulator";
fi

# 3. Start Learning
source $exp_run_dep_dir/pl_env/bin/activate    # Activate python environment
ulimit -n 50000    # Set ulimit to avoid “Too many open files” error when using Multiprocessing Queue
# Run python script （Note: this is the part need to be changed for different experiment runs.）
nohup python $exp_run_code_dir/PL-POMDP/pl/teach.py --env_id LAS-Meander --rl_reward_type hc_reward &>$exp_run_data_dir/console_python.out &
pid_python=$!    # Save PID for later use

#############################################################################
#                        Stop simulation components                         #
#############################################################################
# Stop processes inversely with kill before the timeout of the allocated job time. 
# Check 'kill -l' to see kill signals.
# Setup timer
exp_run_time=$1
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
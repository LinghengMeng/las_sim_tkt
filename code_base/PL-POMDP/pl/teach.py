import math
import os.path as osp
from collections import deque
import os
import sys
import importlib.util
import json
import torch
import numpy as np
from time import time, sleep
from pl import las_config
from pl.envs.env import make_gym_task
from pl.envs.env import get_timesteps_per_episode
from pl.envs.gym_intl_env import IntlEnv
from pl.envs.las_intl_env import LASIntlEnv
from pl.prefs.pref_collectors import SyntheticPreferenceCollector, HumanPreferenceCollector
from pl.rews.rew_comp import RewardComponent, MLPRewardComponent, LSTMRewardComponent
from pl.agents.random_agent.random_agent import RandomAgent
from pl.agents.ddpg.ddpg import DDPG
from pl.agents.td3.td3 import TD3
from pl.agents.mtd3.mtd3 import MTD3
from pl.agents.td3_bc.td3_bc import TD3BC
from pl.agents.sac.sac import SAC
from pl.agents.msac.msac import MSAC
from pl.agents.ppo.ppo import PPO
from pl.agents.lstm_td3.lstm_td3 import LSTMTD3
from pl.agents.lstm_mtd3.lstm_mtd3 import LSTMMTD3
from pl.mems.db_manager import DatabaseManager
from pl.utils.logx import EpochLogger, colorize, setup_logger_kwargs
from collections import namedtuple
import logging
import gc
import sqlite3


def preference_teaching(env_id, env_dp_type,
                        env_act_transform_type, env_obs_delay_step,
                        seed, gym_env_obs_tile, stochastic_env,
                        rl_reward_type, rl_agent, gamma, multistep_size,
                        recompute_reward_in_backup,
                        reward_comp_type, reward_limit, reward_comp_drop_prob,
                        reward_net_input_type,
                        pretrain_label_num, total_label_num, video_clip_length_in_seconds,
                        teacher_type,
                        hidden_sizes=(256, 256), act_noise=0.1,
                        steps_per_epoch=4000, epochs=100, start_steps=10000,
                        replay_buff_type='DB', replay_size=int(1e6), batch_size=64, local_db_type='in_memory_db',
                        update_after=1000, update_every=50, num_test_episodes=10,
                        resume_exp_dir=None, save_checkpoint_every_n_steps=10000, logger_kwargs=dict()):

    # Load fixed hyper-parameters for Openai Gym tasks and for LAS-Meander
    if env_id == "LAS-Meander":
        # LAS-Meander has shorter maximum episode length, so some hyper-params are adapted accordingly.
        steps_per_epoch = 100   #
        start_steps = 100       # start_steps=200 is better than 100
        update_after = 50       # update_after should be smaller than steps_per_epoch in order to have training log data.
        num_test_episodes = 1
        save_checkpoint_every_n_steps = 2 * 100
        video_clip_length_in_seconds = 30
    else:
        steps_per_epoch = 4000
        start_steps = 10000
        update_after = 1000
        num_test_episodes = 5  # 10
        save_checkpoint_every_n_steps = 10000

    # Set data saving path
    results_output_dir = logger_kwargs['output_dir']
    checkpoint_dir = os.path.join(results_output_dir, 'pyt_save')
    os.makedirs(checkpoint_dir, exist_ok=True)

    logger = EpochLogger(**logger_kwargs)
    logger.save_config(locals())

    # Random seed
    torch.manual_seed(seed)
    np.random.seed(seed)

    #############################################
    #       Environment related meta data       #
    #############################################
    # Creat environment
    if env_id == "LAS-Meander":
        intl_env = LASIntlEnv(las_config)
    else:
        gym_env_obs_tile_num = gym_env_obs_tile
        gym_env_obs_tile_value = -1
        intl_env = IntlEnv(env_id, env_dp_type=env_dp_type, act_transform_type=env_act_transform_type, obs_delay_step=env_obs_delay_step,
                           render_width=640, render_height=480, seed=seed,
                           obs_tile_num=gym_env_obs_tile_num, obs_tile_value=gym_env_obs_tile_value)  # used to interact with the environment
        save_checkpoint_every_n_steps = 1000

    video_clip_length_in_steps = int(math.ceil(video_clip_length_in_seconds * intl_env.fps))
    max_ep_len = get_timesteps_per_episode(intl_env)

    obs_space = intl_env.observation_space
    act_space = intl_env.action_space
    obs_dim = intl_env.observation_space.shape[0]
    act_dim = intl_env.action_space.shape[0]

    #############################################
    #          Initialize Memory Manager        #
    #############################################
    if local_db_type == 'disk_db':
        local_db_config = {"drivername": "sqlite", "username": None, "password": None,
                           "database": "Step-0_Checkpoint_DB.sqlite3", "host": None, "port": None}
    elif local_db_type == 'in_memory_db':
        local_db_config = {"drivername": "sqlite"}
    else:
        raise ValueError("Wrong local_db_type: {}".format(local_db_type))
    cloud_db_config = {"drivername": "postgresql", "username": "postgres", "password": "mlhmlh",
                       "database": "postgres", "host": "127.0.0.1", "port": "54321"}
    mem_manager = DatabaseManager(local_db_config, cloud_db_config, checkpoint_dir)

    #############################################
    #          Pretrain reward function         #
    #############################################
    if rl_reward_type == "hc_reward":
        rew_comp = None
    elif rl_reward_type == "pb_reward":
        # Reward component provides the reward of the latest experience.
        rew_comp = RewardComponent(obs_dim, act_dim,
                                   reward_limit=reward_limit,
                                   reward_net_input_type=reward_net_input_type,
                                   reward_comp_type=reward_comp_type,
                                   reward_mem_length=video_clip_length_in_steps,
                                   reward_comp_drop_prob=reward_comp_drop_prob,
                                   checkpoint_dir=checkpoint_dir)

        # Collect preference labels
        if teacher_type == "synth_teacher":
            render_video = False
            video_dir = './test/tmp/teach'
            pretrain_segment_sample_workers = 1

            pretrain_agent_type = 'random'
            # pretrain_agent_type = 'mixed_agent'
            # pretrain_agent_type = 'TD3'
            pretrain_agent_checkpoint_dir = r'F:\scratch\lingheng\PL-Teaching-Data\2021-10-02_PL_TD3_HCReward\2021-10-02_18-10-46-PL_TD3_HCReward_s0\pyt_save\Step-1495999_Checkpoint_Agent_verified.pt'
            pretrain_agent_hyperparams = {'act_limit': 1, 'hidden_sizes': (256, 256), 'act_noise': 0.1}
            online_preferences_collection_method = "only_from_recent"# "maximum_distance_based"  # "maximum_distance_based"    # "one_from_recent_another_from_past"
            pref_collector = SyntheticPreferenceCollector(env=intl_env, env_make_fn=IntlEnv, env_id=env_id,
                                                          env_dp_type=env_dp_type,
                                                          act_transform_type=env_act_transform_type, obs_delay_step=env_obs_delay_step,
                                                          env_seed=seed,
                                                          mem_manager=mem_manager,
                                                          reward_component=rew_comp,
                                                          pretrain_label_num=pretrain_label_num,
                                                          total_label_num=total_label_num,
                                                          pretrain_agent_type=pretrain_agent_type,
                                                          pretrain_agent_checkpoint_dir=pretrain_agent_checkpoint_dir,
                                                          pretrain_agent_hyperparams=pretrain_agent_hyperparams,
                                                          online_preferences_collection_method=online_preferences_collection_method,
                                                          results_output_dir=results_output_dir,
                                                          pretrain_segment_sample_workers=pretrain_segment_sample_workers,
                                                          render_video=render_video,
                                                          video_clip_length_in_steps=video_clip_length_in_steps,
                                                          video_clip_dir=video_dir,
                                                          checkpoint_dir=checkpoint_dir)
        elif teacher_type == "human_teacher":
            pref_collector = HumanPreferenceCollector(env_id, 'test_human_preference')
            render_video = True
        else:
            raise ValueError("Wrong teacher_type was set!")

        # Pretrain reward component based on collected pretrain preference labels, which will be followed by
        # periodical preference collection and reward component training during policy learning.
        # TODO: epoch_num should be related to the number of preference labels.
        # stat = rew_comp.train(pref_collector.training_comp_dataset, pref_collector.test_comp_dataset, epoch_num=20, start_from_scratch=False)

    else:
        raise ValueError("Wrong reward_type was set!")

    #############################################
    #               Learning policy             #
    #############################################
    # Set proper reward component.
    intl_env.set_reward_component(rew_comp)

    if rl_agent == 'RandomAgent':
        agent = RandomAgent(obs_space, act_space, mem_manager=mem_manager, checkpoint_dir=checkpoint_dir)
    elif rl_agent == 'DDPG':
        agent = DDPG(obs_space, act_space, hidden_sizes,
                     gamma=gamma,
                     start_steps=start_steps,
                     update_after=update_after,
                     mem_manager=mem_manager,
                     recompute_reward_in_backup=recompute_reward_in_backup,
                     checkpoint_dir=checkpoint_dir)
    elif rl_agent == 'TD3':
        act_noise = 0.1
        agent = TD3(obs_space, act_space, hidden_sizes,
                    gamma=gamma,
                    start_steps=start_steps,
                    act_noise=act_noise,
                    update_after=update_after,
                    mem_manager=mem_manager,
                    recompute_reward_in_backup=recompute_reward_in_backup,
                    checkpoint_dir=checkpoint_dir)
        # act_tile__num = None
        # agent = TD3BC(obs_space, act_space, hidden_sizes, act_tile_num=act_tile__num,
        #             start_steps=start_steps,
        #             update_after=update_after,
        #             mem_manager=mem_manager,
        #             recompute_reward_in_backup=recompute_reward_in_backup,
        #             checkpoint_dir=checkpoint_dir)
    elif rl_agent == 'MTD3':
        agent = MTD3(obs_space, act_space, hidden_sizes,
                     gamma=gamma,
                    multistep_size=multistep_size,
                    start_steps=start_steps,
                    act_noise=act_noise,
                    update_after=update_after,
                    mem_manager=mem_manager,
                    recompute_reward_in_backup=recompute_reward_in_backup,
                    checkpoint_dir=checkpoint_dir)
    elif rl_agent == 'SAC':
        agent = SAC(obs_space, act_space, hidden_sizes,
                    gamma=gamma,
                    start_steps=start_steps,
                    update_after=update_after,
                    mem_manager=mem_manager,
                    recompute_reward_in_backup=recompute_reward_in_backup,
                    checkpoint_dir=checkpoint_dir)
    elif rl_agent == 'MSAC':
        agent = MSAC(obs_space, act_space, hidden_sizes,
                    gamma=gamma,
                    multistep_size=multistep_size,
                    start_steps=start_steps,
                    update_after=update_after,
                    mem_manager=mem_manager,
                    recompute_reward_in_backup=recompute_reward_in_backup,
                    checkpoint_dir=checkpoint_dir)
    elif rl_agent == 'PPO':
        agent = PPO(obs_space, act_space, hidden_sizes, gamma=gamma,
                    steps_per_epoch=steps_per_epoch, mem_manager=mem_manager, checkpoint_dir=checkpoint_dir)
    elif rl_agent =='LSTM-TD3':
        agent_mem_len = 5
        agent = LSTMTD3(obs_space, act_space, hidden_sizes,
                        gamma=gamma,
                        start_steps=start_steps,
                        update_after=update_after,
                        mem_manager=mem_manager,
                        recompute_reward_in_backup=recompute_reward_in_backup,
                        agent_mem_len=agent_mem_len,
                        checkpoint_dir=checkpoint_dir)
    elif rl_agent =='LSTM-MTD3':
        agent_mem_len = 5
        agent = LSTMMTD3(obs_space, act_space, hidden_sizes,
                         gamma=gamma,
                         multistep_size=multistep_size,
                         start_steps=start_steps,
                         update_after=update_after,
                         mem_manager=mem_manager,
                         recompute_reward_in_backup=recompute_reward_in_backup,
                         agent_mem_len=agent_mem_len,
                         checkpoint_dir=checkpoint_dir)

    # Prepare for interacting with the envs
    total_steps = steps_per_epoch * epochs
    start_time = time()
    past_steps = 0

    # Resume experiment
    if resume_exp_dir is not None:
        cp_files = os.listdir(checkpoint_dir)
        # Delete tmp generated during training reward component
        if "tmp_rew_comp_checkpoint.pt" in cp_files:
            os.remove(os.path.join(checkpoint_dir, "tmp_rew_comp_checkpoint.pt"))
        # Determine restore_version
        if rl_reward_type == "pb_reward" and len(cp_files) == 1 and 'Step-0_Checkpoint_DB' in cp_files[0]:
            # The case where pretraining preference label collection is still ongoing and the actual learning has not happened yet.
            # Restore mem_manager first, because it will be used to restore other components.
            mem_manager.restore_mem_checkpoint(time_step=0)

            # Restore 1. Preference Collector
            recent_segment_idxs = deque(maxlen=pref_collector.recent_segment_num)
            max_recent_seg_id = mem_manager.collected_seg_num
            min_recent_seg_id = 1 if mem_manager.collected_seg_num < pref_collector.recent_segment_num else (
                        mem_manager.collected_seg_num - pref_collector.recent_segment_num + 1)
            for recent_seg_id in range(min_recent_seg_id, max_recent_seg_id+1):
                recent_segment_idxs.append(recent_seg_id)
            pref_collector.restore_checkpoint({'recent_segment_idxs': recent_segment_idxs}, mem_manager)

            # If collected pretraining preferences, but has not trained reward component.
            if pref_collector.collected_pretraining_preferences:
                rew_comp.train(pref_collector.training_dataset, pref_collector.test_dataset)
                # update rew_comp of intl_env
                intl_env.set_reward_component(rew_comp)
        else:
            cp_version_dict = {}
            for cp_f in cp_files:
                if 'verified' not in cp_f:
                    # TODO: consider case where only pretraining segments are collected, but actual learning has not happened.
                    # Remove unverified checkpoint, where to remove db file created during the initialization of the mem_manage disconnect the db first.
                    if 'Step-0_Checkpoint_DB' in cp_f:
                        mem_manager.local_db_session.close()
                        mem_manager.local_db_engine.dispose()
                    os.remove(os.path.join(checkpoint_dir, cp_f))
                else:
                    cp_params = cp_f.split('_')    # checkpoint format: Step-xxx_Checkpoint_xxx_verified.pt
                    cp_param_version = int(cp_params[0].split('-')[-1])
                    cp_param_type = cp_params[2]
                    cp_param_verification = cp_params[3]
                    if cp_param_version not in cp_version_dict:
                        cp_version_dict[cp_param_version] = []
                    cp_version_dict[cp_param_version].append(cp_f)

            # Delete verified file that only one of the two checkpoints is verified.
            clean_cp_version_dict = {}
            for version in cp_version_dict:
                if len(cp_version_dict[version]) != 2:
                    os.remove(os.path.join(checkpoint_dir, cp_version_dict[version][0]))
                else:
                    clean_cp_version_dict[version] = cp_version_dict[version]
            # Select the latest version
            restore_version = np.max(list(clean_cp_version_dict.keys()))

            # Restore mem_manager first, because it will be used to restore other components.
            mem_manager.restore_mem_checkpoint(restore_version)

            # Restore 1. Global Context, 2. Preference Collector, 3. Reward Component, 4. Agent
            cp_elements = torch.load(os.path.join(checkpoint_dir, 'Step-{}_Checkpoint_Vars_verified.pt'.format(restore_version)))
            logger.epoch_dict = cp_elements["global_context_cp_elements"]['logger_epoch_dict']
            past_steps = cp_elements["global_context_cp_elements"]['t']+1  # add 1 step to t to avoid repeating
            if rl_reward_type == "pb_reward":
                pref_collector.restore_checkpoint(cp_elements["pref_coll_cp_elements"], mem_manager)
                rew_comp.restore_checkpoint(cp_elements["rew_comp_cp_elements"])
            agent.restore_checkpoint(cp_elements["agent_cp_elements"], mem_manager)

            # Set reward component to the restored one
            intl_env.set_reward_component(rew_comp)
        print('Resuming experiment succeed!')
        print('Resumed experiment will start from step {}.'.format(past_steps))

    # Collect pretrain labels and pretrain reward component
    if rl_reward_type == "pb_reward":
        if not pref_collector.collected_pretraining_preferences:
            pref_collector.collect_pretraining_preferences(rew_comp)
            rew_comp.train(pref_collector.training_dataset, pref_collector.test_dataset)
            # update rew_comp of intl_env
            intl_env.set_reward_component(rew_comp)
            # # update segment_pair_distance with the latest reward_component
            # mem_manager.update_segment_pair_distance(rew_comp)
        else:
            print('Pretraining preferences exists already!')

    new_obs, info = intl_env.reset()
    ep_log_dict = {}
    ep_log_dict['EpLen'], ep_log_dict['EpHCRet'], ep_log_dict['EpOrigHCRet'], ep_log_dict['EpPBRet'] = 0, 0, 0, 0
    if env_id == 'LAS-Meander':
        ep_log_dict['EpHC_0_1Ret'], ep_log_dict['EpHC_neg_1_1Ret'] = 0, 0
        ep_log_dict['EpHC_0_2Ret'], ep_log_dict['EpHC_neg_2_2Ret'] = 0, 0

    pb_rew, hc_rew, done, terminal = None, None, False, False
    steps_elapsed_after_last_checkpoint = 0
    _ = mem_manager.retrieve_last_experience_episode()    # Important: Call this function to reset episode start id

    # Start interacting with the environment
    for t in range(past_steps, total_steps):
        # Select action
        # if t % 10 == 0:
        #     print(t)
        if stochastic_env != 0:
            new_obs += stochastic_env * np.random.randn(obs_dim)

        act, logger = agent.interact(t, new_obs, pb_rew, hc_rew, done, info, terminal, rew_comp, logger)

        # Interact with the envs
        new_obs, pb_rew, done, info = intl_env.step(act)    # pb_rew: preference-based reward learned from preference
        hc_rew = info['extl_rew']                           # hc_rew: handcrafted reward predefined in original task
        orig_hc_rew = info['orig_rew']
        ep_log_dict['EpLen'] += 1
        ep_log_dict['EpHCRet'] += hc_rew
        ep_log_dict['EpOrigHCRet'] += orig_hc_rew
        ep_log_dict['EpPBRet'] += pb_rew
        if env_id == 'LAS-Meander':
            ep_log_dict['EpHC_0_1Ret'] += info['reward_range_0_pos_1']
            ep_log_dict['EpHC_neg_1_1Ret'] += info['reward_range_neg_1_pos_1']
            ep_log_dict['EpHC_0_2Ret'] += info['reward_range_0_pos_2']
            ep_log_dict['EpHC_neg_2_2Ret'] += info['reward_range_neg_2_pos_2']

        steps_elapsed_after_last_checkpoint += 1

        # End of trajectory handling
        terminal = done or (ep_log_dict['EpLen'] == max_ep_len)
        if terminal:
            # Call agent.interact() only for storing last experience.
            _, logger = agent.interact(t, new_obs, pb_rew, hc_rew, done, info, terminal, rew_comp, logger)

            # Log episodic stats
            logger.store(**ep_log_dict)

            # Reset env and logging variables
            # Note: close old env and regenerate new env is crucial to save memory consumption on
            #   Linux, as pybullet env continuously maintains past simulation status.
            if env_id == "LAS-Meander":
                ep_log_dict['EpHC_0_1Ret'], ep_log_dict['EpHC_neg_1_1Ret'] = 0, 0
                ep_log_dict['EpHC_0_2Ret'], ep_log_dict['EpHC_neg_2_2Ret'] = 0, 0
            else:
                intl_env.close()
                intl_env = IntlEnv(env_id, env_dp_type=env_dp_type, act_transform_type=env_act_transform_type, obs_delay_step=env_obs_delay_step,
                                   render_width=640, render_height=480, seed=seed,
                                   obs_tile_num=gym_env_obs_tile_num, obs_tile_value=gym_env_obs_tile_value)  # used to interact with the environment

            new_obs, info = intl_env.reset()
            ep_log_dict['EpLen'], ep_log_dict['EpHCRet'], ep_log_dict['EpOrigHCRet'], ep_log_dict['EpPBRet'] = 0, 0, 0, 0
            pb_rew, hc_rew, done, terminal = None, None, False, False

            # Collect segments from the latest episode and train reward component.
            rew_comp_start_time = time()
            if rl_reward_type == "pb_reward":
                # TODO:
                # Return last path for segment generating when terminal
                path = mem_manager.retrieve_last_experience_episode()

                # 2. Generate segments and comparison pairs, and collect preferences
                pref_collector.collect_online_preferences(path, t, total_steps, rew_comp)

                # 3. Train reward component every X steps and update rew_comp of intl_env
                if pref_collector._steps_since_last_training >= pref_collector._n_timesteps_per_predictor_training:
                    # train reward_component
                    rew_comp.train(pref_collector.training_dataset, pref_collector.test_dataset)
                    pref_collector._steps_since_last_training -= pref_collector._steps_since_last_training

                    # update rew_comp of intl_env
                    intl_env.set_reward_component(rew_comp)

                    # TODO: update_segment_pair_distance is too time-consuming
                    # # update segment_pair_distance with the latest reward_component
                    # mem_manager.update_segment_pair_distance(rew_comp)

            rew_comp_end_time = time()
            print('Preference Learning costs: {}s.'.format(rew_comp_end_time - rew_comp_start_time))

            # Store checkpoint at the end of trajectory, so there is no need to store env as resume env
            #       in PyBullet is problematic.
            #   Checkpoint list:
            #   1. global context; 2. preference collector; 3. reward component; 4. agent
            if steps_elapsed_after_last_checkpoint > save_checkpoint_every_n_steps:
                cp_start_time = time()
                old_checkpoints = os.listdir(checkpoint_dir)  # Cache old checkpoints to delete later

                # Save checkpoint for each component, and global context.
                cp_elements = {}
                if rl_reward_type == "pb_reward":
                    cp_elements["pref_coll_cp_elements"] = pref_collector.save_checkpoint()
                    cp_elements["rew_comp_cp_elements"] = rew_comp.save_checkpoint()
                cp_elements["agent_cp_elements"] = agent.save_checkpoint()
                cp_elements["global_context_cp_elements"] = {'logger_epoch_dict': logger.epoch_dict,
                                                             'start_time': start_time, 't': t}

                new_cp_file = os.path.join(checkpoint_dir, 'Step-{}_Checkpoint_Vars.pt'.format(t))
                torch.save(cp_elements, new_cp_file)
                # Rename the file to verify the completion of the saving in case of midway cutoff.
                new_verified_cp_file = os.path.join(checkpoint_dir,
                                                        'Step-{}_Checkpoint_Vars_verified.pt'.format(t))
                os.rename(new_cp_file, new_verified_cp_file)

                # Checkpoint: database
                mem_manager.save_mem_checkpoint(t)

                # Remove old checkpoint after saving latest checkpoint
                for old_f in old_checkpoints:
                    if os.path.exists(osp.join(checkpoint_dir, old_f)):
                        os.remove(osp.join(checkpoint_dir, old_f))
                cp_end_time = time()
                print('Saving checkpoint costs: {}s.'.format(cp_end_time-cp_start_time))
                steps_elapsed_after_last_checkpoint = 0

        # End of epoch handling
        # (Actually when t % steps_per_epoch == 0, it's already after the 1st step of next epoch, but the experience until (t-1) is just stored. This
        # compromise is specifically for PPO, because PPO needs all experiences in the last epoch to update its policy.)
        if t > 0 and t % steps_per_epoch == 0:
        # if (t+1) % steps_per_epoch == 0:
            epoch = (t + 1) // steps_per_epoch
            if rl_agent == 'RandomAgent':
                # Test the performance of the deterministic version of the agent.
                def test_agent(rew_comp, agent, logger):
                    # Crucial: pybullet env maintains variables which will not release memory if not close().
                    # Define env outside the loop, otherwise with the same seed the results will be the same.
                    if env_id == "LAS-Meander":
                        test_intl_env = intl_env  # For LAS-Meander, the ip and port are fixed, so only one intl_env can be created.
                        test_intl_env.set_reward_component(rew_comp)
                    else:
                        test_intl_env = IntlEnv(env_id, env_dp_type=env_dp_type, act_transform_type=env_act_transform_type, obs_delay_step=env_obs_delay_step,
                                                render_width=640, render_height=480,
                                                seed=seed, obs_tile_num=gym_env_obs_tile_num,
                                                obs_tile_value=gym_env_obs_tile_value)  # used to interact with the environment
                        test_intl_env.set_reward_component(rew_comp)
                    max_ep_len = get_timesteps_per_episode(test_intl_env)

                    for j in range(num_test_episodes):
                        obs, info = test_intl_env.reset()
                        done = False
                        test_ep_log_dict = {}
                        test_ep_log_dict['TestEpLen'], test_ep_log_dict['TestEpHCRet'], test_ep_log_dict['TestEpPBRet'] = 0, 0, 0
                        test_ep_log_dict['TestEpOrigHCRet'] = 0
                        if env_id == 'LAS-Meander':
                            test_ep_log_dict['TestEpHC_0_1Ret'], test_ep_log_dict['TestEpHC_neg_1_1Ret'] = 0, 0
                            test_ep_log_dict['TestEpHC_0_2Ret'], test_ep_log_dict['TestEpHC_neg_2_2Ret'] = 0, 0

                        while not (done or (test_ep_log_dict['TestEpLen'] == max_ep_len)):
                            # Take deterministic actions at test time (noise_scale=0)
                            act = agent.get_test_action(obs)
                            obs2, pb_rew, done, info = test_intl_env.step(
                                act)  # pb_rew: preference-based reward learned from preference
                            hc_rew = info['extl_rew']  # hc_rew: handcrafted reward predefined in original task
                            orig_hc_rew = info['orig_rew']

                            test_ep_log_dict['TestEpLen'] += 1
                            test_ep_log_dict['TestEpHCRet'] += hc_rew
                            test_ep_log_dict['TestEpOrigHCRet'] += orig_hc_rew
                            test_ep_log_dict['TestEpPBRet'] += pb_rew

                            if env_id == 'LAS-Meander':
                                test_ep_log_dict['TestEpHC_0_1Ret'] += info['reward_range_0_pos_1']
                                test_ep_log_dict['TestEpHC_neg_1_1Ret'] += info['reward_range_neg_1_pos_1']
                                test_ep_log_dict['TestEpHC_0_2Ret'] += info['reward_range_0_pos_2']
                                test_ep_log_dict['TestEpHC_neg_2_2Ret'] += info['reward_range_neg_2_pos_2']

                            obs = obs2

                        logger.store(**test_ep_log_dict)
                    if env_id == "LAS-Meander":
                        pass
                    else:
                        test_intl_env.close()
                    return logger

                logger = test_agent(rew_comp, agent, logger=logger)

                # Log info about epoch
                logger.log_tabular('Epoch', epoch)
                logger.log_tabular('EpHCRet', with_min_and_max=True)
                logger.log_tabular('TestEpHCRet', with_min_and_max=True)
                logger.log_tabular('EpOrigHCRet', with_min_and_max=True)
                logger.log_tabular('TestEpOrigHCRet', with_min_and_max=True)
                logger.log_tabular('EpPBRet', with_min_and_max=True)
                logger.log_tabular('TestEpPBRet', with_min_and_max=True)
                logger.log_tabular('EpLen', average_only=True)
                logger.log_tabular('TestEpLen', average_only=True)
                logger.log_tabular('TotalEnvInteracts', t)
                if env_id == 'LAS-Meander':
                    logger.log_tabular('EpHC_0_1Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_neg_1_1Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_0_2Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_neg_2_2Ret', with_min_and_max=True)

                    logger.log_tabular('TestEpHC_0_1Ret', with_min_and_max=True)
                    logger.log_tabular('TestEpHC_neg_1_1Ret', with_min_and_max=True)
                    logger.log_tabular('TestEpHC_0_2Ret', with_min_and_max=True)
                    logger.log_tabular('TestEpHC_neg_2_2Ret', with_min_and_max=True)
                logger.log_tabular('Time', time() - start_time)
                logger.dump_tabular()
            elif rl_agent == 'DDPG':
                # Test the performance of the deterministic version of the agent.
                def test_agent(rew_comp, agent, logger):
                    # Crucial: pybullet env maintains variables which will not release memory if not close().
                    # Define env outside the loop, otherwise with the same seed the results will be the same.
                    if env_id == "LAS-Meander":
                        test_intl_env = intl_env    # For LAS-Meander, the ip and port are fixed, so only one intl_env can be created.
                        test_intl_env.set_reward_component(rew_comp)
                    else:
                        test_intl_env = IntlEnv(env_id, env_dp_type=env_dp_type, act_transform_type=env_act_transform_type, obs_delay_step=env_obs_delay_step,
                                                render_width=640, render_height=480,
                                                seed=seed, obs_tile_num=gym_env_obs_tile_num, obs_tile_value=gym_env_obs_tile_value)  # used to interact with the environment
                        test_intl_env.set_reward_component(rew_comp)
                    max_ep_len = get_timesteps_per_episode(test_intl_env)

                    for j in range(num_test_episodes):
                        obs, info = test_intl_env.reset()
                        done = False
                        test_ep_log_dict = {}
                        test_ep_log_dict['TestEpLen'], test_ep_log_dict['TestEpHCRet'], test_ep_log_dict['TestEpPBRet'] = 0, 0, 0
                        test_ep_log_dict['TestEpOrigHCRet'] = 0
                        if env_id == 'LAS-Meander':
                            test_ep_log_dict['TestEpHC_0_1Ret'], test_ep_log_dict['TestEpHC_neg_1_1Ret'] = 0, 0
                            test_ep_log_dict['TestEpHC_0_2Ret'], test_ep_log_dict['TestEpHC_neg_2_2Ret'] = 0, 0

                        while not (done or (test_ep_log_dict['TestEpLen'] == max_ep_len)):
                            # Take deterministic actions at test time (noise_scale=0)
                            act = agent.get_test_action(obs)
                            obs2, pb_rew, done, info = test_intl_env.step(
                                act)  # pb_rew: preference-based reward learned from preference
                            hc_rew = info['extl_rew']  # hc_rew: handcrafted reward predefined in original task
                            orig_hc_rew = info['orig_rew']

                            test_ep_log_dict['TestEpLen'] += 1
                            test_ep_log_dict['TestEpHCRet'] += hc_rew
                            test_ep_log_dict['TestEpOrigHCRet'] += orig_hc_rew
                            test_ep_log_dict['TestEpPBRet'] += pb_rew

                            if env_id == 'LAS-Meander':
                                test_ep_log_dict['TestEpHC_0_1Ret'] += info['reward_range_0_pos_1']
                                test_ep_log_dict['TestEpHC_neg_1_1Ret'] += info['reward_range_neg_1_pos_1']
                                test_ep_log_dict['TestEpHC_0_2Ret'] += info['reward_range_0_pos_2']
                                test_ep_log_dict['TestEpHC_neg_2_2Ret'] += info['reward_range_neg_2_pos_2']

                            obs = obs2

                        logger.store(**test_ep_log_dict)
                    if env_id == "LAS-Meander":
                        pass
                    else:
                        test_intl_env.close()
                    return logger
                logger = test_agent(rew_comp, agent, logger=logger)

                # Log info about epoch
                logger.log_tabular('Epoch', epoch)
                logger.log_tabular('EpHCRet', with_min_and_max=True)
                logger.log_tabular('TestEpHCRet', with_min_and_max=True)
                logger.log_tabular('EpOrigHCRet', with_min_and_max=True)
                logger.log_tabular('TestEpOrigHCRet', with_min_and_max=True)
                logger.log_tabular('EpPBRet', with_min_and_max=True)
                logger.log_tabular('TestEpPBRet', with_min_and_max=True)
                logger.log_tabular('EpLen', average_only=True)
                logger.log_tabular('TestEpLen', average_only=True)
                logger.log_tabular('TotalEnvInteracts', t)
                if env_id == 'LAS-Meander':
                    logger.log_tabular('EpHC_0_1Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_neg_1_1Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_0_2Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_neg_2_2Ret', with_min_and_max=True)

                    logger.log_tabular('TestEpHC_0_1Ret', with_min_and_max=True)
                    logger.log_tabular('TestEpHC_neg_1_1Ret', with_min_and_max=True)
                    logger.log_tabular('TestEpHC_0_2Ret', with_min_and_max=True)
                    logger.log_tabular('TestEpHC_neg_2_2Ret', with_min_and_max=True)
                logger.log_tabular('QVals', with_min_and_max=True)
                logger.log_tabular('LossPi', average_only=True)
                logger.log_tabular('LossQ', average_only=True)
                logger.log_tabular('Time', time() - start_time)
                logger.dump_tabular()
            elif rl_agent == 'TD3' or rl_agent == 'MTD3':
                # Test the performance of the deterministic version of the agent.
                def test_agent(rew_comp, agent, logger):
                    # Crucial: pybullet env maintains variables which will not release memory if not close().
                    # Define env outside the loop, otherwise with the same seed the results will be the same.
                    if env_id == "LAS-Meander":
                        test_intl_env = intl_env    # For LAS-Meander, the ip and port are fixed, so only one intl_env can be created.

                    else:
                        test_intl_env = IntlEnv(env_id, env_dp_type=env_dp_type, act_transform_type=env_act_transform_type, obs_delay_step=env_obs_delay_step,
                                                render_width=640, render_height=480,
                                                seed=seed, obs_tile_num=gym_env_obs_tile_num, obs_tile_value=gym_env_obs_tile_value)  # used to interact with the environment
                    test_intl_env.set_reward_component(rew_comp)
                    max_ep_len = get_timesteps_per_episode(test_intl_env)

                    for j in range(num_test_episodes):
                        obs, info = test_intl_env.reset()
                        done = False
                        test_ep_log_dict = {}
                        test_ep_log_dict['TestEpLen'], test_ep_log_dict['TestEpHCRet'], test_ep_log_dict['TestEpPBRet'] = 0, 0, 0
                        test_ep_log_dict['TestEpOrigHCRet'] = 0
                        if env_id == 'LAS-Meander':
                            test_ep_log_dict['TestEpHC_0_1Ret'], test_ep_log_dict['TestEpHC_neg_1_1Ret'] = 0, 0
                            test_ep_log_dict['TestEpHC_0_2Ret'], test_ep_log_dict['TestEpHC_neg_2_2Ret'] = 0, 0

                        while not (done or (test_ep_log_dict['TestEpLen'] == max_ep_len)):
                            # Take deterministic actions at test time (noise_scale=0)
                            act = agent.get_test_action(obs)
                            obs2, pb_rew, done, info = test_intl_env.step(act)  # pb_rew: preference-based reward learned from preference
                            hc_rew = info['extl_rew']  # hc_rew: handcrafted reward predefined in original task
                            orig_hc_rew = info['orig_rew']

                            test_ep_log_dict['TestEpLen'] += 1
                            test_ep_log_dict['TestEpHCRet'] += hc_rew
                            test_ep_log_dict['TestEpOrigHCRet'] += orig_hc_rew
                            test_ep_log_dict['TestEpPBRet'] += pb_rew
                            if env_id == 'LAS-Meander':
                                test_ep_log_dict['TestEpHC_0_1Ret'] += info['reward_range_0_pos_1']
                                test_ep_log_dict['TestEpHC_neg_1_1Ret'] += info['reward_range_neg_1_pos_1']
                                test_ep_log_dict['TestEpHC_0_2Ret'] += info['reward_range_0_pos_2']
                                test_ep_log_dict['TestEpHC_neg_2_2Ret'] += info['reward_range_neg_2_pos_2']

                            obs = obs2

                        logger.store(**test_ep_log_dict)
                    if env_id == "LAS-Meander":
                        pass
                    else:
                        test_intl_env.close()
                    return logger
                logger = test_agent(rew_comp, agent, logger=logger)

                # Log info about epoch
                logger.log_tabular('Epoch', epoch)
                logger.log_tabular('EpHCRet', with_min_and_max=True)
                logger.log_tabular('TestEpHCRet', with_min_and_max=True)
                logger.log_tabular('EpOrigHCRet', with_min_and_max=True)
                logger.log_tabular('TestEpOrigHCRet', with_min_and_max=True)
                logger.log_tabular('EpPBRet', with_min_and_max=True)
                logger.log_tabular('TestEpPBRet', with_min_and_max=True)
                logger.log_tabular('EpLen', average_only=True)
                logger.log_tabular('TestEpLen', average_only=True)
                logger.log_tabular('TotalEnvInteracts', t)

                if env_id == 'LAS-Meander':
                    logger.log_tabular('EpHC_0_1Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_neg_1_1Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_0_2Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_neg_2_2Ret', with_min_and_max=True)

                    logger.log_tabular('TestEpHC_0_1Ret', with_min_and_max=True)
                    logger.log_tabular('TestEpHC_neg_1_1Ret', with_min_and_max=True)
                    logger.log_tabular('TestEpHC_0_2Ret', with_min_and_max=True)
                    logger.log_tabular('TestEpHC_neg_2_2Ret', with_min_and_max=True)

                logger.log_tabular('Q1Vals', with_min_and_max=True)
                logger.log_tabular('Q2Vals', with_min_and_max=True)
                logger.log_tabular('LossPi', average_only=True)
                logger.log_tabular('LossQ', average_only=True)
                logger.log_tabular('Time', time() - start_time)
                logger.dump_tabular()
            elif rl_agent == 'SAC' or rl_agent == 'MSAC':
                def test_agent(rew_comp, agent, logger):
                    # Crucial: pybullet env maintains variables which will not release memory if not close().
                    # Define env outside the loop, otherwise with the same seed the results will be the same.
                    if env_id == "LAS-Meander":
                        test_intl_env = intl_env  # For LAS-Meander, the ip and port are fixed, so only one intl_env can be created.
                        test_intl_env.set_reward_component(rew_comp)
                    else:
                        test_intl_env = IntlEnv(env_id, env_dp_type=env_dp_type, act_transform_type=env_act_transform_type, obs_delay_step=env_obs_delay_step,
                                                render_width=640, render_height=480,
                                                seed=seed, obs_tile_num=gym_env_obs_tile_num, obs_tile_value=gym_env_obs_tile_value)  # used to interact with the environment
                        test_intl_env.set_reward_component(rew_comp)
                    max_ep_len = get_timesteps_per_episode(test_intl_env)

                    for j in range(num_test_episodes):
                        obs, info = test_intl_env.reset()
                        done = False
                        test_ep_log_dict = {}
                        test_ep_log_dict['TestEpLen'], test_ep_log_dict['TestEpHCRet'], test_ep_log_dict['TestEpPBRet'] = 0, 0, 0
                        test_ep_log_dict['TestEpOrigHCRet'] = 0
                        if env_id == 'LAS-Meander':
                            test_ep_log_dict['TestEpHC_0_1Ret'], test_ep_log_dict['TestEpHC_neg_1_1Ret'] = 0, 0
                            test_ep_log_dict['TestEpHC_0_2Ret'], test_ep_log_dict['TestEpHC_neg_2_2Ret'] = 0, 0

                        while not (done or (test_ep_log_dict['TestEpLen'] == max_ep_len)):
                            # Take deterministic actions at test time (noise_scale=0)
                            act = agent.get_test_action(obs)
                            obs2, pb_rew, done, info = test_intl_env.step(act)  # pb_rew: preference-based reward learned from preference
                            hc_rew = info['extl_rew']  # hc_rew: handcrafted reward predefined in original task
                            orig_hc_rew = info['orig_rew']

                            test_ep_log_dict['TestEpLen'] += 1
                            test_ep_log_dict['TestEpHCRet'] += hc_rew
                            test_ep_log_dict['TestEpOrigHCRet'] += orig_hc_rew
                            test_ep_log_dict['TestEpPBRet'] += pb_rew
                            if env_id == 'LAS-Meander':
                                test_ep_log_dict['TestEpHC_0_1Ret'] += info['reward_range_0_pos_1']
                                test_ep_log_dict['TestEpHC_neg_1_1Ret'] += info['reward_range_neg_1_pos_1']
                                test_ep_log_dict['TestEpHC_0_2Ret'] += info['reward_range_0_pos_2']
                                test_ep_log_dict['TestEpHC_neg_2_2Ret'] += info['reward_range_neg_2_pos_2']

                            obs = obs2
                        logger.store(**test_ep_log_dict)
                    if env_id == "LAS-Meander":
                        pass
                    else:
                        test_intl_env.close()
                    return logger

                logger = test_agent(rew_comp, agent, logger=logger)
                # Log info about epoch
                logger.log_tabular('Epoch', epoch)
                logger.log_tabular('EpHCRet', with_min_and_max=True)
                logger.log_tabular('TestEpHCRet', with_min_and_max=True)
                logger.log_tabular('EpOrigHCRet', with_min_and_max=True)
                logger.log_tabular('TestEpOrigHCRet', with_min_and_max=True)
                logger.log_tabular('EpPBRet', with_min_and_max=True)
                logger.log_tabular('TestEpPBRet', with_min_and_max=True)
                logger.log_tabular('EpLen', average_only=True)
                logger.log_tabular('TestEpLen', average_only=True)
                logger.log_tabular('TotalEnvInteracts', t)
                if env_id == 'LAS-Meander':
                    logger.log_tabular('EpHC_0_1Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_neg_1_1Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_0_2Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_neg_2_2Ret', with_min_and_max=True)

                    logger.log_tabular('TestEpHC_0_1Ret', with_min_and_max=True)
                    logger.log_tabular('TestEpHC_neg_1_1Ret', with_min_and_max=True)
                    logger.log_tabular('TestEpHC_0_2Ret', with_min_and_max=True)
                    logger.log_tabular('TestEpHC_neg_2_2Ret', with_min_and_max=True)
                logger.log_tabular('Q1Vals', with_min_and_max=True)
                logger.log_tabular('Q2Vals', with_min_and_max=True)
                logger.log_tabular('LogPi', with_min_and_max=True)
                logger.log_tabular('LossPi', average_only=True)
                logger.log_tabular('LossQ', average_only=True)
                logger.log_tabular('Time', time() - start_time)
                logger.dump_tabular()
            elif rl_agent == 'PPO':
                # Log info about epoch
                logger.log_tabular('Epoch', epoch)
                logger.log_tabular('EpHCRet', with_min_and_max=True)
                logger.log_tabular('EpOrigHCRet', with_min_and_max=True)
                logger.log_tabular('EpPBRet', with_min_and_max=True)
                logger.log_tabular('EpLen', average_only=True)
                if env_id == 'LAS-Meander':
                    logger.log_tabular('EpHC_0_1Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_neg_1_1Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_0_2Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_neg_2_2Ret', with_min_and_max=True)
                logger.log_tabular('VVals', with_min_and_max=True)
                logger.log_tabular('TotalEnvInteracts', t)
                logger.log_tabular('LossPi', average_only=True)
                logger.log_tabular('LossV', average_only=True)
                logger.log_tabular('DeltaLossPi', average_only=True)
                logger.log_tabular('DeltaLossV', average_only=True)
                logger.log_tabular('Entropy', average_only=True)
                logger.log_tabular('KL', average_only=True)
                logger.log_tabular('ClipFrac', average_only=True)
                logger.log_tabular('StopIter', average_only=True)
                logger.log_tabular('Time', time() - start_time)
                logger.dump_tabular()
            elif rl_agent == 'LSTM-TD3' or rl_agent == 'LSTM-MTD3':
                def test_agent(rew_comp, agent, logger):
                    # Crucial: pybullet env maintains variables which will not release memory if not close().
                    # Define env outside the loop, otherwise with the same seed the results will be the same.
                    if env_id == "LAS-Meander":
                        test_intl_env = intl_env  # For LAS-Meander, the ip and port are fixed, so only one intl_env can be created.
                        test_intl_env.set_reward_component(rew_comp)
                    else:
                        test_intl_env = IntlEnv(env_id, env_dp_type=env_dp_type, act_transform_type=env_act_transform_type, obs_delay_step=env_obs_delay_step,
                                                render_width=640, render_height=480,
                                                seed=seed, obs_tile_num=gym_env_obs_tile_num,
                                                obs_tile_value=gym_env_obs_tile_value)  # used to interact with the environment
                        test_intl_env.set_reward_component(rew_comp)
                    max_ep_len = get_timesteps_per_episode(test_intl_env)

                    for j in range(num_test_episodes):
                        obs, info = test_intl_env.reset()
                        done = False
                        test_ep_log_dict = {}
                        test_ep_log_dict['TestEpLen'], test_ep_log_dict['TestEpHCRet'], test_ep_log_dict['TestEpPBRet'] = 0, 0, 0
                        test_ep_log_dict['TestEpOrigHCRet'] = 0
                        if env_id == 'LAS-Meander':
                            test_ep_log_dict['TestEpHC_0_1Ret'], test_ep_log_dict['TestEpHC_neg_1_1Ret'] = 0, 0
                            test_ep_log_dict['TestEpHC_0_2Ret'], test_ep_log_dict['TestEpHC_neg_2_2Ret'] = 0, 0

                        if agent_mem_len > 0:
                            o_buff = np.zeros([agent_mem_len, obs_dim])
                            a_buff = np.zeros([agent_mem_len, act_dim])
                            o_buff[0, :] = obs
                            o_buff_len = 0
                        else:
                            o_buff = np.zeros([1, obs_dim])
                            a_buff = np.zeros([1, act_dim])
                            o_buff_len = 0

                        while not (done or (test_ep_log_dict['TestEpLen'] == max_ep_len)):
                            # Take deterministic actions at test time (noise_scale=0)
                            act = agent.get_test_action(obs, o_buff, a_buff, o_buff_len)
                            obs2, pb_rew, done, info = test_intl_env.step(
                                act)  # pb_rew: preference-based reward learned from preference
                            hc_rew = info['extl_rew']  # hc_rew: handcrafted reward predefined in original task
                            orig_hc_rew = info['orig_rew']

                            test_ep_log_dict['TestEpLen'] += 1
                            test_ep_log_dict['TestEpHCRet'] += hc_rew
                            test_ep_log_dict['TestEpOrigHCRet'] += orig_hc_rew
                            test_ep_log_dict['TestEpPBRet'] += pb_rew
                            if env_id == 'LAS-Meander':
                                test_ep_log_dict['TestEpHC_0_1Ret'] += info['reward_range_0_pos_1']
                                test_ep_log_dict['TestEpHC_neg_1_1Ret'] += info['reward_range_neg_1_pos_1']
                                test_ep_log_dict['TestEpHC_0_2Ret'] += info['reward_range_0_pos_2']
                                test_ep_log_dict['TestEpHC_neg_2_2Ret'] += info['reward_range_neg_2_pos_2']

                            # Add short history
                            if agent_mem_len != 0:
                                if o_buff_len == agent_mem_len:
                                    o_buff[:agent_mem_len - 1] = o_buff[1:]
                                    a_buff[:agent_mem_len - 1] = a_buff[1:]
                                    o_buff[agent_mem_len - 1] = list(obs)
                                    a_buff[agent_mem_len - 1] = list(act)
                                else:
                                    o_buff[o_buff_len + 1 - 1] = list(obs)
                                    a_buff[o_buff_len + 1 - 1] = list(act)
                                    o_buff_len += 1

                            obs = obs2

                        logger.store(**test_ep_log_dict)
                    if env_id == "LAS-Meander":
                        pass
                    else:
                        test_intl_env.close()
                    return logger
                logger = test_agent(rew_comp, agent, logger=logger)

                # Log info about epoch
                logger.log_tabular('Epoch', epoch)
                logger.log_tabular('EpHCRet', with_min_and_max=True)
                logger.log_tabular('TestEpHCRet', with_min_and_max=True)
                logger.log_tabular('EpOrigHCRet', with_min_and_max=True)
                logger.log_tabular('TestEpOrigHCRet', with_min_and_max=True)
                logger.log_tabular('EpPBRet', with_min_and_max=True)
                logger.log_tabular('TestEpPBRet', with_min_and_max=True)
                logger.log_tabular('EpLen', average_only=True)
                logger.log_tabular('TestEpLen', average_only=True)
                logger.log_tabular('TotalEnvInteracts', t)

                if env_id == 'LAS-Meander':
                    logger.log_tabular('EpHC_0_1Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_neg_1_1Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_0_2Ret', with_min_and_max=True)
                    logger.log_tabular('EpHC_neg_2_2Ret', with_min_and_max=True)

                    logger.log_tabular('TestEpHC_0_1Ret', with_min_and_max=True)
                    logger.log_tabular('TestEpHC_neg_1_1Ret', with_min_and_max=True)
                    logger.log_tabular('TestEpHC_0_2Ret', with_min_and_max=True)
                    logger.log_tabular('TestEpHC_neg_2_2Ret', with_min_and_max=True)

                logger.log_tabular('Q1Vals', with_min_and_max=True)
                logger.log_tabular('Q2Vals', with_min_and_max=True)
                logger.log_tabular('LossPi', average_only=True)
                logger.log_tabular('LossQ', average_only=True)
                logger.log_tabular('Time', time() - start_time)
                logger.dump_tabular()
            else:
                raise ValueError('Agent type {} is not implemented!'.format(rl_agent))


def str2bool(v):
    """Function used in argument parser for converting string to bool."""
    if isinstance(v, bool):
        return v
    if v.lower() in ('yes', 'true', 't', 'y', '1'):
        return True
    elif v.lower() in ('no', 'false', 'f', 'n', '0'):
        return False
    else:
        raise argparse.ArgumentTypeError('Boolean value expected.')


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    # If resume experiment, this is the only argument required.
    parser.add_argument('--resume_exp_dir', type=str, default=None, help="The directory of the resuming experiment.")

    # Environment related hyperparams
    parser.add_argument('--env_id', type=str, default='HalfCheetahBulletEnv-v0')
    parser.add_argument('--env_dp_type', choices=['MDP', 'POMDP-RV', 'POMDP-FLK', 'POMDP-RN', 'POMDP-RSM'], default='MDP')
    parser.add_argument('--flicker_prob', type=float, default=0.2)
    parser.add_argument('--random_noise_sigma', type=float, default=0.1)
    parser.add_argument('--random_sensor_missing_prob', type=float, default=0.1)
    parser.add_argument('--env_act_transform_type', choices=['neg', 'tanh', 'sign_square', 'abs_times_2_minus_1', 'neg_abs_times_2_plus_1', 'random'],
                        default=None)
    parser.add_argument('--env_obs_delay_step', type=int, default=None)
    parser.add_argument('--gym_env_obs_tile', type=int, default=1, help="How many times to tile the observation (Only used in Gym tasks)")
    parser.add_argument('--stochastic_env', type=float, default=0)
    parser.add_argument('--las_config', type=str, default='', help="Specify path to LAS config file. If empty, default configuration will be employed.")

    # Preference teaching related hyperparams
    parser.add_argument('--total_label_num', type=int, default=14000)
    parser.add_argument('--pretrain_label_num', type=int, default=700)
    parser.add_argument('--teacher_type', type=str,
                        choices=['human_teacher', 'synth_teacher'],
                        default='synth_teacher')
    parser.add_argument('--video_clip_length_in_seconds', type=float, default=1.5, help='video clip length in second')
    parser.add_argument('--local_db_type', type=str, choices=['disk_db', 'in_memory_db', 'RAM'], default='in_memory_db')

    parser.add_argument('--reward_comp_type', type=str, choices=['MLP', 'LSTM'], default='MLP')
    parser.add_argument('--reward_net_input_type', type=str, choices=['obs_act_obs2', 'obs_act', 'obs2'], default='obs_act_obs2')
    parser.add_argument('--reward_limit', type=float, default=1)
    parser.add_argument('--reward_comp_drop_prob', type=float, default=0.5)

    # RL-agent related hyperparams
    parser.add_argument('--rl_reward_type', type=str,
                        choices=['hc_reward', 'pb_reward'],
                        default='pb_reward')
    parser.add_argument('--rl_agent', type=str, choices=['RandomAgent', 'DDPG', 'TD3', 'MTD3', 'SAC', 'MSAC', 'PPO', 'LSTM-TD3', 'LSTM-MTD3'], default='TD3')
    parser.add_argument('--hidden_layer', type=int, default=2)
    parser.add_argument('--hidden_units', type=int, default=256)
    parser.add_argument('--gamma', type=float, default=0.99)
    parser.add_argument('--multistep_size', type=int, default = 5)
    parser.add_argument('--recompute_reward_in_backup', type=str2bool, nargs='?', const=True, default=True)
    parser.add_argument('--replay_buff_type', type=str, choices=['RAM', 'DB'], default='RAM')
    #
    parser.add_argument('--seed', type=int, default=0)
    parser.add_argument('--epochs', type=int, default=2000)
    parser.add_argument('--exp_name', type=str, default='td3')

    parser.add_argument("--data_dir", type=str, default='F:/PL-Teaching-Data', help="Provide either absolute or relative path to "
                                                                                                   "the directory where data is saving to.")

    args = parser.parse_args()

    # Load las_intl_env_config if specified.
    if args.las_config:
        print("las_intl_env_config is specified to {}".format(args.las_config))
        las_config_spec = importlib.util.spec_from_file_location(las_config.__name__, args.las_config)
        las_config = importlib.util.module_from_spec(las_config_spec)
        las_config_spec.loader.exec_module(las_config)
    else:
        print("No las_intl_env_config is specified! The default configuration will be employed!")

    # Format hidden_sizes as a list of hidden_units
    hidden_sizes = [args.hidden_units for _ in range(args.hidden_layer)]

    # Set log data saving directory
    if args.resume_exp_dir is None:
        data_dir = os.path.abspath(args.data_dir)
        print("Saving data to {}".format(data_dir))
        if not os.path.exists(data_dir):
            os.makedirs(data_dir)
        logger_kwargs = setup_logger_kwargs(args.exp_name, args.seed, data_dir, datestamp=True)
    else:
        if os.path.exists(args.resume_exp_dir):
            # Load config_json
            resume_exp_dir = args.resume_exp_dir
            config_path = osp.join(args.resume_exp_dir, 'config.json')
            with open(osp.join(args.resume_exp_dir, "config.json"), 'r') as config_file:
                config_json = json.load(config_file)
            # Update resume_exp_dir value as default is None.
            config_json['resume_exp_dir'] = resume_exp_dir
            # Print config_json
            output = json.dumps(config_json, separators=(',', ':\t'), indent=4, sort_keys=True)
            print(colorize('Loading config:\n', color='cyan', bold=True))
            print(output)
            # Restore the hyper-parameters
            logger_kwargs = config_json["logger_kwargs"]                        # Restore logger_kwargs
            config_json['logger_kwargs']['output_dir'] = args.resume_exp_dir    # Reset output dir to given resume dir
            config_json.pop('logger', None)                                     # Remove logger from config_json
            args = json.loads(json.dumps(config_json), object_hook=lambda d: namedtuple('args', d.keys())(*d.values()))
            hidden_sizes = args.hidden_sizes
        else:
            raise ValueError('Resume dir {} does not exist!')

    # Start preference teaching
    preference_teaching(env_id=args.env_id, env_dp_type=args.env_dp_type,
                        env_act_transform_type=args.env_act_transform_type, env_obs_delay_step=args.env_obs_delay_step, seed=args.seed,
                        gym_env_obs_tile=args.gym_env_obs_tile, stochastic_env=args.stochastic_env,
                        epochs=args.epochs,
                        rl_reward_type=args.rl_reward_type,
                        rl_agent=args.rl_agent,
                        hidden_sizes=hidden_sizes,
                        gamma=args.gamma,
                        multistep_size=args.multistep_size,
                        recompute_reward_in_backup=args.recompute_reward_in_backup,
                        replay_buff_type=args.replay_buff_type,
                        reward_comp_type=args.reward_comp_type,
                        reward_net_input_type=args.reward_net_input_type,
                        reward_limit=args.reward_limit,
                        reward_comp_drop_prob=args.reward_comp_drop_prob,
                        pretrain_label_num=args.pretrain_label_num, total_label_num=args.total_label_num,
                        video_clip_length_in_seconds=args.video_clip_length_in_seconds,
                        teacher_type=args.teacher_type,
                        local_db_type=args.local_db_type,
                        resume_exp_dir=args.resume_exp_dir,
                        logger_kwargs=logger_kwargs)
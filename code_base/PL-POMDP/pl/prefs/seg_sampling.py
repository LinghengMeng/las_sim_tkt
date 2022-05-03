# import gym.spaces.prng as space_prng

from pl.envs.env import get_timesteps_per_episode
import numpy as np


# def _slice_path(path, segment_length, start_pos=0):
#     seg = {'seg_len': segment_length}
#     for key, val in path.items():
#         if key in ['obs_traj', "act_traj", 'obs2_traj', 'orig_rew_traj', 'done_traj', 'human_obs_traj']:
#             seg[key] = np.asarray(val[start_pos:(start_pos + segment_length)])
#     return seg


# def create_segment_q_states(segment):
#     obs_Ds = segment["obs"]
#     act_Ds = segment["actions"]
#     return np.concatenate([obs_Ds, act_Ds], axis=1)


def sample_segment_from_path(path, segment_length):
    """Returns a segment sampled from a random place in a path. Returns None if the path is too short"""
    path_length = len(path["exp_id_traj"])
    if path_length < segment_length:
        print('path_length < segment_length')
        return None
    else:
        start_pos = np.random.randint(path["exp_id_traj"][0], path["exp_id_traj"][-1] - segment_length + 1)

        # Build segment
        segment = {'seg_start_id': start_pos, 'seg_end_id': start_pos + segment_length - 1,
                   'seg_len': segment_length, 'behavior_mode': path['behavior_mode'],
                   'human_obs_traj': path['human_obs_traj'][start_pos-path["exp_id_traj"][0]: start_pos-path["exp_id_traj"][0]+ segment_length]}
        return segment


def random_action(env, obs):
    """ Pick an action by uniformly sampling the environment's action space. """
    return env.action_space.sample()


def do_rollout(env, pl_pretrain_agent, memory_manager=None):
    """ Builds a path by running through an environment using a provided function to select actions. """
    if memory_manager is None:
        raise ValueError("memory_manager is None!")

    max_timesteps_per_episode = get_timesteps_per_episode(env)

    obs, info = env.reset()
    obs_time = info['obs_datetime']
    start_exp_id = memory_manager.get_latest_experience_id()+1
    human_obs_traj = []

    # Primary environment loop
    for i in range(max_timesteps_per_episode):
        # Interact with the environment
        act = pl_pretrain_agent.act(obs)
        obs2, rew, done, info = env.step(act)

        # Add experience to memory
        if env.rew_comp is not None:
            pb_rew = rew
            hc_rew = info['extl_rew']
        else:
            pb_rew = None
            hc_rew = info['extl_rew']
        memory_manager.store_experience(obs, act, obs2, pb_rew, hc_rew, done, behavior_mode=pl_pretrain_agent.pretrain_agent_name,
                                        obs_time=obs_time, act_time=info['act_datetime'], obs2_time=info['obs_datetime'])
        human_obs_traj.append(info.get("human_obs"))

        obs = obs2  # Crucial to set obs to obs2
        obs_time = info['obs_datetime']

        terminal = done or (i == max_timesteps_per_episode-1)
        if terminal:
            memory_manager.commit()
            end_exp_id = memory_manager.get_latest_experience_id()
            break

    # Build and return trajectory dictionary
    return {"exp_id_traj": np.arange(start_exp_id, end_exp_id + 1),
            "human_obs_traj": human_obs_traj, "behavior_mode": pl_pretrain_agent.pretrain_agent_name}


def basic_segments_from_rollout(env,
                                pl_pretrain_agent, memory_manager, reward_component,
                                render_video, video_dir, worker_id,
                                n_desired_segments, video_clip_length_in_steps,
                                # These are only for use with multiprocessing
                                seed=0, _verbose=True, _multiplier=1, **env_params):
    """ Generate a list of path segments by doing random rollouts. No multiprocessing. """

    print('Start basic segmentation!')
    segments = []
    segment_num = 0

    while segment_num < n_desired_segments:
        env.set_reward_component(reward_component)

        # Random rollout
        path = do_rollout(env, pl_pretrain_agent, memory_manager=memory_manager)

        # Calculate the number of segments to sample from the path
        # Such that the probability of sampling the same part twice is fairly low.
        segments_for_this_path = max(1, int(0.25 * len(path["exp_id_traj"]) / video_clip_length_in_steps))
        # segments_for_this_path = max(1, int(len(path["exp_id_traj"]) / video_clip_length_in_steps))     # This is not good

        for _ in range(segments_for_this_path):
            segment = sample_segment_from_path(path, video_clip_length_in_steps)
            if segment is not None:
                # Add segment to database
                segments.append(segment)

                segment_num += 1

                # Render video
                # TODO: connect rendered video with segment data
                if render_video:
                    local_path = osp.join(video_dir, 'test_worker-{}_segment-{}.mp4'.format(worker_id, segment_num))
                    print("Worker-{} Writing segment to: {}".format(worker_id, local_path))
                    write_segment_to_video(
                        segment,
                        fname=local_path,
                        env=env)

            if _verbose and segment_num % 10 == 0 and segment_num > 0:
                print("Worker-{} Collected {}/{} segments".format(worker_id, segment_num * _multiplier,
                                                                  n_desired_segments * _multiplier))
    if _verbose:
        print("Worker-{} Successfully collected {} segments".format(worker_id, segment_num * _multiplier))
    return segments


def segments_from_rollout(env,
                          pl_pretrain_agent, memory_manager, reward_component,
                          render_video, video_dir,
                          n_desired_segments, video_clip_length_in_steps, workers):
    """ Generate a list of path segments by doing random rollouts. Can use multiple processes. """
    if workers < 2:  # Default to basic segment collection
        worker_id = 1
        segments = basic_segments_from_rollout(env,
                                               pl_pretrain_agent, memory_manager, reward_component,
                                               render_video, video_dir, worker_id,
                                               n_desired_segments, video_clip_length_in_steps)
        return segments
    else:
        # TODO: need to reimplement this part
        pass
        # # Note: PyBullet is a C plugin, so deepcopy cannot be used. To use multiprocessing to sample
        # #   segments, we need to create environment in each process.
        # pool = Pool(processes=workers)
        # segments_per_worker = int(math.ceil(n_desired_segments / workers))
        # # One job per worker.
        # jobs = [
        #     (env_make_fn, env_id, env_dp_type, memory_manager,
        #      render_video, video_dir,
        #      worker_id, segments_per_worker, video_clip_length_in_frames, worker_id, True, workers)
        #     for worker_id in range(workers)]
        #
        # results = pool.starmap(basic_segments_from_rand_rollout, jobs)
        # pool.close()
        # return [segment for sublist in results for segment in sublist]

# @profile
# def basic_segments_from_rollout(env_make_fn, env_id, env_dp_type, env_seed,
#                                 pl_pretrain_agent, memory_manager, reward_component,
#                                 render_video, video_dir, worker_id,
#                                 n_desired_segments, video_clip_length_in_steps,
#                                 # These are only for use with multiprocessing
#                                 seed=0, _verbose=True, _multiplier=1, **env_params):
#     """ Generate a list of path segments by doing random rollouts. No multiprocessing. """
#
#     print('Start basic segmentation!')
#     segments = []
#     segment_num = 0
#
#     while segment_num < n_desired_segments:
#         # Note: make and close env within the while loop can save memory on Linux.
#         env = env_make_fn(env_id, env_dp_type=env_dp_type, seed=env_seed)
#         env.set_reward_component(reward_component)
#
#         # Random rollout
#
#         path = do_rollout(env, pl_pretrain_agent, memory_manager=memory_manager)
#         # Calculate the number of segments to sample from the path
#         # Such that the probability of sampling the same part twice is fairly low.
#         segments_for_this_path = max(1, int(0.25 * len(path["exp_id_traj"]) / video_clip_length_in_steps))
#         for _ in range(segments_for_this_path):
#             # TODO: delete random seg length
#             video_clip_length_in_steps = np.random.randint(50, 61)
#             segment = sample_segment_from_path(path, video_clip_length_in_steps)
#             if segment is not None:
#                 # Add segment to database
#                 segments.append(segment)
#                 segment_num += 1
#
#                 # Render video
#                 # TODO: connect rendered video with segment data
#                 if render_video:
#                     local_path = osp.join(video_dir, 'test_worker-{}_segment-{}.mp4'.format(worker_id, segment_num))
#                     print("Worker-{} Writing segment to: {}".format(worker_id, local_path))
#                     write_segment_to_video(
#                         segment,
#                         fname=local_path,
#                         env=env)
#
#             if _verbose and segment_num % 10 == 0 and segment_num > 0:
#                 print("Worker-{} Collected {}/{} segments".format(worker_id, segment_num * _multiplier,
#                                                                   n_desired_segments * _multiplier))
#         # env.close()
#     if _verbose:
#         print("Worker-{} Successfully collected {} segments".format(worker_id, segment_num * _multiplier))
#     return segments
#
#
# def segments_from_rollout(env_make_fn, env_id, env_dp_type, env_seed,
#                           pl_pretrain_agent, memory_manager, reward_component,
#                           render_video, video_dir,
#                           n_desired_segments, video_clip_length_in_steps, workers):
#     """ Generate a list of path segments by doing random rollouts. Can use multiple processes. """
#     if workers < 2:  # Default to basic segment collection
#         worker_id = 1
#         segments = basic_segments_from_rollout(env_make_fn, env_id, env_dp_type, env_seed,
#                                                pl_pretrain_agent, memory_manager, reward_component,
#                                                render_video, video_dir, worker_id,
#                                                n_desired_segments, video_clip_length_in_steps)
#         return segments
#     else:
#         # TODO: need to reimplement this part
#         pass
#         # # Note: PyBullet is a C plugin, so deepcopy cannot be used. To use multiprocessing to sample
#         # #   segments, we need to create environment in each process.
#         # pool = Pool(processes=workers)
#         # segments_per_worker = int(math.ceil(n_desired_segments / workers))
#         # # One job per worker.
#         # jobs = [
#         #     (env_make_fn, env_id, env_dp_type, memory_manager,
#         #      render_video, video_dir,
#         #      worker_id, segments_per_worker, video_clip_length_in_frames, worker_id, True, workers)
#         #     for worker_id in range(workers)]
#         #
#         # results = pool.starmap(basic_segments_from_rand_rollout, jobs)
#         # pool.close()
#         # return [segment for sublist in results for segment in sublist]


def segment_from_expert_rollout():
    # TODO:
    pass


if __name__ == '__main__':
    import numpy as np
    import os.path as osp
    from pl.envs.env import make_gym_task
    from pl.prefs.seg_sampling import segments_from_rand_rollout
    from pl.video import write_segment_to_video

    clip_length_in_seconds = 2
    n_desired_segments = 40
    render_dir = '../test/tmp/rl_teacher_media_test'
    workers = 2
    env_id = "AntBulletEnv-v0"  # 'AntBulletEnv-v0'. Walker2DBulletEnv-v0, HalfCheetahBulletEnv-v0
    env_dp_type = "MDP"  # ['MDP', 'POMDP-RV', 'POMDP-FLK', 'POMDP-RN', 'POMDP-RSM']
    render_video = True

    print("Saving video clips to: {}".format(osp.abspath(render_dir)))
    segments_from_rand_rollout(make_gym_task, env_id, env_dp_type,
                               render_video, render_dir,
                               n_desired_segments,
                               clip_length_in_seconds, workers)
    print('Collect segments done!')

"""
Internal Environment

This module provides facilities for defining internal environment which is a simulation of
the internal world of an agent. To differentiate it from "External Environment", Internal
Environment is the place where intrinsic and extrinsic motivations can be defined. This is
the interface where an agent can interact with the external environment.

"""
import gym
import numpy as np
from datetime import datetime
import collections
from pl.envs.env import make_gym_task
# from pl.envs.extl_env import make_bullet_task
from pl.rews.rew_comp import RewardComponent, MLPRewardComponent, LSTMRewardComponent


class IntlEnv(gym.Wrapper):
    """Internal Environment is the place to define reward signal when it is provided by external environment."""
    def __init__(self, env_id, seed, rew_comp=None,
                 env_dp_type='MDP', act_transform_type=None, obs_delay_step=0,
                 render_width=640, render_height=480, obs_tile_num=1, obs_tile_value=None):
        super(IntlEnv, self).__init__(make_gym_task(env_id, dp_type=env_dp_type,
                                                    render_width=render_width, render_height=render_height,
                                                    obs_tile_num=obs_tile_num, obs_tile_value=obs_tile_value))
        # self.env = make_bullet_task(env_id, dp_type=env_dp_type, render_width=render_width, render_height=render_height)  # used to simulate external world
        self.fps = self.env.fps
        self.env.seed(seed)

        # Action transformation
        self.act_transform_type = act_transform_type

        # Observation Delay
        self.obs_delay_step = obs_delay_step
        if self.obs_delay_step is None or self.obs_delay_step == 0:
            pass
        else:
            self.obs_delay_queue = collections.deque(
                maxlen=self.obs_delay_step + 1)  # The deque saves previous delay_step observations and the current observation
            self.rew_delay_queue = collections.deque(
                maxlen=self.obs_delay_step + 1)  # The deque saves previous delay_step observations and the current observation

        #
        self.rew_comp = rew_comp
        self.obs = None           # current observation
        #
        self.obs_dim = self.observation_space.shape[0]
        self.act_dim = self.action_space.shape[0]
        self.obs_traj, self.act_traj, self.obs2_traj = [], [], []

    def render_full_obs(self, full_obs):
        return self.env.render_full_obs(full_obs)

    def step(self, act):
        # Action transformation
        if self.act_transform_type is None:
            pass
        elif self.act_transform_type == 'neg':
            act = -act
        elif self.act_transform_type == 'tanh':
            act = np.tanh(act)
        elif self.act_transform_type == 'sign_square':
            act_sign = np.ones(len(act))
            act_sign[act < 0] = -1
            act = act_sign*(act**2)
        elif self.act_transform_type == 'abs_times_2_minus_1':
            act = np.abs(act)*2-1
        elif self.act_transform_type == 'neg_abs_times_2_plus_1':
            act = (-np.abs(act))*2+1
        elif self.act_transform_type == 'random':
            act = self.action_space.sample()
        else:
            raise ValueError('act_transform_type={} is not defined!'.format(self.act_transform_type))

        # Interact with environment
        act_ts = datetime.now()  # Action execution timestamp
        obs2, orig_rew, done, info = self.env.step(act)
        new_obs_ts = datetime.now()

        # Observation delay
        if self.obs_delay_step is None or self.obs_delay_step == 0:
            extl_rew = orig_rew
        else:
            self.obs_delay_queue.append(obs2)
            self.rew_delay_queue.append(orig_rew)
            if len(self.obs_delay_queue) < (self.obs_delay_step+1):
                # TODO: return random rather than zero for the first few observations
                obs2 = np.zeros(self.observation_space.shape[0])
                extl_rew = 0
            else:
                obs2 = self.obs_delay_queue.pop()
                extl_rew = self.rew_delay_queue.pop()
            # print(obs2)

        # Append experiences to trajectory which will be used for calculating learned reward
        self.obs_traj.append(self.obs.reshape(1, -1))
        self.act_traj.append(act.reshape(1, -1))
        self.obs2_traj.append(obs2.reshape(1, -1))

        # Calculate reward
        if self.rew_comp is None:
            rew = extl_rew
        else:
            # Note: when calculate immediate reward, keep the input format (1, dim) for MLP or (1, mem_len, dim) for LSTM.
            if self.rew_comp.reward_comp_type == 'MLP':
                rew = self.rew_comp(self.obs.reshape(1, -1), act.reshape(1, -1), obs2.reshape(1, -1))
            elif self.rew_comp.reward_comp_type == 'LSTM':
                mem_end_id = len(self.obs_traj)-1
                mem_start_id = max(0, mem_end_id-self.rew_comp.reward_mem_length+1)
                # Stack trajectory with the format for obs (1, mem_len, obs_dim)
                rew = self.rew_comp(np.stack(self.obs_traj[mem_start_id:mem_end_id+1], axis=1),
                                    np.stack(self.act_traj[mem_start_id:mem_end_id+1], axis=1),
                                    np.stack(self.obs2_traj[mem_start_id:mem_end_id+1], axis=1), mem_len=[mem_end_id-mem_start_id+1])
            else:
                raise ValueError('Wrong reward_comp_type: {}'.format(self.rew_comp.reward_comp_type))

        # Crucial note: Update current observation after reward computation.
        self.obs = obs2
        # Store extl_env to info for diagnostic purpose
        info['extl_rew'] = extl_rew
        info['orig_rew'] = orig_rew
        info['act_datetime'] = act_ts
        info['obs_datetime'] = new_obs_ts
        info['orig_rew'] = orig_rew
        return obs2, rew, done, info

    def reset(self):
        # Empty episode memory
        self.obs_traj, self.act_traj, self.obs2_traj = [], [], []

        # Empty obs_delay_queue and rew_delay_queue
        if self.obs_delay_step is None or self.obs_delay_step == 0:
            pass
        else:
            self.obs_delay_queue.clear()
            self.rew_delay_queue.clear()

        #
        self.obs = self.env.reset()
        obs_ts = datetime.now()

        # No need to delay the first observation, because it's not a consequence of an action given by the agent

        info = {'obs_datetime': obs_ts}
        return self.obs, info

    def set_reward_component(self, rew_comp):
        self.rew_comp = rew_comp


if __name__ == '__main__':
    from pl.envs.env import make_gym_task
    extl_env = make_gym_task('Ant-v2')
    intl_env = IntlEnv('Ant-v2', act_transform_type='tanh')
    intl_env.reset()
    obs2, rew, done, info = intl_env.step(intl_env.action_space.sample())

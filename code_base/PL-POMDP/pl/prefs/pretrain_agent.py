import torch
import numpy as np
from pl.agents.td3.core import MLPActorCritic


class PrefLearningPretrainRandomAgent(object):
    def __init__(self, observation_space, action_space, pretrain_agent_checkpoint_dir=None, pretrain_agent_hyperparams=None,
                 pretrain_agent_name='PrefLearningPretrainRandomAgent'):
        self.pretrain_agent_name = pretrain_agent_name
        self.observation_space = observation_space
        self.action_space = action_space
        self.obs_dim = self.observation_space.shape[0]
        self.act_dim = self.action_space.shape[0]
        self.pretrain_agent_checkpoint_dir = pretrain_agent_checkpoint_dir
        self.pretrain_agent_hyperparams = pretrain_agent_hyperparams

    def act(self, obs):
        act = self.action_space.sample()
        return act


class PrefLearningPretrainTD3Agent(object):
    def __init__(self, observation_space, action_space, pretrain_agent_checkpoint_path=None, pretrain_agent_hyperparams=None,
                 pretrain_agent_name='PrefLearningPretrainTD3Agent'):
        # Validate arguments
        if pretrain_agent_checkpoint_path is None or pretrain_agent_hyperparams is None:
            raise ValueError('Wrong pretrain_agent_checkpoint_path or pretrain_agent_hyperparams!')

        self.pretrain_agent_name = pretrain_agent_name
        self.observation_space = observation_space
        self.action_space = action_space
        self.obs_dim = self.observation_space.shape[0]
        self.act_dim = self.action_space.shape[0]
        self.pretrain_agent_checkpoint_path = pretrain_agent_checkpoint_path
        self.pretrain_agent_hyperparams = pretrain_agent_hyperparams

        self.act_limit = self.pretrain_agent_hyperparams['act_limit']
        self.hidden_sizes = self.pretrain_agent_hyperparams['hidden_sizes']
        self.act_noise = self.pretrain_agent_hyperparams['act_noise']

        # Initialize
        self.ac_device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
        self.ac = MLPActorCritic(self.obs_dim, self.act_dim, self.act_limit, self.hidden_sizes)
        self.ac.to(self.ac_device)

        # Load pretrained agent
        restore_elements = torch.load(pretrain_agent_checkpoint_path)
        self.ac.load_state_dict(restore_elements['ac_state_dict'])

    def act(self, obs):
        act = self.ac.act(torch.as_tensor(obs, dtype=torch.float32).to(self.ac_device))
        act += self.act_noise * np.random.randn(self.act_dim)
        act = np.clip(act, -self.act_limit, self.act_limit)
        return act


if __name__ == '__main__':
    from pl.envs.gym_intl_env import IntlEnv
    from pl.envs.env import get_timesteps_per_episode

    env_id = 'HalfCheetahBulletEnv-v0'
    env = IntlEnv(env_id, seed=0)  # used to interact with the environment
    max_timesteps_per_episode = get_timesteps_per_episode(env)

    # Load preference learning pretrain agent
    # Random pretrain agent
    pl_pretrain_agent = PrefLearningPretrainRandomAgent(env.observation_space, env.action_space)

    # TD3 pretrain agent
    pretrain_agent_checkpoint_dir = r'F:\scratch\lingheng\PL-Teaching-Data\2021-10-02_PL_TD3_HCReward\2021-10-02_18-10-46-PL_TD3_HCReward_s0\pyt_save\Step-1495999_Checkpoint_Agent_verified.pt'
    pretrain_agent_hyperparams = {'act_limit': 1, 'hidden_sizes': (256, 256)}
    pl_pretrain_agent = PrefLearningPretrainTD3Agent(env.observation_space, env.action_space, pretrain_agent_checkpoint_dir, pretrain_agent_hyperparams)

    obs = env.reset()
    # Primary environment loop
    for i in range(max_timesteps_per_episode):
        # Interact with the environment
        act = pl_pretrain_agent.act(obs)
        obs2, rew, done, info = env.step(act)

        obs = obs2  # Crucial to set obs to obs2
        if done:
            break
        import pdb; pdb.set_trace()

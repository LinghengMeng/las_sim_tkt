import os
from copy import deepcopy
import itertools
import numpy as np
import torch
from torch.optim import Adam
from pl.agents.td3.core import MLPActorCritic, combined_shape


class MTD3(object):
    """
    Multistep Twine Delayed Deep Deterministic Policy Gradient (MTD3) is proposed to improve its robustness to POMDP without manually incorporate
    temporal information to the tasks' observation.
    """
    def __init__(self, obs_space, act_space, hidden_sizes,
                 multistep_size=5,
                 recompute_reward_in_backup=True,
                 combine_hc_and_pb_reward=False,
                 gamma=0.99, polyak=0.995, pi_lr=1e-3, q_lr=1e-3,
                 start_steps=10000,
                 act_noise=0.1, target_noise=0.2, noise_clip=0.5,
                 update_after=1000, update_every=50, batch_size=64,
                 mem_manager=None, replay_size=1e6,
                 policy_delay=2, checkpoint_dir=None):
        #
        self.obs_space = obs_space
        self.act_space = act_space
        self.obs_dim = obs_space.shape[0]
        self.act_dim = act_space.shape[0]
        # Action limit for clamping: critically, assumes all dimensions share the same bound!
        self.act_limit = act_space.high[0]
        self.hidden_sizes = hidden_sizes

        # Multistep size
        self.multistep_size = multistep_size

        self.act_noise = act_noise
        self.start_steps = start_steps

        self.gamma = gamma
        self.target_noise = target_noise
        self.noise_clip = noise_clip

        self.update_after = update_after
        self.update_every = update_every

        self.recompute_reward_in_backup = recompute_reward_in_backup
        self.combine_hc_and_pb_reward = combine_hc_and_pb_reward

        # Create replay buffer
        self.obs = None
        self.act = None
        self.batch_size = batch_size
        self.mem_manager = mem_manager

        self.q_lr = q_lr
        self.pi_lr = pi_lr
        self.polyak = polyak
        self.policy_delay = policy_delay

        assert checkpoint_dir is not None, "Checkpoint_dir is None!"
        os.makedirs(checkpoint_dir, exist_ok=True)
        self.cp_dir = checkpoint_dir

        # Initialize actor-critic
        self._init_actor_critic()

        # Gamma to the power of (step-1)
        self.gamma_power = torch.as_tensor([self.gamma ** i for i in range(self.multistep_size)], dtype=torch.float32).to(self.ac_device)
        self.gamma_power_batch = torch.tile(self.gamma_power, (self.batch_size, 1))

    def _init_actor_critic(self):

        # Create actor-critic module and target networks
        self.ac = MLPActorCritic(self.obs_dim, self.act_dim, self.act_limit, self.hidden_sizes)
        self.ac_targ = deepcopy(self.ac)

        self.ac_device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
        self.ac.to(self.ac_device)
        self.ac_targ.to(self.ac_device)

        # Freeze target networks with respect to optimizers (only update via polyak averaging)
        for p in self.ac_targ.parameters():
            p.requires_grad = False

        # List of parameters for both Q-networks (save this for convenience)
        self.q_params = itertools.chain(self.ac.q1.parameters(), self.ac.q2.parameters())

        # Set up optimizers for policy and q-function
        self.pi_optimizer = Adam(self.ac.pi.parameters(), lr=self.pi_lr)
        self.q_optimizer = Adam(self.q_params, lr=self.q_lr)

    def save_checkpoint(self):
        """Save learned reward network to disk."""
        save_elements = {'ac_state_dict': self.ac.state_dict(),
                         'ac_targ_state_dict': self.ac_targ.state_dict(),
                         'pi_optimizer_state_dict': self.pi_optimizer.state_dict(),
                         'q_optimizer_state_dict': self.q_optimizer.state_dict()}
        return save_elements

    def restore_checkpoint(self, restore_elements, mem_manager):
        self.ac.load_state_dict(restore_elements['ac_state_dict'])
        self.ac_targ.load_state_dict(restore_elements['ac_targ_state_dict'])
        self.pi_optimizer.load_state_dict(restore_elements['pi_optimizer_state_dict'])
        self.q_optimizer.load_state_dict(restore_elements['q_optimizer_state_dict'])
        print('Successfully restored Agent!')
        self.mem_manager = mem_manager

    def _compute_loss_q(self, data, rew_comp):
        """function for computing TD3 Q-losses"""
        o, a, r, o2, d = data['obs'], data['act'], data['rew'], data['obs2'], data['done']
        multistep_size = data['multistep_size']
        multistep_reward_seg = data['multistep_reward_seg']
        multistep_obs2 = data['multistep_obs2']
        multistep_done = data['multistep_done']
        hc_r = data['hc_rew']

        q1 = self.ac.q1(o, a)
        q2 = self.ac.q2(o, a)

        # Bellman backup for Q functions
        with torch.no_grad():
            pi_targ = self.ac_targ.pi(multistep_obs2)

            # Target policy smoothing
            epsilon = torch.randn_like(pi_targ) * self.target_noise
            epsilon = torch.clamp(epsilon, -self.noise_clip, self.noise_clip)
            a2 = pi_targ + epsilon
            a2 = torch.clamp(a2, -self.act_limit, self.act_limit)

            # Target Q-values
            q1_pi_targ = self.ac_targ.q1(multistep_obs2, a2)
            q2_pi_targ = self.ac_targ.q2(multistep_obs2, a2)
            q_pi_targ = torch.min(q1_pi_targ, q2_pi_targ)

            # Note: r should be recalculated as it changes as more preferences coming in.
            # TODO: need to calculate all rewrads within the multistep
            if self.recompute_reward_in_backup and rew_comp is not None:
                if rew_comp.reward_comp_type == "MLP":
                    r = rew_comp(data['obs'], data['act'], data['obs2'])
                elif rew_comp.reward_comp_type == "LSTM":
                    r = rew_comp(data['mem_seg_obs'], data['mem_seg_act'], data['mem_seg_obs2'], data['mem_seg_len'])
                else:
                    raise ValueError('rew_comp.reward_comp_type={}!'.format(rew_comp.reward_comp_type))
            else:
                pass    # Use the previously calculated reward

            # if combine hardcoded-reward and preference-based reward
            if rew_comp is not None and self.combine_hc_and_pb_reward:
                r = r + hc_r

            # Calculate multistep backup
            if self.gamma_power_batch.shape[0] != multistep_reward_seg.shape[0]:    # Avoid recalculate gamma_power if the bach size doesn't change.
                self.gamma_power_batch = torch.tile(self.gamma_power, (multistep_reward_seg.shape[0], 1))
            backup = torch.sum(multistep_reward_seg * self.gamma_power_batch, dim=1) + self.gamma**multistep_size * (1-multistep_done) * q_pi_targ


        # MSE loss against Bellman backup
        loss_q1 = ((q1 - backup) ** 2).mean()
        loss_q2 = ((q2 - backup) ** 2).mean()
        loss_q = loss_q1 + loss_q2

        # Useful info for logging
        loss_info = dict(Q1Vals=q1.cpu().detach().numpy(),
                         Q2Vals=q2.cpu().detach().numpy())

        return loss_q, loss_info

    def _compute_loss_pi(self, data):
        """function for computing TD3 pi loss"""
        o = data['obs']
        q1_pi = self.ac.q1(o, self.ac.pi(o))
        return -q1_pi.mean()

    def get_train_action(self, obs):
        a = self.ac.act(torch.as_tensor(obs, dtype=torch.float32).to(self.ac_device))
        a += self.act_noise * np.random.randn(self.act_dim)
        a = np.clip(a, -self.act_limit, self.act_limit)
        return a

    def get_test_action(self, obs):
        a = self.ac.act(torch.as_tensor(obs, dtype=torch.float32).to(self.ac_device))
        return a

    def interact(self, time_step, new_obs, rew, hc_rew, done, info, terminal, rew_comp, logger):
        # If not the initial observation, store the latest experience (obs, act, rew, new_obs, done).
        if self.obs is not None:
            self.mem_manager.store_experience(self.obs, self.act, new_obs, rew, hc_rew, done, 'TD3_agent',
                                              obs_time=self.obs_timestamp, act_time=info['act_datetime'], obs2_time=info['obs_datetime'])

        # If terminal, start from the new episode where no previous (obs, act) exist.
        if terminal:
            self.obs = None
            self.act = None
            self.obs_timestamp = None
        else:
            # Get action:
            #   Until start_steps have elapsed, randomly sample actions
            #   from a uniform distribution for better exploration. Afterwards,
            #   use the learned policy (with some noise, via act_noise).
            if time_step > self.start_steps:
                self.act = self.get_train_action(new_obs)
            else:
                self.act = self.act_space.sample()
            self.obs = new_obs
            self.obs_timestamp = info['obs_datetime']

        # Update
        logger = self.update(time_step, rew_comp, logger, done)

        return self.act, logger

    def update(self, time_step, rew_comp, logger, done=None):
        #
        if time_step >= self.update_after and time_step % self.update_every == 0:
            # if time_step % 100 == 0:
            #     latest_experience_id = self.mem_manager.get_latest_experience_id()
            #     print("latest_experience_id={}".format(latest_experience_id))

            for j in range(self.update_every):
                # Sample batch from replay buffer and update agent
                if rew_comp is None:
                    reward_mem_len = None
                else:
                    reward_mem_len = rew_comp.reward_mem_length

                # batch = self.replay_buffer.sample_batch(self.batch_size, device=self.ac_device,
                #                                         mem_len=reward_mem_len)
                batch = self.mem_manager.sample_exp_batch(self.batch_size, device=self.ac_device,
                                                          reward_mem_len=reward_mem_len, multistep_size=self.multistep_size)

                # First run one gradient descent step for Q1 and Q2
                self.q_optimizer.zero_grad()
                loss_q, loss_info = self._compute_loss_q(batch, rew_comp)
                loss_q.backward()
                self.q_optimizer.step()

                # Record things
                logger.store(LossQ=loss_q.item(), **loss_info)

                # Possibly update pi and target networks
                if j % self.policy_delay == 0:

                    # Freeze Q-networks so you don't waste computational effort
                    # computing gradients for them during the policy learning step.
                    for p in self.q_params:
                        p.requires_grad = False

                    # Next run one gradient descent step for pi.
                    self.pi_optimizer.zero_grad()
                    loss_pi = self._compute_loss_pi(batch)
                    loss_pi.backward()
                    self.pi_optimizer.step()

                    # Unfreeze Q-networks so you can optimize it at next DDPG step.
                    for p in self.q_params:
                        p.requires_grad = True

                    # Record things
                    logger.store(LossPi=loss_pi.item())

                    # Finally, update target networks by polyak averaging.
                    with torch.no_grad():
                        for p, p_targ in zip(self.ac.parameters(), self.ac_targ.parameters()):
                            # NB: We use an in-place operations "mul_", "add_" to update target
                            # params, as opposed to "mul" and "add", which would make new tensors.
                            p_targ.data.mul_(self.polyak)
                            p_targ.data.add_((1 - self.polyak) * p.data)
        return logger


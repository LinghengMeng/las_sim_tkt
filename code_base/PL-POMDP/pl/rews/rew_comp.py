"""
Reward Component

This module provides the definition of various kinks of reward components which provides the reward signal
given the latest experience tuple (obs, act, obs2, done, info) where info may contain additional
diagnostic information e.g. missing data.
"""
import os
import numpy as np
import torch
from torch.utils.data import DataLoader
from pl.rews.rew_nn import MLPBasedRewardNet, LSTMBasedRewardNet
from pl.utils.early_stopping import EarlyStopping
from pl.prefs.pref_collectors import mlp_reward_collate_fn, lstm_reward_collate_fn


class RewardComponent:
    """
    Unified interface for calculate reward whenever a new experience arrives.
    """
    def __init__(self, obs_dim, act_dim, reward_limit=1, reward_net_input_type='obs2',
                 reward_comp_type='MLP', reward_mem_length=None,
                 reward_comp_drop_prob=0.5, checkpoint_dir=None):
        self.obs_dim = obs_dim
        self.act_dim = act_dim
        self.reward_limit = reward_limit
        self.reward_net_input_type = reward_net_input_type
        self.reward_comp_device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
        self.reward_comp_type = reward_comp_type

        # Only used to sample batch to train Learning Agent, and is None for MLP.
        self.reward_mem_length = None

        # Initialize reward component
        if self.reward_comp_type == "MLP":
            self.rew_comp = MLPRewardComponent(obs_dim, act_dim, rew_lim=reward_limit,
                                               reward_net_input_type=self.reward_net_input_type,
                                               hidden_sizes=[64, 64], drop_prob=reward_comp_drop_prob,
                                               reward_comp_device=self.reward_comp_device,
                                               checkpoint_dir=checkpoint_dir)
        elif self.reward_comp_type == "LSTM":
            pref_learning_output_logit_type = 'sum'  # 'last'
            self.reward_mem_length = reward_mem_length
            self.rew_comp = LSTMRewardComponent(obs_dim, act_dim,
                                                reward_net_input_type=self.reward_net_input_type,
                                                drop_prob=reward_comp_drop_prob,
                                                pref_learning_output_logit_type=pref_learning_output_logit_type,
                                                reward_comp_device=self.reward_comp_device,
                                                checkpoint_dir=checkpoint_dir)
        else:
            raise ValueError("Wrong reward_comp_type was set!")

    def __call__(self, obs, act, obs2, mem_len=None, seg_len=None, missing_data=False):
        """
        Reward is calculated in 3 places for different purposes:
            1. in Internal Environment where immediate reward is required, especially for online on-policy learning
                For MLP:  obs: (1, obs_dim), act: (1, act_dim), obs2: (1, obs_dim)
                For LSTM: obs: (1, mem_len, obs_dim), act: (1, mem_len, act_dim), obs2: (1, mem_len, obs_dim)
            2. in Learning Agent where each time update the policy or value-function reward is recalculated according to latest reward function, e.g. TD3 backup calculation
                For MLP: obs: (batch_size, obs_dim), act: (batch_size, act_dim), obs2: (batch_size, obs_dim)
                For LSTM: obs: (batch_size, mem_len, obs_dim), act: (batch_size, mem_len, act_dim), obs2: (batch_size, mem_len, obs_dim)
            3. in Preference Learning where batch of segment pairs and preference label is used to learn a preference-based reward function.
                For MLP: obs: (batch_size*2, obs_dim), act: (batch_size*2, act_dim), obs2: (batch_size*2, obs_dim)
                        left segment:
                            obs_seg: (batch_size, seg_len, obs_dim), act_seg: (batch_size, seg_len, act_dim), obs2_seg: (batch_size, seg_len, obs_dim), seg_len
                         right segment:
                            obs_seg: (batch_size, seg_len, obs_dim), act_seg: (batch_size, seg_len, act_dim), obs2_seg: (batch_size, seg_len, obs_dim), seg_len
                For LSTM: left segment:
                            obs_seg: (batch_size, seg_len, obs_dim), act_seg: (batch_size, seg_len, act_dim), obs2_seg: (batch_size, seg_len, obs_dim), seg_len
                          right segment:
                            obs_seg: (batch_size, seg_len, obs_dim), act_seg: (batch_size, seg_len, act_dim), obs2_seg: (batch_size, seg_len, obs_dim), seg_len
        Therefore, to differentiate different purposes, for 1 and 2 seg_len is None, while for 3 seg_len is not None and obs, act, obs2 are
        essentially obs_seg, act_seg, and obs2_seg. For 1, batch_size is 1, while for 2 batch_size is not 1.
        For LSTM-based reward, using seg_len and mem_len to differentiate the current reward calculation is for Learning Agent or Preference Learning.

        :param obs:
        :param act:
        :param obs2:
        :param seg_len:
        :param info: additional info e.g. 'missing_data'
        :return:
        """
        if missing_data:
            reward = None
        else:
            with torch.no_grad():
                self.rew_comp.reward_net.eval()  # eval() is called because dropout may be used

                # Convert to tensor if not yet
                if not torch.is_tensor(obs):
                        obs = torch.tensor(obs).float().to(self.reward_comp_device)
                        act = torch.tensor(act).float().to(self.reward_comp_device)
                        obs2 = torch.tensor(obs2).float().to(self.reward_comp_device)
                        if seg_len is not None:
                            seg_len = torch.tensor(seg_len).float()
                        if mem_len is not None:
                            mem_len = torch.tensor(mem_len).float()
                else:
                    if obs.device != self.reward_comp_device:
                        obs = obs.float().to(self.reward_comp_device)
                        act = act.float().to(self.reward_comp_device)
                        obs2 = obs2.float().to(self.reward_comp_device)
                if self.reward_comp_type == 'MLP':
                    reward, pref_learning_output_logit = self.rew_comp(obs, act, obs2, seg_len)
                else:
                    reward, pref_learning_output_logit = self.rew_comp(obs, act, obs2, mem_len, seg_len)

            reward = torch.squeeze(reward, -1)
            if reward.shape[0] == 1:
                reward = reward.item()
        return reward

    def train(self, training_dataset, test_dataset, training_batch_size=64, test_batch_size=128):
        return self.rew_comp.train(training_dataset, test_dataset, training_batch_size, test_batch_size)

    def save_checkpoint(self):
        """Save learned reward network to disk."""
        return self.rew_comp.save_checkpoint()

    def restore_checkpoint(self, restore_elements):
        self.rew_comp.restore_checkpoint(restore_elements)


class HandcraftedRewardComponent(RewardComponent):
    """
    Handcrafted reward based on human knowledge is employed to predict reward.
    """
    def __init__(self):
        super(HandcraftedRewardComponent, self).__init__()
        pass

    def __call__(self, obs, act, obs2, missing_data=False):
        reward = 0
        return reward


class MLPRewardComponent():
    """
    Multi-Layer Perceptron based reward network is employed to predict reward.
    """
    def __init__(self, obs_dim, act_dim, rew_lim, hidden_sizes=[64, 64], drop_prob=0.5,
                 reward_net_input_type="obs_act", reward_comp_device=None, checkpoint_dir=None, lr=0.001):
        super(MLPRewardComponent, self).__init__()
        self.obs_dim = obs_dim
        self.act_dim = act_dim
        self.rew_lim = rew_lim
        self.reward_net_input_type = reward_net_input_type
        self.reward_net_hidden_sizes = hidden_sizes
        self.reward_comp_device = reward_comp_device

        #
        assert checkpoint_dir is not None, "Checkpoint_dir is None!"
        os.makedirs(checkpoint_dir, exist_ok=True)
        self.cp_dir = checkpoint_dir

        self.lr = lr

        self.train_epoch_num = 5  #
        self.train_patience = 2   # train_patience should be less than train_epoch_num
        self.batch_collate_fn = mlp_reward_collate_fn
        #
        self._init_reward_net()

    def _init_reward_net(self):
        """Initialize reward network."""
        # Instantiate and load learned reward_net
        if self.reward_net_input_type == "obs_act_obs2":
            input_size = self.obs_dim + self.act_dim + self.obs_dim
        elif self.reward_net_input_type == "obs_act":
            input_size = self.obs_dim + self.act_dim
        elif self.reward_net_input_type == 'obs2':
            input_size = self.obs_dim
        else:
            raise ValueError("Wrong reward_net_input_type!")
        self.reward_net = MLPBasedRewardNet([input_size] + list(self.reward_net_hidden_sizes) + [1],
                                            rew_lim=self.rew_lim)

        # Optimizer setup
        self.reward_net_criterion = torch.nn.CrossEntropyLoss()
        self.reward_net_optimizer = torch.optim.Adam(self.reward_net.parameters(),
                                                     lr=self.lr)
        # Put network to corresponding device
        self.reward_net.to(self.reward_comp_device)

    def __call__(self, obs, act, obs2, seg_len=None, missing_data=False):
        """
        Predict reward given the latest experience.

        """
        # Check input
        if missing_data:
            reward, pref_learning_output_logit = None, None
        else:
            with torch.no_grad():
                self.reward_net.eval()

                # Set obs, act and obs2 for different input type
                if self.reward_net_input_type == "obs_act_obs2":
                    if obs is None or act is None or obs2 is None:
                        raise ValueError("reward_net_input_type={} does not align with input obs2".format(self.reward_net_input_type))
                elif self.reward_net_input_type == "obs_act":
                    obs2 = None
                    if obs is None or act is None:
                        raise ValueError("reward_net_input_type={} does not align with input obs2".format(self.reward_net_input_type))
                elif self.reward_net_input_type == "obs2":
                    obs, act = None, None
                    if obs2 is None:
                        raise ValueError("reward_net_input_type={} does not align with input obs2".format(self.reward_net_input_type))
                else:
                    raise ValueError("Wrong reward_net_input_type!")

            reward, pref_learning_output_logit = self.reward_net(obs, act, obs2, seg_len)
        return reward, pref_learning_output_logit

    def train(self, training_dataset, test_dataset,
              training_batch_size=64, test_batch_size=128):

        # Define dataset loader
        training_dataset_loader = DataLoader(dataset=training_dataset,
                                             batch_size=training_batch_size,
                                             collate_fn=self.batch_collate_fn,
                                             pin_memory=True)
        test_dataset_loader = DataLoader(dataset=test_dataset,
                                         batch_size=test_batch_size,
                                         collate_fn=self.batch_collate_fn,
                                         pin_memory=True)

        # stat = {}
        # # Evaluate before training.
        # stat = self._evaluate(training_dataset_loader, test_dataset_loader, stat, 'before_train')

        # Initialize early_stopping
        path = os.path.join(self.cp_dir, 'tmp_rew_comp_checkpoint.pt')
        early_stopping = EarlyStopping(patience=self.train_patience, verbose=True, delta=0, path=path)

        # epoch_num = 20
        # early_stopping = None

        stat_avg_train_losses = []
        stat_avg_valid_losses = []

        # Train
        if len(training_dataset) != 0:
            for epoch_i in range(self.train_epoch_num):
                train_losses = []
                valid_losses = []
                ###########################################
                #            Train Reward Model           #
                ###########################################
                # Run one epoch
                self.reward_net.train()

                for batch_i, batch in enumerate(training_dataset_loader):
                    obs = batch.obs.to(self.reward_comp_device)
                    act = batch.act.to(self.reward_comp_device)
                    obs2 = batch.obs2.to(self.reward_comp_device)
                    seg_len = batch.seg_len.to(self.reward_comp_device)
                    labels = batch.labels.to(self.reward_comp_device)

                    # Set obs2 to None, if self.reward_net_input_type == "obs_act"
                    if self.reward_net_input_type == "obs_act":
                        obs2 = None
                    elif self.reward_net_input_type == "obs2":
                        obs, act = None, None

                    # zero the parameter gradients
                    self.reward_net_optimizer.zero_grad()

                    # forward + backward + optimize
                    rew_pred, seg_reward_pred = self.reward_net(obs, act, obs2, seg_len=seg_len)
                    loss = self.reward_net_criterion(seg_reward_pred, labels)
                    loss.backward()
                    self.reward_net_optimizer.step()

                    # Statistics
                    train_losses.append(loss.item())

                epoch_avg_train_loss = np.average(train_losses)

                ############################################
                # Validate Reward Model and Early Stopping #
                ############################################
                if len(test_dataset) != 0:
                    self.reward_net.eval()
                    with torch.no_grad():
                        for i, batch in enumerate(test_dataset_loader):
                            obs = batch.obs.to(self.reward_comp_device)
                            act = batch.act.to(self.reward_comp_device)
                            obs2 = batch.obs2.to(self.reward_comp_device)
                            seg_len = batch.seg_len.to(self.reward_comp_device)
                            labels = batch.labels.to(self.reward_comp_device)
                            # Set obs2 for different input type
                            if self.reward_net_input_type == "obs_act_obs2":
                                pass
                            elif self.reward_net_input_type == "obs_act":
                                obs2 = None
                            elif self.reward_net_input_type == "obs2":
                                obs, act = None, None
                            else:
                                raise ValueError("Wrong reward_net_input_type!")
                            # forward + backward + optimize
                            rew_pred, seg_reward_pred = self.reward_net(obs, act, obs2, seg_len=seg_len)
                            loss = self.reward_net_criterion(seg_reward_pred, labels)
                            valid_losses.append(loss.item())

                    epoch_avg_valid_loss = np.average(valid_losses)
                    stat_avg_train_losses.append(epoch_avg_train_loss)
                    stat_avg_valid_losses.append(epoch_avg_valid_loss)
                    print("[Train Epoch {:d}] Train loss: {:.3f}, Valid loss: {:.3f}".format(epoch_i + 1, epoch_avg_train_loss,
                                                                                             epoch_avg_valid_loss))
                    #
                    if early_stopping is not None:
                        early_stopping(epoch_avg_valid_loss, self.reward_net)
                        if early_stopping.early_stop:
                            print("Early stopping")
                            break
            # Load the last checkpoint with the best model
            if len(test_dataset) != 0:
                self.reward_net.load_state_dict(torch.load(path))
        # # Evaluate after training.
        # stat = self._evaluate(training_dataset_loader, test_dataset_loader, stat, 'after_train')
        return stat_avg_train_losses, stat_avg_valid_losses

    # def train(self, pref_collector, epoch_num=10, start_from_scratch=False):
    #     """Train reward network."""
    #
    #     # Start from scratch if start_from_scratch=False. Otherwise, continue training.
    #     # Note: every training from scratch will cause the output scale different, so if different reward scale
    #     #   was used for learning policy, it's not sure will this work.
    #     if start_from_scratch:
    #         self._init_reward_net()
    #
    #     # Define dataset loader
    #     self.train_dataset_loader = DataLoader(dataset=pref_collector.labeled_decisive_comparisons,
    #                                            batch_size=64, shuffle=True,
    #                                            collate_fn=self._batch_collate,
    #                                            pin_memory=True)
    #     stat = {}
    #     # Evaluate before training.
    #     stat = self._evaluate(self.train_dataset_loader, stat, 'before_train')
    #
    #     # Train epochs
    #     for epoch_i in range(epoch_num):
    #         epoch_loss = 0.0
    #         stat['Epoch {}'.format(epoch_i+1)] = {'rew_pred': [], 'seg_reward_pred': [], 'labels': []}
    #         # Run one epoch
    #         for i, batch in enumerate(self.train_dataset_loader):
    #             obs = batch['obs'].to(self.reward_net_device)
    #             act = batch['act'].to(self.reward_net_device)
    #             seg_len = batch['seg_len'].to(self.reward_net_device)
    #             labels = batch['labels'].to(self.reward_net_device)
    #
    #             # zero the parameter gradients
    #             self.reward_net_optimizer.zero_grad()
    #
    #             # forward + backward + optimize
    #             rew_pred, seg_reward_pred = self.reward_net(obs, act, seg_len=seg_len)
    #             loss = self.reward_net_criterion(seg_reward_pred, labels)
    #             loss.backward()
    #             self.reward_net_optimizer.step()
    #
    #             # Statistics
    #             epoch_loss += loss.item()
    #             stat['Epoch {}'.format(epoch_i + 1)]['rew_pred'].append(rew_pred)
    #             stat['Epoch {}'.format(epoch_i + 1)]['seg_reward_pred'].append(seg_reward_pred)
    #             stat['Epoch {}'.format(epoch_i + 1)]['labels'].append(labels)
    #
    #         print("[Train Epoch {:d}] loss: {:.3f}".format(epoch_i + 1, epoch_loss))
    #
    #     # Evaluate after training.
    #     stat = self._evaluate(self.train_dataset_loader, stat, 'after_train')
    #
    #     return stat

    # @staticmethod
    # def _batch_collate(batch):
    #     """
    #     Function passed as the collate_fn argument is used to collate lists of samples into batches.
    #     """
    #     # Concatenate
    #     left_obs = np.asarray(np.concatenate([comp['left']['obs'] for comp in batch]))
    #     left_acts = np.asarray(np.concatenate([comp['left']['actions'] for comp in batch]))
    #     left_seg_len = np.asarray([comp['left']['seg_len'] for comp in batch])
    #     right_obs = np.asarray(np.concatenate([comp['right']['obs'] for comp in batch]))
    #     right_acts = np.asarray(np.concatenate([comp['right']['actions'] for comp in batch]))
    #     right_seg_len = np.asarray([comp['right']['seg_len'] for comp in batch])
    #     labels = np.asarray([comp['label'] for comp in batch])
    #
    #     obs = torch.cat([torch.tensor(left_obs), torch.tensor(right_obs)]).float()  # convert float64 to float
    #     act = torch.cat([torch.tensor(left_acts), torch.tensor(right_acts)]).float()
    #     seg_len = torch.cat([torch.tensor(left_seg_len), torch.tensor(right_seg_len)]).float()
    #     labels = torch.tensor(labels).long()
    #     return {'obs': obs, 'act': act, 'seg_len': seg_len, 'labels': labels}

    def _evaluate(self, training_dataset_loader, test_dataset_loader,
                  stat, epoch_key='before_train'):
        """For logging evaluation performance only."""

        # Training dataset
        stat[epoch_key] = {"training_dataset": {'rew_pred': [], 'seg_reward_pred': [], 'labels': []}}
        self.reward_net.eval()  # prep model for evaluation
        with torch.no_grad():
            for i, batch in enumerate(training_dataset_loader):
                obs = batch.obs.to(self.reward_net_device)
                act = batch.act.to(self.reward_net_device)
                obs2 = batch.obs2.to(self.reward_net_device)
                seg_len = batch.seg_len.to(self.reward_net_device)
                labels = batch.labels.to(self.reward_net_device)
                # Set obs2 for different input type
                if self.reward_net_input_type == "obs_act":
                    obs2 = None

                # forward + backward + optimize
                rew_pred, seg_reward_pred = self.reward_net(obs, act, obs2, seg_len=seg_len)
                loss = self.reward_net_criterion(seg_reward_pred, labels)

                stat[epoch_key]["training_dataset"]['rew_pred'].append(rew_pred)
                stat[epoch_key]["training_dataset"]['seg_reward_pred'].append(seg_reward_pred)
                stat[epoch_key]["training_dataset"]['labels'].append(labels)

        # Test datast
        stat[epoch_key] = {"test_dataset": {'rew_pred': [], 'seg_reward_pred': [], 'labels': []}}
        with torch.no_grad():
            for i, batch in enumerate(test_dataset_loader):
                obs = batch.obs.to(self.reward_net_device)
                act = batch.act.to(self.reward_net_device)
                obs2 = batch.obs2.to(self.reward_net_device)
                seg_len = batch.seg_len.to(self.reward_net_device)
                labels = batch.labels.to(self.reward_net_device)
                # Set obs2 for different input type
                if self.reward_net_input_type == "obs_act_obs2":
                    pass
                elif self.reward_net_input_type == "obs_act":
                    obs2 = None
                else:
                    raise ValueError("Wrong reward_net_input_type!")
                # forward + backward + optimize
                rew_pred, seg_reward_pred = self.reward_net(obs, act, obs2, seg_len=seg_len)
                loss = self.reward_net_criterion(seg_reward_pred, labels)

                stat[epoch_key]["test_dataset"]['rew_pred'].append(rew_pred)
                stat[epoch_key]["test_dataset"]['seg_reward_pred'].append(seg_reward_pred)
                stat[epoch_key]["test_dataset"]['labels'].append(labels)
        return stat

    # def save_checkpoint(self, time_step):
    #     """Save learned reward network to disk."""
    #     cp_file = os.path.join(self.cp_dir, 'Step-{}_Checkpoint_Reward-Component.pt'.format(time_step))
    #     save_elements = {'reward_net_state_dict': self.reward_net.state_dict(),
    #                      'reward_net_optimizer_state_dict': self.reward_net_optimizer.state_dict()}
    #     torch.save(save_elements, cp_file)
    #     # Rename the file to verify the completion of the saving in case of midway cutoff.
    #     verified_cp_file = os.path.join(self.cp_dir,
    #                                     'Step-{}_Checkpoint_Reward-Component_verified.pt'.format(time_step))
    #     os.rename(cp_file, verified_cp_file)

    def save_checkpoint(self):
        """Save learned reward network to disk."""
        save_elements = {'reward_net_state_dict': self.reward_net.state_dict(),
                         'reward_net_optimizer_state_dict': self.reward_net_optimizer.state_dict()}
        return save_elements

    def restore_checkpoint(self, restore_elements):
        """"""
        self.reward_net.load_state_dict(restore_elements['reward_net_state_dict'])
        self.reward_net_optimizer.load_state_dict(restore_elements['reward_net_optimizer_state_dict'])
        print('Successfully restored Reward Component!')

    # def restore_checkpoint(self, time_step):
    #     """"""
    #     cp_file = os.path.join(self.cp_dir, 'Step-{}_Checkpoint_Reward-Component_verified.pt'.format(time_step))
    #     restore_elements = torch.load(cp_file)
    #     self.reward_net.load_state_dict(restore_elements['reward_net_state_dict'])
    #     self.reward_net_optimizer.load_state_dict(restore_elements['reward_net_optimizer_state_dict'])
    #     print('Successfully restored Reward Component!')


class LSTMRewardComponent():
    """
    LSTM-based reward network is employed to predict reward.
    """
    def __init__(self, obs_dim, act_dim, reward_net_input_type='obs_act',
                 lstm_n_layers=2, lstm_hidden_dim=64, drop_prob=0.5, pref_learning_output_logit_type='sum', lr=0.001,
                 checkpoint_dir=None, **kwargs):
        super(LSTMRewardComponent, self).__init__()
        self.obs_dim = obs_dim
        self.act_dim = act_dim

        # Instantiate reward_net
        self.reward_net_input_type = reward_net_input_type
        self.output_size = 1
        self.lstm_n_layers = lstm_n_layers
        self.lstm_hidden_dim = lstm_hidden_dim
        self.drop_prob = drop_prob
        self.pref_learning_output_logit_type = pref_learning_output_logit_type
        self.lr = lr
        self._init_reward_net()

        #
        assert checkpoint_dir is not None, "Checkpoint_dir is None!"
        os.makedirs(checkpoint_dir, exist_ok=True)
        self.cp_dir = checkpoint_dir

        self.train_epoch_num = 5  #
        self.train_patience = 2  # train_patience should be less than train_epoch_num
        self.batch_collate_fn = lstm_reward_collate_fn

    def _init_reward_net(self):
        """Initialize reward network."""
        # Instantiate and load learned reward_net
        if self.reward_net_input_type == "obs_act_obs2":
            input_size = self.obs_dim + self.act_dim + self.obs_dim
        elif self.reward_net_input_type == "obs_act":
            input_size = self.obs_dim + self.act_dim
        elif self.reward_net_input_type == "obs2":
            input_size = self.obs_dim
        else:
            raise ValueError("Wrong reward_net_input_type!")
        self.reward_net = LSTMBasedRewardNet(input_size, self.output_size,
                                             self.lstm_n_layers, self.lstm_hidden_dim,
                                             drop_prob=self.drop_prob, pref_learning_output_logit_type=self.pref_learning_output_logit_type)

        # Optimizer setup
        self.reward_net_criterion = torch.nn.CrossEntropyLoss()
        self.reward_net_optimizer = torch.optim.Adam(self.reward_net.parameters(),
                                                     lr=self.lr)
        # Put to GPU device
        self.reward_net_device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
        self.reward_net.to(self.reward_net_device)

    # def save_checkpoint(self, time_step):
    #     """Save learned reward network to disk."""
    #     cp_file = os.path.join(self.cp_dir, 'Step-{}_Checkpoint_Reward-Component.pt'.format(time_step))
    #     save_elements = {'reward_net_state_dict': self.reward_net.state_dict(),
    #                      'reward_net_optimizer_state_dict': self.reward_net_optimizer.state_dict()}
    #     torch.save(save_elements, cp_file)
    #     # Rename the file to verify the completion of the saving in case of midway cutoff.
    #     verified_cp_file = os.path.join(self.cp_dir,
    #                                     'Step-{}_Checkpoint_Reward-Component_verified.pt'.format(time_step))
    #     os.rename(cp_file, verified_cp_file)

    def save_checkpoint(self):
        """Save learned reward network to disk."""
        save_elements = {'reward_net_state_dict': self.reward_net.state_dict(),
                         'reward_net_optimizer_state_dict': self.reward_net_optimizer.state_dict()}
        return save_elements

    def restore_checkpoint(self, restore_elements):
        self.reward_net.load_state_dict(restore_elements['reward_net_state_dict'])
        self.reward_net_optimizer.load_state_dict(restore_elements['reward_net_optimizer_state_dict'])
        print('Successfully restored Reward Component!')

    # def restore_checkpoint(self, time_step):
    #     cp_file = os.path.join(self.cp_dir, 'Step-{}_Checkpoint_Reward-Component_verified.pt'.format(time_step))
    #     restore_elements = torch.load(cp_file)
    #     self.reward_net.load_state_dict(restore_elements['reward_net_state_dict'])
    #     self.reward_net_optimizer.load_state_dict(restore_elements['reward_net_optimizer_state_dict'])
    #     print('Successfully restored Reward Component!')

    def __call__(self, obs, act, obs2, mem_len=None, seg_len=None, missing_data=False):
        # Check input
        # TODO：actually the short memory is already saved in output of LSTM, so no need to keep a separate memory data.
        #   But, if we want to limit the memory length, the separate memory data is necessary.
        if missing_data:
            reward, pref_learning_output_logit = None, None
        else:
            with torch.no_grad():
                self.reward_net.eval()  # eval() is necessary for network with dropout

                # Set obs, act and obs2 for different input type
                if self.reward_net_input_type == "obs_act_obs2":
                    if obs is None or act is None or obs2 is None:
                        raise ValueError("reward_net_input_type={} does not align with input obs2".format(self.reward_net_input_type))
                elif self.reward_net_input_type == "obs_act":
                    obs2 = None
                    if obs is None or act is None:
                        raise ValueError("reward_net_input_type={} does not align with input obs2".format(self.reward_net_input_type))
                elif self.reward_net_input_type == "obs2":
                    obs, act = None, None
                    if obs2 is None:
                        raise ValueError("reward_net_input_type={} does not align with input obs2".format(self.reward_net_input_type))
                else:
                    raise ValueError("Wrong reward_net_input_type!")

                reward, pref_learning_output_logit = self.reward_net(obs, act, obs2, mem_len, seg_len)
        return reward, pref_learning_output_logit

    def train(self, training_dataset, test_dataset,
              training_batch_size=64, test_batch_size=128):
        # Define dataset loader
        training_dataset_loader = DataLoader(dataset=training_dataset,
                                             batch_size=training_batch_size,
                                             collate_fn=self.batch_collate_fn,
                                             pin_memory=True)
        test_dataset_loader = DataLoader(dataset=test_dataset,
                                         batch_size=test_batch_size,
                                         collate_fn=self.batch_collate_fn,
                                         pin_memory=True)
        # stat = {}
        # # Evaluate before training.
        # stat = self._evaluate(training_dataset_loader, test_dataset_loader, stat, 'before_train')

        # Initialize early_stopping
        path = os.path.join(self.cp_dir, 'tmp_rew_comp_checkpoint.pt')
        early_stopping = EarlyStopping(patience=self.train_patience, verbose=True, delta=0, path=path)

        # epoch_num = 20
        # early_stopping = None

        stat_avg_train_losses = []
        stat_avg_valid_losses = []
        # Train
        for epoch_i in range(self.train_epoch_num):
            train_losses = []
            valid_losses = []
            ###########################################
            #            Train Reward Model           #
            ###########################################
            # Run one epoch
            self.reward_net.train()
            for batch_i, batch in enumerate(training_dataset_loader):
                obs = batch.obs.to(self.reward_net_device)
                act = batch.act.to(self.reward_net_device)
                obs2 = batch.obs2.to(self.reward_net_device)
                seg_len = batch.seg_len
                labels = batch.labels.to(self.reward_net_device)

                # Set obs2 to None, if self.reward_net_input_type == "obs_act"
                if self.reward_net_input_type == "obs_act":
                    obs2 = None
                elif self.reward_net_input_type == "obs2":
                    obs, act = None, None

                # zero the parameter gradients
                self.reward_net_optimizer.zero_grad()

                # forward + backward + optimize
                rew_pred, seg_reward_pred = self.reward_net(obs, act, obs2, seg_len=seg_len)
                loss = self.reward_net_criterion(seg_reward_pred, labels)
                loss.backward()
                self.reward_net_optimizer.step()

                # Statistics
                train_losses.append(loss.item())

            epoch_avg_train_loss = np.average(train_losses)

            ############################################
            # Validate Reward Model and Early Stopping #
            ############################################
            self.reward_net.eval()
            with torch.no_grad():
                for i, batch in enumerate(test_dataset_loader):
                    obs = batch.obs.to(self.reward_net_device)
                    act = batch.act.to(self.reward_net_device)
                    obs2 = batch.obs2.to(self.reward_net_device)
                    seg_len = batch.seg_len
                    labels = batch.labels.to(self.reward_net_device)
                    # Set obs2 for different input type
                    if self.reward_net_input_type == "obs_act_obs2":
                        pass
                    elif self.reward_net_input_type == "obs_act":
                        obs2 = None
                    elif self.reward_net_input_type == "obs2":
                        obs, act = None, None
                    else:
                        raise ValueError("Wrong reward_net_input_type!")
                    # forward + backward + optimize
                    rew_pred, seg_reward_pred = self.reward_net(obs, act, obs2, seg_len=seg_len)
                    loss = self.reward_net_criterion(seg_reward_pred, labels)
                    valid_losses.append(loss.item())

            epoch_avg_valid_loss = np.average(valid_losses)
            stat_avg_train_losses.append(epoch_avg_train_loss)
            stat_avg_valid_losses.append(epoch_avg_valid_loss)
            print("[Train Epoch {:d}] Train loss: {:.3f}, Valid loss: {:.3f}".format(epoch_i + 1, epoch_avg_train_loss,
                                                                                     epoch_avg_valid_loss))
            #
            if early_stopping is not None:
                early_stopping(epoch_avg_valid_loss, self.reward_net)
                if early_stopping.early_stop:
                    print("Early stopping")
                    break
        # Load the last checkpoint with the best model
        self.reward_net.load_state_dict(torch.load(path))
        # # Evaluate after training.
        # stat = self._evaluate(training_dataset_loader, test_dataset_loader, stat, 'after_train')
        return stat_avg_train_losses, stat_avg_valid_losses


class HandcraftedAndMLPHybridRewardComponent(RewardComponent):
    """
    Hybrid reward component fusing both handcrafted and MLP reward component is employed to predict reward.
    """
    def __init__(self):
        super(HandcraftedAndMLPHybridRewardComponent, self).__init__()
        pass

    def calculate_reward(self, obs, act, obs2, missing_data=False):
        reward = 0
        return reward


if __name__ == '__main__':
    import os.path as osp
    import os
    import numpy as np
    from pl.archive.mem_manager import MemoryManager

    mem_type = 'DB_disk'
    checkpoint_dir = osp.join(
        osp.dirname('F:/scratch/lingheng/'), 'test_db_size')
    if not osp.exists(checkpoint_dir):
        os.mkdir(checkpoint_dir)

    mem_manager = MemoryManager(mem_type, checkpoint_dir)
    obs_dim = 26
    act_dim = 6
    reward_limit = 1
    reward_net_input_type = 'obs_act_obs2'
    reward_comp_type = 'MLP'
    reward_comp_drop_prob = 0.5
    video_clip_length_in_frames = 60

    rew_comp = RewardComponent(obs_dim, act_dim,
                               reward_limit=reward_limit,
                               reward_net_input_type=reward_net_input_type,
                               reward_comp_type=reward_comp_type,
                               reward_comp_drop_prob=reward_comp_drop_prob,
                               checkpoint_dir=checkpoint_dir)

    experience_num = 10000
    obs = np.random.rand(obs_dim)
    act = np.random.rand(act_dim)
    new_obs = np.random.rand(obs_dim)
    rew = 0
    hc_rew = 0
    done = False
    for i in range(experience_num):
        if i % 10000 == 0:
            print(i)
        mem_manager.store_experience(obs, act, new_obs, rew, hc_rew, done, 'TD3_agent')
    mem_manager.db_conn.commit()
    batch = mem_manager.sample_exp_batch(64, mem_len=video_clip_length_in_frames)
    reward = rew_comp(batch['obs'], batch['act'], batch['obs2'], batch['mem_seg_obs'], batch['mem_seg_act'], batch['mem_seg_obs2'],
                      batch['mem_seg_len'])

    import pdb;

    pdb.set_trace()

    obs = np.random.rand(obs_dim)
    act = np.random.rand(act_dim)
    obs2 = np.random.rand(obs_dim)
    mem_seg_obs = np.random.rand(video_clip_length_in_frames, obs_dim)
    mem_seg_act = np.random.rand(video_clip_length_in_frames, act_dim)
    mem_seg_obs2 = np.random.rand(video_clip_length_in_frames, obs_dim)
    mem_seg_len = video_clip_length_in_frames
    reward = rew_comp(obs, act, obs2, mem_seg_obs, mem_seg_act, mem_seg_obs2, mem_seg_len)
    import pdb;

    pdb.set_trace()
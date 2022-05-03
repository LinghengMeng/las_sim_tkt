"""

"""
import torch
import torch.nn as nn
from torch.nn.utils.rnn import pad_sequence, pack_padded_sequence, pad_packed_sequence


class MLPBasedRewardNet(nn.Module):
    """
    MLP Based Reward Network uses simple multilayer perceptron to approximate reward function.
    """
    def __init__(self, sizes, rew_lim=1, activation=nn.ReLU, output_activation=nn.Tanh, drop_prob=0.5, normalize_seg_rew=False):
        super(MLPBasedRewardNet, self).__init__()
        self.rew_lim = rew_lim      # limit the output range
        self.normalize_seg_rew = normalize_seg_rew
        self.layers = nn.ModuleList()
        # Hidden layers
        for j in range(len(sizes) - 2):
            self.layers += [nn.Linear(sizes[j], sizes[j + 1]), activation(), nn.Dropout(drop_prob)]

        # Output layer
        self.layers += [nn.Linear(sizes[-2], sizes[-1]), output_activation()]

    def forward(self, obs, act, obs2=None, seg_len=None):
        """

        :param obs:
        :param act:
        :param obs2:
        :param seg_len:
        :return:
        """
        # Input
        if obs2 is None:
            x = torch.cat((obs, act), dim=1)
        elif obs is None and act is None:
            x = obs2
        else:
            x = torch.cat((obs, act, obs2), dim=1)
        # Forward propagation
        for layer in self.layers:
            x = layer(x)
        # Output
        reward_output = self.rew_lim*x

        # sum over segment
        if seg_len is not None:
            # Init mask: for each column of mask only the items belong to the same segment are set to 1.
            seg_num = len(seg_len)
            sample_num = seg_len.sum()
            mask = torch.zeros((int(sample_num), seg_num)).to(x.device)
            for seg_i in range(len(seg_len)):
                mask[int(seg_len[:seg_i].sum()):int(seg_len[:seg_i+1].sum()), seg_i] = 1
            #
            x = torch.mm(x.transpose(0, 1), mask).view(-1)
            if self.normalize_seg_rew:
                x = x / seg_len     # Normalize by seg_len as segments may have different lengths
            batch_size = int(seg_len.shape[0] / torch.tensor(2).to(x.device))
            seg_reward_output = torch.stack(torch.split(x, [batch_size, batch_size]), dim=1)
        else:
            seg_reward_output = None

        return reward_output, seg_reward_output


class LSTMBasedRewardNet(nn.Module):
    """
    LSTM Based Reward Network employs LSTM to predict reward from a sequence of experiences.
    """
    def __init__(self, input_size, output_size, lstm_n_layers, lstm_hidden_dim,
                 fc_hidden_sizes=[64], rew_lim=1, activation=nn.ReLU, output_activation=nn.Tanh,
                 drop_prob=0.5, pref_learning_output_logit_type='sum', normalize_seg_rew=False):
        super(LSTMBasedRewardNet, self).__init__()
        self.input_size = input_size
        self.output_size = output_size
        self.rew_lim = rew_lim
        self.pref_learning_output_logit_type = pref_learning_output_logit_type  # 'sum' or 'last

        self.lstm_n_layers = lstm_n_layers
        self.lstm_hidden_dim = lstm_hidden_dim
        # LSTM layers
        self.lstm = nn.LSTM(self.input_size, self.lstm_hidden_dim, self.lstm_n_layers, dropout=drop_prob,
                            batch_first=True)
        # Fully connected layers
        self.fc_layers = nn.ModuleList()
        fc_sizes = [self.lstm_hidden_dim] + fc_hidden_sizes + [self.output_size]
        for j in range(len(fc_sizes) - 2):
            self.fc_layers += [nn.Linear(fc_sizes[j], fc_sizes[j + 1]), activation(), nn.Dropout(drop_prob)]

        # Output layer
        self.fc_layers += [nn.Linear(fc_sizes[-2], fc_sizes[-1]), output_activation()]

    def forward(self, obs, act, obs2, mem_len=None, seg_len=None):
        # To determine how to deal with the output, mem_len and seg_len cannot be not None simultaneously.
        if mem_len is not None and seg_len is not None:
            raise ValueError('mem_len and seg_len cannot be both not None!')
        if obs.ndim != 3:
            raise ValueError('Input have incorrect format: obs.ndim={}!'.format(obs.ndim))
        if mem_len is None and seg_len is None:
            if obs.shape[1] != 1:
                raise ValueError('When mem_len and seg_len are None, obs.shape[1] must be 1!')

        # Generate the input to the neural networks
        if obs2 is None:
            x = torch.cat([obs, act], dim=2)
        elif obs is None and act is None:
            x = obs2
        else:
            x = torch.cat([obs, act, obs2], dim=2)

        # Packs a Tensor containing padded sequences of variable length.
        if mem_len is None and seg_len is None:
            lengths = torch.tensor([x.size(1) for _ in range(x.size(0))])
        else:
            lengths = mem_len if mem_len is not None else seg_len
        x_packed = pack_padded_sequence(x, lengths=lengths, batch_first=True, enforce_sorted=False)

        # LSTM layers
        output_packed, (hidden_state, cell_state) = self.lstm(x_packed)
        output_padded, output_lengths = pad_packed_sequence(output_packed, batch_first=True)

        # Fully connected layer
        output = output_padded
        for layer in self.fc_layers:
            output = layer(output)
        output = self.rew_lim * output

        # Format output for different scenario
        pref_learning_output_logit = None
        if mem_len is None and seg_len is not None:
            # Reward for Preference Learning
            # In this case, the batch of the left segments is concatenated with the right segments, so the batch size is the half.
            batch_size = int(x.size(0) / 2)
            # The following two methods both work.
            if self.pref_learning_output_logit_type == 'sum':
                # Option 1: Sum over segment
                reduced_output = torch.stack([output[seg_i, :seg_len[seg_i].int()].sum() for seg_i in range(output.shape[0])]).reshape((-1, 1))
                if self.normalize_seg_rew:
                    reduced_output = reduced_output / seg_len     # Normalize by seg_len as segments may have different lengths
            elif self.pref_learning_output_logit_type == 'last':
                # Option 2: Only last of segment
                reduced_output = torch.stack([output[seg_i, seg_len.long()[seg_i] - 1, 0] for seg_i in range(output.shape[0])]).reshape((-1, 1))
            else:
                raise ValueError('Wrong output_logit_type: {}'.format(self.ouput_logit_type))
            pref_learning_output_logit = torch.cat(torch.split(reduced_output, [batch_size, batch_size], dim=0), dim=1)
        elif mem_len is not None and seg_len is None:
            # Reward with memory for Internal Environment or Learning Agent needs to recalculate reward with memory
            # Only retrieve the last prediction of segment
            reduced_output = torch.stack([output[mem_i, mem_len.long()[mem_i] - 1, 0] for mem_i in range(output.shape[0])]).reshape((-1, 1))
        elif mem_len is None and seg_len is None:
            # Reward without memory for Internal Environment or Learning Agent to recalculate reward
            reduced_output = output
        else:
            raise ValueError('mem_len and seg_len cannot be both not None!')

        return reduced_output, pref_learning_output_logit

    def init_hidden(self, batch_size):
        pass


class RNNBasedRewardNet(nn.Module):
    def __init__(self):
        super(RNNBasedRewardNet, self).__init__()

    def forward(self):
        pass

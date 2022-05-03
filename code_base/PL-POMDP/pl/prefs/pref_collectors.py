import multiprocessing
import os
import os.path as osp
import uuid
import random
import numpy as np
from collections import deque

from pl.envs.env import make_gym_task
from pl.prefs.seg_sampling import segments_from_rollout, sample_segment_from_path
from pl.prefs.pretrain_agent import PrefLearningPretrainRandomAgent, PrefLearningPretrainTD3Agent
from pl.video import write_segment_to_video, upload_to_gcs
from pl.prefs.label_schedules import LabelAnnealer
from pl.mems.ram_mems import RamSegmentBuffer

import torch
from torch.nn.utils.rnn import pad_sequence


# class PreferenceBatch:
#     def __init__(self, data):
#         # Concatenate
#         # 'obs_traj', "act_traj", 'obs2_traj', 'orig_rew_traj', 'done_traj', 'human_obs_traj'
#         left_obs = np.asarray(np.concatenate([comp['left']['obs_traj'] for comp in data]))
#         left_act = np.asarray(np.concatenate([comp['left']['act_traj'] for comp in data]))
#         left_obs2 = np.asarray(np.concatenate([comp['left']['obs2_traj'] for comp in data]))
#         left_seg_len = np.asarray([comp['left']['seg_len'] for comp in data])
#
#         right_obs = np.asarray(np.concatenate([comp['right']['obs_traj'] for comp in data]))
#         right_act = np.asarray(np.concatenate([comp['right']['act_traj'] for comp in data]))
#         right_obs2 = np.asarray(np.concatenate([comp['right']['obs2_traj'] for comp in data]))
#         right_seg_len = np.asarray([comp['right']['seg_len'] for comp in data])
#
#         labels = np.asarray([comp['label'] for comp in data])
#
#         self.obs = torch.cat([torch.tensor(left_obs), torch.tensor(right_obs)]).float()  # convert float64 to float
#         self.act = torch.cat([torch.tensor(left_act), torch.tensor(right_act)]).float()
#         self.obs2 = torch.cat([torch.tensor(left_obs2), torch.tensor(right_obs2)]).float()
#
#         self.seg_len = torch.cat([torch.tensor(left_seg_len), torch.tensor(right_seg_len)]).float()
#         self.labels = torch.tensor(labels).long()
#
#     def pin_memory(self):
#         self.obs = self.obs.pin_memory()
#         self.act = self.act.pin_memory()
#         self.obs2 = self.obs2.pin_memory()
#         self.seg_len = self.seg_len.pin_memory()
#         self.labels = self.labels.pin_memory()
#         return self


class PreferenceBatch:
    def __init__(self, data):
        # Concatenate
        # 'obs_traj', "act_traj", 'obs2_traj', 'orig_rew_traj', 'done_traj', 'human_obs_traj'
        # 'obs_traj', "act_traj", 'obs2_traj' are 2d-array
        left_obs = np.asarray(np.concatenate([comp['left_seg_obs_traj'] for comp in data]))
        left_act = np.asarray(np.concatenate([comp['left_seg_act_traj'] for comp in data]))
        left_obs2 = np.asarray(np.concatenate([comp['left_seg_obs2_traj'] for comp in data]))
        left_seg_len = np.asarray([comp['left_seg_length'] for comp in data])

        right_obs = np.asarray(np.concatenate([comp['right_seg_obs_traj'] for comp in data]))
        right_act = np.asarray(np.concatenate([comp['right_seg_act_traj'] for comp in data]))
        right_obs2 = np.asarray(np.concatenate([comp['right_seg_obs2_traj'] for comp in data]))
        right_seg_len = np.asarray([comp['right_seg_length'] for comp in data])

        if 'pref_label' in data[0]:
            labels = np.asarray([comp['pref_label'] for comp in data])
        else:
            labels = None

        # Concatenate sequentially left segment and right segment.
        self.obs = torch.cat([torch.tensor(left_obs), torch.tensor(right_obs)]).float()  # convert float64 to float
        self.act = torch.cat([torch.tensor(left_act), torch.tensor(right_act)]).float()
        self.obs2 = torch.cat([torch.tensor(left_obs2), torch.tensor(right_obs2)]).float()

        self.seg_len = torch.cat([torch.tensor(left_seg_len), torch.tensor(right_seg_len)]).float()
        if labels is not None:
            self.labels = torch.tensor(labels).long()
        else:
            self.labels = labels

    def pin_memory(self):
        self.obs = self.obs.pin_memory()
        self.act = self.act.pin_memory()
        self.obs2 = self.obs2.pin_memory()
        self.seg_len = self.seg_len.pin_memory()
        if self.labels is not None:
            self.labels = self.labels.pin_memory()
        return self


def mlp_reward_collate_fn(batch):
    return PreferenceBatch(batch)


class LSTMRewardPreferenceBatch:
    def __init__(self, data):
        # Concatenate segments of the left and the right sequentially, then pad segments with 0 just in case segments with different length
        self.obs = pad_sequence(
            [torch.tensor(comp['left_seg_obs_traj']) for comp in data] + [torch.tensor(comp['right_seg_obs_traj']) for comp in data],
            batch_first=True).float()    # convert float64 to float
        self.act = pad_sequence(
            [torch.tensor(comp['left_seg_act_traj']) for comp in data] + [torch.tensor(comp['right_seg_act_traj']) for comp in data],
            batch_first=True).float()    # convert float64 to float
        self.obs2 = pad_sequence(
            [torch.tensor(comp['left_seg_obs2_traj']) for comp in data] + [torch.tensor(comp['right_seg_obs2_traj']) for comp in data],
            batch_first=True).float()    # convert float64 to float
        self.seg_len = torch.tensor(np.asarray([comp['left_seg_length'] for comp in data]+[comp['right_seg_length'] for comp in data]))
        self.labels = torch.tensor(np.asarray([comp['pref_label'] for comp in data])).long()

    def pin_memory(self):
        self.obs = self.obs.pin_memory()
        self.act = self.act.pin_memory()
        self.obs2 = self.obs2.pin_memory()
        self.seg_len = self.seg_len.pin_memory()
        self.labels = self.labels.pin_memory()
        return self


def lstm_reward_collate_fn(batch):
    return LSTMRewardPreferenceBatch(batch)


class PreferenceCollector(object):
    def __init__(self):
        pass

    def collect_pretrain_preferences(self):
        """Preferences are collected for pretraining purposes."""
        pass

    def collect_online_preferences(self, path):
        """Preferences are collected based on segments sampled from online interaction trajectories."""
        pass

    def add_segment_pair(self, left_seg, right_seg):
        """Add a new unlabeled comparison from a segment pair"""
        pass


class SyntheticPreferenceCollector(object):
    def __init__(self, env, env_make_fn, env_id, env_dp_type, env_seed,
                 mem_manager, reward_component,
                 pretrain_label_num, total_label_num,
                 pretrain_agent_type='random', pretrain_agent_checkpoint_dir=None, pretrain_agent_hyperparams=None,
                 online_preferences_collection_method="only_from_recent",
                 results_output_dir=None,
                 pretrain_segment_sample_workers=1,
                 render_video=False,
                 video_clip_length_in_steps=60, video_clip_dir=None, checkpoint_dir=None):
        # Environment
        self.env = env
        self.env_make_fn = env_make_fn
        self.env_id = env_id
        self.env_dp_type = env_dp_type
        self.env_seed = env_seed
        # env = env_make_fn(env_id, env_seed, env_dp_type=env_dp_type)

        #
        assert checkpoint_dir is not None, "Checkpoint_dir is None!"
        os.makedirs(checkpoint_dir, exist_ok=True)
        self.cp_dir = checkpoint_dir

        self.results_output_dir = results_output_dir

        # Pretrain related
        self.pretrain_label_num = pretrain_label_num
        self.pretrain_segment_sample_workers = pretrain_segment_sample_workers

        self.total_label_num = total_label_num
        self.max_seg_num_per_collect = 400      # To reduce memory consumption, limit segments that can be collected for each collection.
        self.online_preferences_collection_method = online_preferences_collection_method #"maximum_distance_based"    # "one_from_recent_another_from_past"
        if self.online_preferences_collection_method == "maximum_distance_based":
            self.add_seg_pair_distance = True
        else:
            self.add_seg_pair_distance = False

        # Load preference learning pretrain agents
        self.pl_pretrain_agent_set = {}
        if pretrain_agent_type == 'random':
            # Random pretrain agent
            pretrain_agent_name = 'random_pretrain_agent'
            self.pl_pretrain_agent_set[pretrain_agent_name] = PrefLearningPretrainRandomAgent(env.observation_space, env.action_space,
                                                                                              pretrain_agent_name=pretrain_agent_name)
        elif pretrain_agent_type == 'TD3':
            # TD3 pretrain agent
            pretrain_agent_name = 'TD3_pretrain_agent'
            self.pl_pretrain_agent_set[pretrain_agent_name] = PrefLearningPretrainTD3Agent(env.observation_space, env.action_space,
                                                                                           pretrain_agent_checkpoint_dir,
                                                                                           pretrain_agent_hyperparams,
                                                                                           pretrain_agent_name=pretrain_agent_name)
        elif pretrain_agent_type == 'mixed_agent':
            pretrain_agent_name = 'random_pretrain_agent'
            self.pl_pretrain_agent_set['random_pretrain_agent'] = PrefLearningPretrainRandomAgent(env.observation_space, env.action_space,
                                                                                                  pretrain_agent_name=pretrain_agent_name)
            pretrain_agent_name = 'TD3_pretrain_agent'
            self.pl_pretrain_agent_set['TD3_pretrain_agent'] = PrefLearningPretrainTD3Agent(env.observation_space, env.action_space,
                                                                                            pretrain_agent_checkpoint_dir,
                                                                                            pretrain_agent_hyperparams,
                                                                                            pretrain_agent_name=pretrain_agent_name)
        else:
            raise ValueError('Wrong pretrain_agent_type: {}'.format(pretrain_agent_type))

        self.mem_manager = mem_manager
        self.reward_component = reward_component

        # Init the number of segment and preferences have been collected
        self.collected_seg_num, self.collected_pref_num = self._init_meta_info()
        if self.collected_pref_num < self.pretrain_label_num:
            self.collected_pretraining_preferences = False
            self.pretrain_label_num -= self.collected_pref_num
        else:
            self.collected_pretraining_preferences = True
            self.pretrain_label_num = 0     # No need of pretrain label

        self.video_clip_length_in_steps = video_clip_length_in_steps   # in frames
        self.render_video = render_video
        self.video_clip_dir = video_clip_dir

        # 90% of comparisons will go to training dataset.
        self.training_probability = 0.9

        self.label_schedule = LabelAnnealer(self.pretrain_label_num, self.total_label_num)
        self.segments_for_online_path = 2
        self.recent_segment_num = 200    # Keep a queue of recently seen segments to pull new comparisons from
        self.recent_segment_idxs = deque(maxlen=self.recent_segment_num)
        self.recent_seg_buffer_operator = RamSegmentBuffer()

        self._steps_since_last_training = 0
        self._n_timesteps_per_predictor_training = 1e3   # How often should we train our predictor?

    def _init_meta_info(self):
        collected_seg_num = self.mem_manager.collected_seg_num
        collected_pref_num = self.mem_manager.collected_pref_num
        return collected_seg_num, collected_pref_num

    def collect_pretraining_preferences(self, reward_comp=None):
        """Collect pretraining preferences"""
        print("Starting rollouts to generate pretraining segments. No learning will take place...")

        # To reduce memory consumption, collect multiple times. As the while loop in segments_from_rand_rollout
        #   does not free memory automatically in time.
        total_pretrain_seg_num = self.pretrain_label_num*2

        pretrain_seg_num_for_each_agent = (total_pretrain_seg_num // len(self.pl_pretrain_agent_set))
        pretrain_seg_num_for_last_agent = pretrain_seg_num_for_each_agent+total_pretrain_seg_num % len(self.pl_pretrain_agent_set)

        pretrain_seg_allocate = {}
        for pretrain_agent_name in self.pl_pretrain_agent_set:
            pretrain_seg_allocate[pretrain_agent_name] = {}
            pretrain_seg_allocate[pretrain_agent_name]['pretrain_agent'] = self.pl_pretrain_agent_set[pretrain_agent_name]

            # Allocate segments for each agent
            segment_num = 0
            if pretrain_agent_name != list(self.pl_pretrain_agent_set.keys())[-1]:
                segment_num = pretrain_seg_num_for_each_agent
            else:
                segment_num = pretrain_seg_num_for_last_agent
            # If segment_num is greater than max_seg_num_per_collect, cut it into smaller pieces.
            if segment_num > self.max_seg_num_per_collect:
                seg_num_list = [self.max_seg_num_per_collect for i in range(segment_num // self.max_seg_num_per_collect)]
                if segment_num % self.max_seg_num_per_collect != 0:
                    seg_num_list.append(segment_num % self.max_seg_num_per_collect)
            else:
                seg_num_list = [segment_num]
            pretrain_seg_allocate[pretrain_agent_name]['seg_num_list'] = seg_num_list

        # Sample segments for each pretrain_agent
        for pretrain_agent_name in pretrain_seg_allocate:
            print('Collect segments from {}'.format(pretrain_agent_name))
            for seg_num in pretrain_seg_allocate[pretrain_agent_name]['seg_num_list']:
                segments = segments_from_rollout(self.env,
                                                 pl_pretrain_agent=pretrain_seg_allocate[pretrain_agent_name]['pretrain_agent'],
                                                 memory_manager=self.mem_manager,
                                                 reward_component=self.reward_component,
                                                 render_video=self.render_video,
                                                 video_dir=self.video_clip_dir,
                                                 n_desired_segments=seg_num,
                                                 video_clip_length_in_steps=self.video_clip_length_in_steps,
                                                 workers=self.pretrain_segment_sample_workers)
                # segments = segments_from_rollout(self.env_make_fn, env_id=self.env_id, env_dp_type=self.env_dp_type, env_seed=self.env_seed,
                #                                  pl_pretrain_agent=pretrain_seg_allocate[pretrain_agent_name]['pretrain_agent'],
                #                                  memory_manager=self.mem_manager,
                #                                  reward_component=self.reward_component,
                #                                  render_video=self.render_video,
                #                                  video_dir=self.video_clip_dir,
                #                                  n_desired_segments=seg_num,
                #                                  video_clip_length_in_steps=self.video_clip_length_in_steps,
                #                                  workers=self.pretrain_segment_sample_workers)
                # Add segments to memory database
                for seg in segments:
                    self.mem_manager.store_segment(seg['seg_start_id'], seg['seg_end_id'], seg['behavior_mode'],
                                                   add_seg_pair_distance=self.add_seg_pair_distance, reward_comp=reward_comp)
                    self.collected_seg_num += 1
                    self.recent_segment_idxs.append(self.collected_seg_num)

        print('Successfully collected {} segments for pretraining preference labels.'.format(total_pretrain_seg_num))

        print("Adding segment pairs and labelling")
        # 2. Add new segment within [new_seg_start_id, new_seg_end_id], to preference pairs
        for pretrain_label_i in range(self.pretrain_label_num):  # Turn segments into comparisons
            left_seg_id = random.randint(1, self.mem_manager.collected_seg_num)
            right_seg_id = random.randint(1, self.mem_manager.collected_seg_num)
            # seg_1_id, seg_2_id = self.mem_manager.retrieve_top_n_unlabeled_pairs(top_n=1)
            # left_seg_id = seg_1_id[0]
            # right_seg_id = seg_2_id[0]
            self.add_segment_pair(left_seg_id=left_seg_id, right_seg_id=right_seg_id)
        print("{} synthetic labels generated... ".format(self.pretrain_label_num))

    def collect_online_preferences(self, path, elapsed_steps, total_steps, reward_comp=None):
        """Collect preferences throughout the interacting with the environment."""
        path_length = len(path['exp_id_traj'])
        self._steps_since_last_training += path_length

        # We may be in a new part of the environment, so we take new segments to build comparisons from
        # Note: For synthetic preferences, we don't need to render videos, so only sample segments is enough.
        for _ in range(self.segments_for_online_path):
            segment = sample_segment_from_path(path, self.video_clip_length_in_steps)
            if segment is not None:
                # Add segment to database
                self.mem_manager.store_segment(segment['seg_start_id'], segment['seg_end_id'], segment['behavior_mode'],
                                               add_seg_pair_distance=self.add_seg_pair_distance, reward_comp=reward_comp)
                self.collected_seg_num += 1
                self.recent_segment_idxs.append(self.collected_seg_num)
        self.mem_manager.commit()

        # If we need more comparisons, then we build them from either only recent segments or all segments.
        if self.collected_pref_num < int(self.label_schedule.n_desired_labels(elapsed_steps, total_steps)):
            if self.online_preferences_collection_method == "only_from_recent":
                # Collect online preferences only from recent segments
                left_seg_id = random.choice(self.recent_segment_idxs)
                right_seg_id = random.choice(self.recent_segment_idxs)
            elif self.online_preferences_collection_method == "one_from_recent_another_from_past":
                # Collect online preferences from segment pairs where one from recent segments and another from past segments
                left_seg_id = random.choice(self.recent_segment_idxs)
                if self.collected_seg_num > len(self.recent_segment_idxs):
                    right_seg_sample_end_id = int(self.collected_seg_num - len(self.recent_segment_idxs))
                else:
                    right_seg_sample_end_id = self.collected_seg_num
                right_seg_id = random.randint(1, right_seg_sample_end_id)
            elif self.online_preferences_collection_method == "from_all":
                # Collect online preferences from all segments
                left_seg_id = random.randint(1, self.collected_seg_num)
                right_seg_id = random.randint(1, self.collected_seg_num)
            elif self.online_preferences_collection_method == "mixed_recent_and_past":
                # Mix the previous methods by randomly selecting one of them
                pass
            elif self.online_preferences_collection_method == "count_based":
                pass
            elif self.online_preferences_collection_method == "maximum_distance_based":
                # TODO: sample segments based on diversity maximization
                seg_1_id, seg_2_id = self.mem_manager.retrieve_top_n_unlabeled_pairs(top_n=1)
                left_seg_id = seg_1_id[0]
                right_seg_id = seg_2_id[0]
            else:
                raise ValueError("Wrong online_preferences_collection_method={}!".format(self.online_preferences_collection_method))
            self.add_segment_pair(left_seg_id=left_seg_id, right_seg_id=right_seg_id)

    def add_segment_pair(self, left_seg_id, right_seg_id):
        """Add a new comparison of a segment pair"""
        # Retrieve segments
        left_seg, left_seg_traj = self.mem_manager.sample_segment(left_seg_id)
        right_seg, right_seg_traj = self.mem_manager.sample_segment(right_seg_id)

        # Mutate the comparison and give it the new label
        if left_seg_traj['hc_rew'].values.sum() > right_seg_traj['hc_rew'].values.sum():
            pref_choice = 'Left is better'
            pref_label = 0
        elif left_seg_traj['hc_rew'].values.sum() < right_seg_traj['hc_rew'].values.sum():
            pref_choice = 'Right is better'
            pref_label = 1
        else:
            # Can't tell case will not be saved.
            pref_choice = "Can't tell!"
            pref_label = -1

        # Separately store in training and test dataset.
        train_set = True if np.random.rand() <= self.training_probability else False
        self.mem_manager.store_preference(seg_1_id=left_seg['id'], seg_2_id=right_seg['id'],
                                          time_spend_for_labeling=None, teacher_id=None,
                                          pref_choice=pref_choice, pref_label=pref_label, train_set=train_set)
        self.collected_pref_num += 1

    def __len__(self):
        return len(self.training_dataset)+len(self.test_dataset)

    def save_checkpoint(self):
        """time_step: specify the checkpoint version."""
        # Checkpoint: Local variables
        return {'recent_segment_idxs': self.recent_segment_idxs}

    def restore_checkpoint(self, restore_elements, mem_manager):
        """time_step: specify the checkpoint version."""
        #
        self.recent_segment_idxs = restore_elements['recent_segment_idxs']

        # restore memory
        self.mem_manager = mem_manager

        self.collected_seg_num, self.collected_pref_num = self._init_meta_info()

        if self.collected_pref_num < self.pretrain_label_num:
            self.collected_pretraining_preferences = False
            self.pretrain_label_num -= self.collected_pref_num
        else:
            self.collected_pretraining_preferences = True
            self.pretrain_label_num = 0

    @property
    def training_dataset(self):
        return self.mem_manager.local_db_pref_table_op.training_dataset

    @property
    def test_dataset(self):
        return self.mem_manager.local_db_pref_table_op.test_dataset

    @property
    def labeled_comparisons(self):
        return [comp for comp in self.training_comp_dataset if comp['label'] is not None] + [comp for comp in
                                                                                             self.test_comp_dataset if
                                                                                             comp['label'] is not None]

    @property
    def labeled_training_comparisons(self):
        return [comp for comp in self.training_comp_dataset if comp['label'] is not None]

    @property
    def labeled_test_comparisons(self):
        return [comp for comp in self.test_comp_dataset if comp['label'] is not None]

    @property
    def labeled_decisive_training_comparisons(self):
        return [comp for comp in self.training_comp_dataset if comp['label'] in [0, 1]]

    @property
    def labeled_decisive_test_comparisons(self):
        return [comp for comp in self.test_comp_dataset if comp['label'] in [0, 1]]

    @property
    def unlabeled_training_comparisons(self):
        return [comp for comp in self.training_comp_dataset if comp['label'] is None]

    @property
    def unlabeled_test_comparisons(self):
        return [comp for comp in self.test_comp_dataset if comp['label'] is None]

    def label_unlabeled_comparisons(self):
        #
        for comp in self.unlabeled_training_comparisons:
            self._add_synthetic_label(comp)
        for comp in self.unlabeled_test_comparisons:
            self._add_synthetic_label(comp)

    @staticmethod
    def _add_synthetic_label(comparison):
        left_seg = comparison['left']
        right_seg = comparison['right']
        left_has_more_rew = np.sum(left_seg["orig_rew_traj"]) > np.sum(right_seg["orig_rew_traj"])

        # Mutate the comparison and give it the new label
        comparison['label'] = 0 if left_has_more_rew else 1


def _write_and_upload_video(env_id, gcs_path, local_path, segment):
    env = make_gym_task(env_id)
    write_segment_to_video(segment, fname=local_path, env=env)
    upload_to_gcs(local_path, gcs_path)


class HumanPreferenceCollector():
    def __init__(self, env_id, experiment_name):
        from human_feedback_api import Comparison

        self._comparisons = []
        self.env_id = env_id
        self.experiment_name = experiment_name
        self._upload_workers = multiprocessing.Pool(4)

        if Comparison.objects.filter(experiment_name=experiment_name).count() > 0:
            raise EnvironmentError("Existing experiment named %s! Pick a new experiment name." % experiment_name)

    def convert_segment_to_media_url(self, comparison_uuid, side, segment):
        tmp_media_dir = '/tmp/rl_teacher_media'
        media_id = "%s-%s.mp4" % (comparison_uuid, side)
        local_path = osp.join(tmp_media_dir, media_id)
        gcs_bucket = os.environ.get('RL_TEACHER_GCS_BUCKET')
        gcs_path = osp.join(gcs_bucket, media_id)
        self._upload_workers.apply_async(_write_and_upload_video, (self.env_id, gcs_path, local_path, segment))

        media_url = "https://storage.googleapis.com/%s/%s" % (gcs_bucket.lstrip("gs://"), media_id)
        return media_url

    def _create_comparison_in_webapp(self, left_seg, right_seg):
        """Creates a comparison DB object. Returns the db_id of the comparison"""
        from human_feedback_api import Comparison

        comparison_uuid = str(uuid.uuid4())
        comparison = Comparison(
            experiment_name=self.experiment_name,
            media_url_1=self.convert_segment_to_media_url(comparison_uuid, 'left', left_seg),
            media_url_2=self.convert_segment_to_media_url(comparison_uuid, 'right', right_seg),
            response_kind='left_or_right',
            priority=1.
        )
        comparison.full_clean()
        comparison.save()
        return comparison.id

    def add_segment_pair(self, left_seg, right_seg):
        """Add a new unlabeled comparison from a segment pair"""

        comparison_id = self._create_comparison_in_webapp(left_seg, right_seg)
        comparison = {
            "left": left_seg,
            "right": right_seg,
            "id": comparison_id,
            "label": None
        }

        self._comparisons.append(comparison)

    def __len__(self):
        return len(self._comparisons)

    @property
    def labeled_comparisons(self):
        return [comp for comp in self._comparisons if comp['label'] is not None]

    @property
    def labeled_decisive_comparisons(self):
        return [comp for comp in self._comparisons if comp['label'] in [0, 1]]

    @property
    def unlabeled_comparisons(self):
        return [comp for comp in self._comparisons if comp['label'] is None]

    def label_unlabeled_comparisons(self):
        from human_feedback_api import Comparison

        for comparison in self.unlabeled_comparisons:
            db_comp = Comparison.objects.get(pk=comparison['id'])
            if db_comp.response == 'left':
                comparison['label'] = 0
            elif db_comp.response == 'right':
                comparison['label'] = 1
            elif db_comp.response == 'tie' or db_comp.response == 'abstain':
                comparison['label'] = 'equal'
                # If we did not match, then there is no response yet, so we just wait

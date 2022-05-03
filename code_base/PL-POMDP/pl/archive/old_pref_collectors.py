import multiprocessing
import os
import os.path as osp
import uuid

import random
import numpy as np
from collections import deque

from pl.envs.env import make_gym_task
from pl.prefs.seg_sampling import sample_segment_from_path
from pl.video import write_segment_to_video, upload_to_gcs
from pl.prefs.label_schedules import LabelAnnealer
from pl.archive.db_mems import SegmentTableOperator
from pl.mems.ram_mems import RamSegmentBuffer, RamPreferenceBuffer

import torch


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
        left_obs = np.asarray(np.concatenate([comp['left_seg_obs_traj'] for comp in data]))
        left_act = np.asarray(np.concatenate([comp['left_seg_act_traj'] for comp in data]))
        left_obs2 = np.asarray(np.concatenate([comp['left_seg_obs2_traj'] for comp in data]))
        left_seg_len = np.asarray([comp['left_seg_length'] for comp in data])

        right_obs = np.asarray(np.concatenate([comp['right_seg_obs_traj'] for comp in data]))
        right_act = np.asarray(np.concatenate([comp['right_seg_act_traj'] for comp in data]))
        right_obs2 = np.asarray(np.concatenate([comp['right_seg_obs2_traj'] for comp in data]))
        right_seg_len = np.asarray([comp['right_seg_length'] for comp in data])

        labels = np.asarray([comp['pref_label'] for comp in data])

        self.obs = torch.cat([torch.tensor(left_obs), torch.tensor(right_obs)]).float()  # convert float64 to float
        self.act = torch.cat([torch.tensor(left_act), torch.tensor(right_act)]).float()
        self.obs2 = torch.cat([torch.tensor(left_obs2), torch.tensor(right_obs2)]).float()

        self.seg_len = torch.cat([torch.tensor(left_seg_len), torch.tensor(right_seg_len)]).float()
        self.labels = torch.tensor(labels).long()

    def pin_memory(self):
        self.obs = self.obs.pin_memory()
        self.act = self.act.pin_memory()
        self.obs2 = self.obs2.pin_memory()
        self.seg_len = self.seg_len.pin_memory()
        self.labels = self.labels.pin_memory()
        return self


def mlp_reward_collate_fn(batch):
    return PreferenceBatch(batch)


class LSTMRewardPreferenceBatch:
    def __init__(self, data):
        # Concatenate
        # 'obs_traj', "act_traj", 'obs2_traj', 'orig_rew_traj', 'done_traj', 'human_obs_traj'

        left_obs = np.asarray(np.stack([comp['left_seg_obs_traj'] for comp in data]))
        left_act = np.asarray(np.stack([comp['left_seg_act_traj'] for comp in data]))
        left_obs2 = np.asarray(np.stack([comp['left_seg_obs2_traj'] for comp in data]))
        left_seg_len = np.asarray([comp['left_seg_length'] for comp in data])

        right_obs = np.asarray(np.stack([comp['right_seg_obs_traj'] for comp in data]))
        right_act = np.asarray(np.stack([comp['right_seg_act_traj'] for comp in data]))
        right_obs2 = np.asarray(np.stack([comp['right_seg_obs2_traj'] for comp in data]))
        right_seg_len = np.asarray([comp['right_seg_length'] for comp in data])

        labels = np.asarray([comp['pref_label'] for comp in data])

        self.obs = torch.cat([torch.tensor(left_obs), torch.tensor(right_obs)]).float()  # convert float64 to float
        self.act = torch.cat([torch.tensor(left_act), torch.tensor(right_act)]).float()
        self.obs2 = torch.cat([torch.tensor(left_obs2), torch.tensor(right_obs2)]).float()

        self.seg_len = torch.cat([torch.tensor(left_seg_len), torch.tensor(right_seg_len)]).float()
        self.labels = torch.tensor(labels).long()

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
    def __init__(self, env_make_fn, env_id, env_dp_type,
                 seg_buffer_type, pref_buffer_type,
                 pretrain_label_num, total_label_num,
                 db_file='test_database', results_output_dir=None,
                 pretrain_segment_sample_workers=1,
                 render_video=False,
                 video_clip_length_in_frames=60, video_clip_dir=None, checkpoint_dir=None):
        # Environment
        self.env_make_fn = env_make_fn
        self.env_id = env_id
        self.env_dp_type = env_dp_type
        self.db_file = db_file
        #
        assert checkpoint_dir is not None, "Checkpoint_dir is None!"
        os.makedirs(checkpoint_dir, exist_ok=True)
        self.cp_dir = checkpoint_dir

        self.results_output_dir = results_output_dir

        # Pretrain related
        self.pretrain_label_num = pretrain_label_num
        self.total_label_num = total_label_num
        self.pretrain_segment_sample_workers = pretrain_segment_sample_workers
        self.seg_num_per_collect = 400
        self.seg_buffer_type = seg_buffer_type

        if seg_buffer_type=='DB':
            self.seg_buffer_operator = SegmentTableOperator(db_file)
        else:
            self.seg_buffer_operator = RamSegmentBuffer()
        if pref_buffer_type == 'DB':
            self.pref_buffer_operator = PreferenceDatabaseOperator(db_file)
        else:
            self.pref_buffer_operator = RamPreferenceBuffer()

        # Init the number of segment and preferences have been collected
        self.collected_seg_num, self.collected_pref_num = self._init_meta_info()
        if self.collected_pref_num < self.pretrain_label_num:
            self.collected_pretraining_preferences = False
            self.pretrain_label_num -= self.collected_pref_num
        else:
            self.collected_pretraining_preferences = True
            self.pretrain_label_num = 0

        self.video_clip_length_in_frames = video_clip_length_in_frames   # in frames
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
        collected_seg_num = self.seg_buffer_operator.collected_seg_num
        collected_pref_num = self.pref_buffer_operator.collected_pref_num
        return collected_seg_num, collected_pref_num

    def collect_pretraining_preferences(self):
        """Collect pretraining preferences"""
        # 1. Collect segments
        new_seg_start_id = self.seg_buffer_operator.collected_seg_num
        if new_seg_start_id==0:
            new_seg_start_id = 1

        print("Starting random rollouts to generate pretraining segments. No learning will take place...")
        # To reduce memory consumption, collect multiple times. As the while loop in segments_from_rand_rollout
        #   does not free memory automatically in time.
        total_pretrain_seg_num = self.pretrain_label_num*2
        if total_pretrain_seg_num <= self.seg_num_per_collect:
            seg_collect_list = [total_pretrain_seg_num]
        else:
            collect_times = int(total_pretrain_seg_num/self.seg_num_per_collect)
            seg_collect_list = [self.seg_num_per_collect for i in range(collect_times)]
            if total_pretrain_seg_num % self.seg_num_per_collect != 0:
                seg_collect_list += [total_pretrain_seg_num % self.seg_num_per_collect]
        from time import time
        for seg_num in seg_collect_list:
            start_time = time()
            segments = segments_from_rand_rollout(self.env_make_fn, env_id=self.env_id, env_dp_type=self.env_dp_type,
                                                   db_file=self.db_file, render_video=self.render_video,
                                                   video_dir=self.video_clip_dir,
                                                   n_desired_segments=seg_num,
                                                   video_clip_length_in_frames=self.video_clip_length_in_frames,
                                                   workers=self.pretrain_segment_sample_workers)
            print('Collect segments costs {}s'.format(time() - start_time))
            start_time = time()
            for seg in segments:
                self.seg_buffer_operator.store(seg)
                self.collected_seg_num += 1
                self.recent_segment_idxs.append(self.collected_seg_num)
            print('Store segments costs {}s'.format(time() - start_time))

        print('Successfully collected {} segments for pretraining preference labels.'.format(total_pretrain_seg_num))

        print("Adding segment pairs and labelling")
        # 2. Add new segment within [new_seg_start_id, new_seg_end_id], to preference pairs
        start_time = time()
        for seg_id in range(new_seg_start_id, new_seg_start_id+self.pretrain_label_num):  # Turn random segments into comparisons
            self.add_segment_pair(left_seg_id=seg_id,
                                  right_seg_id=seg_id+self.pretrain_label_num)
        print('Store preference costs {}s'.format(time() - start_time))
        print("{} synthetic labels generated... ".format(self.pretrain_label_num))

    def collect_online_preferences(self, path, elapsed_steps, total_steps):
        """Collect preferences throughout the interacting with the environment."""
        path_length = len(path['obs_traj'])
        self._steps_since_last_training += path_length

        # We may be in a new part of the environment, so we take new segments to build comparisons from
        # Note: For synthetic preferences, we don't need to render videos, so only sample segments is enough.
        for _ in range(self.segments_for_online_path):
            segment = sample_segment_from_path(path, self.video_clip_length_in_frames)
            if segment is not None:
                # Add segment to database
                self.seg_buffer_operator.store(segment)
                self.collected_seg_num += 1
                self.recent_segment_idxs.append(self.collected_seg_num)

        # If we need more comparisons, then we build them from our recent segments
        if self.collected_pref_num < int(self.label_schedule.n_desired_labels(elapsed_steps, total_steps)):
            self.add_segment_pair(left_seg_id=random.choice(self.recent_segment_idxs),
                                  right_seg_id=random.choice(self.recent_segment_idxs))

    def add_segment_pair(self, left_seg_id, right_seg_id):
        """Add a new comparison of a segment pair"""
        # Retrieve segments
        left_seg = self.seg_buffer_operator.sample_segment(left_seg_id)
        right_seg = self.seg_buffer_operator.sample_segment(right_seg_id)

        # Mutate the comparison and give it the new label
        # import pdb; pdb.set_trace()
        left_has_more_rew = np.sum(left_seg["orig_rew_traj"]) > np.sum(right_seg["orig_rew_traj"])
        pref_label = 0 if left_has_more_rew else 1

        # Separately store in training and test dataset.
        train_set = True if np.random.rand() <= self.training_probability else False
        self.pref_buffer_operator.store(left_seg, right_seg, pref_label, train_set)
        self.collected_pref_num += 1

    def __len__(self):
        return len(self.training_dataset)+len(self.test_dataset)

    def save_checkpoint(self, time_step):
        """time_step: specify the checkpoint version."""
        #
        cp_file = os.path.join(self.cp_dir, 'Step-{}_Checkpoint_Preference-Collector.pt'.format(time_step))
        save_elements = {'recent_segment_idxs': self.recent_segment_idxs}
        torch.save(save_elements, cp_file)
        # Rename the file to verify the completion of the saving in case of midway cutoff.
        verified_cp_file = os.path.join(self.cp_dir, 'Step-{}_Checkpoint_Preference-Collector_verified.pt'.format(time_step))
        os.rename(cp_file, verified_cp_file)

        #
        disk_db_seg_file = os.path.join(self.cp_dir, 'Step-{}_Checkpoint_DB-Segment.sqlite3'.format(time_step))
        self.seg_buffer_operator.dump_mem_db_to_disk_db(disk_db_seg_file)
        # Rename the file to verify the completion of the saving in case of midway cutoff.
        verified_disk_db_seg_file = os.path.join(self.cp_dir,
                                             'Step-{}_Checkpoint_DB-Segment_verified.sqlite3'.format(time_step))
        os.rename(disk_db_seg_file, verified_disk_db_seg_file)
        print('Successfully saved seg_buffer_operator with {} segments!'.format(
            self.seg_buffer_operator.collected_seg_num))

        #
        disk_db_pref_file = os.path.join(self.cp_dir, 'Step-{}_Checkpoint_DB-Preference.sqlite3'.format(time_step))
        self.pref_buffer_operator.dump_mem_db_to_disk_db(disk_db_pref_file)
        # Rename the file to verify the completion of the saving in case of midway cutoff.
        verified_disk_db_pref_file = os.path.join(self.cp_dir,
                                                 'Step-{}_Checkpoint_DB-Preference_verified.sqlite3'.format(time_step))
        os.rename(disk_db_pref_file, verified_disk_db_pref_file)
        print('Successfully saved pref_buffer_operator with {} preference labels!'.format(
            self.pref_buffer_operator.collected_pref_num))

    def restore_checkpoint(self, time_step):
        """time_step: specify the checkpoint version."""
        #
        cp_file = os.path.join(self.cp_dir, 'Step-{}_Checkpoint_Preference-Collector_verified.pt'.format(time_step))
        restore_elements = torch.load(cp_file)
        self.recent_segment_idxs = restore_elements['recent_segment_idxs']

        # restore Segments
        disk_db_seg_file = os.path.join(self.cp_dir,
                                        'Step-{}_Checkpoint_DB-Segment_verified.sqlite3'.format(time_step))
        self.seg_buffer_operator.load_disk_db_to_mem_db(disk_db_seg_file)
        print('Successfully restored seg_buffer_operator with {} segments!'.format(self.seg_buffer_operator.collected_seg_num))

        # restore Preferences
        disk_db_pref_file = os.path.join(self.cp_dir,
                                         'Step-{}_Checkpoint_DB-Preference_verified.sqlite3'.format(time_step))
        self.pref_buffer_operator.load_disk_db_to_mem_db(disk_db_pref_file)
        print('Successfully restored pref_buffer_operator with {} preference labels!'.format(self.pref_buffer_operator.collected_pref_num))

        self.collected_seg_num, self.collected_pref_num = self._init_meta_info()
        if self.collected_pref_num < self.pretrain_label_num:
            self.collected_pretraining_preferences = False
            self.pretrain_label_num -= self.collected_pref_num
        else:
            self.collected_pretraining_preferences = True
            self.pretrain_label_num = 0


    @property
    def training_dataset(self):
        return self.pref_buffer_operator.training_dataset

    @property
    def test_dataset(self):
        return self.pref_buffer_operator.test_dataset

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

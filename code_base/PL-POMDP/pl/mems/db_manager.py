"""
db_manager.py declares all necessary api for manipulate database tables.

sqlalchemy is used in order to make the implemented functions be database transparent.
"""
import os
from pl.pref_gui.las_teacher_gui.app_teacher_preference.db_config import db_table_config
import numpy as np
import pandas as pd
import random
import torch
import datetime
import sqlite3
import sqlalchemy as sqla
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.types import TypeDecorator, TEXT
from sqlalchemy.orm import sessionmaker
import json

Base = declarative_base()


class JSONEncodedArray(TypeDecorator):
    """
    Represents an numpy.array as a json-encoded text.
    Reference: https://docs.sqlalchemy.org/en/14/core/custom_types.html#sqlalchemy.types.TypeDecorator
    """
    impl = TEXT
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is not None:
            value = json.dumps(value.tolist())
        return value

    def process_result_value(self, value, dialect):
        if value is not None:
            value = np.asarray(json.loads(value))
        return value


def table_column_declare(table_config):
    table_columns = {}
    for column_name in table_config:
        col_data_type = table_config[column_name]["data_type"]
        col_default = table_config[column_name]["default"]
        col_primary_key = table_config[column_name]["primary_key"]
        col_foreign_key = table_config[column_name]["foreign_key"]
        # Define data_type
        if col_data_type == "int":
            data_type = sqla.Integer
        elif col_data_type == "float":
            data_type = sqla.Float
        elif col_data_type == "boolean":
            data_type == sqla.Boolean
        elif col_data_type == "text":
            data_type = sqla.Text
        elif col_data_type == "array":
            # data_type = sqla.ARRAY(sqla.Float)
            data_type = JSONEncodedArray
        elif col_data_type == "time":
            data_type = sqla.DateTime
        else:
            raise ValueError("col_data_type: {} not defined!".format())

        if column_name == "create_time":
            col_default = sqla.func.now()

        primary_key = True if col_primary_key is not None else False
        if col_foreign_key is not None:
            column = sqla.Column(data_type, sqla.ForeignKey('{}.{}'.format(col_foreign_key[0], col_foreign_key[1])),
                                 primary_key=primary_key, default=col_default)
        else:
            column = sqla.Column(data_type, primary_key=primary_key, default=col_default)
        table_columns[column_name] = column
    return table_columns


###########################################################################################
#                               Declare Database Tables                                   #
###########################################################################################
class ExperienceTable(Base):
    __tablename__ = "experience_table"
    table_columns = table_column_declare(db_table_config[__tablename__])
    # Convert to local variables
    for column_name in table_columns:
        vars()[column_name] = table_columns[column_name]


class SegmentTable(Base):
    __tablename__ = "segment_table"
    table_columns = table_column_declare(db_table_config[__tablename__])
    # Convert to local variables
    for column_name in table_columns:
        vars()[column_name] = table_columns[column_name]


class ExperienceAndSegmentMatchTable(Base):
    __tablename__ = "experience_and_segment_match_table"
    table_columns = table_column_declare(db_table_config[__tablename__])
    # Convert to local variables
    for column_name in table_columns:
        vars()[column_name] = table_columns[column_name]


class SegmentPairDistanceTable(Base):
    __tablename__ = "segment_pair_distance_table"
    table_columns = table_column_declare(db_table_config[__tablename__])
    # Convert to local variables
    for column_name in table_columns:
        vars()[column_name] = table_columns[column_name]


class PreferenceUserDemographicTable(Base):
    __tablename__ = "preference_user_demographic_table"
    table_columns = table_column_declare(db_table_config[__tablename__])
    # Convert to local variables
    for column_name in table_columns:
        vars()[column_name] = table_columns[column_name]


class PreferenceTable(Base):
    __tablename__ = "preference_table"
    table_columns = table_column_declare(db_table_config[__tablename__])
    # Convert to local variables
    for column_name in table_columns:
        vars()[column_name] = table_columns[column_name]


class PreferenceSurveyTable(Base):
    __tablename__ = "preference_survey_table"
    table_columns = table_column_declare(db_table_config[__tablename__])
    # Convert to local variables
    for column_name in table_columns:
        vars()[column_name] = table_columns[column_name]


class InteractiveExperienceSurveyTable(Base):
    __tablename__ = "interactive_experience_survey_table"
    table_columns = table_column_declare(db_table_config[__tablename__])
    # Convert to local variables
    for column_name in table_columns:
        vars()[column_name] = table_columns[column_name]


###########################################################################################
#                         Declare Database Table Operators                                #
###########################################################################################
class ExperienceTableOperator:
    """A replay buffer based on database."""

    def __init__(self, db_session, max_replay_size=1e6, table_name="experience"):
        """Initialize replay buffer"""

        self.max_replay_size = max_replay_size
        self.db_not_committed = False           # Indicating if commit() needs to be called.

        # Connect to database
        self.db_session = db_session

        # Initialize current replay buffer size if the number of previous experiences in database is larger than the
        # maximum of the reply buffer size set the current replay buffer to max_replay_size.
        self.replay_buffer_size = min(self.max_replay_size, self.db_session.query(ExperienceTable).count())
        self.start_id = 0
        max_id = self.db_session.query(sqla.func.max(ExperienceTable.id)).scalar()
        if max_id is None:
            self.end_id = 0
            self.replay_buffer_size = 0
            self.start_id = 1  # start_id always start from 1 in database table
        else:
            self.end_id = max_id
            self.replay_buffer_size = min(self.max_replay_size, max_id)
            self.start_id = self.end_id - self.replay_buffer_size + 1

    def store(self, obs, act, obs2, pb_rew, hc_rew, done, behavior_mode=None, obs_time=None, act_time=None, obs2_time=None):
        """Store experience into database"""
        experience = ExperienceTable(obs=obs, act=act, obs2=obs2, pb_rew=pb_rew, hc_rew=hc_rew, done=done, behavior_mode=behavior_mode,
                                     obs_time=obs_time, act_time=act_time, obs2_time=obs2_time)
        self.db_session.add(experience)

        # Commit is time-consuming, so only commit() when done or when updating the RL-agent in sample_batch.
        if done:
            self.db_session.commit()
            self.db_not_committed = False
        else:
            self.db_not_committed = True

        if self.replay_buffer_size < self.max_replay_size:
            self.replay_buffer_size += 1
            self.end_id += 1
        else:
            self.end_id += 1
            self.start_id += 1

    def sample_batch(self, batch_size=64, device=None, mem_len=None):
        """Sample a mini-batch of experiences"""
        # Commit if not.
        if self.db_not_committed:
            self.db_session.commit()
            self.db_not_committed = False

        # It's faster to use randint to generate random sample indices rather than fetching ids from the database.
        batch_idxs = [int(id_) for id_ in random.sample(list(np.arange(self.start_id, self.end_id+1, dtype=int)), min(batch_size, int(self.replay_buffer_size)))]  # Random sample without replacement

        # Fetch sampled experiences from database
        batch_df = pd.read_sql(self.db_session.query(ExperienceTable).filter(ExperienceTable.id.in_(batch_idxs)).statement, self.db_session.bind)

        # To speed up, do not update sampled number
        # # Increase the sampled_num of the sampled experiences
        # self.db_session.query(ExperienceTable).filter(ExperienceTable.id.in_(batch_idxs)).update({"sampled_num": ExperienceTable.sampled_num + 1})
        # self.db_session.commit()

        # Form batch tensor
        batch = dict(obs=np.stack(batch_df['obs']),
                     act=np.stack(batch_df['act']),
                     obs2=np.stack(batch_df['obs2']),
                     rew=np.stack(batch_df['pb_rew']),
                     hc_rew=np.stack(batch_df['hc_rew']),
                     done=np.stack(batch_df['done']))
        # Extract memory if mem_len is not None
        if mem_len is not None:
            obs_dim = len(batch_df['obs'][0])
            act_dim = len(batch_df['act'][0])
            batch['mem_seg_len'] = np.zeros(batch_size)
            batch['mem_seg_obs'] = np.zeros((batch_size, mem_len, obs_dim))
            batch['mem_seg_obs2'] = np.zeros((batch_size, mem_len, obs_dim))
            batch['mem_seg_act'] = np.zeros((batch_size, mem_len, act_dim))
            for sample_i, sample_id in enumerate(batch_idxs):
                # Note: start_id and id correspond to database entry id, so they start from 1 rather than 0.
                sample_start_id = max(1, sample_id - mem_len + 1)    # Init start id
                # If exist done before the last experience, start from the index next to the done.
                mem_seg_df = pd.read_sql(
                    self.db_session.query(ExperienceTable).filter(ExperienceTable.id.between(sample_start_id, sample_id)).statement,
                    self.db_session.bind)

                # Important: If there is done, except the one in the last index, within a fixed memory window, start only after the latest done,
                # so there is a '+1'.
                if len(np.where(mem_seg_df['done'].values[:-1] == 1)[0]) != 0:
                    sample_start_id = sample_start_id + (np.where(mem_seg_df['done'].values[:-1] == 1)[0][-1]) + 1

                sample_seg_len = sample_id - sample_start_id + 1
                batch['mem_seg_len'][sample_i] = sample_seg_len
                batch['mem_seg_obs'][sample_i, :sample_seg_len, :] = np.stack(mem_seg_df['obs'].values)[-sample_seg_len:]    # adjust the index to start from 0
                batch['mem_seg_obs2'][sample_i, :sample_seg_len, :] = np.stack(mem_seg_df['obs2'].values)[-sample_seg_len:]
                batch['mem_seg_act'][sample_i, :sample_seg_len, :] = np.stack(mem_seg_df['act'].values)[-sample_seg_len:]
        batch_tensor = {}
        for k, v in batch.items():
            if v is None:
                batch_tensor[k] = None
            else:
                # seg_len is used in pack_padded_sequence and should be on CPU, while others can be on GPU
                if k == 'mem_seg_len':
                    batch_tensor[k] = torch.as_tensor(v, dtype=torch.float32)
                else:
                    batch_tensor[k] = torch.as_tensor(v, dtype=torch.float32).to(device)
        return batch_tensor

    @property
    def last_experience_id(self):
        max_id = self.db_session.query(sqla.func.max(ExperienceTable.id)).scalar()
        return max_id

    def retrieve_last_experience_episode(self, episode_exp_start_id):
        # Commit if not.
        if self.db_not_committed:
            self.db_session.commit()
            self.db_not_committed = False

        last_experience_id = self.last_experience_id
        if episode_exp_start_id is None:
            new_episode_exp_start_id = 1
        else:
            new_episode_exp_start_id = last_experience_id + 1

        if episode_exp_start_id is None:
            last_path = None
        else:
            if episode_exp_start_id == last_experience_id or episode_exp_start_id > last_experience_id:
                import pdb; pdb.set_trace()
            last_episode = pd.read_sql(
                self.db_session.query(ExperienceTable).filter(ExperienceTable.id.between(episode_exp_start_id, last_experience_id)).statement,
                self.db_session.bind)
            last_path = {"exp_id_traj":  last_episode['id'].values,
                         "human_obs_traj": np.zeros(len(last_episode['id'].values)), "behavior_mode": last_episode['behavior_mode'].values[0]}

        return last_path, new_episode_exp_start_id

    def extract_id_corresponding_time_interval(self, start_datetime, end_datetime):
        exp_df = pd.read_sql(self.db_session.query(ExperienceTable).filter(sqla.and_(start_datetime <= ExperienceTable.obs_time, ExperienceTable.obs2_time <= end_datetime)).statement, self.db_session.bind)
        if len(exp_df) == 0:
            return None, None
        else:
            return exp_df['id'].values[0], exp_df['id'].values[-1]

class ExperienceAndSegmentMatchTableOperator:
    """The table saves the correspondence between segment and experience sequence."""
    def __init__(self, db_session):
        self.db_session = db_session

    def store(self, segment_id, experience_id):
        exp_and_seg_match = ExperienceAndSegmentMatchTable(segment_id=int(segment_id), experience_id=int(experience_id))
        self.db_session.add(exp_and_seg_match)

    def retrieve_segment_trajectory(self, segment_id):
        experience_id_trajectory = pd.read_sql(self.db_session.query(ExperienceTable).join(ExperienceAndSegmentMatchTable,
                                                                                           ExperienceAndSegmentMatchTable.experience_id == ExperienceTable.id).filter(
            ExperienceAndSegmentMatchTable.segment_id == segment_id).order_by(ExperienceTable.id.asc()).statement, self.db_session.bind)
        return experience_id_trajectory


class SegmentTableOperator:
    """Saving in and retrieve segments from database"""
    def __init__(self, db_session):
        self.db_session = db_session

        # Create experience table operator
        self.exp_op = ExperienceTableOperator(self.db_session)
        # Create experience and segment match table operator
        self.exp_seg_match_table_op = ExperienceAndSegmentMatchTableOperator(self.db_session)
        # Create segment_pair_distance table operator
        self.seg_pair_distance_op = SegmentPairDistanceTableOperator(self.db_session)

    @property
    def collected_seg_num(self):
        return self.db_session.query(SegmentTable).count()

    def store_video_clip(self, clip_url, time_format='%Y-%m-%d-%H-%M-%S', add_seg_pair_distance=False, reward_comp=None):
        match_results = pd.read_sql(self.db_session.query(SegmentTable).filter(SegmentTable.video_clip_url == clip_url).statement, self.db_session.bind)

        # Add video_clip to table if not exist
        if len(match_results) == 0:
            # Extract clip info
            clip_name = clip_url.split('/')[-1]
            clip_info = clip_name.split('_')
            clip_start_time = datetime.datetime.strptime(clip_info[0], time_format)
            clip_end_time = datetime.datetime.strptime(clip_info[1], time_format)
            clip_camera_name = clip_info[2]
            clip_behavior_mode = clip_info[3]

            # Extract corresponding experiences
            if clip_end_time > clip_start_time:
                seg_exp_start_id, seg_exp_end_id = self.exp_op.extract_id_corresponding_time_interval(clip_start_time, clip_end_time)
            else:
                raise ValueError("start_time={} > end_time={}!".format(clip_start_time, clip_end_time))
            if seg_exp_start_id is None or seg_exp_end_id is None:
                raise ValueError("No corresponding experience is found in ExperienceTable!")
            else:
                # Add segment
                self.store(seg_exp_start_id, seg_exp_end_id, clip_behavior_mode,
                           clip_camera_name, clip_url, clip_start_time, clip_end_time,
                           add_seg_pair_distance=add_seg_pair_distance, reward_comp=reward_comp)
        else:
            print("{} has already in table! Skip this insert operation.".format(clip_url))

    def store(self, seg_exp_start_id, seg_exp_end_id, behavior_mode,
              video_camera_name, video_clip_url, video_clip_start_time, video_clip_end_time,
              add_seg_pair_distance=False, reward_comp=None):
        # Store segment: (Note: psycopy2 cannot adapt numpy.int32, so we'll convert use int().)
        segment = SegmentTable(seg_exp_start_id=int(seg_exp_start_id), seg_exp_end_id=int(seg_exp_end_id), behavior_mode=behavior_mode,
                               video_camera_name=video_camera_name, video_clip_url=video_clip_url,
                               video_clip_start_time=video_clip_start_time, video_clip_end_time=video_clip_end_time)
        self.db_session.add(segment)
        self.db_session.commit()

        # Store experience and segment match
        seg_id = self.db_session.query(sqla.func.max(SegmentTable.id)).scalar()
        for exp_id in range(seg_exp_start_id, seg_exp_end_id + 1):
            self.exp_seg_match_table_op.store(seg_id, exp_id)
        self.db_session.commit()

        # Add segment pair distance for new seg_id
        if add_seg_pair_distance:
            if reward_comp is None:
                raise ValueError("Invalid reward_comp was provided!")
            self.seg_pair_distance_op.add_segment_pair_distance(seg_id, reward_comp)

    def sample_segment(self, seg_id):
        """Sample segment by id."""
        seg = pd.read_sql(self.db_session.query(SegmentTable).filter(SegmentTable.id.in_([seg_id])).statement, self.db_session.bind)

        # segment trajectory
        seg_trajectory = self.exp_seg_match_table_op.retrieve_segment_trajectory(seg_id)

        # Increase the sampled_num of the sampled segment
        self.db_session.query(SegmentTable).filter(SegmentTable.id.in_([seg_id])).update({"sampled_num": SegmentTable.sampled_num + 1})
        self.db_session.commit()

        return seg, seg_trajectory


class SegmentPairDistanceTableOperator:
    """The table saves the distance between two segments in a segment pair."""
    def __init__(self, db_session):
        self.db_session = db_session

        # Create experience and segment match table operator
        self.exp_seg_match_table_op = ExperienceAndSegmentMatchTableOperator(self.db_session)

    @property
    def exist_segment_ids(self):
        """Return exist segment ids in segment table."""
        return pd.read_sql(self.db_session.query(SegmentTable.id).statement, self.db_session.bind)['id'].values

    @property
    def last_seg_pair_distance_id(self):
        max_id = self.db_session.query(sqla.func.max(SegmentPairDistanceTable.id)).scalar()
        if max_id is None:
            max_id = 0
        return max_id

    def _convert_to_trajectory_sqlite(self, value):
        """Sqlite does not support np.ndarray, so this function is used to convert string to ndarray in pandas.DataFrame."""
        if isinstance(value, str):
            return np.asarray(json.loads('[{}]'.format(value)))
        else:
            return value.apply(self._convert_to_trajectory_sqlite)

    def _convert_to_trajectory_postgresql(self, value):
        if isinstance(value, pd.Series):
            return value.apply(np.stack)
        else:
            return value.apply(self._convert_to_trajectory_postgresql)

    def _retrieve_data(self, seg_pair_start_id, seg_pair_end_id):
        """train_set=1 if retrieving training set, otherwise train_set=0."""
        # Different databases have different aggregation functions, so they also need different apply function to form a trajectory in pandas.DataFrame.
        #   SQLite: group_concat, return a concatenated string.
        #   PostgreSQL: array_agg, return a concatenated array.
        sql_agg_func = None
        df_apply_func = None
        if self.db_session.bind.dialect.name == 'sqlite':
            sql_agg_func = sqla.func.group_concat
            df_apply_func = self._convert_to_trajectory_sqlite
        elif self.db_session.bind.dialect.name == 'postgresql':
            sql_agg_func = sqla.func.array_agg
            df_apply_func = self._convert_to_trajectory_postgresql
        else:
            raise ValueError('Aggregate function for {} is not defined!'.format(self.db_session.bind.dialect.name))

        # Left segment
        query = self.db_session.query(SegmentPairDistanceTable.id, SegmentPairDistanceTable.seg_1_id,
                                      SegmentPairDistanceTable.sampled_num,
                                      sql_agg_func(ExperienceTable.obs).label('left_seg_obs_traj'),
                                      sql_agg_func(ExperienceTable.act).label('left_seg_act_traj'),
                                      sql_agg_func(ExperienceTable.obs2).label('left_seg_obs2_traj'),
                                      sqla.func.count(ExperienceTable.obs2).label('left_seg_length')).join(SegmentTable,
                                                                                                           SegmentPairDistanceTable.seg_1_id == SegmentTable.id).join(
            ExperienceAndSegmentMatchTable, SegmentTable.id == ExperienceAndSegmentMatchTable.segment_id).join(ExperienceTable,
                                                                                                               ExperienceAndSegmentMatchTable.experience_id == ExperienceTable.id).filter(
            SegmentPairDistanceTable.id.between(seg_pair_start_id, seg_pair_end_id)).group_by(
            SegmentPairDistanceTable.id)

        # Note: Use DataFrame.group_by rather than SQL GROUP_BY
        left_segment = pd.read_sql(query.statement, self.db_session.bind)
        left_segment[["left_seg_obs_traj", "left_seg_act_traj", "left_seg_obs2_traj"]] = left_segment[
            ["left_seg_obs_traj", "left_seg_act_traj", "left_seg_obs2_traj"]].apply(df_apply_func)

        # Right segment
        query = self.db_session.query(SegmentPairDistanceTable.seg_2_id,
                                      sql_agg_func(ExperienceTable.obs).label('right_seg_obs_traj'),
                                      sql_agg_func(ExperienceTable.act).label('right_seg_act_traj'),
                                      sql_agg_func(ExperienceTable.obs2).label('right_seg_obs2_traj'),
                                      sqla.func.count(ExperienceTable.obs2).label('right_seg_length')).join(SegmentTable,
                                                                                                            SegmentPairDistanceTable.seg_2_id == SegmentTable.id).join(
            ExperienceAndSegmentMatchTable, SegmentTable.id == ExperienceAndSegmentMatchTable.segment_id).join(ExperienceTable,
                                                                                                               ExperienceAndSegmentMatchTable.experience_id == ExperienceTable.id).filter(
            SegmentPairDistanceTable.id.between(seg_pair_start_id, seg_pair_end_id)).group_by(
            SegmentPairDistanceTable.id)

        right_segment = pd.read_sql(query.statement, self.db_session.bind)
        right_segment[["right_seg_obs_traj", "right_seg_act_traj", "right_seg_obs2_traj"]] = right_segment[
            ["right_seg_obs_traj", "right_seg_act_traj", "right_seg_obs2_traj"]].apply(df_apply_func)

        # Combine left and right segment
        dataset = pd.concat([left_segment, right_segment], axis=1).to_dict('records')
        return dataset

    def _calculate_segment_pair_distance(self, seg_pair_start_id, seg_pair_end_id, reward_comp):
        """Calculate the segment pair distance for id in [seg_pair_start_id, seg_pair_end_id]."""
        # Add the entry then calculate distance in batch, which is faster.
        # Retrieve data
        dataset = self._retrieve_data(seg_pair_start_id, seg_pair_end_id)

        # Define dataset loader
        from torch.utils.data import DataLoader
        from pl.prefs.pref_collectors import mlp_reward_collate_fn, lstm_reward_collate_fn
        if reward_comp.reward_comp_type == "MLP":
            batch_collate_fn = mlp_reward_collate_fn
        elif self.reward_comp_type == "LSTM":
            batch_collate_fn = lstm_reward_collate_fn
        else:
            raise ValueError("Wrong reward_comp_type was set!")
        dataset_loader = DataLoader(dataset=dataset, batch_size=100, shuffle=False,
                                    collate_fn=batch_collate_fn, pin_memory=True)

        distance = []
        reward_comp.rew_comp.reward_net.eval()
        with torch.no_grad():
            for batch_i, batch in enumerate(dataset_loader):
                obs = batch.obs.to(reward_comp.reward_comp_device)
                act = batch.act.to(reward_comp.reward_comp_device)
                obs2 = batch.obs2.to(reward_comp.reward_comp_device)
                seg_len = batch.seg_len.to(reward_comp.reward_comp_device)

                # Set obs2 for different input type
                if reward_comp.reward_net_input_type == "obs_act_obs2":
                    pass
                elif reward_comp.reward_net_input_type == "obs_act":
                    obs2 = None
                elif reward_comp.reward_net_input_type == "obs2":
                    obs, act = None, None
                else:
                    raise ValueError("Wrong reward_net_input_type!")
                # forward + backward + optimize
                rew_pred, seg_reward_pred = reward_comp.rew_comp.reward_net(obs, act, obs2, seg_len=seg_len)
                if reward_comp.reward_comp_type == "MLP":
                    # Normalize segment reward as it's the summation of all rewards within a segment
                    batch_size = int(len(seg_len)/2)
                    normalized_seg_reward_pred = seg_reward_pred / torch.stack([seg_len[:batch_size], seg_len[batch_size:]], dim=1)
                    batch_distance = abs(normalized_seg_reward_pred[:, 0] - normalized_seg_reward_pred[:, 1]).tolist()
                    # seg_reward_pred = seg_reward_pred /
                elif self.reward_comp_type == "LSTM":
                    batch_distance = abs(seg_reward_pred[:, 0] - seg_reward_pred[:, 1]).tolist()
                else:
                    raise ValueError("Wrong reward_comp_type was set!")
                distance += batch_distance
        # Update distance
        for idx, seg_pair_id in enumerate(range(seg_pair_start_id, seg_pair_end_id+1)):
            self.db_session.query(SegmentPairDistanceTable).filter(SegmentPairDistanceTable.id == seg_pair_id).update({"distance": distance[idx]})
        self.db_session.commit()

    def add_segment_pair_distance(self, new_seg_id, reward_comp=None):
        """Add the distance between the segment_id and the all segments in segment table."""
        if reward_comp is None:
            raise ValueError("Invalid reward_comp was provided!")

        # Insert rows
        new_entry_start_id = self.last_seg_pair_distance_id + 1
        new_entry_end_id = self.last_seg_pair_distance_id
        for old_seg_id in self.exist_segment_ids:
            if old_seg_id != new_seg_id:
                # Add to table
                seg_pair = SegmentPairDistanceTable(seg_1_id=int(new_seg_id), seg_2_id=int(old_seg_id), sampled_num=0)
                self.db_session.add(seg_pair)
                new_entry_end_id += 1
        self.db_session.commit()
        # Calculate distance (Note: if new_entry_start_id>new_entry_end_id, it means no entry needs to be added.)
        if new_entry_start_id <= new_entry_end_id:
            self._calculate_segment_pair_distance(new_entry_start_id, new_entry_end_id, reward_comp)

    def update_segment_pair_distance(self, reward_comp, max_chunk_size = 1000):
        """Update segment_pair_distance table based on latest reward_component."""
        # Update the whole table in chunks in order to fit it into the memory
        start_idx = np.asarray([start_i for start_i in range(1, self.last_seg_pair_distance_id, max_chunk_size)])
        end_idx = start_idx + max_chunk_size - 1
        end_idx[-1] = min(end_idx[-1], self.last_seg_pair_distance_id)
        for chunk_i in range(len(start_idx)):
            self._calculate_segment_pair_distance(start_idx[chunk_i], end_idx[chunk_i], reward_comp)

    def retrieve_top_n_unlabeled_pairs(self, top_n=1):
        """Retrieve n unlabeled pairs with the top distance."""
        #
        seg_table_1 = sqla.orm.aliased(SegmentTable)
        seg_table_2 = sqla.orm.aliased(SegmentTable)
        query = self.db_session.query(SegmentPairDistanceTable, seg_table_1, seg_table_2).join(seg_table_1,
                                                                                               SegmentPairDistanceTable.seg_1_id == seg_table_1.id).join(
            seg_table_2,
            SegmentPairDistanceTable.seg_2_id == seg_table_2.id).filter(
            SegmentPairDistanceTable.sampled_num == 0)
        seg_pair_distance_df = pd.read_sql(query.statement, self.db_session.bind)
        seg_pair_distance_df['mix_distance_count'] = seg_pair_distance_df['distance'] + np.exp(-(seg_pair_distance_df['sampled_num_1'] + seg_pair_distance_df['sampled_num_2']))
        retrieved_pair = seg_pair_distance_df.sort_values('mix_distance_count', ascending=False).head(top_n)

        # retrieved_pair = pd.read_sql(self.db_session.query(SegmentPairDistanceTable).filter(SegmentPairDistanceTable.sampled_num == 0).order_by(
        #     SegmentPairDistanceTable.distance.desc()).limit(top_n).statement, self.db_session.bind)

        # Set sampled_num to 1
        self.db_session.query(SegmentPairDistanceTable).filter(SegmentPairDistanceTable.id.in_(retrieved_pair['id'].tolist())).update(
            {"sampled_num": SegmentPairDistanceTable.sampled_num + 1})

        return retrieved_pair['seg_1_id'].tolist(), retrieved_pair['seg_2_id'].tolist()


class PreferenceTableOperator:
    def __init__(self, db_session):
        self.db_session = db_session
        self.db_not_committed = False  # Indicating if commit() needs to be called.

    @property
    def collected_pref_num(self):
        return self.db_session.query(PreferenceTable).count()

    @property
    def training_dataset(self):
        # Commit is time-consuming, so only commit() when needing to retrieve.
        if self.db_not_committed:
            self.db_session.commit()
            self.db_not_committed = False
        training_dataset = self._retrieve_data(train_set=1)
        return training_dataset.to_dict('records')

    @property
    def test_dataset(self):
        # Commit is time-consuming, so only commit() when needing to retrieve.
        if self.db_not_committed:
            self.db_session.commit()
            self.db_not_committed = False
        test_dataset = self._retrieve_data(train_set=0)
        return test_dataset.to_dict('records')

    def _convert_to_trajectory_sqlite(self, value):
        """Sqlite does not support np.ndarray, so this function is used to convert string to ndarray in pandas.DataFrame."""
        if isinstance(value, str):
            return np.asarray(json.loads('[{}]'.format(value)))
        else:
            return value.apply(self._convert_to_trajectory_sqlite)

    def _convert_to_trajectory_postgresql(self, value):
        if isinstance(value, pd.Series):
            return value.apply(np.stack)
        else:
            return value.apply(self._convert_to_trajectory_postgresql)

    def _retrieve_data(self, train_set=1):
        """train_set=1 if retrieving training set, otherwise train_set=0."""
        # Different databases have different aggregation functions, so they also need different apply function to form a trajectory in pandas.DataFrame.
        #   SQLite: group_concat, return a concatenated string.
        #   PostgreSQL: array_agg, return a concatenated array.
        sql_agg_func = None
        df_apply_func = None
        if self.db_session.bind.dialect.name == 'sqlite':
            sql_agg_func = sqla.func.group_concat
            df_apply_func = self._convert_to_trajectory_sqlite
        elif self.db_session.bind.dialect.name == 'postgresql':
            sql_agg_func = sqla.func.array_agg
            df_apply_func = self._convert_to_trajectory_postgresql
        else:
            raise ValueError('Aggregate function for {} is not defined!'.format(self.db_session.bind.dialect.name))

        # Left segment
        query = self.db_session.query(PreferenceTable.id, PreferenceTable.seg_1_id, PreferenceTable.pref_choice,
                                      PreferenceTable.pref_label, PreferenceTable.time_spend_for_labeling, PreferenceTable.teacher_id,
                                      PreferenceTable.sampled_num,
                                      sql_agg_func(ExperienceTable.obs).label('left_seg_obs_traj'),
                                      sql_agg_func(ExperienceTable.act).label('left_seg_act_traj'),
                                      sql_agg_func(ExperienceTable.obs2).label('left_seg_obs2_traj'),
                                      sqla.func.count(ExperienceTable.obs2).label('left_seg_length')).join(SegmentTable,
                                                                                                       PreferenceTable.seg_1_id == SegmentTable.id).join(
            ExperienceAndSegmentMatchTable, SegmentTable.id == ExperienceAndSegmentMatchTable.segment_id).join(ExperienceTable,
                                                                                                               ExperienceAndSegmentMatchTable.experience_id == ExperienceTable.id).filter(
            sqla.and_(PreferenceTable.train_set == train_set, PreferenceTable.pref_label != -1)).group_by(PreferenceTable.id)

        # Note: Use DataFrame.group_by rather than SQL GROUP_BY
        left_segment = pd.read_sql(query.statement, self.db_session.bind)
        left_segment[["left_seg_obs_traj", "left_seg_act_traj", "left_seg_obs2_traj"]] = left_segment[
            ["left_seg_obs_traj", "left_seg_act_traj", "left_seg_obs2_traj"]].apply(df_apply_func)

        # Right segment
        query = self.db_session.query(PreferenceTable.seg_2_id,
                                      sql_agg_func(ExperienceTable.obs).label('right_seg_obs_traj'),
                                      sql_agg_func(ExperienceTable.act).label('right_seg_act_traj'),
                                      sql_agg_func(ExperienceTable.obs2).label('right_seg_obs2_traj'),
                                      sqla.func.count(ExperienceTable.obs2).label('right_seg_length')).join(SegmentTable,
                                                                                                            PreferenceTable.seg_2_id == SegmentTable.id).join(
            ExperienceAndSegmentMatchTable, SegmentTable.id == ExperienceAndSegmentMatchTable.segment_id).join(ExperienceTable,
                                                                                                               ExperienceAndSegmentMatchTable.experience_id == ExperienceTable.id).filter(
            sqla.and_(PreferenceTable.train_set == train_set, PreferenceTable.pref_label != -1)).group_by(PreferenceTable.id)

        right_segment = pd.read_sql(query.statement, self.db_session.bind)
        right_segment[["right_seg_obs_traj", "right_seg_act_traj", "right_seg_obs2_traj"]] = right_segment[
            ["right_seg_obs_traj", "right_seg_act_traj", "right_seg_obs2_traj"]].apply(df_apply_func)

        # Combine left and right segment
        dataset = pd.concat([left_segment, right_segment], axis=1)
        return dataset

    def store(self, seg_1_id, seg_2_id, pref_choice, pref_label, time_spend_for_labeling=None, teacher_id=None, train_set=True):
        # Add new preference record
        preference = PreferenceTable(seg_1_id=int(seg_1_id), seg_2_id=int(seg_2_id), pref_choice=pref_choice, pref_label=pref_label,
                                     time_spend_for_labeling=time_spend_for_labeling, teacher_id=teacher_id, train_set=int(train_set))
        self.db_session.add(preference)
        self.db_session.commit()

    def sample_preference(self):
        pass


class DatabaseManager:
    def __init__(self, local_db_config=None, cloud_db_config=None, checkpoint_dir=None, connect_cloud_db=False):
        self.checkpoint_dir = checkpoint_dir
        # Local database uses in-memory db, if going to submit job to ComputeCanada to avoid huge I/O load.
        if 'database' not in local_db_config or local_db_config['database'] is None:
            # In-memory database
            local_db_config['database'] = None
        else:
            # Disk database
            local_db_config['database'] = os.path.join(self.checkpoint_dir, local_db_config['database'])
        self.local_db_config = local_db_config
        self.cloud_db_config = cloud_db_config

        self._init_local_db_connection()
        self.episode_exp_start_id = self.local_db_exp_table_op.last_experience_id

        self.connect_cloud_db = connect_cloud_db    # Connect to cloud db only when need to use web-based survey
        if self.connect_cloud_db:
            self._init_cloud_db_connection()

    def _init_cloud_db_connection(self):
        if self.cloud_db_config is not None:
            self.cloud_db_url = sqla.engine.URL.create(**self.cloud_db_config)
        else:
            self.cloud_db_url = None

        # Create engine
        self.cloud_db_engine = sqla.create_engine(self.cloud_db_url) if self.cloud_db_url is not None else None

        # Create db tables if not exist
        if self.cloud_db_engine is not None:
            Base.metadata.create_all(self.cloud_db_engine)

        if self.cloud_db_engine is not None:
            # Init local database table operators
            self.cloud_db_session_maker = sessionmaker(bind=self.cloud_db_engine)
            self.cloud_db_session = self.cloud_db_session_maker()

            self.cloud_db_exp_table_op = ExperienceTableOperator(self.cloud_db_session)
            self.cloud_db_seg_table_op = SegmentTableOperator(self.cloud_db_session)
            self.cloud_db_pref_table_op = PreferenceTableOperator(self.cloud_db_session)
            self.cloud_db_seg_pair_dist_table_op = SegmentPairDistanceTableOperator(self.cloud_db_session)

        self.cloud_db_meta = sqla.MetaData()
        self.cloud_db_meta.reflect(bind=self.cloud_db_engine)

    def _init_local_db_connection(self):
        # Init database URL
        if self.local_db_config is not None:
            self.local_db_url = sqla.engine.URL.create(**self.local_db_config)
        else:
            self.local_db_url = None
            raise ValueError("Please provide local_db_config!")


        # Create engine
        self.local_db_engine = sqla.create_engine(self.local_db_url) if self.local_db_url is not None else None

        # Create db tables if not exist
        if self.local_db_engine is not None:
            Base.metadata.create_all(self.local_db_engine)

        # Init local database table operators
        if self.local_db_engine is not None:
            self.local_db_session_maker = sessionmaker(bind=self.local_db_engine)
            self.local_db_session = self.local_db_session_maker()

            self.local_db_exp_table_op = ExperienceTableOperator(self.local_db_session)
            self.local_db_seg_table_op = SegmentTableOperator(self.local_db_session)
            self.local_db_pref_table_op = PreferenceTableOperator(self.local_db_session)
            self.local_db_seg_pair_dist_table_op = SegmentPairDistanceTableOperator(self.local_db_session)

        self.local_db_meta = sqla.MetaData()
        self.local_db_meta.reflect(bind=self.local_db_engine)


    ##########################################################################################################################
    #                                     ExperienceTable related operations                                                 #
    ##########################################################################################################################
    @property
    def collected_exp_num(self):
        return self.local_db_exp_table_op.last_experience_id

    def store_experience(self, obs, act, obs2, pb_rew, hc_rew, done, behavior_mode=None, obs_time=None, act_time=None, obs2_time=None):
        self.local_db_exp_table_op.store(obs, act, obs2, pb_rew, hc_rew, done, behavior_mode, obs_time, act_time, obs2_time)

    def sample_exp_batch(self, batch_size=64, device=None, mem_len=None):
        return self.local_db_exp_table_op.sample_batch(batch_size, device, mem_len)

    def get_latest_experience_id(self):
        latest_experience_id = self.local_db_exp_table_op.last_experience_id
        if latest_experience_id is None:
            latest_experience_id = 0
        return latest_experience_id

    def retrieve_last_experience_episode(self):
        """
        This function is used to retrieve last experience episode, which will be used to sample segment from online experiences.
        Note: only call this function after an episode, i.e., either reaching done or maximum_episode_length.
        """
        last_episode, self.episode_exp_start_id = self.local_db_exp_table_op.retrieve_last_experience_episode(self.episode_exp_start_id)
        return last_episode

    ##########################################################################################################################
    #                                        SegmentTable related operations                                                 #
    ##########################################################################################################################
    @property
    def collected_seg_num(self):
        return self.local_db_seg_table_op.collected_seg_num

    def store_segment(self, seg_exp_start_id, seg_exp_end_id, behavior_mode,
                      video_camera_name=None, video_clip_url=None, video_clip_start_time=None, video_clip_end_time=None,
                      add_seg_pair_distance=False, reward_comp=None):
        self.local_db_seg_table_op.store(seg_exp_start_id, seg_exp_end_id, behavior_mode,
                                         video_camera_name, video_clip_url, video_clip_start_time, video_clip_end_time,
                                         add_seg_pair_distance, reward_comp)

    def store_video_clip(self, clip_url, time_format='%Y-%m-%d-%H-%M-%S'):
        """Extra process is needed to store a segment with video clip url."""
        self.local_db_seg_table_op.store_video_clip(clip_url, time_format)

    def sample_segment(self, segment_id):
        return self.local_db_seg_table_op.sample_segment(segment_id)

    ##########################################################################################################################
    #                                     ExperienceTable related operations                                                 #
    ##########################################################################################################################
    # TODO:
    def retrieve_top_n_unlabeled_pairs(self, top_n):
        return self.local_db_seg_pair_dist_table_op.retrieve_top_n_unlabeled_pairs(top_n)

    def update_segment_pair_distance(self, reward_comp):
        self.local_db_seg_pair_dist_table_op.update_segment_pair_distance(reward_comp)

    ##########################################################################################################################
    #                                     PreferenceTable related operations                                                 #
    ##########################################################################################################################
    @property
    def collected_pref_num(self):
        return self.local_db_pref_table_op.collected_pref_num

    @property
    def training_dataset(self):
        return self.local_db_pref_table_op.training_dataset

    @property
    def test_dataset(self):
        return self.local_db_pref_table_op.test_dataset

    def store_preference(self, seg_1_id, seg_2_id, pref_choice, pref_label, time_spend_for_labeling=None, teacher_id=None, train_set=True):
        self.local_db_pref_table_op.store(seg_1_id, seg_2_id, pref_choice, pref_label, time_spend_for_labeling, teacher_id, train_set)

    ##########################################################################################################################
    #                                       Other general purpose operations                                                 #
    ##########################################################################################################################
    def commit(self):
        self.local_db_session.commit()
        # self.cloud_db_session.commit()

    def _dump_mem_db_to_disk_db(self, db_disk_file):
        db_disk_conn = sqlite3.connect(db_disk_file)
        with db_disk_conn:
            for line in self.local_db_engine.raw_connection().iterdump():
                if line not in ('BEGIN;', 'COMMIT;'):
                    db_disk_conn.execute(line)
        db_disk_conn.commit()   # Commit
        db_disk_conn.close()    # Close the database connection

    def save_mem_checkpoint(self, time_step):
        if self.local_db_config['database'] is None:
            # In-memory database: dump it to disk."
            disk_pref_db_file = os.path.join(self.checkpoint_dir, 'Step-{}_Checkpoint_DB.sqlite3'.format(time_step))
            self._dump_mem_db_to_disk_db(disk_pref_db_file)
            # Rename the file to verify the completion of the saving in case of midway cutoff.
            verified_disk_pref_db_file = os.path.join(self.checkpoint_dir, 'Step-{}_Checkpoint_DB_verified.sqlite3'.format(time_step))
            os.rename(disk_pref_db_file, verified_disk_pref_db_file)
        else:
            # Disk database
            # Rename the file to verify the completion of the saving in case of midway cutoff.
            verified_disk_pref_db_file = os.path.join(self.checkpoint_dir,
                                                      'Step-{}_Checkpoint_DB_verified.sqlite3'.format(time_step))
            disk_pref_db_file = None
            for f_name in os.listdir(self.checkpoint_dir):
                if 'Checkpoint_DB' in f_name:
                    disk_pref_db_file = os.path.join(self.checkpoint_dir, f_name)
                    break

            if disk_pref_db_file is not None:
                # Close the database connection before renaming the file
                if self.local_db_engine:
                    self.local_db_session.close()
                    self.local_db_engine.dispose()
                os.rename(disk_pref_db_file, verified_disk_pref_db_file)
                # Reconnect the database and recreate aggregate
                self.local_db_config['database'] = verified_disk_pref_db_file
                self._init_local_db_connection()
            else:
                raise ValueError("disk_pref_db_file is None!")
        print('Successfully saved database with {} segments and {} preference labels!'.format(
            self.collected_seg_num, self.collected_pref_num))

    def restore_mem_checkpoint(self, time_step):
        # restore memory checkpoint
        if time_step == 0:
            disk_db_file = os.path.join(self.checkpoint_dir, 'Step-{}_Checkpoint_DB.sqlite3'.format(time_step))
        else:
            disk_db_file = os.path.join(self.checkpoint_dir, 'Step-{}_Checkpoint_DB_verified.sqlite3'.format(time_step))

        #
        if self.local_db_config['database'] is None:
            self.local_db_config['database'] = None
            self._init_local_db_connection()
            # Connect to disk database and backup it to in-memory database
            disk_db_conn = sqlite3.connect(disk_db_file)
            disk_db_conn.backup(self.local_db_engine.raw_connection().connection)
        else:
            self.local_db_config['database'] = disk_db_file
            self._init_local_db_connection()

        # TODO: delete experiences after time_step to align precisely.
        print('Successfully restored database with {} experiences, {} segments and {} preference labels!'.format(self.collected_exp_num,
                                                                                                                 self.collected_seg_num,
                                                                                                                 self.collected_pref_num))

    ##########################################################################################################################
    #                                     Synchronization Related Functions                                                  #
    # The reason for this is the Preference and Survey Data collection is web-based, so there are some data on the cloud.    #
    # In addition, the experience table is space-consuming and is unnecessary to save on the cloud.                          #
    ##########################################################################################################################
    def one_way_sync_from_source_to_destination(self, source_db_session, destination_db_session, table_class, match_column):
        """
        Synchronize the table_class from the source_db to destination_db. After synchronization, use match_column to math the records in the two
        database.
        :param source_db_session:
        :param destination_db_session:
        :param table_class:
        :param match_column: a list of column names that can be used to match the records in two databases.
        :return:
        """
        source_db_record_num = source_db_session.query(table_class).count()
        destination_db_record_num = destination_db_session.query(table_class).count()

        if destination_db_record_num > source_db_record_num:
            raise ValueError("destination_db_record_num={} > source_db_record_num={}".format(destination_db_record_num, source_db_record_num))
        elif destination_db_record_num < source_db_record_num:
            # Find the ids of unsynchronized records
            source_db_table_df = pd.read_sql_table(table_name=table_class.__tablename__, con=source_db_session.connection())
            destination_db_table_df = pd.read_sql_table(table_name=table_class.__tablename__, con=destination_db_session.connection())
            unsynchronized_ids = pd.concat([source_db_table_df['id'], destination_db_table_df['id']]).drop_duplicates(keep=False)
            # Retrieve unsynchronized records
            unsynchronized_df = pd.read_sql(source_db_session.query(table_class).filter(table_class.id.in_(unsynchronized_ids)).statement,
                                            source_db_session.bind)
            # Write to local_db
            unsynchronized_df.to_sql(table_class.__tablename__, con=destination_db_session.connection(), if_exists='append', index=False)
            destination_db_session.commit()
        else:
            pass
        # Check if match
        source_db_table_df = pd.read_sql_table(table_name=table_class.__tablename__, con=source_db_session.connection())
        destination_db_table_df = pd.read_sql_table(table_name=table_class.__tablename__, con=destination_db_session.connection())
        unmatched_records = pd.concat([source_db_table_df[match_column], destination_db_table_df[match_column]]).drop_duplicates(keep=False)
        if len(unmatched_records) != 0:
            raise ValueError("{} on cloud and local database are unmatched!".format(table_class.__tablename__))

    def one_way_sync_segment_table_local2cloud(self):
        """
        SegmentTable needs to be synchronized two-way, where each new segment will be synchronized from local to cloud and the sampled_num needs to
            be synchronized from cloud to local. (If each time a new segment is generated, it can be added to both the cloud and local database.
            If so, there is no need to synchronize.)
            Currently, sampled_num is not synchronized back to local database.
        :return:
        """
        source_db_session = self.local_db_session
        destination_db_session = self.cloud_db_session
        table_class = SegmentTable
        match_column = ['id', 'seg_exp_start_id', 'seg_exp_end_id']
        self.one_way_sync_from_source_to_destination(source_db_session, destination_db_session, table_class, match_column)

    def one_way_sync_preference_table_cloud2local(self):
        """
        PreferenceTable needs to be synchronized two-way, where new preference label is added to cloud database by user through web-based interface,
            but sampled_num is modified on local database when the preference label is used to learn a reward function. (Actually, there is no need
            to update the sampled_num of PreferenceTable on cloud database, unless in the future this attribute will be used in the web-based interface.)
            Currently, sampled_num is not synchronized back to cloud database.
        :return:
        """
        source_db_session = self.cloud_db_session
        destination_db_session = self.local_db_session
        table_class = PreferenceTable
        match_column = ['id', 'seg_1_id', 'seg_2_id']
        self.one_way_sync_from_source_to_destination(source_db_session, destination_db_session, table_class, match_column)

    def one_way_sync_cloud2local(self):
        """
        One way synchronization all survey-related tables from cloud to local database, which includes:
            1. preference_user_demographic_table
            2. preference_survey_table
            3. interactive_experience_survey_table.
        The copy of these tables in local database is just for backup and data analysis, so call this function only when it's necessary.
        """
        table_classes = [PreferenceUserDemographicTable, PreferenceSurveyTable, InteractiveExperienceSurveyTable]
        #
        for table in table_classes:
            pref_user_demo_table_df = pd.read_sql_table(table_name=table.__tablename__, con=self.cloud_db_session.connection())
            pref_user_demo_table_df.to_sql(name=table.__tablename__, con=self.local_db_session.connection(), if_exists='replace', index=False)
            self.local_db_session.commit()

    def check_if_synchronized(self, local_db_session, cloud_db_session, table):
        pass


if __name__ == '__main__':

    local_db_config = {"drivername": "sqlite", "username": None, "password": None,
                       "database": "Step-0_Checkpoint_DB.sqlite3", "host": None, "port": None}
    local_db_config = {"drivername": "sqlite"}

    cloud_db_config = {"drivername": "postgresql", "username": "postgres", "password": "mlhmlh",
                       "database": "postgres", "host": "127.0.0.1", "port": "54321"}
    db_manager = DatabaseManager(local_db_config=local_db_config, cloud_db_config=cloud_db_config, checkpoint_dir='./')

    # db_manager.save_mem_checkpoint(1)

    test_local_db = True #False #True

    # Add experiences
    # db_manager.store_experience()
    obs_dim = 726
    act_dim = 16
    exp_num = 1000
    # # "2021-10-20-13-09-48_2021-10-20-13-10-18_NorthRiverCamera_clip"
    # video_start_time = datetime.datetime.strptime("2021-10-20-13-09-48", '%Y-%m-%d-%H-%M-%S')
    # video_end_time = datetime.datetime.strptime("2021-10-20-13-10-18", '%Y-%m-%d-%H-%M-%S')
    # for exp_i in range(exp_num):
    #     obs = np.random.rand(obs_dim)
    #     act = np.random.rand(act_dim)
    #     obs2 = np.random.rand(obs_dim)
    #     pb_rew = np.random.rand()
    #     hc_rew = np.random.rand()
    #     done = False
    #     behavior_mode = 'test'
    #     obs_time = video_start_time + exp_i*datetime.timedelta(seconds=2)
    #     act_time = video_start_time + exp_i*datetime.timedelta(seconds=3)
    #     obs2_time = video_start_time + exp_i*datetime.timedelta(seconds=2)
    #     if test_local_db:
    #         db_manager.local_db_exp_table_op.store(obs=obs, act=act, obs2=obs2, pb_rew=pb_rew, hc_rew=hc_rew, done=int(done), behavior_mode=behavior_mode,
    #                                                obs_time=obs_time, act_time=act_time, obs2_time=obs2_time)
    #     else:
    #         db_manager.cloud_db_exp_table_op.store(obs=obs, act=act, obs2=obs2, pb_rew=pb_rew, hc_rew=hc_rew, done=int(done), behavior_mode=behavior_mode,
    #                                                obs_time=obs_time, act_time=act_time, obs2_time=obs2_time)
    # db_manager.commit()
    # db_manager.local_db_exp_table_op.sample_batch(mem_len=16)
    # # db_manager.cloud_db_exp_table_op.sample_batch(mem_len=16)
    # # Add segments
    # seg_num = 100
    # seg_len = 15
    # seg_start_id = np.random.randint(1, exp_num - seg_len + 1, size=seg_num)
    # seg_end_id = seg_start_id + seg_len - 1
    # for seg_i in range(seg_num):
    #     if test_local_db:
    #         db_manager.local_db_seg_table_op.store(seg_start_id[seg_i - 1], seg_end_id[seg_i - 1], behavior_mode, 'NorthRiver-Camera', None, None, None,
    #                                                add_seg_pair_distance=True, reward_comp='')
    #     else:
    #         db_manager.cloud_db_seg_table_op.store(seg_start_id[seg_i - 1], seg_end_id[seg_i - 1], behavior_mode, 'NorthRiver-Camera', None, None, None)

    # # db_manager.local_db_seg_table_op.sample_segment(2)
    # # Simulate preference
    # pref_num = 3000
    # for i in range(pref_num):
    #     if i % 100 == 0:
    #         print(i)
    #     seg_1_id = np.random.randint(1, seg_num+1)
    #     seg_2_id = np.random.randint(1, seg_num + 1)
    #     pref_choice = 'right_better'
    #     pref_label = 1
    #     if test_local_db:
    #         db_manager.local_db_pref_table_op.store(seg_1_id, seg_2_id, pref_choice, pref_label, time_spend_for_labeling=None, teacher_id=None,
    #                                                 train_set=True)
    #     else:
    #         db_manager.cloud_db_pref_table_op.store(seg_1_id, seg_2_id, pref_choice, pref_label, time_spend_for_labeling=None, teacher_id=None,
    #                                                 train_set=True)
    # db_manager.cloud_db_pref_table_op.db_session.commit()
    # if test_local_db:
    #     db_manager.local_db_pref_table_op.training_dataset
    # else:
    #     db_manager.cloud_db_pref_table_op.training_dataset

    # # Test synchronization functions
    # db_manager.one_way_sync_cloud2local()

    # db_manager.local_db_seg_pair_dist_table_op.exist_segment_ids
    #
    # db_manager.save_mem_checkpoint(100)
    db_manager.restore_mem_checkpoint(100)

    # db_manager.one_way_sync_preference_table_cloud2local()
    # db_manager.one_way_sync_segment_table_local2cloud()
import random

import numpy as np
import pandas as pd
import json
import sqlite3
import torch


def adapt_array(arr):
    """adapt array to text"""
    return json.dumps(arr.tolist())


def convert_array(text):
    """convert text back to array"""
    return np.asarray(json.loads(text))


def convert_str_to_array(value):
    """Sqlite does not support np.ndarray, so this function is used to convert string to ndarray in pandas.DataFrame."""
    if isinstance(value, str):
        return np.asarray(json.loads(value))
    else:
        return value.apply(convert_str_to_array)


# Converts np.array to TEXT when inserting
sqlite3.register_adapter(np.ndarray, adapt_array)

# Converts TEXT to np.array when selecting
sqlite3.register_converter("array", convert_array)

from pl.pref_gui.las_teacher_gui.app_teacher_preference.db_config import db_table_config

# import pdb; pdb.set_trace()
# Local SQLite tables:
db_file = 'test_db_create.sqlite3'
db_conn = sqlite3.connect(db_file, detect_types=sqlite3.PARSE_DECLTYPES)
cur = db_conn.cursor()
for table_name in db_table_config:
    table_column_def = []
    table_foreign_key_def = []
    for column_name in db_table_config[table_name]:
        col_data_type = db_table_config[table_name][column_name]["data_type"]
        col_default = db_table_config[table_name][column_name]["default"]
        col_primary_key = db_table_config[table_name][column_name]["primary_key"]
        col_foreign_key = db_table_config[table_name][column_name]["foreign_key"]

        col_description = "{} ".format(column_name)
        if col_data_type == "int":
            col_description += "INTEGER"
        elif col_data_type == "float":
            col_description += "REAL"
        elif col_data_type == "text":
            col_description += "TEXT"
        elif col_data_type == "array":
            col_description += "ARRAY"
        elif col_data_type == "time":
            col_description += "TEXT"
        else:
            raise ValueError("col_data_type: {} not defined!".format())

        if col_primary_key is not None:
            col_description += " PRIMARY KEY"

        if col_default is not None:
            col_description += " DEFAULT {}".format(col_default)

        if col_foreign_key is not None:
            table_foreign_key_def.append("FOREIGN KEY({}) REFERENCES {}({})".format(column_name, col_foreign_key[0], col_foreign_key[1]))

        table_column_def.append(col_description)
    # Create table if not exist (Note: in SQLite foreign key definition must be put at the end of the column definition.)
    if len(table_foreign_key_def) == 0:
        # print("CREATE TABLE IF NOT EXISTS {} ({})".format(table_name, ", ".join(table_column_def)))
        cur.execute("CREATE TABLE IF NOT EXISTS {} ({})".format(table_name, ", ".join(table_column_def)))
    else:
        # print("CREATE TABLE IF NOT EXISTS {} ({}, {})".format(table_name, ", ".join(table_column_def), ", ".join(table_foreign_key_def)))
        cur.execute("CREATE TABLE IF NOT EXISTS {} ({}, {})".format(table_name, ", ".join(table_column_def), ", ".join(table_foreign_key_def)))




class ExperienceTableOperator:
    """A replay buffer based on database."""

    def __init__(self, db_conn, max_replay_size=1e6, table_name="experience"):
        """Initialize replay buffer"""

        self.max_replay_size = max_replay_size
        self.table_name = table_name
        self.db_not_committed = False  # Indicating if commit() needs to be called.

        # Connect to database
        self.db_conn = db_conn
        self.cur = self.db_conn.cursor()
        # Create table if not exists
        self.cur.execute(
            "CREATE TABLE IF NOT EXISTS {} (id INTEGER PRIMARY KEY, \
                                            obs ARRAY, \
                                            act ARRAY, \
                                            pb_rew REAL, \
                                            hc_rew REAL, \
                                            obs2 ARRAY, \
                                            done INTEGER,\
                                            sampled_num INTEGER DEFAULT 0,\
                                            behavior_mode TEXT)".format(table_name))
        # Initialize current replay buffer size if the number of previous experiences in database is larger than the
        # maximum of the reply buffer size set the current replay buffer to max_replay_size.
        self.cur.execute('SELECT COUNT(*) from {}'.format(self.table_name))
        self.size = min(self.max_replay_size, self.cur.fetchone()[0])
        self.start_id = 0
        self.cur.execute('SELECT max(id) FROM {}'.format(self.table_name))
        max_id = self.cur.fetchone()[0]
        if max_id is None:
            self.end_id = 0
            self.size = 0
            self.start_id = 1  # start_id always start from 1 in database table
        else:
            self.end_id = max_id
            self.size = min(self.max_replay_size, max_id)
            self.start_id = self.end_id - self.size + 1

    def store(self, obs, act, obs2, pb_rew, hc_rew, done, behavior_mode=None):
        """Store experience into database"""
        self.cur.execute(
            "INSERT INTO {}(obs, act, obs2, pb_rew, hc_rew, done, sampled_num, behavior_mode) VALUES (?,?,?,?,?,?,?,?)".format(self.table_name),
            (obs, act, obs2, pb_rew, hc_rew, done, 0, behavior_mode))
        # Commit is time-consuming, so only commit() when done or when updating the RL-agent in sample_batch.
        if done:
            self.db_conn.commit()
            self.db_not_committed = False
        else:
            self.db_not_committed = True

        if self.size < self.max_replay_size:
            self.size += 1
            self.end_id += 1
        else:
            self.end_id += 1
            self.start_id += 1

    def sample_batch(self, batch_size=64, device=None, mem_len=None):
        """Sample a mini-batch of experiences"""
        # Commit if not.
        if self.db_not_committed:
            self.db_conn.commit()
            self.db_not_committed = False

        # It's faster to use randint to generate random sample indices rather than fetching ids from the database.
        # batch_idxs = np.random.randint(self.start_id, self.end_id, size=min(batch_size, int(self.size)))
        # batch_idxs = random.randint(self.start_id, self.end_id, size=min(batch_size, int(self.size)))
        batch_idxs = random.sample(list(np.arange(self.start_id, self.end_id+1)), min(batch_size, int(self.size)))  # Random sample without replacement

        # Fetch sampled experiences from database
        self.cur.execute("SELECT * FROM {} WHERE id in {}".format(self.table_name, tuple(batch_idxs)))
        batch_df = pd.DataFrame(self.cur.fetchall(), columns=[col[0] for col in self.cur.description])

        # Increase the sampled_num of the sampled experiences
        self.cur.execute(
            "UPDATE {} SET sampled_num=sampled_num+1  WHERE id in {}".format(self.table_name, tuple(batch_idxs)))

        # Form batch tensor
        batch = dict(obs=np.stack(batch_df['obs']),
                     act=np.stack(batch_df['act']),
                     obs2=np.stack(batch_df['obs2']),
                     rew=np.stack(batch_df['pb_rew']),
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
                self.cur.execute("SELECT * FROM {} WHERE id BETWEEN {} AND {}".format(self.table_name, sample_start_id, sample_id))
                mem_seg_df = pd.DataFrame(self.cur.fetchall(), columns=[col[0] for col in self.cur.description])

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
        self.cur.execute('SELECT max(id) FROM {}'.format(self.table_name))
        max_id = self.cur.fetchone()[0]
        return max_id

    def retrieve_last_experience_episode(self, episode_exp_start_id):
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
            self.cur.execute("SELECT * FROM {} WHERE id BETWEEN {} AND {}".format(self.table_name, episode_exp_start_id, last_experience_id))
            last_episode = pd.DataFrame(self.cur.fetchall(), columns=[col[0] for col in self.cur.description])
            last_path = {"exp_id_traj":  last_episode['id'].values,
                         "human_obs_traj": np.zeros(len(last_episode['id'].values)), "behavior_mode": last_episode['behavior_mode'].values[0]}

        return last_path, new_episode_exp_start_id


class ExperienceAndSegmentMatchTableOperator:
    """The table saves the correspondence between segment and experience sequence."""
    def __init__(self, db_conn, table_name="experience_and_segment_match"):
        self.table_name = table_name
        # Connect to database
        self.db_conn = db_conn
        self.cur = self.db_conn.cursor()
        # Create table if not exists
        self.cur.execute(
            "CREATE TABLE IF NOT EXISTS {} (id INTEGER PRIMARY KEY, \
                                            segment_id INTEGER, \
                                            experience_id INTEGER, \
                                            FOREIGN KEY(experience_id) REFERENCES experience(id),\
                                            FOREIGN KEY(segment_id) REFERENCES segment(id))".format(self.table_name))

    def store(self, segment_id, experience_id):
        self.cur.execute(
            "INSERT INTO {}(experience_id, segment_id) VALUES (?,?)".format(self.table_name), (experience_id, segment_id))

    def retrieve_segment_trajectory(self, segment_id):
        # self.cur.execute("SELECT experience_id FROM {0} WHERE segment_id={1} ORDER BY experience_id ASC".format(self.table_name, segment_id))
        # experience_id_trajectory = pd.DataFrame(self.cur.fetchall(), columns=[col[0] for col in self.cur.description]).values.flatten()
        self.cur.execute("SELECT obs, act, obs2, hc_rew FROM experience_and_segment_match \
                                JOIN experience ON experience_and_segment_match.experience_id=experience.id \
                                WHERE experience_and_segment_match.segment_id={} ORDER BY experience_id ASC ".format(segment_id))
        experience_id_trajectory = pd.DataFrame(self.cur.fetchall(), columns=[col[0] for col in self.cur.description])
        return experience_id_trajectory


class SegmentTableOperator:
    """Saving in and retrieve segments from database"""
    def __init__(self, db_conn, table_name="segment"):
        self.table_name = table_name

        # Connect to database
        self.db_conn = db_conn
        self.cur = self.db_conn.cursor()
        # Create table if not exists
        self.cur.execute(
            "CREATE TABLE IF NOT EXISTS {} (id INTEGER PRIMARY KEY, \
                                            seg_start_id INTEGER, \
                                            seg_end_id INTEGER, \
                                            seg_length INTEGER,\
                                            sampled_num INTEGER DEFAULT 0,\
                                            behavior_mode TEXT)".format(self.table_name))
        # Create experience and segment match table operator
        self.exp_seg_match_table_operator = ExperienceAndSegmentMatchTableOperator(self.db_conn)
        # Create segment_pair_distance table operator
        self.seg_pair_distance_operator = SegmentPairDistanceTableOperator(self.db_conn)

    @property
    def collected_seg_num(self):
        self.cur.execute('SELECT COUNT(*) from {}'.format(self.table_name))
        collected_seg_num = self.cur.fetchone()[0]
        return collected_seg_num

    def store(self, seg_start_id, seg_end_id, seg_length, behavior_mode, add_seg_pair_distance=False, reward_comp=None):
        # Store segment
        self.cur.execute(
            "INSERT INTO {}(seg_start_id, seg_end_id, seg_length, sampled_num, behavior_mode) VALUES (?,?,?,?,?)".format(
                self.table_name),
            (int(seg_start_id), int(seg_end_id), seg_length, 0, behavior_mode))

        # Store experience and segment match
        seg_id = self.cur.lastrowid
        for exp_id in range(seg_start_id, seg_end_id + 1):
            self.exp_seg_match_table_operator.store(seg_id, exp_id)

        # Add segment pair distance for new seg_id
        if add_seg_pair_distance:
            if reward_comp is None:
                raise ValueError("Invalid reward_comp was provided!")
            self.seg_pair_distance_operator.add_segment_pair_distance(seg_id, reward_comp)

    def sample_segment(self, seg_id):
        """Sample segment by id."""
        self.cur.execute("SELECT * FROM {} WHERE id={}".format(self.table_name, seg_id))
        fetch_data = self.cur.fetchall()[0]
        seg = {}
        for col_i, col_name in enumerate([col[0] for col in self.cur.description]):
            seg[col_name] = fetch_data[col_i]
        # segment trajectory
        seg_trajectory = self.exp_seg_match_table_operator.retrieve_segment_trajectory(seg_id)
        # Increase the sampled_num of the sampled segment
        self.cur.execute(
            "UPDATE {} SET sampled_num=sampled_num+1  WHERE id={}".format(self.table_name, seg_id))
        self.db_conn.commit()

        return seg, seg_trajectory


class SegmentPairDistanceTableOperator:
    """The table saves the distance between two segments in a segment pair."""
    def __init__(self, db_conn, table_name='segment_pair_distance', segment_table_name="segment"):
        self.table_name = table_name
        self.segment_table_name = segment_table_name

        # Connect to database
        self.db_conn = db_conn
        self.cur = self.db_conn.cursor()
        # Create table if not exists
        self.cur.execute(
            "CREATE TABLE IF NOT EXISTS {} (id INTEGER PRIMARY KEY, \
                                            seg_1_id INTEGER, \
                                            seg_2_id INTEGER, \
                                            distance REAL,\
                                            sampled_num INTEGER DEFAULT 0)".format(self.table_name))
        # Create experience and segment match table operator
        self.exp_seg_match_table_operator = ExperienceAndSegmentMatchTableOperator(self.db_conn)

    @property
    def exist_segment_ids(self):
        """Return exist segment ids in segment table."""
        self.cur.execute('SELECT id from {}'.format(self.segment_table_name))
        return pd.DataFrame(self.cur.fetchall(), columns=[col[0] for col in self.cur.description])['id'].values

    @property
    def last_seg_pair_distance_id(self):
        self.cur.execute('SELECT max(id) FROM {}'.format(self.table_name))
        max_id = self.cur.fetchone()[0]
        if max_id is None:
            max_id = 0
        return max_id

    def _calculate_segment_pair_distance(self, seg_pair_start_id, seg_pair_end_id, reward_comp):
        """Calculate the segment pair distance for id in [seg_pair_start_id, seg_pair_end_id]."""
        # Add the entry then calculate distance in batch, which is faster.
        self.cur.execute("SELECT segment_pair_distance.id, segment_pair_distance.seg_1_id, \
                                        concat_trajectory(experience.obs) as left_seg_obs_traj, \
                                        concat_trajectory(experience.act) as left_seg_act_traj, \
                                        concat_trajectory(experience.obs2) as left_seg_obs2_traj, \
                                        COUNT (experience.obs2) as left_seg_length\
                                        FROM segment_pair_distance JOIN segment ON segment_pair_distance.seg_1_id=segment.id \
                                        JOIN experience_and_segment_match exp_match ON segment.id=exp_match.segment_id \
                                        JOIN experience ON exp_match.experience_id=experience.id \
                                        WHERE segment_pair_distance.id BETWEEN {} AND {}\
                                        GROUP BY segment_pair_distance.id".format(seg_pair_start_id, seg_pair_end_id))

        left_segment = pd.DataFrame(self.cur.fetchall(), columns=[col[0] for col in self.cur.description])
        left_segment[["left_seg_obs_traj", "left_seg_act_traj", "left_seg_obs2_traj"]] = left_segment[
            ["left_seg_obs_traj", "left_seg_act_traj", "left_seg_obs2_traj"]].apply(convert_str_to_array)
        # Right segment
        self.cur.execute("SELECT segment_pair_distance.id, segment_pair_distance.seg_2_id, \
                                                concat_trajectory(experience.obs) as right_seg_obs_traj, \
                                                concat_trajectory(experience.act) as right_seg_act_traj, \
                                                concat_trajectory(experience.obs2) as right_seg_obs2_traj, \
                                                COUNT (experience.obs2) as right_seg_length\
                                                FROM segment_pair_distance JOIN segment ON segment_pair_distance.seg_2_id=segment.id \
                                                JOIN experience_and_segment_match exp_match ON segment.id=exp_match.segment_id \
                                                JOIN experience ON exp_match.experience_id=experience.id \
                                                WHERE segment_pair_distance.id BETWEEN {} AND {}\
                                                GROUP BY segment_pair_distance.id".format(seg_pair_start_id, seg_pair_end_id))
        right_segment = pd.DataFrame(self.cur.fetchall(), columns=[col[0] for col in self.cur.description])
        right_segment[["right_seg_obs_traj", "right_seg_act_traj", "right_seg_obs2_traj"]] = right_segment[
            ["right_seg_obs_traj", "right_seg_act_traj", "right_seg_obs2_traj"]].apply(convert_str_to_array)
        # Combine left and right segment
        dataset = pd.concat([left_segment, right_segment], axis=1).to_dict('records')

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
                distance += abs(seg_reward_pred[:, 0] - seg_reward_pred[:, 1]).tolist()
        # Update distance
        for idx, seg_pair_id in enumerate(range(seg_pair_start_id, seg_pair_end_id+1)):
            self.cur.execute("UPDATE {} SET distance = {} WHERE id = {}".format(self.table_name, distance[idx], seg_pair_id))

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
                self.cur.execute(
                    "INSERT INTO {} (seg_1_id, seg_2_id, sampled_num) VALUES (?,?,?)".format(
                        self.table_name),
                    (int(new_seg_id), int(old_seg_id), 0))
                new_entry_end_id += 1

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
        self.cur.execute('SELECT * from {} WHERE sampled_num=0 ORDER BY distance DESC LIMIT {}'.format(self.table_name, top_n))
        retrieved_pair = pd.DataFrame(self.cur.fetchall(), columns=[col[0] for col in self.cur.description])

        # Set sampled_num to 1
        self.cur.execute("UPDATE {} SET sampled_num = 1 WHERE id IN ({})".format(self.table_name, ",".join([str(id) for id in retrieved_pair['id'].tolist()])))

        return retrieved_pair['seg_1_id'].tolist(), retrieved_pair['seg_2_id'].tolist()

class VideoClipTableOperator:
    """
    video_clip_table saves video clip related data, where each record in video_clip_table corresponds to a record in segment if
    videos are rendered.
    """
    def __init__(self, db_conn, table_name='video_clip_table', cloud_db_conn=None):
        self.table_name = table_name

        # Connection to local database
        self.db_conn = db_conn
        self.cur = self.db_conn.cursor()

        # Connection to cloud database
        self.cloud_db_conn = cloud_db_conn
        self.clould_cur = self.cloud_db_conn.c

        # Create table if not exists
        self.cur.execute(
            "CREATE TABLE IF NOT EXISTS {} (id INTEGER PRIMARY KEY, \
                                            video_clip_url TEXT,\
                                            behavior_mode TEXT,\
                                            camera_name INTEGER,\
                                            video_clip_start_time TEXT,\
                                            video_clip_end_time TEXT, \
                                            sampled_count INTEGER DEFAULT 0,\
                                            FOREIGN KEY(left_seg_id) REFERENCES segment(id),\
                                            FOREIGN KEY(right_seg_id) REFERENCES segment(id))".format(self.table_name))

    def store(self, video_clip_url, behavior_mode, camera_name, video_clip_start_time, video_clip_end_time):
        # Add video clip

        # Add the corresponding segment to segment_table.
        pass

    def sync(self):
        """"""
        pass

class PreferenceTableOperator:
    def __init__(self, db_conn, table_name='preference'):
        self.table_name = table_name
        self.db_not_committed = False  # Indicating if commit() needs to be called.

        # Connect to database
        self.db_conn = db_conn
        self.cur = self.db_conn.cursor()
        # Create table if not exists
        self.cur.execute(
            "CREATE TABLE IF NOT EXISTS {} (id INTEGER PRIMARY KEY, \
                                            left_seg_id INTEGER,\
                                            right_seg_id INTEGER,\
                                            pref_label INTEGER,\
                                            train_set INTEGER,\
                                            sampled_num INTEGER DEFAULT 0,\
                                            FOREIGN KEY(left_seg_id) REFERENCES segment(id),\
                                            FOREIGN KEY(right_seg_id) REFERENCES segment(id))".format(self.table_name))

    @property
    def collected_pref_num(self):
        self.cur.execute('SELECT COUNT(*) from {}'.format(self.table_name))
        collected_pref_num = self.cur.fetchone()[0]
        return collected_pref_num

    @property
    def training_dataset(self):
        # Commit is time-consuming, so only commit() when needing to retrieve.
        if self.db_not_committed:
            self.db_conn.commit()
            self.db_not_committed = False
        training_dataset = self._retrieve_data(train_set=1)
        return training_dataset.to_dict('records')

    @property
    def test_dataset(self):
        # Commit is time-consuming, so only commit() when needing to retrieve.
        if self.db_not_committed:
            self.db_conn.commit()
            self.db_not_committed = False
        test_dataset = self._retrieve_data(train_set=0)
        return test_dataset.to_dict('records')

    def _retrieve_data(self, train_set=1):
        """train_set=1 if retrieving training set, otherwise train_set=0."""
        # Left segment
        self.cur.execute("SELECT pref.id, pref.pref_label, pref.left_seg_id, \
                                concat_trajectory(experience.obs) as left_seg_obs_traj, \
                                concat_trajectory(experience.act) as left_seg_act_traj, \
                                concat_trajectory(experience.obs2) as left_seg_obs2_traj, \
                                COUNT (experience.obs2) as left_seg_length\
                                FROM preference pref JOIN segment ON pref.left_seg_id=segment.id \
                                JOIN experience_and_segment_match exp_match ON segment.id=exp_match.segment_id \
                                JOIN experience ON exp_match.experience_id=experience.id WHERE train_set={}\
                                GROUP BY pref.id".format(train_set))
        left_segment = pd.DataFrame(self.cur.fetchall(), columns=[col[0] for col in self.cur.description])
        left_segment[["left_seg_obs_traj", "left_seg_act_traj", "left_seg_obs2_traj"]] = left_segment[
            ["left_seg_obs_traj", "left_seg_act_traj", "left_seg_obs2_traj"]].apply(convert_str_to_array)
        # Right segment
        self.cur.execute("SELECT pref.right_seg_id, \
                                    concat_trajectory(experience.obs) as right_seg_obs_traj, \
                                    concat_trajectory(experience.act) as right_seg_act_traj, \
                                    concat_trajectory(experience.obs2) as right_seg_obs2_traj, \
                                    COUNT (experience.obs2) as right_seg_length\
                                    FROM preference pref JOIN segment ON pref.right_seg_id=segment.id \
                                    JOIN experience_and_segment_match exp_match ON segment.id=exp_match.segment_id \
                                    JOIN experience ON exp_match.experience_id=experience.id WHERE train_set={}\
                                    GROUP BY pref.id".format(train_set))
        right_segment = pd.DataFrame(self.cur.fetchall(), columns=[col[0] for col in self.cur.description])
        right_segment[["right_seg_obs_traj", "right_seg_act_traj", "right_seg_obs2_traj"]] = right_segment[
            ["right_seg_obs_traj", "right_seg_act_traj", "right_seg_obs2_traj"]].apply(convert_str_to_array)
        # Combine left and right segment
        dataset = pd.concat([left_segment, right_segment], axis=1)
        return dataset

    def store(self, left_seg_id, right_seg_id, pref_label, train_set=True):
        self.cur.execute(
            "INSERT INTO {} (left_seg_id, right_seg_id, pref_label, train_set) VALUES (?,?,?,?)".format(
                self.table_name),
            (left_seg_id, right_seg_id, pref_label, train_set))

    def sample_preference(self):
        pass

if __name__ == '__main__':
    db_file = './test.sqlite3'
    # db_file = ':memory:'
    db_conn = sqlite3.connect(db_file, detect_types=sqlite3.PARSE_DECLTYPES)

    # # Test segment
    # seg_table_op = SegmentTableOperator(db_conn, table_name="segment")
    #
    # for i in range(100):
    #     seg ={}
    #     seg['obs_traj'] = np.random.rand(10, 5)
    #     seg['act_traj'] = np.random.rand(10, 8)
    #     seg['obs2_traj'] = np.random.rand(10, 5)
    #     seg['orig_rew_traj'] = np.random.rand(10, 1)
    #     seg['done_traj'] = np.random.rand(10, 5)
    #     seg['seg_len'] = 10
    #     seg_table_op.store(seg)
    #
    # import pdb; pdb.set_trace()
    # pref_table_op = PreferenceTableOperator(db_conn, table_name="preference")
    # for i in range(10):
    #     left_seg_id = np.random.randint(1, 101)
    #     right_seg_id = np.random.randint(1, 101)
    #     pref_label = np.random.randint(0, 2)
    #     pref_table_op.store(left_seg_id, right_seg_id, pref_label, train_set=True)
    #
    # # pref_table_op.cur.execute("SELECT preference.id, \
    # #                                   preference.left_seg_id, \
    # #                                   left_seg.obs_traj as left_seg_obs_traj, left_seg.act_traj as left_seg_act_traj, left_seg.obs2_traj as left_seg_obs2_traj, \
    # #                                   left_seg.orig_rew_traj as left_seg_orig_rew_traj, \
    # #                                   left_seg.done_traj as left_seg_done_traj,\
    # #                                   left_seg.seg_length as left_seg_length,\
    # #                                   left_seg.sampled_num as left_seg_sampled_num,\
    # #                                   preference.right_seg_id, \
    # #                                   right_seg.obs_traj as right_seg_obs_traj, right_seg.act_traj as right_seg_act_traj, right_seg.obs2_traj as right_seg_obs2_traj, \
    # #                                   right_seg.orig_rew_traj as right_seg_orig_rew_traj, \
    # #                                   right_seg.done_traj as right_seg_done_traj,\
    # #                                   right_seg.seg_length as right_seg_length,\
    # #                                   right_seg.sampled_num as right_seg_sampled_num \
    # #                                   FROM preference JOIN segment as left_seg ON preference.left_seg_id = left_seg.id JOIN segment as right_seg ON preference.right_seg_id = right_seg.id WHERE train_set=1")
    # #
    # # training_dataset = pd.DataFrame(pref_table_op.cur.fetchall(), columns=[col[0] for col in pref_table_op.cur.description])
    #
    # pref_train_dataset = pref_table_op.training_dataset
    #
    # import pdb;
    # pdb.set_trace()
    #
    # db_disk_file = './test_dump_mem.sqlite3'
    # pref_table_op.dump_mem_db_to_disk_db(db_disk_file)
    #
    # # # Store random experiences
    # # import time
    # # start_time = time.time()
    # #
    # # for i in range(1000):
    # #     obs = np.random.randn(5)
    # #     act = np.random.randn(5)
    # #     hc_rew = np.random.randn(1)[0]
    # #     pb_rew = np.random.randn(1)[0]
    # #     obs2 = np.random.randn(8)
    # #     done = False
    # #     replay_buf.store(obs, act, obs2, pb_rew, hc_rew, done)
    # # print("Time elapsed: {}s".format(time.time() - start_time))
    # #
    # # # Sample mini-batch
    # # batch = replay_buf.sample_batch()
    # # # import pdb; pdb.set_trace()

    # Test segment_pair_distance table
    seg_pair_distance_op = SegmentPairDistanceTableOperator(db_conn)
    exist_seg_ids = seg_pair_distance_op.exist_segment_ids
    print('print id')
    for id in exist_seg_ids:
        print(id)
    import pdb; pdb.set_trace()
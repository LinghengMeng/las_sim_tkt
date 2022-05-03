import json
import pandas as pd
import numpy as np
import sqlite3
import torch


def adapt_array(arr):
    """adapt array to text"""
    return json.dumps(arr.tolist())


def convert_array(text):
    """convert text back to array"""
    return np.asarray(json.loads(text))


# Converts np.array to TEXT when inserting
sqlite3.register_adapter(np.ndarray, adapt_array)

# Converts TEXT to np.array when selecting
sqlite3.register_converter("array", convert_array)

# db_config = {'db_file_name': 'database.sqlite3',
#              ''}


class DatabaseReplayBuffer:
    """A replay buffer based on database."""

    def __init__(self, max_replay_size=1e6,
                 db_file="test_database", table_name="experience"):
        """Initialize replay buffer"""

        self.max_replay_size = max_replay_size
        self.table_name = table_name
        self.db_not_committed = False  # Indicating if commit() needs to be called.

        # Connect to database
        self.db_conn = sqlite3.connect(db_file, detect_types=sqlite3.PARSE_DECLTYPES)
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
                                            sampled_num INTEGER DEFAULT 0)".format(table_name))
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

    def store(self, obs, act, obs2, pb_rew, hc_rew, done):
        """Store experience into database"""
        self.cur.execute(
            "INSERT INTO {}(obs, act, obs2, pb_rew, hc_rew, done, sampled_num) VALUES (?,?,?,?,?,?,?)".format(self.table_name),
            (obs, act, obs2, pb_rew, hc_rew, done, 0))
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

    def sample_batch(self, batch_size=64, device=None):
        """Sample a mini-batch of experiences"""
        # Commit if not.
        if self.db_not_committed:
            self.db_conn.commit()
            self.db_not_committed = False

        # It's faster to use randint to generate random sample indices rather than fetching ids from the database.
        batch_idxs = np.random.randint(self.start_id, self.end_id, size=min(batch_size, int(self.size)))

        # Fetch sampled experiences from database
        self.cur.execute("SELECT * FROM {} WHERE id in {}".format(self.table_name, tuple(batch_idxs)))
        batch_df = pd.DataFrame(self.cur.fetchall(), columns=[col[0] for col in self.cur.description])

        # Increase the sampled_num of the sampled experiences
        self.cur.execute(
            "UPDATE {} SET sampled_num=sampled_num+1  WHERE id in {}".format(self.table_name, tuple(batch_idxs)))

        # From batch tensor
        batch = dict(obs=np.stack(batch_df['obs']),
                     act=np.stack(batch_df['act']),
                     obs2=np.stack(batch_df['obs2']),
                     rew=np.stack(batch_df['pb_rew']),
                     done=np.stack(batch_df['done']))
        return {k: torch.as_tensor(v, dtype=torch.float32).to(device) for k, v in batch.items()}


class SegmentTableOperator:
    """Saving in and retrieve segments from database"""
    def __init__(self, db_file="test_database", table_name="segment"):
        self.db_file = db_file
        self.table_name = table_name

        # Connect to database
        self.db_conn = sqlite3.connect(db_file, detect_types=sqlite3.PARSE_DECLTYPES)  # Crucial: set uri=True
        self.cur = self.db_conn.cursor()
        # Create table if not exists
        self.cur.execute(
            "CREATE TABLE IF NOT EXISTS {} (id INTEGER PRIMARY KEY, \
                                            obs_traj ARRAY, \
                                            act_traj ARRAY, \
                                            obs2_traj ARRAY, \
                                            orig_rew_traj ARRAY, \
                                            done_traj ARRAY,\
                                            seg_length INTEGER,\
                                            sampled_num INTEGER DEFAULT 0)".format(self.table_name))

    @property
    def collected_seg_num(self):
        self.cur.execute('SELECT COUNT(*) from {}'.format(self.table_name))
        collected_seg_num = self.cur.fetchone()[0]
        return collected_seg_num

    def store(self, seg):
        self.cur.execute(
            "INSERT INTO {}(obs_traj, act_traj, obs2_traj, orig_rew_traj, done_traj, seg_length) VALUES (?,?,?,?,?,?)".format(
                self.table_name),
            (seg['obs_traj'], seg['act_traj'], seg['obs2_traj'], seg['orig_rew_traj'], seg['done_traj'], seg['seg_len']))
        self.db_conn.commit()

    def sample_segment(self, seg_id):
        """Sample segment by id."""
        self.cur.execute("SELECT * FROM {} WHERE id={}".format(self.table_name, seg_id))
        fetch_data = self.cur.fetchall()[0]
        seg = {}
        for col_i, col_name in enumerate([col[0] for col in self.cur.description]):
            seg[col_name] = fetch_data[col_i]
        # Increase the sampled_num of the sampled segment
        self.cur.execute(
            "UPDATE {} SET sampled_num=sampled_num+1  WHERE id={}".format(self.table_name, seg_id))
        self.db_conn.commit()
        return seg

    def dump_mem_db_to_disk_db(self, db_disk_file):
        db_disk_conn = sqlite3.connect(db_disk_file)
        with db_disk_conn:
            for line in self.db_conn.iterdump():
                if line not in ('BEGIN;', 'COMMIT;'):
                    db_disk_conn.execute(line)
        db_disk_conn.commit()

    def load_disk_db_to_mem_db(self, db_disk_file):
        disk_db_conn = sqlite3.connect(db_disk_file)
        self.db_conn = sqlite3.connect(':memory:', detect_types=sqlite3.PARSE_DECLTYPES)
        disk_db_conn.backup(self.db_conn)
        self.cur = self.db_conn.cursor()


class PreferenceDatabaseOperator:
    def __init__(self, db_file='test_database', table_name='preference'):
        self.db_file = db_file
        self.table_name = table_name
        self.db_not_committed = False  # Indicating if commit() needs to be called.

        # Connect to database
        self.db_conn = sqlite3.connect(db_file, detect_types=sqlite3.PARSE_DECLTYPES)
        self.cur = self.db_conn.cursor()
        # Create table if not exists
        self.cur.execute(
            "CREATE TABLE IF NOT EXISTS {} (id INTEGER PRIMARY KEY, \
                                            left_seg_id INTEGER,\
                                            left_seg_obs_traj ARRAY, \
                                            left_seg_act_traj ARRAY, \
                                            left_seg_obs2_traj ARRAY, \
                                            left_seg_orig_rew_traj ARRAY, \
                                            left_seg_done_traj ARRAY,\
                                            left_seg_length INTEGER,\
                                            left_seg_sampled_num INTEGER,\
                                            right_seg_id INTEGER,\
                                            right_seg_obs_traj ARRAY, \
                                            right_seg_act_traj ARRAY, \
                                            right_seg_obs2_traj ARRAY, \
                                            right_seg_orig_rew_traj ARRAY, \
                                            right_seg_done_traj ARRAY,\
                                            right_seg_length INTEGER,\
                                            right_seg_sampled_num INTEGER,\
                                            pref_label INTEGER,\
                                            train_set INTEGER,\
                                            sampled_num INTEGER DEFAULT 0)".format(self.table_name))

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

        self.cur.execute("SELECT * FROM {} WHERE train_set=1".format(self.table_name))
        training_dataset = pd.DataFrame(self.cur.fetchall(), columns=[col[0] for col in self.cur.description])
        return training_dataset.to_dict('records')

    @property
    def test_dataset(self):
        # Commit is time-consuming, so only commit() when needing to retrieve.
        if self.db_not_committed:
            self.db_conn.commit()
            self.db_not_committed = False

        self.cur.execute("SELECT * FROM {} WHERE train_set=0".format(self.table_name))
        test_dataset = pd.DataFrame(self.cur.fetchall(), columns=[col[0] for col in self.cur.description])
        return test_dataset.to_dict('records')

    def store(self, left_seg, right_seg, pref_label, train_set=True):
        self.cur.execute(
            "INSERT INTO {} (left_seg_id, left_seg_obs_traj, left_seg_act_traj, left_seg_obs2_traj, \
                             left_seg_orig_rew_traj, left_seg_done_traj, left_seg_length, left_seg_sampled_num,\
                             right_seg_id, right_seg_obs_traj, right_seg_act_traj, right_seg_obs2_traj,\
                             right_seg_orig_rew_traj, right_seg_done_traj, right_seg_length, right_seg_sampled_num,\
                             pref_label, train_set) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)".format(
                self.table_name),
            (left_seg['id'], left_seg['obs_traj'], left_seg['act_traj'], left_seg['obs2_traj'],
             left_seg['orig_rew_traj'], left_seg['done_traj'], left_seg['seg_length'], left_seg['sampled_num'],
             right_seg['id'], right_seg['obs_traj'], right_seg['act_traj'], right_seg['obs2_traj'],
             right_seg['orig_rew_traj'], right_seg['done_traj'], right_seg['seg_length'], right_seg['sampled_num'],
             pref_label, train_set))

        self.db_conn.commit()

    def dump_mem_db_to_disk_db(self, db_disk_file):
        db_disk_conn = sqlite3.connect(db_disk_file)
        with db_disk_conn:
            for line in self.db_conn.iterdump():
                if line not in ('BEGIN;', 'COMMIT;'):
                    db_disk_conn.execute(line)
        db_disk_conn.commit()

    def load_disk_db_to_mem_db(self, db_disk_file):
        disk_db_conn = sqlite3.connect(db_disk_file)
        self.db_conn = sqlite3.connect(':memory:', detect_types=sqlite3.PARSE_DECLTYPES)
        disk_db_conn.backup(self.db_conn)
        self.cur = self.db_conn.cursor()

    def sample_preference(self):
        pass


if __name__ == '__main__':
    replay_buf = DatabaseReplayBuffer(max_replay_size=1e6,
                                      db_file='test_db.db', table_name='experience')
    # Store random experiences
    import time
    start_time = time.time()

    for i in range(1000):
        obs = np.random.randn(5)
        act = np.random.randn(5)
        hc_rew = np.random.randn(1)[0]
        pb_rew = np.random.randn(1)[0]
        obs2 = np.random.randn(8)
        done = False
        replay_buf.store(obs, act, obs2, pb_rew, hc_rew, done)
    print("Time elapsed: {}s".format(time.time() - start_time))

    # Sample mini-batch
    batch = replay_buf.sample_batch()
    # import pdb; pdb.set_trace()

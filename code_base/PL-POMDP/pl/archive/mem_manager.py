import json
import sqlite3
from pl.archive.db_mems import ExperienceTableOperator, SegmentTableOperator, SegmentPairDistanceTableOperator, PreferenceTableOperator
from pl.mems.ram_mems import RamReplayBuffer, RamSegmentBuffer, RamPreferenceBuffer


class ConcatTrajectory:
    """Aggregation function used to concatenate observations and actions within a segment to form a trajectory."""
    def __init__(self):
        self.result = '['

    def step(self, value):
        self.result += value + ','

    def finalize(self):
        return self.result[:-1] + ']'


def convert_str_to_array(value):
    """Sqlite does not support np.ndarray, so this function is used to convert string to ndarray in pandas.DataFrame."""
    if isinstance(value, str):
        return np.asarray(json.loads(value))
    else:
        return value.apply(convert_str_to_array)


class MemoryManager(object):
    def __init__(self, mem_type, cp_dir, ):
        self.mem_type = mem_type
        self.cp_dir = cp_dir
        if 'DB' in self.mem_type:
            if self.mem_type == 'DB_disk':
                db_file = os.path.join(self.cp_dir, 'Step-0_Checkpoint_DB.sqlite3')
            elif self.mem_type == 'DB_memory':
                db_file = ':memory:'
            else:
                raise ValueError('Wrong mem_type: {}'.format(self.mem_type))
            # If all operations of the database are through the same connection, then everything is visible even without calling commit().
            self.db_conn = sqlite3.connect(db_file, detect_types=sqlite3.PARSE_DECLTYPES)
            self.db_conn.create_aggregate("concat_trajectory", 1, ConcatTrajectory)
            #
            self.exp_table_operator = ExperienceTableOperator(self.db_conn)
            self.seg_table_operator = SegmentTableOperator(self.db_conn)
            self.seg_pair_distance_operator = SegmentPairDistanceTableOperator(self.db_conn)
            self.pref_table_operator = PreferenceTableOperator(self.db_conn)
            #
            self.episode_exp_start_id = self.exp_table_operator.last_experience_id
        elif self.mem_type == 'RAM':
            self.exp_table_operator = RamReplayBuffer()
            self.seg_table_operator = RamSegmentBuffer()
            self.pref_table_operator = RamPreferenceBuffer()
        else:
            raise ValueError('Wrong mem_type: {}'.format(self.mem_type))

    def store_experience(self, obs, act, obs2, pb_rew, hc_rew, done, behavior_mode=None):
        self.exp_table_operator.store(obs, act, obs2, pb_rew, hc_rew, done, behavior_mode)

    def sample_exp_batch(self, batch_size=64, device=None, mem_len=None):
        return self.exp_table_operator.sample_batch(batch_size, device, mem_len)

    def get_latest_experience_id(self):
        self.db_conn.commit()
        cur = self.db_conn.cursor()
        cur.execute("SELECT MAX(Id) FROM experience")
        result = cur.fetchone()[0]
        if result is None:
            return 0
        else:
            return result

    def retrieve_last_experience_episode(self):
        """
        This function is used to retrieve last experience episode, which will be used to sample segment from online experiences.
        Note: only call this function after an episode, i.e., either reaching done or maximum_episode_length.
        """
        last_episode, self.episode_exp_start_id = self.exp_table_operator.retrieve_last_experience_episode(self.episode_exp_start_id)
        return last_episode

    @property
    def collected_seg_num(self):
        return self.seg_table_operator.collected_seg_num

    def store_segment(self, seg_start_id, seg_end_id, seg_length, behavior_mode, add_seg_pair_distance=False, reward_comp=None):
        self.seg_table_operator.store(seg_start_id, seg_end_id, seg_length, behavior_mode, add_seg_pair_distance, reward_comp)

    def sample_segment(self, segment_id):
        return self.seg_table_operator.sample_segment(segment_id)

    def retrieve_top_n_unlabeled_pairs(self, top_n):
        return self.seg_pair_distance_operator.retrieve_top_n_unlabeled_pairs(top_n)

    def update_segment_pair_distance(self, reward_comp):
        self.seg_pair_distance_operator.update_segment_pair_distance(reward_comp)

    @property
    def collected_pref_num(self):
        return self.pref_table_operator.collected_pref_num

    def store_preference(self, left_seg_id, right_seg_id, pref_label, train_set=True):
        self.pref_table_operator.store(left_seg_id, right_seg_id, pref_label, train_set)

    @property
    def collected_exp_num(self):
        return self.exp_table_operator.last_experience_id

    def commit(self):
        self.db_conn.commit()

    def _dump_mem_db_to_disk_db(self, db_disk_file):
        db_disk_conn = sqlite3.connect(db_disk_file)
        with db_disk_conn:
            for line in self.db_conn.iterdump():
                if line not in ('BEGIN;', 'COMMIT;'):
                    db_disk_conn.execute(line)
        db_disk_conn.commit()   # Commit
        db_disk_conn.close()    # Close the database connection

    def save_mem_checkpoint(self, time_step):
        if self.mem_type == 'DB_memory':
            "If using database buffer and in-memory database, dump it to disk by seg_buffer_operator or pref_buffer_operator."
            disk_pref_db_file = os.path.join(self.cp_dir, 'Step-{}_Checkpoint_DB.sqlite3'.format(time_step))
            self._dump_mem_db_to_disk_db(disk_pref_db_file)
            # Rename the file to verify the completion of the saving in case of midway cutoff.
            verified_disk_pref_db_file = os.path.join(self.cp_dir,
                                                      'Step-{}_Checkpoint_DB_verified.sqlite3'.format(time_step))
            os.rename(disk_pref_db_file, verified_disk_pref_db_file)
        elif self.mem_type == 'DB_disk':
            # Rename the file to verify the completion of the saving in case of midway cutoff.
            verified_disk_pref_db_file = os.path.join(self.cp_dir,
                                                      'Step-{}_Checkpoint_DB_verified.sqlite3'.format(time_step))
            disk_pref_db_file = None
            for f_name in os.listdir(self.cp_dir):
                if 'Checkpoint_DB' in f_name:
                    disk_pref_db_file = os.path.join(self.cp_dir, f_name)
                    break

            if disk_pref_db_file is not None:
                # Close the database connection before renaming the file
                if self.db_conn:
                    self.db_conn.close()
                os.rename(disk_pref_db_file, verified_disk_pref_db_file)
                # Reconnect the database and recreate aggregate
                self.db_conn = sqlite3.connect(verified_disk_pref_db_file, detect_types=sqlite3.PARSE_DECLTYPES)
                self.db_conn.create_aggregate("concat_trajectory", 1, ConcatTrajectory)
                self.exp_table_operator = ExperienceTableOperator(self.db_conn)
                self.seg_table_operator = SegmentTableOperator(self.db_conn)
                self.seg_pair_distance_operator = SegmentPairDistanceTableOperator(self.db_conn)
                self.pref_table_operator = PreferenceTableOperator(self.db_conn)
            else:
                raise ValueError("disk_pref_db_file is None!")
        else:
            "If use RAM buffer, pickle to disk"
            # TODO:
            raise ValueError("RAM buffer checkpoint not implemented!")
        print('Successfully saved database with {} segments and {} preference labels!'.format(
            self.collected_seg_num, self.collected_pref_num))

    def restore_mem_checkpoint(self, time_step):
        # restore memory checkpoint
        disk_db_file = os.path.join(self.cp_dir, 'Step-{}_Checkpoint_DB_verified.sqlite3'.format(time_step))
        if 'DB' in self.mem_type:
            if self.mem_type == 'DB_disk':
                self.db_conn = sqlite3.connect(disk_db_file, detect_types=sqlite3.PARSE_DECLTYPES)
            elif self.mem_type == 'DB_memory':
                disk_db_conn = sqlite3.connect(disk_db_file)
                self.db_conn = sqlite3.connect(':memory:', detect_types=sqlite3.PARSE_DECLTYPES)
                disk_db_conn.backup(self.db_conn)
            else:
                raise ValueError('Wrong mem_type: {}'.format(self.mem_type))
            self.db_conn.create_aggregate("concat_trajectory", 1, ConcatTrajectory)
            self.exp_table_operator = ExperienceTableOperator(self.db_conn)
            self.seg_table_operator = SegmentTableOperator(self.db_conn)
            self.seg_pair_distance_operator = SegmentPairDistanceTableOperator(self.db_conn)
            self.pref_table_operator = PreferenceTableOperator(self.db_conn)
            # TODO: delete experiences after time_step to align precisely.

        elif self.mem_type == 'RAM':
            # TODO
            pass
        else:
            raise ValueError('Wrong mem_type: {}'.format(self.mem_type))
        print('Successfully restored database with {} experiences, {} segments and {} preference labels!'.format(self.collected_exp_num,
                                                                                                                 self.collected_seg_num,
                                                                                                                 self.collected_pref_num))


if __name__ == '__main__':
    import os.path as osp
    import os
    import numpy as np
    import time
    mem_type = 'DB_disk'
    data_dir = osp.join(
        osp.dirname('F:/scratch/lingheng/'), 'test_db_size')
    if not osp.exists(data_dir):
        os.mkdir(data_dir)
    mem_manager = MemoryManager(mem_type, data_dir)

    obs_dim = 26
    act_dim = 6

    start_time = time.time()
    # Simulate experiences
    experience_num = 10000

    obs = np.random.rand(obs_dim)
    act = np.random.rand(act_dim)
    new_obs = np.random.rand(obs_dim)
    rew = 0
    hc_rew = 0
    done = False
    for i in range(experience_num):
        if i % 10000 == 0:
            print('Stored {} experiences'.format(i))
        mem_manager.store_experience(obs, act, new_obs, rew, hc_rew, done, 'TD3_agent')
    mem_manager.db_conn.commit()
    # mem_manager.exp_table_operator.cur.lastrowid
    print('Adding {} experiences costs {}s'.format(experience_num, time.time()-start_time))

    start_time = time.time()
    # Simulate experience_video_match_table
    segment_num = 60000
    seg_len = 15
    seg_start_id = np.random.randint(1, experience_num-seg_len+1, size=segment_num)
    seg_end_id = seg_start_id + seg_len - 1

    for i in range(1, segment_num+1):
        if i % 1000 == 0:
            print(i)
        # Add segment
        mem_manager.seg_table_operator.store(seg_start_id[i-1], seg_end_id[i-1], seg_len, 'test', add_seg_pair_distance=True)
    mem_manager.db_conn.commit()
    print('Adding {} segments costs {}s'.format(segment_num, time.time() - start_time))
    import pdb;
    pdb.set_trace()
    # start_time = time.time()
    #
    # # Simulate preference
    # pref_num = 3000
    # for i in range(pref_num):
    #     if i % 100 == 0:
    #         print(i)
    #     left_seg_id = np.random.randint(1, segment_num+1)
    #     right_seg_id = np.random.randint(1, segment_num + 1)
    #     pref_label = 1
    #     mem_manager.pref_table_operator.store(left_seg_id, right_seg_id, pref_label, train_set=True)
    # mem_manager.db_conn.commit()
    # print('Adding {} preferences costs {}s'.format(pref_num, time.time() - start_time))
    # import pdb;
    # pdb.set_trace()
    #
    # start_time = time.time()
    # training_dataset = mem_manager.pref_table_operator.training_dataset
    # print('Extract {} preference data costs {}s'.format(len(training_dataset), time.time() - start_time))
    #
    # test_dataset = mem_manager.pref_table_operator.test_dataset
    #
    # cur = mem_manager.db_conn.cursor()
    # cur.execute('SELECT COUNT(*) from {}'.format('experience'))
    # cur.fetchone()[0]

    # batch = mem_manager.sample_exp_batch(batch_size=64, device=None, mem_len=12)
    mem_manager.get_latest_experience_id()
    import pdb; pdb.set_trace()

import os
import pkg_resources
import sqlalchemy as db



# Database related configuration
db_config = {
    # Google_Cloud_DB is to configurate Google cloud databased when running the algorithm in real application.
    "Google_Cloud_DB": {"postgresql": {"drivername": "postgres+pg8000",
                                        "username": "lingheng",
                                        "password": "mlhmlh",
                                        "database": "las-preference-learning",
                                        "host": "127.0.0.1",
                                        "port": "54321"},
                         "tables": {
                             "interaction_experiences": {
                                 "columns": ["id", "behaviour_mode", "obs", "obs_time",
                                             "act", "act_time", "rew", "obs2", "obs2_time", "create_time"]},
                             "app_teacher_preference_videoclipsandobsactdata": {
                                 "columns": ["id", "behaviour_mode", "camera_name", "video_clip_url",
                                             "obs_trajectory", "act_trajectory", "sampled_count",
                                             "start_time", "end_time", "create_time"]}
                         }},
    # Local_DB is to configurate local databased used for testing purpose.
    "Local_DB": {"postgresql": {"drivername": "postgres+pg8000",
                                "username": "postgres",
                                "password": "mlhmlh",
                                "database": "preference_learning",  # Change to a new database if not want to pollute it
                                "host": "127.0.0.1",
                                "port": "5433"},
                 "tables": {
                     "interaction_experiences": {
                            "columns": {"id": {"args": {"type_": db.Integer}, "kwargs": {"primary_key": True}},
                                        "behaviour_mode": {"args": {"type_": db.String(255)},
                                                           "kwargs": {"nullable": False}},
                                        "obs": {"args": {"type_": db.ARRAY(db.Float)}, "kwargs": {}},
                                        "obs_time": {"args": {"type_": db.DateTime}, "kwargs": {}},
                                        "act": {"args": {"type_": db.ARRAY(db.Float)}, "kwargs": {}},
                                        "act_time": {"args": {"type_": db.DateTime}, "kwargs": {}},
                                        "rew": {"args": {"type_": db.Float}, "kwargs": {}},
                                        "obs2": {"args": {"type_": db.ARRAY(db.Float)}, "kwargs": {}},
                                        "obs2_time": {"args": {"type_": db.DateTime}, "kwargs": {}},
                                        "create_time": {"args": {"type_": db.DateTime},
                                                        "kwargs": {"default": db.func.now()}}}},
                     "app_teacher_preference_videoclipsandobsactdata": {
                            "columns": {"id": {"args": {"type_": db.Integer}, "kwargs": {"primary_key": True}},
                                        "behaviour_mode": {"args": {"type_": db.String(255)},
                                                           "kwargs": {"nullable": False}},
                                        "camera_name": {"args": {"type_": db.String(255)}, "kwargs": {}},
                                        "video_clip_url": {"args": {"type_": db.String(255)}, "kwargs": {}},
                                        "obs_trajectory": {"args": {"type_": db.ARRAY(db.Float, dimensions=2)}, "kwargs": {}},
                                        "act_trajectory": {"args": {"type_": db.ARRAY(db.Float, dimensions=2)}, "kwargs": {}},
                                        "obs2_trajectory": {"args": {"type_": db.ARRAY(db.Float, dimensions=2)}, "kwargs": {}},
                                        "sampled_count": {"args": {"type_": db.Integer}, "kwargs": {}},
                                        "start_time": {"args": {"type_": db.DateTime}, "kwargs": {}},
                                        "end_time": {"args": {"type_": db.DateTime}, "kwargs": {}},
                                        "create_time": {"args": {"type_": db.DateTime}, "kwargs": {"default": db.func.now()}}}},
                     "teacher_preference_label": {
                         "columns": {"id": {"args": {"type_": db.Integer}, "kwargs": {"primary_key": True}},
                                     "video_clip_1": {"args": {"foreign_key": db.ForeignKey('app_teacher_preference_videoclipsandobsactdata.id')},
                                                      "kwargs": {}},
                                     "video_clip_2": {"args": {"foreign_key": db.ForeignKey('app_teacher_preference_videoclipsandobsactdata.id')},
                                                      "kwargs": {}},
                                     "teacher": {"args": {"type_": db.Integer,
                                                          "foreign_key": db.ForeignKey('teacher_demographic_data.id')},
                                                 "kwargs": {}},
                                     "preference_p": {"args": {"type_": db.Float}, "kwargs": {}},
                                     "create_time": {"args": {"type_": db.DateTime}, "kwargs": {"default": db.func.now()}}},
                         # "relationship": db.orm.relationship()
                     },
                     "teacher_demographic_data": {
                         "columns": {"id": {"args": {"type_": db.Integer}, "kwargs": {"primary_key": True}},
                                     "name": {"args": {"type_": db.String(255)}, "kwargs": {}},
                                     "age": {"args": {"type_": db.Integer}, "kwargs": {}},
                                     "gender": {"args": {"type_": db.Integer}, "kwargs": {}},
                                     "background_on_AI": {"args": {"type_": db.String(255)}, "kwargs": {}},
                                     "how_do_you_know_the_installation": {"args": {"type_": db.String(255)}, "kwargs": {}},
                                     "have_you_ever_experienced_the_installation": {"args": {"type_": db.String(255)}, "kwargs": {}},
                                     "create_time": {"args": {"type_": db.DateTime}, "kwargs": {"default": db.func.now()}}
                                     }}}
                 }
}



# Preference Learning related configuration
teacher_preference_learner_config = {
    "ignore_cannot_tell": True,
    "train_data_ratio": 0.8,
    "train_batch_size": 64,
    "test_batch_size":  200,
    "lr": 0.001,
    "momentum": 0.9,
    "mlp_based_reward_net": {
        "hidden_sizes": [256, 128],
        "train_epoch_num": 100,
        "model_save_path": './learned_reward_model/mlp_reward_net.pth',
    },
    "lstm_based_reward_net": {
        "lstm_n_layers": 2,
        "lstm_hidden_dim": 128,
        "lstm_drop_prob": 0,
        "train_epoch_num": 100,
        "model_save_path": './learned_reward_model/lstm_reward_net.pth',
    },

}

# RL Learning algorithm related configuration
agent_config = {}




from .survey_questions import SYSTEM_USABILITY_SCALE,CUSTOM_QUESTIONS_ON_PREFERENCE_TEACHING_PROCESS,GOD_SPEED_QUESTIONS_LABELS,PREDICT_USAGE_INTENTION_LABELS

# Preference Survey Questions
preference_survey_system_usability_scale_questions = {}
for q_name in SYSTEM_USABILITY_SCALE:
    preference_survey_system_usability_scale_questions[q_name] = {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None}
preference_survey_cutom_questions = {}
for q_name in CUSTOM_QUESTIONS_ON_PREFERENCE_TEACHING_PROCESS:
    preference_survey_cutom_questions[q_name] = {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None}
# Interactive Experience Survey Questions
interactive_experience_survey_god_speed_questions = {}
for q_name in GOD_SPEED_QUESTIONS_LABELS:
    interactive_experience_survey_god_speed_questions[q_name] = {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None}
interactive_experience_survey_usage_intention_questions = {}
for q_name in PREDICT_USAGE_INTENTION_LABELS:
    interactive_experience_survey_usage_intention_questions[q_name] = {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None}

# Database table configurations
db_table_config = {"experience_table": {"id": {"data_type": "int", "default": None, "primary_key": True, "foreign_key": None},
                                        "obs": {"data_type": "array", "default": None, "primary_key": None, "foreign_key": None},
                                        "act": {"data_type": "array", "default": None, "primary_key": None, "foreign_key": None},
                                        "obs2": {"data_type": "array", "default": None, "primary_key": None, "foreign_key": None},
                                        "pb_rew": {"data_type": "float", "default": None, "primary_key": None, "foreign_key": None},
                                        "hc_rew": {"data_type": "float", "default": None, "primary_key": None, "foreign_key": None},
                                        "done": {"data_type": "int", "default": None, "primary_key": None, "foreign_key": None},
                                        "sampled_num": {"data_type": "int", "default": 0, "primary_key": None, "foreign_key": None},
                                        "behavior_mode": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                        # Time related columns are used to find the correspondence between experiences and video clip.
                                        "obs_time": {"data_type": "time", "default": None, "primary_key": None, "foreign_key": None},
                                        "act_time": {"data_type": "time", "default": None, "primary_key": None, "foreign_key": None},
                                        "obs2_time": {"data_type": "time", "default": None, "primary_key": None, "foreign_key": None},
                                        "create_time": {"data_type": "time", "default": None, "primary_key": None, "foreign_key": None}},
                   #
                   "segment_table": {"id": {"data_type": "int", "default": None, "primary_key": True, "foreign_key": None},
                                     "seg_exp_start_id": {"data_type": "int", "default": None, "primary_key": None, "foreign_key": None},
                                     "seg_exp_end_id": {"data_type": "int", "default": None, "primary_key": None, "foreign_key": None},
                                     "sampled_num": {"data_type": "int", "default": 0, "primary_key": None, "foreign_key": None},
                                     "behavior_mode": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                     "video_camera_name": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                     "video_clip_url": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                     "video_clip_start_time": {"data_type": "time", "default": None, "primary_key": None, "foreign_key": None},
                                     "video_clip_end_time": {"data_type": "time", "default": None, "primary_key": None, "foreign_key": None},
                                     "create_time": {"data_type": "time", "default": None, "primary_key": None, "foreign_key": None}},
                   #
                   "experience_and_segment_match_table": {"id": {"data_type": "int", "default": None, "primary_key": True, "foreign_key": None},
                                                          "segment_id": {"data_type": "int", "default": None, "primary_key": None,
                                                                         "foreign_key": ["segment_table", "id"]},
                                                          "experience_id": {"data_type": "int", "default": None, "primary_key": None,
                                                                            "foreign_key": ["experience_table", "id"]}},
                   #
                   "segment_pair_distance_table": {"id": {"data_type": "int", "default": None, "primary_key": True, "foreign_key": None},
                                                   "seg_1_id": {"data_type": "int", "default": None, "primary_key": None,
                                                                "foreign_key": ["segment_table", "id"]},
                                                   "seg_2_id": {"data_type": "int", "default": None, "primary_key": None,
                                                                "foreign_key": ["segment_table", "id"]},
                                                   "distance": {"data_type": "float", "default": None, "primary_key": None, "foreign_key": None},
                                                   "sampled_num": {"data_type": "int", "default": 0, "primary_key": None, "foreign_key": None}},
                   #
                   "preference_user_demographic_table": {"id": {"data_type": "int", "default": None, "primary_key": True, "foreign_key": None},
                                                         "consent_anonymous_quotations": {"data_type": "text", "default": None, "primary_key": None,
                                                                                          "foreign_key": None},
                                                         "age": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                                         "gender": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                                         "edu_background": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                                         "have_interacted_with_the_sculpture": {"data_type": "int", "default": None, "primary_key": None,
                                                                                                "foreign_key": None},
                                                         "experience_date": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                                         "experience_start_time": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                                         "experience_end_time": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                                         "create_time": {"data_type": "time", "default": None, "primary_key": None, "foreign_key": None}},
                   #
                   "preference_table": {"id": {"data_type": "int", "default": None, "primary_key": True, "foreign_key": None},
                                        "seg_1_id": {"data_type": "int", "default": None, "primary_key": None, "foreign_key": ["segment_table", "id"]},
                                        "seg_2_id": {"data_type": "int", "default": None, "primary_key": None, "foreign_key": ["segment_table", "id"]},
                                        # pref_choice in ["Left is better", "Right is better", "Can't tell, equally good!", "Can't tell, equally bad!"]
                                        "pref_choice": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                        # pref_label in [0, 1, 0.5, -0.5]
                                        "pref_label": {"data_type": "int", "default": None, "primary_key": None, "foreign_key": None},
                                        "time_spend_for_labeling": {"data_type": "float", "default": None, "primary_key": None, "foreign_key": None},
                                        "teacher_id": {"data_type": "int", "default": None, "primary_key": None,
                                                       "foreign_key": ["preference_user_demographic_table", "id"]},
                                        "train_set": {"data_type": "int", "default": None, "primary_key": None, "foreign_key": None},
                                        "sampled_num": {"data_type": "int", "default": 0, "primary_key": None, "foreign_key": None},
                                        "create_time": {"data_type": "time", "default": None, "primary_key": None, "foreign_key": None}
                                        },
                   #
                   "preference_survey_table": {"id": {"data_type": "int", "default": None, "primary_key": True, "foreign_key": None},
                                               "teacher_id": {"data_type": "int", "default": None, "primary_key": None,
                                                              "foreign_key": ["preference_user_demographic_table", "id"]},
                                               # System Usability Scale Questions
                                               **preference_survey_system_usability_scale_questions,
                                               # Custom Questions
                                               **preference_survey_cutom_questions,
                                               # Open Questions
                                               "best_way_to_teach": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                               "reason_for_choice": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                               "general_comment": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                               "create_time": {"data_type": "time", "default": None, "primary_key": None, "foreign_key": None}
                                               },
                   "interactive_experience_survey_table": {"id": {"data_type": "int", "default": None, "primary_key": True, "foreign_key": None},
                                                           "consent_anonymous_quotations": {"data_type": "text", "default": None, "primary_key": None,
                                                                                            "foreign_key": None},
                                                           "experience_date": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                                           "experience_start_time": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                                           "experience_end_time": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                                           # Godspeed questions
                                                           **interactive_experience_survey_god_speed_questions,
                                                           # Incentive & Self-efficacy & Intention of Use
                                                           **interactive_experience_survey_usage_intention_questions,
                                                           # General comments
                                                           "general_comment": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                                           # Demographic
                                                           "age": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                                           "gender": {"data_type": "text", "default": None, "primary_key": None, "foreign_key": None},
                                                           "edu_background": {"data_type": "text", "default": None, "primary_key": None,
                                                                              "foreign_key": None},
                                                           "prior_experience_robot": {"data_type": "text", "default": None, "primary_key": None,
                                                                                      "foreign_key": None},
                                                           "prior_experience_interactive_art": {"data_type": "text", "default": None, "primary_key": None,
                                                                                                "foreign_key": None},
                                                           "perceive_interactive_art_as_robot": {"data_type": "text", "default": None, "primary_key": None,
                                                                                                 "foreign_key": None},
                                                           "create_time": {"data_type": "time", "default": None, "primary_key": None, "foreign_key": None}
                                                           }}
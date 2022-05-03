from django.db import models
from django.utils import timezone
from django.conf import settings
from django.contrib.postgres.fields import ArrayField

from .db_config import db_table_config


class SegmentTable(models.Model):
    """
    Table saves segments.
    """
    table_name = 'segment_table'
    for column_name in db_table_config[table_name]:
        col_data_type = db_table_config[table_name][column_name]["data_type"]
        col_default = db_table_config[table_name][column_name]["default"]
        col_primary_key = db_table_config[table_name][column_name]["primary_key"]
        col_foreign_key = db_table_config[table_name][column_name]["foreign_key"]

        if col_primary_key is not None:
            vars()[column_name] = models.BigAutoField(primary_key=True)
            continue

        if col_foreign_key is not None:
            vars()[column_name] = models.ForeignKey(col_foreign_key[0], on_delete=models.CASCADE, related_name=column_name)
            continue

        if col_data_type == "int":
            vars()[column_name] = models.PositiveIntegerField()
        elif col_data_type == "float":
            vars()[column_name] = models.FloatField()
        elif col_data_type == "text":
            vars()[column_name] = models.TextField()
        elif col_data_type == "array":
            vars()[column_name] = ArrayField(ArrayField(models.FloatField()))   # Array only exists in saving obs or action, so no need to worry it in cloud.
        elif col_data_type == "time":
            auto_now = True if column_name == 'create_time' else False
            vars()[column_name] = models.DateTimeField(auto_now=auto_now)
        else:
            raise ValueError("col_data_type: {} not defined!".format())

    class Meta:
        managed = True
        db_table = 'segment_table'


class PreferenceUserDemographicTable(models.Model):
    """
    Table saves segments.
    """
    table_name = 'preference_user_demographic_table'
    for column_name in db_table_config[table_name]:
        col_data_type = db_table_config[table_name][column_name]["data_type"]
        col_default = db_table_config[table_name][column_name]["default"]
        col_primary_key = db_table_config[table_name][column_name]["primary_key"]
        col_foreign_key = db_table_config[table_name][column_name]["foreign_key"]

        if col_primary_key is not None:
            vars()[column_name] = models.BigAutoField(primary_key=True)
            continue

        if col_foreign_key is not None:
            vars()[column_name] = models.ForeignKey(col_foreign_key[0], on_delete=models.CASCADE, related_name=column_name)
            continue

        if col_data_type == "int":
            vars()[column_name] = models.PositiveIntegerField()
        elif col_data_type == "float":
            vars()[column_name] = models.FloatField()
        elif col_data_type == "text":
            vars()[column_name] = models.TextField()
        elif col_data_type == "array":
            vars()[column_name] = ArrayField(
                ArrayField(models.FloatField()))  # Array only exists in saving obs or action, so no need to worry it in cloud.
        elif col_data_type == "time":
            auto_now = True if column_name == 'create_time' else False
            vars()[column_name] = models.DateTimeField(auto_now=auto_now)
        else:
            raise ValueError("col_data_type: {} not defined!".format())

    class Meta:
        managed = True
        db_table = 'preference_user_demographic_table'


class PreferenceTable(models.Model):
    """
    Table saves segments.
    """
    table_name = 'preference_table'
    for column_name in db_table_config[table_name]:
        col_data_type = db_table_config[table_name][column_name]["data_type"]
        col_default = db_table_config[table_name][column_name]["default"]
        col_primary_key = db_table_config[table_name][column_name]["primary_key"]
        col_foreign_key = db_table_config[table_name][column_name]["foreign_key"]

        if col_primary_key is not None:
            vars()[column_name] = models.BigAutoField(primary_key=True)
            continue

        if col_foreign_key is not None:
            if col_foreign_key[0] == "preference_user_demographic_table":
                vars()[column_name] = models.ForeignKey(PreferenceUserDemographicTable, on_delete=models.CASCADE, db_column=column_name)
                continue
            elif col_foreign_key[0] == "segment_table":
                vars()[column_name] = models.ForeignKey(SegmentTable, on_delete=models.CASCADE, related_name=column_name, db_column=column_name)
                continue
            else:
                raise ValueError('col_foreign_key[0]:{}'.format(col_foreign_key[0]))

        if col_data_type == "int":
            vars()[column_name] = models.PositiveIntegerField()
        elif col_data_type == "float":
            vars()[column_name] = models.FloatField()
        elif col_data_type == "text":
            vars()[column_name] = models.TextField()
        elif col_data_type == "array":
            vars()[column_name] = ArrayField(
                ArrayField(models.FloatField()))  # Array only exists in saving obs or action, so no need to worry it in cloud.
        elif col_data_type == "time":
            auto_now = True if column_name == 'create_time' else False
            vars()[column_name] = models.DateTimeField(auto_now=auto_now)
        else:
            raise ValueError("col_data_type: {} not defined!".format())

    class Meta:
        managed = True
        db_table = 'preference_table'


class PreferenceSurveyTable(models.Model):
    """
    Table saves segments.
    """
    table_name = 'preference_survey_table'
    for column_name in db_table_config[table_name]:
        col_data_type = db_table_config[table_name][column_name]["data_type"]
        col_default = db_table_config[table_name][column_name]["default"]
        col_primary_key = db_table_config[table_name][column_name]["primary_key"]
        col_foreign_key = db_table_config[table_name][column_name]["foreign_key"]

        if col_primary_key is not None:
            vars()[column_name] = models.BigAutoField(primary_key=True)
            continue

        if col_foreign_key is not None:
            if col_foreign_key[0] == 'preference_user_demographic_table':
                vars()[column_name] = models.ForeignKey(PreferenceUserDemographicTable, on_delete=models.CASCADE, db_column=column_name)
            continue

        if col_data_type == "int":
            vars()[column_name] = models.PositiveIntegerField()
        elif col_data_type == "float":
            vars()[column_name] = models.FloatField()
        elif col_data_type == "text":
            vars()[column_name] = models.TextField()
        elif col_data_type == "array":
            vars()[column_name] = ArrayField(
                ArrayField(models.FloatField()))  # Array only exists in saving obs or action, so no need to worry it in cloud.
        elif col_data_type == "time":
            auto_now = True if column_name == 'create_time' else False
            vars()[column_name] = models.DateTimeField(auto_now=auto_now)
        else:
            raise ValueError("col_data_type: {} not defined!".format())

    class Meta:
        managed = True
        db_table = 'preference_survey_table'


class InteractiveExperienceSurveyTable(models.Model):
    """
    Table saves segments.
    """
    table_name = 'interactive_experience_survey_table'
    for column_name in db_table_config[table_name]:
        col_data_type = db_table_config[table_name][column_name]["data_type"]
        col_default = db_table_config[table_name][column_name]["default"]
        col_primary_key = db_table_config[table_name][column_name]["primary_key"]
        col_foreign_key = db_table_config[table_name][column_name]["foreign_key"]

        if col_primary_key is not None:
            vars()[column_name] = models.BigAutoField(primary_key=True)
            continue

        if col_foreign_key is not None:
            vars()[column_name] = models.ForeignKey(col_foreign_key[0], on_delete=models.CASCADE, related_name=col_foreign_key[1])
            continue

        if col_data_type == "int":
            vars()[column_name] = models.PositiveIntegerField()
        elif col_data_type == "float":
            vars()[column_name] = models.FloatField()
        elif col_data_type == "text":
            vars()[column_name] = models.TextField()
        elif col_data_type == "array":
            vars()[column_name] = ArrayField(
                ArrayField(models.FloatField()))  # Array only exists in saving obs or action, so no need to worry it in cloud.
        elif col_data_type == "time":
            auto_now = True if column_name == 'create_time' else False
            vars()[column_name] = models.DateTimeField(auto_now=auto_now)
        else:
            raise ValueError("col_data_type: {} not defined!".format())

    class Meta:
        managed = True
        db_table = 'interactive_experience_survey_table'


# import pdb; pdb.set_trace()
#
# # Create your models here.
# class VideoClipTable(models.Model):
#     """
#     Table saves all video clips and their corresponding obs-act data.
#         Note: this table is read only and it's written by learning agent.
#     """
#     behavior_mode = models.CharField(max_length=200)
#     camera_name = models.TextField()
#     video_clip_url = models.TextField()
#     video_clip_seg_len = models.PositiveIntegerField()
#     obs_trajectory = ArrayField(ArrayField(models.DecimalField(max_digits=19, decimal_places=10)))  # array of array of decimals
#     act_trajectory = ArrayField(ArrayField(models.DecimalField(max_digits=19, decimal_places=10)))  # array of array of decimals
#     obs2_trajectory = ArrayField(ArrayField(models.DecimalField(max_digits=19, decimal_places=10)))  # array of array of decimals
#     sampled_count = models.PositiveIntegerField()
#     video_clip_start_time = models.DateTimeField()
#     video_clip_end_time = models.DateTimeField()
#     create_time = models.DateTimeField(auto_now=True)
#
#     class Meta:
#         managed = True
#         db_table = "video_clip_table"
#
# class TeacherDemographicTable(models.Model):
#     """
#     Table saves all teachers' demographic data.
#     """
#     consent_anonymous_quotations = models.CharField(max_length=20)
#     age = models.CharField(max_length=200)
#     gender = models.CharField(max_length=200)
#     edu_background = models.CharField(max_length=200)
#     experience_date = models.CharField(max_length=200, null=True)
#     experience_start_time = models.CharField(max_length=200, null=True)
#     experience_end_time = models.CharField(max_length=200, null=True)
#     record_time = models.DateTimeField(auto_now=True)
#
#     class Meta:
#         managed = True
#         db_table = "teacher_demographic_table"
#
#
# class TeacherPreferenceTable(models.Model):
#     """
#     Table saves preference labels from novice teachers.
#     """
#     video_clip_1 = models.ForeignKey(VideoClipTable, on_delete=models.PROTECT, related_name='video_clip_1', default ="")
#     video_clip_2 = models.ForeignKey(VideoClipTable, on_delete=models.PROTECT, related_name='video_clip_2', default ="")
#     teacher = models.ForeignKey(TeacherDemographicTable, on_delete=models.CASCADE)
#     preference_choice = models.CharField(max_length=100)
#     preference_p_of_1_greater_2 = models.DecimalField(max_digits=2, decimal_places=1)
#     time_spend_for_labeling = models.FloatField(null=True, blank=True, default=None)
#     create_time = models.DateTimeField(auto_now=True)
#
#     class Meta:
#         managed = True
#         db_table = "teacher_preference_table"
#
#
# class PreferenceTeachingSurveyTable(models.Model):
#     """
#     Table saves questionnaire data of preference teachers.
#     """
#     teacher = models.ForeignKey(TeacherDemographicTable, on_delete=models.CASCADE)
#     # System Usability Scale
#     for q_label in SYSTEM_USABILITY_SCALE.keys():
#         vars()[q_label] = models.CharField(max_length=200)
#     # Custom questions
#     for q_label in CUSTOM_QUESTIONS_ON_PREFERENCE_TEACHING_PROCESS.keys():
#         vars()[q_label] = models.CharField(max_length=200)
#     # Open Questions
#     best_way_to_teach = models.CharField(max_length=500)
#     reason_for_choice = models.CharField(max_length=200)
#     general_comment = models.CharField(max_length=1000)
#     submit_time = models.DateTimeField(auto_now=True)
#
#     class Meta:
#         managed = True
#         db_table = "preference_teaching_survey_table"
#
#
# class InteractiveExperienceSurveyTable(models.Model):
#     """
#     Table saves all participants' survey data.
#     """
#     consent_anonymous_quotations = models.CharField(max_length=20)
#     # Demographic
#     experience = models.CharField(max_length=200)
#     age = models.CharField(max_length=200)
#     gender = models.CharField(max_length=200)
#     edu_background = models.CharField(max_length=200)
#     prior_experience_robot = models.CharField(max_length=200)
#     prior_experience_interactive_art = models.CharField(max_length=200)
#     perceive_interactive_art_as_robot = models.CharField(max_length=200)
#
#     # Godspeed questions
#     for q_label_god_speed in GOD_SPEED_QUESTIONS_LABELS:
#         vars()[q_label_god_speed] = models.CharField(max_length=200)
#
#     # Incentive & Self-efficacy & Intention of Use
#     for q_label_acceptance in PREDICT_USAGE_INTENTION_LABELS:
#         vars()[q_label_acceptance] = models.CharField(max_length=200)
#
#     # General comments
#     general_comments = models.CharField(max_length=1000)
#
#     # Record submit time
#     submit_time = models.DateTimeField(auto_now=True)
#
#     class Meta:
#         managed = True
#         db_table = "interactive_experience_survey_table"



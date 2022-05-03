from django.shortcuts import get_object_or_404, render
from django.urls import reverse
from django.views import generic
from .models import InteractiveExperienceSurveyTable, PreferenceUserDemographicTable, SegmentTable, PreferenceTable, PreferenceSurveyTable
from django.utils import timezone
from django.core.mail import send_mail
from django.core.mail import EmailMessage
from .survey_questions import GOD_SPEED_QUESTIONS, PREDICT_USAGE_INTENTION, SYSTEM_USABILITY_SCALE, CUSTOM_QUESTIONS_ON_PREFERENCE_TEACHING_PROCESS, \
    GOD_SPEED_QUESTIONS_LABELS, PREDICT_USAGE_INTENTION_LABELS

import os
import datetime
import random
import numpy as np

# Create your views here.
def index(request):
    num_teacher_participants = PreferenceUserDemographicTable.objects.count()
    num_interactive_exp_participants = InteractiveExperienceSurveyTable.objects.count()
    num_video_clips = SegmentTable.objects.count()
    num_preference_labels = PreferenceTable.objects.count()
    return render(request, 'app_teacher_preference/index.html',
                  {'num_teacher_participants': num_teacher_participants,
                   'num_interactive_exp_participants': num_interactive_exp_participants,
                   'num_video_clips': num_video_clips,
                   'num_preference_labels': num_preference_labels})


def general_visitor(request):
    return render(request, 'app_teacher_preference/general_visitor_info.html')


def interactive_experience_survey_consent(request):
    return render(request, 'app_teacher_preference/interactive_experience_survey_consent.html')


def interactive_experience_survey_data(request):
    if request.POST.get('submit_and_start_survey') == "False":
        return render(request, 'app_teacher_preference/index.html')
    else:
        # If confirm {participate + use data + above 18}, then proceed.
        # Otherwise, finish and back to homepage.
        if request.POST.get('above_18') == 'True':
            consent_anonymous_quotations = request.POST.get('consent_anonymous_quotations')

            # Godspeed questionnaires
            godspeed_questions = {}
            q_index = 1
            for questionnaire, questions in GOD_SPEED_QUESTIONS.items():
                for q_i in range(len(questions)):
                    print(questions[q_i])
                    print("{}: {}-{}-{}".format(q_index, questionnaire, questions[q_i][0], questions[q_i][1]))
                    godspeed_questions[q_index] = "{}-{}-{}".format(questionnaire, questions[q_i][0], questions[q_i][1])
                    q_index += 1
            # Randomize questions
            tmp_keys = list(godspeed_questions.keys())
            random.shuffle(tmp_keys)
            random_ordered_godspeed_questions = {}
            for key in tmp_keys:
                random_ordered_godspeed_questions[key] = godspeed_questions[key]

            # Incentives & Self-efficacy & Usage Intention
            incentives_questions = {}
            self_efficacy_questions = {}
            usage_intention_questions = {}
            for scale, scale_questions in PREDICT_USAGE_INTENTION.items():
                if scale == 'Interactive Art Incentives Scale':
                    for sub_scale, sub_scale_questions in scale_questions.items():
                        for q_k, q_i in sub_scale_questions.items():
                            incentives_questions[scale.replace(" ", "_") + '-' + sub_scale.replace(" ", "_") + '-' + q_k] = q_i
                elif scale == 'Interactive Art Self-Efficacy Scale':
                    for sub_scale, sub_scale_questions in scale_questions.items():
                        for q_k, q_i in sub_scale_questions.items():
                            self_efficacy_questions[scale.replace(" ", "_") + '-' + sub_scale.replace(" ", "_") + '-' + q_k] = q_i
                elif scale == 'Interactive Art Usage Intention':
                    for q_k, q_i in scale_questions.items():
                        usage_intention_questions[scale.replace(" ", "_") + '-' + q_k] = q_i
                else:
                    raise ValueError('Wrong scale {} in Usage Intention model!'.format(scale))
            # Randomize questions
            tmp_keys = list(incentives_questions.keys())
            random.shuffle(tmp_keys)
            random_ordered_incentives_questions = {}
            for key in tmp_keys:
                random_ordered_incentives_questions[key] = incentives_questions[key]

            tmp_keys = list(self_efficacy_questions.keys())
            random.shuffle(tmp_keys)
            random_ordered_self_efficacy_questions = {}
            for key in tmp_keys:
                random_ordered_self_efficacy_questions[key] = self_efficacy_questions[key]

            tmp_keys = list(usage_intention_questions.keys())
            random.shuffle(tmp_keys)
            random_ordered_usage_intention_questions = {}
            for key in tmp_keys:
                random_ordered_usage_intention_questions[key] = usage_intention_questions[key]

            # import pdb; pdb.set_trace()

            return render(request, 'app_teacher_preference/interactive_experience_survey_data.html',
                          {'consent_anonymous_quotations': consent_anonymous_quotations,
                           'random_ordered_godspeed_questions': random_ordered_godspeed_questions,
                           'random_ordered_incentives_questions': random_ordered_incentives_questions,
                           'random_ordered_self_efficacy_questions': random_ordered_self_efficacy_questions,
                           'random_ordered_usage_intention_questions': random_ordered_usage_intention_questions,
                           'current_date': datetime.datetime.now().strftime("%Y-%m-%d"),
                           'current_time': datetime.datetime.now().strftime("%H:%M"),
                           '10_Likert_scale': range(11)})
        else:
            consent_fail_reason = 'you did not confirm you are above 18 years old.'
            return render(request, 'app_teacher_preference/survey_consent_fail.html', {'consent_fail_reason': consent_fail_reason})


def interactive_experience_survey_thanks(request):
    # Store survey data to database
    interact_exp_sur_data = {}
    #
    interact_exp_sur_data['consent_anonymous_quotations'] = request.POST.get('consent_anonymous_quotations')
    # Demographic data
    interact_exp_sur_data['experience_date'] = str(request.POST.get('participant_experience_date'))
    interact_exp_sur_data['experience_start_time'] = str(request.POST.get('participant_experience_start_time'))
    interact_exp_sur_data['experience_end_time'] = str(request.POST.get('participant_experience_end_time'))
    interact_exp_sur_data['age'] = str(request.POST.get('participant_age'))
    interact_exp_sur_data['gender'] = str(request.POST.get('participant_gender'))
    interact_exp_sur_data['edu_background'] = str(request.POST.get('participant_edu_bg_1')) + "_" + \
                                              str(request.POST.get('participant_edu_bg_2')) + "_" + \
                                              str(request.POST.get('participant_edu_bg_3')) + "_" + \
                                              str(request.POST.get('participant_edu_bg_4')) + "_" + \
                                              str(request.POST.get('participant_edu_bg_5')) + "_" + \
                                              str(request.POST.get('participant_edu_bg_6')) + "_" + \
                                              str(request.POST.get('participant_edu_bg_7'))
    interact_exp_sur_data['prior_experience_robot'] = str(request.POST.get('participant_prior_exp_robot'))
    interact_exp_sur_data['prior_experience_interactive_art'] = str(
        request.POST.get('participant_prior_exp_interactive_art'))
    interact_exp_sur_data['perceive_interactive_art_as_robot'] = str(request.POST.get(
        'participant_perceive_interactive_art_as_robot'))
    # Godspeed Questions
    for q_label_god_speed in GOD_SPEED_QUESTIONS_LABELS:
        interact_exp_sur_data[q_label_god_speed] = str(request.POST.get(q_label_god_speed))
    # Incentive & Self-efficacy & Intention to Use
    for q_label_usage_intention in PREDICT_USAGE_INTENTION_LABELS:
        interact_exp_sur_data[q_label_usage_intention] = str(request.POST.get(q_label_usage_intention))
    # General comments
    interact_exp_sur_data['general_comment'] = str(request.POST.get('participant_general_comments'))
    # survey_data_args_dict['submit_time'] = datetime.datetime.now()
    survey_data_obj = InteractiveExperienceSurveyTable(**interact_exp_sur_data)
    survey_data_obj.save()
    return render(request, 'app_teacher_preference/interactive_experience_survey_thanks.html')


def survey_leave(request):
    return render(request, 'app_teacher_preference/survey_thanks.html')


def teach_consent(request):
    return render(request, 'app_teacher_preference/teach_consent.html')


def teach_welcome(request):
    # Send a copy of consent form to participant's email
    # print(request.POST)
    if request.POST.get('submit_and_start_survey') == "False":
        return render(request, 'app_teacher_preference/index.html')
    else:
        # If confirm {participate + use data + above 18}, then proceed.
        # Otherwise, finish and back to homepage.
        if request.POST.get('above_18') == 'True':
            consent_anonymous_quotations = request.POST.get('consent_anonymous_quotations')
            return render(request, 'app_teacher_preference/teach_welcome.html',
                          {'consent_anonymous_quotations': consent_anonymous_quotations,
                           'current_date': datetime.datetime.now().strftime("%Y-%m-%d"),
                           'current_time': datetime.datetime.now().strftime("%H:%M")})
        else:
            consent_fail_reason = 'you did not confirm you are above 18 years old.'
            return render(request, 'app_teacher_preference/teach_consent_fail.html',
                          {'consent_fail_reason': consent_fail_reason})


def sim_save_video_clips_obj():
    media_url_1 = "https://storage.googleapis.com/meander-simulated-video-clips/2020-06-13-22-48-28-289488_2020-06-13-22-48-33-206154_Mini-Map-Cam-VideoCapture_clip.mp4"
    media_url_2 = "https://storage.googleapis.com/meander-simulated-video-clips/2020-06-13-22-50-57-246237_2020-06-13-22-51-02-162903_Mini-Map-Cam-VideoCapture_clip.mp4"

    video_clips_args_dict = {}
    video_clips_args_dict['seg_exp_start_id'] = 1
    video_clips_args_dict['seg_exp_end_id'] = 1
    video_clips_args_dict['sampled_num'] = 0
    video_clips_args_dict['behavior_mode'] = "test"
    video_clips_args_dict['video_camera_name'] = 'VIP Mezzanine'
    video_clips_args_dict['video_clip_url'] = media_url_1
    video_clips_args_dict['video_clip_start_time'] = datetime.datetime.now()
    video_clips_args_dict['video_clip_end_time'] = datetime.datetime.now()
    video_clips_obj = SegmentTable(**video_clips_args_dict)
    video_clips_obj.save()

    video_clips_args_dict = {}
    video_clips_args_dict['seg_exp_start_id'] = 1
    video_clips_args_dict['seg_exp_end_id'] = 1
    video_clips_args_dict['sampled_num'] = 0
    video_clips_args_dict['behavior_mode'] = "test"
    video_clips_args_dict['video_camera_name'] = 'VIP Mezzanine'
    video_clips_args_dict['video_clip_url'] = media_url_1
    video_clips_args_dict['video_clip_start_time'] = datetime.datetime.now()
    video_clips_args_dict['video_clip_end_time'] = datetime.datetime.now()
    video_clips_obj = SegmentTable(**video_clips_args_dict)
    video_clips_obj.save()


def teach_data(request):
    # Save teacher data
    teacher_args_dict = {}
    teacher_args_dict['consent_anonymous_quotations'] = request.POST.get('consent_anonymous_quotations')
    teacher_args_dict['age'] = str(request.POST.get('teacher_age'))
    teacher_args_dict['gender'] = str(request.POST.get('teacher_gender'))
    teacher_args_dict['edu_background'] = str(request.POST.get('teacher_edu_bg_1')) + "_" + \
                                          str(request.POST.get('teacher_edu_bg_2')) + "_" + \
                                          str(request.POST.get('teacher_edu_bg_3')) + "_" + \
                                          str(request.POST.get('teacher_edu_bg_4')) + "_" + \
                                          str(request.POST.get('teacher_edu_bg_5')) + "_" + \
                                          str(request.POST.get('teacher_edu_bg_6')) + "_" + \
                                          str(request.POST.get('teacher_edu_bg_7'))
    teacher_args_dict['have_interacted_with_the_sculpture'] = str(request.POST.get('teacher_experienced_the_installation'))
    teacher_args_dict['experience_date'] = str(request.POST.get('teacher_experience_date'))
    teacher_args_dict['experience_start_time'] = str(request.POST.get('teacher_experience_start_time'))
    teacher_args_dict['experience_end_time'] = str(request.POST.get('teacher_experience_end_time'))
    teacher = PreferenceUserDemographicTable(**teacher_args_dict)
    teacher.save()

    # # # TODO: delete this after testing
    # sim_save_video_clips_obj()

    # Sample video clips belong to behaviour_mode from VideoClipsAndObsActData table.
    # behaviour_mode = 'TeacherPreference'
    # total_entry_num = VideoClipsAndObsActData.objects.filter(behaviour_mode=behaviour_mode).count()
    total_entry_num = SegmentTable.objects.count()
    print("Number of entries in VideoClipsAndObsActData: {}".format(total_entry_num))
    sample_from_last_num = 1000
    end_index = total_entry_num
    if total_entry_num >= 2:
        if total_entry_num < sample_from_last_num:
            start_index = 0
        else:
            start_index = end_index-(1000-1)
        valid_index = list(range(start_index, end_index))
        random.shuffle(valid_index)
        # id_set = VideoClipsAndObsActData.objects.values_list('id', flat=True).filter(behaviour_mode=behaviour_mode)
        id_set = SegmentTable.objects.values_list('id', flat=True)
        random_unique_ids = [id_set[valid_index.pop()], id_set[valid_index.pop()]]
        sampled_video_objs = SegmentTable.objects.filter(pk__in=random_unique_ids)

        # Get the number of preference labels provided by the teacher
        provided_preference_label_num = PreferenceTable.objects.filter(teacher_id=teacher.id).count()
        # import pdb; pdb.set_trace()
        return render(request, 'app_teacher_preference/teach_data.html',
                      context={"video_clip_1": sampled_video_objs[0],
                               'video_clip_2': sampled_video_objs[1],
                               'teacher': teacher,
                               'provided_preference_label_num': provided_preference_label_num,
                               'labeling_start_time': datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")})
    else:
        return render(request, 'app_teacher_preference/teach_no_data_warning.html')


def teach_data_collect(request):
    # Save preference label
    labeling_end_time = datetime.datetime.now()
    teacher = get_object_or_404(PreferenceUserDemographicTable, pk=request.POST['teacher_id'])
    video_clip_1 = get_object_or_404(SegmentTable, pk=request.POST['video_clip_1_id'])
    video_clip_2 = get_object_or_404(SegmentTable, pk=request.POST['video_clip_2_id'])
    labeling_start_time = datetime.datetime.strptime(request.POST.get('labeling_start_time'), '%Y-%m-%d %H:%M:%S.%f')
    time_spend_for_labeling = (labeling_end_time - labeling_start_time).total_seconds()

    preference_label_btn = request.POST.get('preference_label_btn')
    if preference_label_btn == "Left is better":
        pref_label = 0
        preference_choice = 'left'
    elif preference_label_btn == "Right is better":
        pref_label = 1
        preference_choice = 'right'
    elif preference_label_btn == "Can't tell, equally good!":
        pref_label = 0.5
        preference_choice = 'abstain_equally_good'
    elif preference_label_btn == "Can't tell, equally so-so!":
        pref_label = 0.5
        preference_choice = 'abstain_equally_soso'
    elif preference_label_btn == "Can't tell, equally bad!":
        pref_label = -0.5
        preference_choice = 'abstain_equally_bad'
    else:
        raise ValueError('teacher_preference value wrong!')
    # 90% of comparisons will go to training dataset.
    training_probability = 0.9
    train_set = True if np.random.rand() <= training_probability else False
    preference_label_obj = PreferenceTable(seg_1_id=video_clip_1, seg_2_id=video_clip_2, pref_choice=preference_choice,
                                           pref_label=pref_label, time_spend_for_labeling=time_spend_for_labeling,
                                           teacher_id=teacher, train_set=train_set, sampled_num=0)
    preference_label_obj.save()

    # Sample video clips from VideoClipsAndObsActData table.
    # behaviour_mode = 'TeacherPreference'
    # total_entry_num = VideoClipsAndObsActData.objects.filter(behaviour_mode=behaviour_mode).count()
    total_entry_num = SegmentTable.objects.count()
    print("Number of entries in VideoClipsAndObsActData: {}".format(total_entry_num))
    sample_from_last_num = 1000
    end_index = total_entry_num
    if total_entry_num > 0:
        if total_entry_num < sample_from_last_num:
            start_index = 0
        else:
            start_index = end_index - (1000 - 1)

        valid_index = list(range(start_index, end_index))
        random.shuffle(valid_index)
        # id_set = VideoClipsAndObsActData.objects.values_list('id', flat=True).filter(behaviour_mode=behaviour_mode)
        id_set = SegmentTable.objects.values_list('id', flat=True)
        random_unique_ids = [id_set[valid_index.pop()], id_set[valid_index.pop()]]
        sampled_video_objs = SegmentTable.objects.filter(pk__in=random_unique_ids)

        # Get the number of preference labels provided by the teacher
        provided_preference_label_num = PreferenceTable.objects.filter(teacher_id=teacher.id).count()
        return render(request, 'app_teacher_preference/teach_data.html',
                      context={'video_clip_1': sampled_video_objs[0],
                               'video_clip_2': sampled_video_objs[1],
                               'teacher': teacher,
                               'provided_preference_label_num': provided_preference_label_num,
                               'labeling_start_time': datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")})
    else:
        return render(request, 'app_teacher_preference/teach_no_data_warning.html')


def teach_questionnaire(request):
    teacher = get_object_or_404(PreferenceUserDemographicTable, pk=request.POST['teacher_id'])
    #
    system_usability_scale = {}
    for q_k, q_i in SYSTEM_USABILITY_SCALE.items():
        system_usability_scale[q_k] = q_i
    custom_questions = {}
    for q_k, q_i in CUSTOM_QUESTIONS_ON_PREFERENCE_TEACHING_PROCESS.items():
        custom_questions[q_k] = q_i
    # Randomly order statements
    tmp_keys = list(system_usability_scale.keys())
    random.shuffle(tmp_keys)
    random_ordered_system_usability_scale = {}
    for key in tmp_keys:
        random_ordered_system_usability_scale[key] = system_usability_scale[key]

    tmp_keys = list(custom_questions.keys())
    random.shuffle(tmp_keys)
    random_ordered_custom_questions = {}
    for key in tmp_keys:
        random_ordered_custom_questions[key] = custom_questions[key]

    return render(request, 'app_teacher_preference/teach_questionnaire.html',
                  context={'teacher': teacher,
                           'random_ordered_system_usability_scale': random_ordered_system_usability_scale,
                           'system_usability_scale_likert_scale': range(1, 6),
                           'random_ordered_custom_questions': random_ordered_custom_questions,
                           'custom_questions_likert_scale': range(11)})


def teach_thanks(request):
    # Save survey data
    teacher = get_object_or_404(PreferenceUserDemographicTable, pk=request.POST['teacher_id'])

    # Store survey data to database
    survey_data_args_dict = {}
    survey_data_args_dict['teacher_id'] = teacher

    # System Usability Scale (SUS)
    for q_label_SUS in SYSTEM_USABILITY_SCALE.keys():
        survey_data_args_dict[q_label_SUS] = str(request.POST.get(q_label_SUS))

    # Custom Questions
    for q_label_custom in CUSTOM_QUESTIONS_ON_PREFERENCE_TEACHING_PROCESS:
        survey_data_args_dict[q_label_custom] = str(request.POST.get(q_label_custom))

    survey_data_args_dict['best_way_to_teach'] = str(request.POST.get('best_way_to_teach_1')) + "_" + \
                                                 str(request.POST.get('best_way_to_teach_2')) + "_" + \
                                                 str(request.POST.get('best_way_to_teach_3')) + "_" + \
                                                 str(request.POST.get('best_way_to_teach_4')) + "_" + \
                                                 str(request.POST.get('best_way_to_teach_5')) + "_" + \
                                                 str(request.POST.get('best_way_to_teach_6'))

    survey_data_args_dict['reason_for_choice'] = request.POST.get('reason_for_choice')
    survey_data_args_dict['general_comment'] = request.POST.get('general_comment')

    # survey_data_args_dict['submit_time'] = datetime.datetime.now()
    survey_data_obj = PreferenceSurveyTable(**survey_data_args_dict)
    survey_data_obj.save()

    # Get the number of preference labels provided by the teacher
    provided_preference_label_num = PreferenceTable.objects.filter(teacher_id=request.POST['teacher_id']).count()

    return render(request, 'app_teacher_preference/teach_thanks.html',
                  context={'provided_preference_label_num': provided_preference_label_num})


def teach_leave(request):
    return render(request, 'app_teacher_preference/teach_thanks.html')


def teach(request):
    media_url_1 = "https://storage.googleapis.com/las-example-store/Camera1_Oct_02_1300_1400_Prescribed_behavior_Visitors_interacting_with_the_system.mp4"
    media_url_2 = "https://storage.googleapis.com/las-example-store/Camera1_Oct_05_1400_1500_Parameterized_Learning_Agent_Interesting_pattern_different_from_PB.mp4"
    return render(request, 'app_teacher_preference/teach.html', context={'media_url_1': media_url_1, 'media_url_2': media_url_2})

def about(request):
    return render(request, 'app_teacher_preference/about.html')
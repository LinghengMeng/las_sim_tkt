###############################################################
#               Interactive Experience Survey                 #
###############################################################
# Godspeed questionnaires:
GOD_SPEED_QUESTIONS = {'GODSPEED: ANIMACY': [['Dead', 'Alive'],
                                             ['Stagnant', 'Lively'],
                                             ['Mechanical', 'Organic'],
                                             ['Artificial', 'Lifelike'],
                                             ['Inert', 'Interactive'],
                                             ['Apathetic', 'Responsive']],
                       'GODSPEED: LIKEABILITY': [['Dislike', 'Like'],
                                                 ['Unfriendly', 'Friendly'],
                                                 ['Unkind', 'Kind'],
                                                 ['Unpleasant', 'Pleasant'],
                                                 ['Awful', 'Nice']],
                       'GODSPEED: PERCEIVED INTELLIGENCE': [['Incompetent', 'Competent'],
                                                            ['Ignorant', 'Knowledgeable'],
                                                            ['Irresponsible', 'Responsible'],
                                                            ['Unintelligent', 'Intelligent'],
                                                            ['Foolish', 'Sensible']]}
GOD_SPEED_QUESTIONS_LABELS = []   # Only used to define database Model in models.py
for category in GOD_SPEED_QUESTIONS.keys():
    for q_i in range(len(GOD_SPEED_QUESTIONS[category])):
        GOD_SPEED_QUESTIONS_LABELS.append(category.replace(": ", "_").replace(" ", "") + '_' + GOD_SPEED_QUESTIONS[category][q_i][0].replace(" ", "") + '_' + GOD_SPEED_QUESTIONS[category][q_i][1].replace(" ", ""))

# Incentives & Self-efficacy & Usage Intention
PREDICT_USAGE_INTENTION = {'Interactive Art Incentives Scale': {'Emotion': {'Q1': 'I enjoy interacting with this sculpture.',
                                                                            'Q2': 'I like to have this sculpture around me.',
                                                                            'Q3': 'This sculpture evokes emotions in me.',
                                                                            'Q4': 'I feel happy to walk around the sculpture.',
                                                                            'Q5': 'I like the sculpture’s appearance.',
                                                                            'Q6': 'I feel surprised by the reaction of the sculpture.',
                                                                            'Q7': 'I feel encouraged to interact with the sculpture when observing other people’s interaction.',
                                                                            'Q8': 'I feel excited that the sculpture keeps changing its reaction to me.'},
                                                                'Utility': {'Q9': 'This sculpture is able to engage me immediately after I approach it.',
                                                                            'Q10': 'This sculpture is useful for me to have in my life.',
                                                                            'Q11': 'This sculpture is able to engage me over the  long-term.',
                                                                            'Q12': 'This sculpture has reliably entertained me.'},
                                                                'Art Appreciation': {'Q13': 'The sculpture inspires me to think about things in a new way.',
                                                                                     'Q14': 'The scale of the sculpture immerses me in the interaction with it.',
                                                                                     'Q15': 'The sculpture makes me feel it is alive.',
                                                                                     'Q16': 'The sculpture makes me reflect.',
                                                                                     'Q17': 'The sculpture evokes a feeling of wonder.',
                                                                                     'Q18': 'I find the sculpture is fascinating and it draws my attention.'},
                                                                'Social Connection': {'Q19': 'I feel close to this sculpture.',
                                                                                      'Q20': 'I feel socially connected to the sculpture.',
                                                                                      'Q21': 'I am happy to share the interaction with the sculpture with others.'}},
                           'Interactive Art Self-Efficacy Scale': {'Ease of Interaction': {'Q22': 'Interact easily with this sculpture',
                                                                                           'Q23': 'Interact with the sculpture freely without knowing how and why the sculpture behaves like it does',
                                                                                           'Q24': 'Learn how to interact to my own satisfaction with this sculpture without help'},
                                                                   'Application': {'Q25': 'Interact with this sculpture to engage and entertain myself ',
                                                                                   'Q26': 'Arouse other people’s curiosity to interact with the sculpture',
                                                                                   'Q27': 'Draw other people’s attention by interacting with the sculpture'}},
                           'Interactive Art Usage Intention': {'Q28': 'I would interact with this sculpture often.',
                                                               'Q29': 'I would recommend that my friends interact with the sculpture.',
                                                               'Q30': 'I would spend time with this sculpture.',
                                                               'Q31': 'I would interact with this sculpture for a long time.'}}
PREDICT_USAGE_INTENTION_LABELS = []
for scale in PREDICT_USAGE_INTENTION.keys():
    if scale != 'Interactive Art Usage Intention':
        for sub_scale in PREDICT_USAGE_INTENTION[scale].keys():
            for ques_key in PREDICT_USAGE_INTENTION[scale][sub_scale].keys():
                PREDICT_USAGE_INTENTION_LABELS.append(
                    scale.replace(" ", "").replace("-", "") + '_' + sub_scale.replace(" ", "") + '_' + ques_key)
    else:
        for ques_key in PREDICT_USAGE_INTENTION[scale].keys():
            PREDICT_USAGE_INTENTION_LABELS.append(
                scale.replace(" ", "") + '_' + ques_key)

###############################################################
#                   Preference Teaching Survey                #
###############################################################
# System Usability Scale (SUS):
#   To make it easy to understand the questions for participants, "the system" is replace with "the interface".
SYSTEM_USABILITY_SCALE = {'SUS_Q1': 'I think that I would like to use this interface frequently.',
                          'SUS_Q2': 'I found the interface unnecessarily complex.',
                          'SUS_Q3': 'I thought the interface was easy to use.',
                          'SUS_Q4': 'I think that I would need the support of a technical person to be able to use this interface.',
                          'SUS_Q5': 'I found the various functions in this interface were well integrated.',
                          'SUS_Q6': 'I thought there was too much inconsistency in this interface.',
                          'SUS_Q7': 'I would imagine that most people would learn to use this interface very quickly.',
                          'SUS_Q8': 'I found the interface very cumbersome to use.',
                          'SUS_Q9': 'I felt very confident using the interface.',
                          'SUS_Q10': 'I needed to learn a lot of things before I could get going with this interface.'}
CUSTOM_QUESTIONS_ON_PREFERENCE_TEACHING_PROCESS = {'Emotion_Q1': 'I like this teaching process.',
                                                   'Emotion_Q2': 'I enjoy providing my preference of video clip to teach the sculpture how to engage visitors.',
                                                   'Emotion_Q3': 'I find it is easy to choose the video clip I prefer.',
                                                   'Emotion_Q4': 'I am unhappy with the “Cannot Tell” queries.',
                                                   'Emotion_Q5': 'If I should use the teaching interface, I would be afraid to provide unreliable feedback.',
                                                   'Emotion_Q6': 'If I should use the teaching interface, I would be afraid to ruin the sculpture’s behavior by providing incorrect feedback.',
                                                   'Utility_Q1': 'This teaching process would be able to make the sculpture’s behavior more engaging.',
                                                   'Utility_Q2': 'This teaching process would be useful for me to teach the sculpture how to generate more engaging behavior.',
                                                   'Utility_Q3': 'This  teaching process would be able to help any user to adapt the sculpture’s behavior to his/her preferences.',
                                                   'Utility_Q4': 'This teaching process would provide reliable assistance to adapt the sculpture’s behavior.',
                                                   'Social_Connection_Q1': 'I feel socially connected to the visitors of the sculpture, even though they are not aware I am one of the teachers who taught this sculpture.',
                                                   'Social_Connection_Q2': 'I am aware that the sculpture I am teaching is intended to engage its visitors.',
                                                   'Social_Connection_Q3': 'I am proud to tell the visitors of the sculpture that I contributed to teaching the sculpture.',
                                                   'Social_Connection_Q4': 'I would recommend to my friends that they use the interface to help teach the sculpture.'}

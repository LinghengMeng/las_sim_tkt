"""las_teacher_gui URL Configuration

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/2.1/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path
import app_teacher_preference.views

urlpatterns = [
path('admin/', admin.site.urls),
    path('', app_teacher_preference.views.index, name='index'),
    path('index', app_teacher_preference.views.index, name='index'),
    path('general_visitor', app_teacher_preference.views.general_visitor, name='general_visitor'),
    path('teach_consent', app_teacher_preference.views.teach_consent, name='teach_consent'),
    path('teach_welcome', app_teacher_preference.views.teach_welcome, name='teach_welcome'),
    path('teach_data', app_teacher_preference.views.teach_data, name='teach_data'),
    path('teach_data_collect', app_teacher_preference.views.teach_data_collect, name='teach_data_collect'),
    path('teach_questionnaire', app_teacher_preference.views.teach_questionnaire, name='teach_questionnaire'),
    path('teach_thanks', app_teacher_preference.views.teach_thanks, name='teach_thanks'),
    path('teach_leave', app_teacher_preference.views.teach_leave, name='teach_leave'),
    path('interactive_experience_survey_consent/', app_teacher_preference.views.interactive_experience_survey_consent, name='interactive_experience_survey_consent'),
    path('interactive_experience_survey_data', app_teacher_preference.views.interactive_experience_survey_data, name='interactive_experience_survey_data'),
    path('interactive_experience_survey_thanks', app_teacher_preference.views.interactive_experience_survey_thanks, name='interactive_experience_survey_thanks'),
    path('survey_leave', app_teacher_preference.views.survey_leave, name='survey_leave'),
    path('teach/', app_teacher_preference.views.teach, name='teach'),
    path('about/', app_teacher_preference.views.about, name='about'),
]

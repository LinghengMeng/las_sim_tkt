# Generated by Django 3.2.8 on 2021-11-01 19:12

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('app_teacher_preference', '0001_initial'),
    ]

    operations = [
        migrations.AlterField(
            model_name='interactiveexperiencesurveytable',
            name='create_time',
            field=models.DateTimeField(auto_now=True),
        ),
        migrations.AlterField(
            model_name='preferencesurveytable',
            name='create_time',
            field=models.DateTimeField(auto_now=True),
        ),
        migrations.AlterField(
            model_name='preferencetable',
            name='create_time',
            field=models.DateTimeField(auto_now=True),
        ),
        migrations.AlterField(
            model_name='preferenceuserdemographictable',
            name='create_time',
            field=models.DateTimeField(auto_now=True),
        ),
        migrations.AlterField(
            model_name='segmenttable',
            name='create_time',
            field=models.DateTimeField(auto_now=True),
        ),
    ]

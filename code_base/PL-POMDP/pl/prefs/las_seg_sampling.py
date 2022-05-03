"""
Different from simulated GYM tasks where a segment of trajectory is sampled then a video can be rendered, for the field study of LAS a segment of
video is sampled from the raw video recording first then the corresponding of the segment of the trajectory is extracted from the memory.
"""
import sys
import cv2
import datetime
import os
import shutil
import glob
from sys import platform
import argparse
from PIL import Image
from PIL import ImageDraw
from PIL import ImageFilter
import time
import numpy as np
from matplotlib import pyplot as plt
from collections import deque
import pkg_resources
from google.cloud import storage
from pl.mems.db_manager import DatabaseManager
import pl

# Import Openpose (Windows/Ubuntu/OSX)
print('Importing Openpose ...')
openpose_dir = os.path.join(os.path.dirname(pl.__file__), 'rsrc\openpose')
# openpose_build_path = os.path.join(openpose_dir, 'build_windows')
# openpose_model_path = os.path.join(openpose_dir, 'models')
# TODO: need to find a way to include compiled Openpose to repository
openpose_build_path = r"E:\git_repos\openpose\build_windows"
openpose_model_path = r"E:\git_repos\openpose\models"
google_cloud_storage_credentials_file = os.path.join(os.path.dirname(pl.__file__), 'rsrc\las-ai-ae1df2a3ca2b.json')

try:
    # Windows Import
    if platform == "win32":
        # Change these variables to point to the correct folder (Release/x64 etc.)
        sys.path.append(r'{}\python\openpose\Release'.format(openpose_build_path))
        os.environ['PATH'] = os.environ['PATH'] + ';' + r'{}\x64\Release;'.format(
            openpose_build_path) + r'{}\bin;'.format(openpose_build_path)
        import pyopenpose as op
        print('Import Openpose done!')
    else:
        # Change these variables to point to the correct folder (Release/x64 etc.)
        sys.path.append(r'{}\python'.format(openpose_build_path))
        # If you run `make install` (default path is `/usr/local/python` for Ubuntu), you can also access the OpenPose/python module from there. This will install OpenPose and the python library at your desired installation path. Ensure that this is in your python path in order to use it.
        # sys.path.append('/usr/local/python')
        from openpose import pyopenpose as op
except ImportError as e:
    print(
        'Error: OpenPose library could not be found. Did you enable `BUILD_PYTHON` in CMake and have this Python script in the right folder?')
    raise e

# os.environ["PATH"] += os.pathsep + pkg_resources.resource_filename('las_ai', 'resources/ffmpeg/Windows/ffmpeg/ffmpeg-20200528-c0f01ea-win64-static/bin')
# pkg_resources.resource_string('las_ai', 'resources/ffmpeg/Windows/ffmpeg/ffmpeg-20200528-c0f01ea-win64-static/bin')
ffmpeg_dir = os.path.join(os.path.dirname(pl.__file__), 'rsrc\ffmpeg')
os.environ["PATH"] += os.pathsep + os.path.join(ffmpeg_dir, 'Windows\ffmpeg-20200528-c0f01ea-win64-static\bin')


class VideoClipGenerator(object):
    def __init__(self, video_data_dir=None,
                 local_db_config=None, cloud_db_config=None, experiment_checkpoint_dir=None):
        """
        Initialize all hyper-parameters.

        Video file structure:
            video_orig_todo_dir: original videos not being processed yet
            video_orig_face_blurred_dir: original videos that are face blurred but not yet been vetted by researchers.
            video_orig_done_dir: face blurred videos that have been visually vetted by researchers to ensure identifications are removed.

            video_clip_todo_dir: video clips with face blurred but not been vetted yet.
            video_clip_vetted_dir: video clips vetted by researchers.
            video_clip_stored_dir: vetted video clips stored into the video_clip_table
        """
        # Hyperparameters:
        # Region of Interest: region in where human faces will be detected
        # Demo: self.roi_polygon = np.array(
        #             [[(0, 420), (20, 430), (50, 440), (90, 440), (110, 430), (150, 440), (210, 450), (250, 410), (280, 410),
        #               (300, 380), (430, 380), (460, 400), (500, 360), (570, 360), (590, 380), (610, 380), (620, 365),
        #               (650, 365), (660, 385), (800, 385),
        #               (840, 400), (770, 420), (820, 420), (780, 450), (800, 455), (800, 500),
        #               (650, 515), (265, 720), (0, 720), (0, 580), (280, 540), (280, 530), (0, 510)]], np.int32)
        self.roi_polygon = np.array([[(1920, 350), (1500, 350), (1080, 350), (650, 400),
                                      (650, 500), (0, 500), (0, 1080), (1920, 1080)]], np.int32)
        # Region of Disinterest: where the whole region will be blurred
        # Demo: self.rod_polygon = [np.array([[(0, 510), (280, 530), (280, 540), (0, 580)]], np.int32),
        #                             np.array([[(265, 720), (650, 515), (800, 505), (900, 560), (850, 600),
        #                                        (860, 630), (950, 600), (950, 620), (890, 670), (940, 650),
        #                                        (940, 665), (890, 700), (950, 700), (990, 670), (960, 720),
        #                                        (1080, 720), (1100, 720), (1150, 580), (1280, 580), (1280, 720), (265, 720)]],
        #                                      np.int32)]
        self.rod_polygon = []

        self.add_pose = False                    # Add Openpose skeleton or not
        self.face_size_threshold = 500
        self.face_size = 50                      # Use fixed face size is better because of the inaccurate OpenPose Output
        self.face_dectection_window_size = 5

        # Face blurring
        self.kernel_size_face_blur = 21          # Decide the degree of face blur
        self.draw_face_rectangle = False          # Draw rectangle around the detected faces

        # Region of disinterest blurring
        self.kernel_size_rod_blur = 51           # Decide the degree of region of disinterest blur
        self.draw_rod_rectangle = True

        # Video saving properties
        self.video_output_format = 'mp4'                         # only consider 'mp4'
        self.video_fourcc = 'mp4v'                               # Define four character code. Use 'mp4v' rather than 'MP4V', when using ffmpeg.
        self.video_clip_length_second = 30                        # video clip length of 5 seconds
        self.video_clip_down_sample_ratio = 1                    # (0,1] downsample ratio along width and height

        self.video_name_time_format = "%Y-%m-%d-%H-%M-%S"        # time format used in the name of the original video and video clips
        self.display_processed_frame = False

        # Custom Openpose Params (refer to include/openpose/flags.hpp for more parameters)
        openpose_params = dict()
        openpose_params["model_folder"] = openpose_model_path
        # Starting OpenPose
        self.opWrapper = op.WrapperPython()
        self.opWrapper.configure(openpose_params)
        self.opWrapper.start()

        # Set video data directories
        self.orig_video_dir = os.path.join(video_data_dir, 'video_orig')                    # Store all original videos
        self.orig_video_todo_dir = os.path.join(video_data_dir, 'video_orig_todo')          # Store original videos that are waiting for processing
        self.orig_video_face_blurred_dir = os.path.join(video_data_dir, 'video_orig_face_blurred')   # Store all face blurred videos
        self.orig_video_done_dir = os.path.join(video_data_dir, 'video_orig_done')          # Store all processed original videos
        if not os.path.exists(video_data_dir):
            os.makedirs(video_data_dir)
        if not os.path.exists(self.orig_video_dir):
            os.makedirs(self.orig_video_dir)
        if not os.path.exists(self.orig_video_todo_dir):
            os.makedirs(self.orig_video_todo_dir)
        if not os.path.exists(self.orig_video_face_blurred_dir):
            os.makedirs(self.orig_video_face_blurred_dir)
        if not os.path.exists(self.orig_video_done_dir):
            os.makedirs(self.orig_video_done_dir)

        self.video_clip_todo_dir = os.path.join(video_data_dir, 'video_clip_todo')          # Store all generated video clips
        self.video_clip_todo_compressed_dir = os.path.join(video_data_dir, 'video_clip_todo_compressed')         # Store all generated video clips
        self.video_clip_vetted_dir = os.path.join(video_data_dir, 'video_clip_vetted')      # Store video clips vetted by researchers
        self.video_clip_stored_dir = os.path.join(video_data_dir, 'video_clip_stored')      # Store video clips successfully stored
        if not os.path.exists(self.video_clip_todo_dir):
            os.makedirs(self.video_clip_todo_dir)
        if not os.path.exists(self.video_clip_todo_compressed_dir):
            os.makedirs(self.video_clip_todo_compressed_dir)
        if not os.path.exists(self.video_clip_vetted_dir):
            os.makedirs(self.video_clip_vetted_dir)
        if not os.path.exists(self.video_clip_stored_dir):
            os.makedirs(self.video_clip_stored_dir)

        # Init Google storage related settings: https://cloud.google.com/docs/authentication/getting-started
        os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = google_cloud_storage_credentials_file
        self.google_storage_client = storage.Client()
        self.google_storage_video_clip_bucket_name = 'mender_video_clips'

        # Database manager is the unified interface used to manipulate the database.
        self.mem_manager = DatabaseManager(local_db_config, cloud_db_config, experiment_checkpoint_dir)

    def blur_and_clip(self):
        """Blur raw videos and cut it into video clips."""
        # Iterate all videos in orig_video_todo_dir
        for orig_video_path in glob.glob(os.path.join(self.orig_video_todo_dir, '*.mp4')):
            print("Processing {}".format(orig_video_path))
            orig_video_path = os.path.abspath(orig_video_path)

            # Extract video info for creating clip file name
            orig_video_file_name = orig_video_path.split('\\')[-1]
            orig_video_info = orig_video_file_name.split('_')
            orig_video_start_time = datetime.datetime.strptime(orig_video_info[0], self.video_name_time_format)
            orig_video_camera = orig_video_info[2].split('.')[0]

            # Init video capture and extract video properties
            orig_video_cap = cv2.VideoCapture(orig_video_path)
            if (orig_video_cap.isOpened() == False):
                print('Error while trying to read video. Please check path again')
            # get the video frames' width and height
            orig_video_frame_width = int(orig_video_cap.get(3))
            orig_video_frame_height = int(orig_video_cap.get(4))
            orig_video_fps = orig_video_cap.get(cv2.CAP_PROP_FPS)
            print('Total frames of the raw video: {}'.format(orig_video_cap.get(cv2.CAP_PROP_FRAME_COUNT)))

            # set the save path
            face_blurred_video_save_path = os.path.join(self.orig_video_face_blurred_dir,
                                                        'face_blurred_video_{}'.format(orig_video_file_name))

            # Create VideoWriter object
            # face_blurred_video_out is for visually vetting identity removing, as vetting video clips is too inconvenient.
            face_blurred_video_out = cv2.VideoWriter(face_blurred_video_save_path,
                                                     cv2.VideoWriter_fourcc(*self.video_fourcc),
                                                     orig_video_fps,
                                                     (orig_video_frame_width, orig_video_frame_height))
            # Video clips
            video_clip_length_frame = round(self.video_clip_length_second * orig_video_fps)
            video_clip_frame_width = int(orig_video_frame_width * self.video_clip_down_sample_ratio)
            video_clip_frame_height = int(orig_video_frame_height * self.video_clip_down_sample_ratio)
            video_clip_flag = False  # Indicate if video clip is generating

            # Blur all dectected faces within the face_dectection_window to avoid missing detection
            face_dectection_window_flag = deque(maxlen=self.face_dectection_window_size)
            face_dectection_window_pose = deque(maxlen=self.face_dectection_window_size)

            # Log info
            frame_count = 0  # to count total frames
            total_fps = 0  # to get the final frames per second

            while (orig_video_cap.isOpened()):
                retval, image = orig_video_cap.read()
                if retval == True:
                    # get the start time
                    start_time = time.time()
                    ###################################################################################
                    # 1. Extract Region of Interest(ROI) for Face Detection
                    #    Generate mask with 0 outside the ROI and 255 within the ROI
                    if len(self.roi_polygon) != 0:
                        roi_mask = np.zeros(image.shape[:2], dtype="uint8")
                        cv2.fillPoly(roi_mask, self.roi_polygon, True, 255)
                        roi_image = cv2.bitwise_and(image, image, mask=roi_mask)
                    else:
                        roi_image = image

                    # 2. Detect faces within ROI
                    datum = op.Datum()
                    datum.cvInputData = roi_image
                    self.opWrapper.emplaceAndPop(op.VectorDatum([datum]))
                    # print('Frame: {}, Detected {} people'.format(frame_count + 1,
                    #                                              len(datum.poseKeypoints) if datum.poseKeypoints is not None else 0))

                    # Add pose skeleton
                    if self.add_pose:
                        roi_image = datum.cvOutputData

                    # Blur all human faces detected within face_dectection_window
                    face_dectection_window_flag.append(1 if datum.poseKeypoints is not None else 0)
                    face_dectection_window_pose.append(datum.poseKeypoints)

                    # Exist detected human face
                    if np.sum(face_dectection_window_flag) != 0:
                        # Blur human faces
                        face_blurred_roi_image = cv2.GaussianBlur(image, (self.kernel_size_face_blur, self.kernel_size_face_blur),
                                                                  0)
                        face_blur_mask = np.zeros(image.shape, dtype=np.uint8)

                        #
                        for pre_detected_pose in face_dectection_window_pose:
                            if pre_detected_pose is not None:
                                # Add mask to each detected face
                                for person in pre_detected_pose:
                                    # Blur faces
                                    width = self.face_size
                                    if width <= self.face_size_threshold:
                                        face_blur_mask = cv2.rectangle(face_blur_mask,
                                                                       (int(person[0][0] - width * 0.8),
                                                                        int(person[0][1] - width * 0.8)),
                                                                       (int(person[0][0] + width * 0.8),
                                                                        int(person[0][1] + width * 0.8)),
                                                                       (255, 255, 255), -1)
                                        # Draw rectangle around the detected face
                                        if self.draw_face_rectangle:
                                            cv2.rectangle(roi_image,
                                                          (int(person[0][0] - width * 0.8),
                                                           int(person[0][1] - width * 0.8)),
                                                          (int(person[0][0] + width * 0.8),
                                                           int(person[0][1] + width * 0.8)),
                                                          (0, 0, 255), 4)
                        face_blurred_roi_image = np.where(face_blur_mask == np.array([255, 255, 255]),
                                                          face_blurred_roi_image,
                                                          roi_image)
                    else:
                        face_blurred_roi_image = roi_image

                    # Blur Region of Disinterest
                    if len(self.rod_polygon) != 0:
                        rod_blurred_image = cv2.GaussianBlur(image, (self.kernel_size_rod_blur, self.kernel_size_rod_blur), 0)
                        rod_blur_mask = np.zeros(image.shape, dtype=np.uint8)
                        rod_blur_mask = cv2.fillPoly(rod_blur_mask, self.rod_polygon, color=(255, 255, 255))
                        rod_blurred_image = np.where(rod_blur_mask == np.array([255, 255, 255]), rod_blurred_image, image)
                    else:
                        rod_blurred_image = image
                    # Combine ROI with face blurred and ROD with whole area blurred
                    combine_mask = np.zeros(image.shape, dtype=np.uint8)
                    combine_mask = cv2.fillPoly(combine_mask, self.roi_polygon, color=(255, 255, 255))
                    combined_blurred_image = np.where(combine_mask == np.array([0, 0, 0]), rod_blurred_image,
                                                      face_blurred_roi_image)

                    ##################################################################################
                    # Write to output video
                    # Start clip if exist human in the last 5 frame
                    if video_clip_flag == False:
                        if np.sum(face_dectection_window_flag) == self.face_dectection_window_size:
                            video_clip_flag = True
                            clip_frame_count = 0
                            # Set video clip file name
                            clip_start_time = orig_video_start_time + datetime.timedelta(
                                seconds=(frame_count + 1) / orig_video_fps)
                            clip_end_time = orig_video_start_time + datetime.timedelta(
                                seconds=(frame_count + video_clip_length_frame - 1) / orig_video_fps)
                            clip_file_name = '{}_{}_{}_clip.{}'.format(clip_start_time.strftime(self.video_name_time_format),
                                                                       clip_end_time.strftime(self.video_name_time_format),
                                                                       orig_video_camera, self.video_output_format)
                            #   1.2 Define video writter
                            clip_file_path = os.path.join(self.video_clip_todo_dir, clip_file_name)
                            video_clip_out = cv2.VideoWriter(clip_file_path, cv2.VideoWriter_fourcc(*self.video_fourcc),
                                                             orig_video_fps,
                                                             (video_clip_frame_width, video_clip_frame_height))
                            video_clip_out.write(combined_blurred_image)
                            clip_frame_count += 1
                    else:
                        if clip_frame_count < video_clip_length_frame:
                            video_clip_out.write(combined_blurred_image)
                            clip_frame_count += 1

                        # If reached the video clip length, reset clip flag and release video clip writer
                        if clip_frame_count == video_clip_length_frame:
                            video_clip_flag = False
                            video_clip_out.release()
                            # Compress video with ffmpeg for Web
                            compressed_clip_file_path = os.path.join(self.video_clip_todo_compressed_dir, clip_file_name)
                            print('Compressing video clip ...')
                            os.system('ffmpeg -v quiet -stats -i \"{}\" -vcodec libx264 -vf "scale=iw/2:ih/2" -preset veryslow -crf 18 -y \"{}\"'.format(
                                clip_file_path, compressed_clip_file_path))

                    # Write out to face blurred video
                    face_blurred_video_out.write(combined_blurred_image)

                    frame_count += 1  # increment frame count

                    # Log info
                    if self.display_processed_frame:
                        cv2.imshow('Face detection frame', combined_blurred_image)
                    end_time = time.time()  # get the end time
                    # get the fps
                    video_process_fps = 1 / (end_time - start_time)
                    # add fps to total fps
                    total_fps += video_process_fps
                    wait_time = max(1, int(video_process_fps / 4))
                    # press `q` to exit
                    if cv2.waitKey(wait_time) & 0xFF == ord('q'):
                        break
                else:
                    # If reached the end of the video capture, and a video clip is writing but less than the given clip length, remove the video clip.
                    if video_clip_flag is True and clip_frame_count < 0.9*video_clip_length_frame:
                        video_clip_out.release()
                        os.remove(clip_file_path)
                    else:
                        video_clip_flag = False
                        video_clip_out.release()
                        # Compress video with ffmpeg for Web
                        compressed_clip_file_path = os.path.join(self.video_clip_todo_compressed_dir, clip_file_name)
                        # import pdb; pdb.set_trace()
                        # os.system("ffmpeg -h")
                        # os.system(
                        #     'ffmpeg -v quiet -stats -i \"{}\" -vcodec libx264 -vf "scale=iw/2:ih/2" -preset veryfast -crf \"{}\" -y \"{}\"'.format(
                        #         clip_file_path, orig_video_fps, compressed_clip_file_path))
                        print('Compressing video clip ...')
                        os.system('ffmpeg -v quiet -stats -i \"{}\" -vcodec libx264 -vf "scale=iw/2:ih/2" -preset veryslow -crf 18 -y \"{}\"'.format(
                            clip_file_path, compressed_clip_file_path))
                    break

            # release VideoCapture()
            orig_video_cap.release()
            face_blurred_video_out.release()

            # Move processed origional video from to
            shutil.move(os.path.join(self.orig_video_todo_dir, orig_video_file_name),
                        os.path.join(self.orig_video_done_dir, orig_video_file_name))

            # close all frames and video windows
            cv2.destroyAllWindows()
            # calculate and print the average FPS
            avg_fps = total_fps / frame_count
            print(f"Average FPS: {avg_fps:.3f}")

    def upload_video_clip_to_cloud(self):
        """Upload video clips to Google cloud."""
        # Create bucket_name if not exist
        if self.google_storage_video_clip_bucket_name not in [bucket.name for bucket in
                                                              self.google_storage_client.list_buckets()]:
            video_clip_bucket = self.google_storage_client.create_bucket(self.google_storage_video_clip_bucket_name)
        else:
            video_clip_bucket = self.google_storage_client.bucket(self.google_storage_video_clip_bucket_name)
        # List all uploaded video clips
        video_clip_names = [video_clip.name for video_clip in
                            self.google_storage_client.list_blobs(self.google_storage_video_clip_bucket_name)]

        for i, video_clip_vetted_path in enumerate(glob.glob(os.path.join(self.video_clip_vetted_dir, '*.mp4'))):

            new_video_clip_name = os.path.basename(video_clip_vetted_path)
            if new_video_clip_name not in video_clip_names:
                video_clip_names.append(new_video_clip_name)

                # upload video clip to Google cloud
                print('Uploading {} video clip: {}'.format(i, new_video_clip_name))
                blob = video_clip_bucket.blob(new_video_clip_name)
                blob.upload_from_filename(video_clip_vetted_path)

                # Add video clip to Database: video_clip_table
                new_video_clip_url = "https://storage.googleapis.com/{}/{}".format(self.google_storage_video_clip_bucket_name, new_video_clip_name)
                print('Update video_clip_table')
                self.mem_manager.store_video_clip(new_video_clip_url, time_format=self.video_name_time_format)

                # Move video clip from video_clip_vetted_dir to video_clip_stored_dir
                shutil.move(os.path.join(self.video_clip_vetted_dir, new_video_clip_name),
                            os.path.join(self.video_clip_stored_dir, new_video_clip_name))
            else:
                print('{} video clip: {} already exists!'.format(i, new_video_clip_name))


    def _store_video_clip_to_table(self, clip_url):
        """Store the generated video clips with their corresponding experiences into the video_clip_table."""
        pass


if __name__ == '__main__':
    # To connect to Google Cloud Database,
    # TODO: Important! specify local database correctly
    local_db_config = {"drivername": "sqlite", "username": None, "password": None,
                       "database": "Step-0_Checkpoint_DB.sqlite3", "host": None, "port": None}
    cloud_db_config = {"drivername": "postgresql", "username": "postgres", "password": "mlhmlh",
                       "database": "postgres", "host": "127.0.0.1", "port": "54321"}
    experiment_checkpoint_dir = './'
    video_data_dir = 'E:/git_repos/PL-POMDP/pl/test/video_data'

    video_clipper = VideoClipGenerator(video_data_dir=video_data_dir, local_db_config=local_db_config,
                                       cloud_db_config=cloud_db_config, experiment_checkpoint_dir=experiment_checkpoint_dir)

    option = "one_way_sync_segment_table_local2cloud" # "one_way_sync_segment_table_local2cloud" # "upload_video_clip_to_cloud" # "blur_and_clip"
    if option == "blur_and_clip":
        #############################################################
        #                    Blur and Clip video                    #
        #############################################################
        video_clipper.blur_and_clip()
    elif option == "upload_video_clip_to_cloud":
        #############################################################
        #        Upload Video Clip Only After Visually Vetted       #
        #############################################################
        video_clipper.upload_video_clip_to_cloud()
    elif option == "random_experiences_for_test_purpose_only":
        ################################################
        # Random experiences for test purpose only
        ################################################
        video_start_time = '2021-10-20-15-47-13'  # '2021-10-20-13-09-48'
        video_end_time = '2021-10-20-15-47-43'    # '2021-10-20-13-10-18'
        orig_video_start_time = datetime.datetime.strptime(video_start_time, video_clipper.video_name_time_format)
        orig_video_end_time = datetime.datetime.strptime(video_end_time, video_clipper.video_name_time_format)
        while True:
            orig_video_start_time += datetime.timedelta(seconds=0.2)
            behavior_mode = 'Machine_Learning'
            obs = np.random.rand(3)
            obs_time = orig_video_start_time
            act = np.random.rand(3)
            act_time = orig_video_start_time
            rew = 0
            obs2 = np.random.rand(3)
            obs2_time = orig_video_start_time
            pb_rew, hc_rew, done = 0, 0, 0

            video_clipper.mem_manager.store_experience(obs, act, obs2, pb_rew, hc_rew, done, behavior_mode, obs_time, act_time, obs2_time)

            if orig_video_start_time >= orig_video_end_time:
                video_clipper.mem_manager.commit()
                break
    elif option == "one_way_sync_segment_table_local2cloud":
        video_clipper.mem_manager.one_way_sync_segment_table_local2cloud()
    else:
        raise ValueError("Undefined operation!")
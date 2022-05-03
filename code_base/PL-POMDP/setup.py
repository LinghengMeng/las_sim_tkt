from setuptools import setup
import sys

assert sys.version_info.major == 3 and sys.version_info.minor >= 6, \
    "The PL-POMDP repo is designed to work with Python 3.6 and greater." \
    + "Please install it before proceeding."

setup(
    name='pl',
    py_modules=['pl'],
    version='0.1',
    install_requires=[
        # 'cloudpickle==1.2.1',
        # 'gym[atari,box2d,classic_control]~=0.15.3',
        # 'ipython',
        'joblib',
        # 'matplotlib==3.1.1',
        # 'mpi4py',
        'gym==0.19.0',
        'mujoco-py',
        'numpy',
        'pybullet==3.2.0',
        'pandas',
        # 'pytest',
        # 'psutil',
        'scipy',
        # 'seaborn==0.8.1',
        # 'tqdm',
        'google-cloud-storage',
        'torch',
        'SQLAlchemy',
        'pep517',
        'python-osc',
        'psycopg2'
    ],
    description="Preference Learning in POMDP.",
    author="Lingheng Meng",
)

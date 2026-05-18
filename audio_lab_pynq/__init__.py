import os
import shutil

from .AxisSwitch import AxisSwitch
from .AudioLabOverlay import XbarSource, XbarEffect, XbarSink, AudioLabOverlay
from .AudioCodec import ADAU1761

def install_notebooks(notebook_dir=None):
    """Copy notebooks to the filesystem
    notebook_dir: str
        An optional destination filepath. If None, assume PYNQ's default
        jupyter_notebooks folder.
    """
    if notebook_dir == None:
        notebook_dir = os.environ['PYNQ_JUPYTER_NOTEBOOKS']
        if not os.path.isdir(notebook_dir):
            raise ValueError(
            f'Directory {notebook_dir} does not exist. Please supply a `notebook_dir` argument.')

    src_nb_dir = os.path.join(os.path.dirname(__file__), 'notebooks')
    src_bs_dir = os.path.join(os.path.dirname(__file__), 'bitstreams')
    dst_nb_dir = os.path.join(notebook_dir, 'audio_lab')
    dst_bs_dir = os.path.join(dst_nb_dir, 'bitstreams')
    # `shutil.copytree` with `dirs_exist_ok` is the simplest reliable copy on
    # Python 3.8+, but PYNQ-Z2 ships Python 3.6, so wipe-and-recreate is the
    # only portable option here. `distutils.dir_util.copy_tree` was used
    # previously but its module-level `_path_created` cache occasionally
    # left zero-byte files on retry; `shutil.copytree` does not have that
    # caching layer.
    if os.path.exists(dst_nb_dir):
        shutil.rmtree(dst_nb_dir)
    shutil.copytree(src_nb_dir, dst_nb_dir)
    os.makedirs(dst_bs_dir, exist_ok=True)
    for entry in os.listdir(src_bs_dir):
        src = os.path.join(src_bs_dir, entry)
        dst = os.path.join(dst_bs_dir, entry)
        if os.path.isfile(src):
            shutil.copyfile(src, dst)

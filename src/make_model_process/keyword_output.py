"""Publish prepared keyword bytes without silently replacing existing output."""
import errno
import os
from pathlib import Path
from tempfile import NamedTemporaryFile


def check_output(path,payload,overwrite=False,reuse_existing=False):
    path=Path(path)
    if path.is_dir():raise IsADirectoryError(path)
    if path.exists():
        if reuse_existing and path.read_bytes()==payload:return False
        if not overwrite:raise FileExistsError(f'Existing output differs or reuse was not requested: {path}')
    return True


def write_output(path,payload,overwrite=False,reuse_existing=False):
    path=Path(path)
    if not check_output(path,payload,overwrite,reuse_existing):return False
    path.parent.mkdir(parents=True,exist_ok=True)
    with NamedTemporaryFile(dir=path.parent,prefix='.'+path.name+'.',suffix='.tmp',delete=False) as f:
        temporary=Path(f.name);f.write(payload)
    try:
        if overwrite:
            os.replace(temporary,path)
        else:
            try:os.link(temporary,path)
            except OSError as exc:
                if exc.errno not in {errno.EPERM,errno.EOPNOTSUPP,errno.ENOSYS,errno.EXDEV}:raise
                with path.open('xb') as f:f.write(payload)
    finally:
        temporary.unlink(missing_ok=True)
    return True

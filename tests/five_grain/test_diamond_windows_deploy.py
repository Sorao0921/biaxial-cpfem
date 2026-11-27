from pathlib import Path
import sys
import pytest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from tools.preprocess import prepare_diamond_windows as windows


def test_deploy_only_two_files_and_preserve_embedded_solver_settings(tmp_path):
    files=windows.deploy_runner(tmp_path)
    assert {p.name for p in files}=={'prepare.ps1','RUN_ALL.bat'}
    assert len(list(tmp_path.iterdir()))==2
    bat=tmp_path/'RUN_ALL.bat'
    content=bat.read_text().replace(r'C:\LSDYNA\program\lsdyna_cp.exe',r'D:\my solver\lsdyna.exe').replace('DIAMOND_NCPU=16','DIAMOND_NCPU=8')
    bat.write_bytes(content.replace('\n','\r\n').encode())
    windows.deploy_runner(tmp_path,overwrite=True)
    assert r'D:\my solver\lsdyna.exe' in bat.read_text() and 'DIAMOND_NCPU=8' in bat.read_text()
    assert not list(tmp_path.rglob('*.k'))


def test_modified_runner_requires_explicit_update_before_any_copy(tmp_path):
    windows.deploy_runner(tmp_path)
    p=tmp_path/'RUN_ALL.bat';p.write_text('custom runner')
    (tmp_path/'prepare.ps1').unlink()
    with pytest.raises(FileExistsError):windows.deploy_runner(tmp_path)
    assert p.read_text()=='custom runner' and not (tmp_path/'prepare.ps1').exists()


def test_deploy_places_one_launcher_per_rho_and_retains_each_solver_setting(tmp_path):
 for rho in ['rho_-0.5','rho_0','rho_0.5','rho_1']:(tmp_path/rho).mkdir()
 (tmp_path/'other').mkdir()
 files=windows.deploy_runner(tmp_path)
 assert len(files)==6
 for rho in ['rho_-0.5','rho_0','rho_0.5','rho_1']:
  assert (tmp_path/rho/'RUN_ALL.bat').exists()
  assert not (tmp_path/rho/'prepare.ps1').exists()
 assert not (tmp_path/'other/RUN_ALL.bat').exists()
 bat=tmp_path/'rho_1/RUN_ALL.bat'
 bat.write_text(bat.read_text().replace('DIAMOND_NCPU=16','DIAMOND_NCPU=4'))
 windows.deploy_runner(tmp_path,overwrite=True)
 assert 'DIAMOND_NCPU=4' in bat.read_text()
 assert 'DIAMOND_NCPU=16' in (tmp_path/'rho_0/RUN_ALL.bat').read_text()

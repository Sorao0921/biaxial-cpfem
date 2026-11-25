"""Exercise the two-file Windows runner's PowerShell body with a fake solver."""
from pathlib import Path
import os,shutil,subprocess,sys
import pytest
ROOT=Path(__file__).resolve().parents[2]
BUNDLE=ROOT/'external/diamond_runner'
PWSH=os.environ.get('DIAMOND_PWSH') or shutil.which('pwsh')
pytestmark=pytest.mark.skipif(not PWSH or sys.platform=='win32',reason='Requires PowerShell and a POSIX fake solver')

@pytest.fixture
def dataset(tmp_path):
 root=tmp_path/'space 日本語 [diamond]';root.mkdir()
 for name in ['prepare.ps1','RUN_ALL.bat']:shutil.copy2(BUNDLE/name,root/name)
 for rho in ['-0.5','1']:
  for seed in [1,2]:
   for deg in [5,15,25]:
    folder=root/f'rho_{rho}/seed_{seed}/deg_{deg}';folder.mkdir(parents=True)
    for tex in ['goss','cube']:(folder/f'{tex}.k').write_text('*KEYWORD\n*END\n')
 (root/'diamond_center_5grains.k').write_text('not a case')
 (root/'rho_1/seed_1/keywordset.k').write_text('not a case')
 (root/'rho_1/unrelated_folder').mkdir()
 fake=root/'fake solver'
 fake.write_text('#!/usr/bin/env python3\nfrom pathlib import Path\nimport sys,os\nPath("arguments.txt").write_text(" ".join(sys.argv[1:]))\nif os.environ.get("DIAMOND_TEST_FAIL"): Path("d3hsp").write_text("Error termination");sys.exit(3)\nPath("d3hsp").write_text("still running" if os.environ.get("DIAMOND_TEST_BAD_NORMAL") else " N o r m a l    t e r m i n a t i o n\\n")\n')
 fake.chmod(0o755)
 return root

def prepare(root,*args):
 return subprocess.run([PWSH,'-NoProfile','-File',str(root/'prepare.ps1'),*args],capture_output=True,text=True)

def run(root,preview=False,retry=False,fail=False,badnormal=False,keepgoing=False):
 env=os.environ.copy()
 env.update(DIAMOND_ROOT=str(root),DIAMOND_RUNNER=str(root/'RUN_ALL.bat'),DIAMOND_SOLVER=str(root/'fake solver'),DIAMOND_NCPU='2',DIAMOND_MEMORY='1000000',DIAMOND_RETRY=str(int(retry)),DIAMOND_PREVIEW=str(int(preview)),DIAMOND_CONTINUE=str(int(keepgoing)))
 if fail:env['DIAMOND_TEST_FAIL']='1'
 if badnormal:env['DIAMOND_TEST_BAD_NORMAL']='1'
 # Execute exactly the embedded PowerShell extraction used by RUN_ALL.bat.
 command="$t=[System.IO.File]::ReadAllText($env:DIAMOND_RUNNER); $m=[Environment]::NewLine+'# POWERSHELL_BEGIN'; & ([scriptblock]::Create($t.Substring($t.IndexOf($m)+$m.Length)))"
 return subprocess.run([PWSH,'-NoProfile','-Command',command],capture_output=True,text=True,env=env)

SELECT=['-Rhos','1','-Seeds','1','-Degrees','5','-Textures','goss']

def test_move_rename_all_cases_and_repeat_without_external_dependencies(dataset):
 r=prepare(dataset,'-Preview');assert r.returncode==0 and 'Selected 24' in r.stdout,r.stdout+r.stderr
 assert not list(dataset.rglob('model.k'))
 r=prepare(dataset);assert r.returncode==0,r.stdout+r.stderr
 assert len(list(dataset.rglob('model.k')))==24
 assert not list(dataset.glob('rho_*/seed_*/deg_*/*.k'))
 assert not list(dataset.rglob('RUN_SMP.bat'))
 assert 'Prepared=0' in prepare(dataset).stdout
 assert (dataset/'diamond_center_5grains.k').read_text()=='not a case'
 assert (dataset/'rho_1/seed_1/keywordset.k').read_text()=='not a case'
 r=run(dataset,preview=True);assert r.returncode==0 and 'Selected 24 prepared' in r.stdout,r.stdout+r.stderr
 # RUN_ALL must discover model.k even after source deck names no longer exist.
 assert len([p for p in dataset.iterdir() if p.suffix in {'.ps1','.bat'}])==2

def test_single_prepared_case_normal_finish_and_skip(dataset):
 assert prepare(dataset,*SELECT).returncode==0
 r=run(dataset);assert r.returncode==0,r.stdout+r.stderr
 folder=dataset/'rho_1/seed_1/deg_5/goss/run';marker=folder/'diamond_success.json'
 assert marker.exists() and (folder/'arguments.txt').read_text()=='i=model.k ncpu=2 memory=1000000'
 t=marker.stat().st_mtime_ns
 r=run(dataset);assert r.returncode==0 and 'Skipped=1' in r.stdout and marker.stat().st_mtime_ns==t
 assert not list(dataset.rglob('diamond_run.lock'))

def test_existing_results_retry_and_duplicate_lock(dataset):
 assert prepare(dataset,*SELECT).returncode==0
 case=dataset/'rho_1/seed_1/deg_5/goss'
 r=run(dataset,fail=True);assert r.returncode!=0 and not (case/'run/diamond_success.json').exists()
 r=run(dataset);assert r.returncode!=0 and 'Existing run preserved' in r.stdout
 r=run(dataset,retry=True);assert r.returncode==0,r.stdout+r.stderr
 assert len(list((case/'archive').glob('run_*/d3hsp')))==1
 lock=case/'diamond_run.lock';lock.write_text('existing')
 r=run(dataset);assert r.returncode!=0 and lock.read_text()=='existing'

def test_zero_exit_without_termination_banner_fails(dataset):
 assert prepare(dataset,*SELECT).returncode==0
 r=run(dataset,badnormal=True);assert r.returncode!=0 and 'exit=0' in r.stdout
 assert not list(dataset.rglob('diamond_success.json'))

def test_preflight_will_not_overwrite_prepared_model(dataset):
 assert prepare(dataset,*SELECT).returncode==0
 case=dataset/'rho_1/seed_1/deg_5/goss';(case.parent/'goss.k').write_text('new source')
 r=prepare(dataset);assert r.returncode!=0
 assert (case/'model.k').read_text()=='*KEYWORD\n*END\n'
 assert (case.parent/'goss.k').read_text()=='new source'
 assert len(list(dataset.rglob('model.k')))==1

def test_unprepared_case_is_not_run_and_continue_on_error(dataset):
 r=run(dataset,preview=True);assert r.returncode!=0 and 'prepare.ps1 first' in r.stdout
 assert prepare(dataset,'-Rhos','1','-Seeds','1','-Degrees','5').returncode==0
 r=run(dataset,fail=True,keepgoing=True);assert r.returncode!=0 and 'Failed=2 NotProcessed=0' in r.stdout

from pathlib import Path
import os,shutil,subprocess
import pytest
ROOT=Path(__file__).resolve().parents[2]
PWSH=os.environ.get('DIAMOND_PWSH') or shutil.which('pwsh')
pytestmark=pytest.mark.skipif(not PWSH,reason='Requires PowerShell')
SCRIPT=ROOT/'tools/preprocess/repair_diamond_curves.ps1'
CURVE='*KEYWORD\r\n*DEFINE_CURVE\r\n1,0,1,1,0,0,0,0\r\n0,0\r\n0.016,0.00811\r\n0.333,0.00811\r\n\r\n*NODE\r\n1,0,0,0\r\n\r\n*END\r\n'


def put(path,text=CURVE):path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(text.encode())


def run(root,*args):return subprocess.run([PWSH,'-NoProfile','-File',str(SCRIPT),'-Root',str(root),*args],capture_output=True,text=True)


def test_repairs_input_copies_and_deferred_seeds_but_preserves_runs_and_backups(tmp_path):
 root=tmp_path/'diamond with space [日本語]';case=root/'rho_0/seed_1/deg_5/goss'
 paths=[case.parent/'goss.k',case/'model.k',root/'rho_0/seed_1/keywordset.k',root/'rho_0/additional/seed_21/deg_15/cube.k']
 for p in paths:put(p)
 oldrun=case/'run/model.k';put(oldrun)
 oldarchive=case/'archive/run_old/model.k';put(oldarchive)
 bat=root/'rho_0/RUN_ALL.bat';put(bat,'unchanged runner')
 original={p:p.read_bytes() for p in paths}
 r=run(root);assert r.returncode==0 and 'repair: 4' in r.stdout,r.stdout+r.stderr
 assert {p:p.read_bytes() for p in paths}==original
 r=run(root,'-Apply');assert r.returncode==0,r.stdout+r.stderr
 backups=list(root.glob('_curve_repair_backup_*'));assert len(backups)==1
 expected=CURVE.replace('0.333,0.00811\r\n\r\n*NODE','0.333,0.00811\r\n*NODE').encode()
 for p in paths:
  assert p.read_bytes()==expected
  assert (backups[0]/p.relative_to(root)).read_bytes()==original[p]
 assert oldrun.read_bytes()==CURVE.encode() and oldarchive.read_bytes()==CURVE.encode()
 assert bat.read_bytes()==b'unchanged runner'
 r=run(root,'-Apply');assert r.returncode==0 and 'repair: 0' in r.stdout,r.stdout+r.stderr
 assert len(list(root.glob('_curve_repair_backup_*')))==1


def test_nonblank_reversed_curve_stops_before_any_write(tmp_path):
 good=tmp_path/'rho_0/seed_1/deg_5/goss.k';bad=tmp_path/'rho_0/seed_2/deg_5/cube.k'
 put(good);put(bad,CURVE.replace('\r\n\r\n*NODE','\r\n0,0\r\n*NODE'))
 r=run(tmp_path,'-Apply');assert r.returncode!=0 and 'non-increasing' in r.stdout
 assert good.read_bytes()==CURVE.encode() and not list(tmp_path.glob('_curve_repair_backup_*'))

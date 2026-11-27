from pathlib import Path
import os,shutil,subprocess
import pytest
ROOT=Path(__file__).resolve().parents[2]
PWSH=os.environ.get('DIAMOND_PWSH') or shutil.which('pwsh')
pytestmark=pytest.mark.skipif(not PWSH,reason='Requires PowerShell')
SCRIPT=ROOT/'external/diamond_runner/FIX_MODEL_CURVES.bat'
CURVE='*KEYWORD\r\n*DEFINE_CURVE\r\n1,0,1,1,0,0,0,0\r\n0,0\r\n0.016,0.00811\r\n0.333,0.00811\r\n\r\n*NODE\r\n1,0,0,0\r\n\r\n*END\r\n'


def put(path,text=CURVE):path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(text.encode())


def run(root,apply=False):
 env=os.environ.copy();env.update(DIAMOND_REPAIR_ROOT=str(root),DIAMOND_REPAIR_RUNNER=str(root/'FIX_MODEL_CURVES.bat'),DIAMOND_REPAIR_APPLY=str(int(apply)))
 cmd="$t=[System.IO.File]::ReadAllText($env:DIAMOND_REPAIR_RUNNER); $m=[Environment]::NewLine+'# POWERSHELL_BEGIN'; & ([scriptblock]::Create($t.Substring($t.IndexOf($m)+$m.Length)))"
 return subprocess.run([PWSH,'-NoProfile','-Command',cmd],env=env,capture_output=True,text=True)


@pytest.mark.parametrize('at_rho',[True,False])
def test_standalone_batch_repairs_only_case_model_files_and_preserves_runs(tmp_path,at_rho):
 base=tmp_path/'diamond 日本語 [space]';base.mkdir()
 root=base/'rho_0' if at_rho else base
 root.mkdir(exist_ok=True);shutil.copy2(SCRIPT,root/'FIX_MODEL_CURVES.bat')
 seedparent=root if at_rho else root/'rho_0'
 cases=[seedparent/'seed_1/deg_5/goss/model.k',seedparent/'additional/seed_21/deg_25/cube/model.k']
 for p in cases:put(p)
 untouched=[cases[0].parent/'run/model.k',cases[0].parent/'archive/old/model.k',seedparent/'seed_1/deg_5/goss.k',seedparent/'seed_1/keywordset.k']
 for p in untouched:put(p)
 bat=root/'RUN_ALL.bat';put(bat,'do not change')
 r=run(root);assert r.returncode==0 and 'repair: 2' in r.stdout,r.stdout+r.stderr
 assert cases[0].read_bytes()==CURVE.encode()
 r=run(root,apply=True);assert r.returncode==0,r.stdout+r.stderr
 backups=list(root.glob('_curve_repair_backup_*'));assert len(backups)==1
 expected=CURVE.replace('0.333,0.00811\r\n\r\n*NODE','0.333,0.00811\r\n*NODE').encode()
 for p in cases:
  assert p.read_bytes()==expected
  assert (backups[0]/p.relative_to(root)).read_bytes()==CURVE.encode()
 for p in untouched:assert p.read_bytes()==CURVE.encode()
 assert bat.read_bytes()==b'do not change'
 r=run(root,apply=True);assert r.returncode==0 and 'repair: 0' in r.stdout,r.stdout+r.stderr
 assert len(list(root.glob('_curve_repair_backup_*')))==1

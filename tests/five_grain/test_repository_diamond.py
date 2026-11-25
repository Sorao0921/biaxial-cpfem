"""Merge supplied cards without CSV, UMAT generation, or numeric conversion."""
import hashlib
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'tools/preprocess/merge_all_diamond.py'


def put(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def prepare(tmp_path):
    keys = tmp_path/'keywords';materials = tmp_path/'partsmat';out = tmp_path/'models'
    put(keys/'consts/partset_diamond.k', '*KEYWORD\n*TITLE\nGeometry title\n*NODE\n1,0,0,0\n*ELEMENT_SOLID\n1,1,1,2,3,4,5,6,7,8\n*END\n')
    put(keys/'consts/control.k', '*KEYWORD\n*CONTROL_TERMINATION\n0.333,0\n*DATABASE_HISTORY_NODE\n1,2,3,4,5\n*END\n')
    put(keys/'consts/section.k', '*SECTION_SOLID\n1,1\n')
    for rho in [-.5,0,.5,1]:
        label=f'{rho:g}';folder=keys/f'keyword_rho_{label}'
        put(folder/f'boundary_diamond_rho_{label}.k',f'*BOUNDARY_PRESCRIBED_MOTION_SET\n102,1,0,1,1,0,1e28,0\n104,2,0,1,{rho},0,1e28,0\n')
        put(folder/f'curve_diamond_rho_{label}.k','*DEFINE_CURVE\n1,0,1,1,0,0,0,0\n0,0\n0.016,0.156\n0.333,0.156\n')
    for seed in range(1,6):
        for degree in [2,4,6,8,10]:
            put(materials/f'seed_{seed}/deg_{degree}/partsmat_goss.k',f'*KEYWORD\n*TITLE\nPartsmat title\n*PART\nGRAIN_CENTER\n1,1,1\n*MAT_USER_DEFINED_MATERIAL_MODELS_TITLE\nUSER_seed{seed}_deg{degree}\n1,0.027,43,32,300,0,3,4\n*END\n')
    return keys,materials,out


def run(keys,materials,out,*extra):
    return subprocess.run([sys.executable,str(SCRIPT),'--keywords-dir',str(keys),'--partsmat-dir',str(materials),'--output-dir',str(out),'--seeds','1','2','3','4','5','--degs','2','4','6','8','10',*extra],capture_output=True,text=True)


def fingerprints(*roots):
    return {p:hashlib.sha256(p.read_bytes()).hexdigest() for root in roots for p in root.rglob('*') if p.is_file()}


def test_full_batch_has_rho_seed_deg_order_and_only_k_outputs(tmp_path):
    keys,materials,out=prepare(tmp_path);before=fingerprints(keys,materials)
    result=run(keys,materials,out);assert result.returncode==0,result.stderr
    assert '100 written' in result.stdout
    files=[p for p in out.rglob('*') if p.is_file()]
    assert len(files)==120 and {p.suffix for p in files}=={'.k'}
    for rho in [-.5,0,.5,1]:
        for seed in range(1,6):
            parent=out/f'rho_{rho:g}/seed_{seed}'
            assert (parent/'keywordset.k').is_file()
            for degree in [2,4,6,8,10]:
                text=(parent/f'deg_{degree}/goss.k').read_text();lines=text.splitlines()
                assert lines.count('*KEYWORD')==1 and lines.count('*END')==1 and lines[-1]=='*END'
                assert '*TITLE' not in lines
                assert f'USER_seed{seed}_deg{degree}' in lines
                assert '1,0.027,43,32,300,0,3,4' in lines
                assert '*DATABASE_HISTORY_NODE\n1,2,3,4,5' in text
                assert f'104,2,0,1,{rho},0,1e28,0' in lines
                assert '0.016,0.156' in lines
    assert fingerprints(keys,materials)==before


def test_missing_input_fails_before_any_output(tmp_path):
    keys,materials,out=prepare(tmp_path)
    (materials/'seed_5/deg_10/partsmat_goss.k').unlink()
    result=run(keys,materials,out)
    assert result.returncode!=0 and 'no partsmat files' in result.stderr
    assert not out.exists()


def test_subset_and_multiple_materials(tmp_path):
    keys,materials,out=prepare(tmp_path)
    put(materials/'seed_2/deg_4/partsmat_cube.k','*KEYWORD\n*MAT_ELASTIC\n2,0.027,69000,0.3\n*END\n')
    result=run(keys,materials,out,'--rhos','0.5','--seeds','2','--degs','4')
    assert result.returncode==0,result.stderr
    assert {p.relative_to(out).as_posix() for p in out.rglob('*.k')}=={
        'rho_0.5/seed_2/keywordset.k','rho_0.5/seed_2/deg_4/goss.k','rho_0.5/seed_2/deg_4/cube.k'}


def test_existing_models_skip_until_overwrite(tmp_path):
    keys,materials,out=prepare(tmp_path);args=('--rhos','0','--seeds','1','--degs','2')
    assert run(keys,materials,out,*args).returncode==0
    model=out/'rho_0/seed_1/deg_2/goss.k';original=model.read_bytes()
    p=materials/'seed_1/deg_2/partsmat_goss.k';p.write_text(p.read_text().replace('USER_seed1_deg2','UPDATED_USER_MATERIAL'))
    result=run(keys,materials,out,*args);assert result.returncode==0 and '1 skipped' in result.stdout
    assert model.read_bytes()==original
    result=run(keys,materials,out,*args,'--overwrite');assert result.returncode==0,result.stderr
    assert 'UPDATED_USER_MATERIAL' in model.read_text()


def test_invalid_settings_do_not_write(tmp_path):
    keys,materials,out=prepare(tmp_path)
    result=run(keys,materials,out,'--degs','nan');assert result.returncode!=0
    assert not out.exists()

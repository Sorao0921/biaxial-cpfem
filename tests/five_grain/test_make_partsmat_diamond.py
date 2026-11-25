"""Verify diamond cards reuse the macro writer and feed the existing merger."""
import hashlib
from pathlib import Path
import subprocess
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.preprocess.make_partsmat import make_partsmat

SCRIPT = ROOT / 'tools/preprocess/make_partsmat_diamond.py'
MERGE = ROOT / 'tools/preprocess/merge_all_diamond.py'


def put(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def prepare(tmp_path):
    source=tmp_path/'orientation';output=tmp_path/'partsmat'
    for seed in range(1,6):
        for degree in [2,4,6,8,10]:
            ori=np.array([[0,np.pi/4,0],[.01,.77,.02],[.02,.78,.03],[.03,.79,.04],[.04,.80,.05]])
            ori[1:,0]+=seed*.001+degree*.0001
            csv=source/f'seed_{seed}/deg_{degree}/goss.csv';csv.parent.mkdir(parents=True,exist_ok=True)
            np.savetxt(csv,ori,delimiter=',',fmt='%.15g')
    return source,output


def run(source,output,*extra):
    return subprocess.run([sys.executable,str(SCRIPT),'--orientation-dir',str(source),'--partsmat-dir',str(output),'--seeds','1','2','3','4','5','--degs','2','4','6','8','10',*extra],capture_output=True,text=True)


def fingerprints(root):
    return {p:hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}


def test_card_bytes_equal_macro_writer_and_macro_source_unchanged(tmp_path):
    source,output=prepare(tmp_path);macro=ROOT/'tools/preprocess/make_partsmat.py';before=macro.read_bytes()
    result=run(source,output,'--seeds','1','--degs','2');assert result.returncode==0,result.stderr
    actual=output/'seed_1/deg_2/partsmat_goss.k';expected=tmp_path/'macro.k'
    make_partsmat(source/'seed_1/deg_2/goss.csv',expected)
    assert actual.read_bytes()==expected.read_bytes()
    lines=actual.read_text().splitlines()
    assert lines.count('*PART')==5 and lines.count('*MAT_USER_DEFINED_MATERIAL_MODELS_TITLE')==5
    for index,line in enumerate(lines):
        if line=='*MAT_USER_DEFINED_MATERIAL_MODELS_TITLE':
            header=lines[index+2];values=[float(header[i:i+10]) for i in range(0,len(header),10)]
            assert values[2:5]==[43,32,300]
    assert macro.read_bytes()==before


def test_batch_only_writes_25_material_files_and_preserves_csv(tmp_path):
    source,output=prepare(tmp_path);before=fingerprints(source)
    result=run(source,output);assert result.returncode==0,result.stderr
    files=[p for p in output.rglob('*') if p.is_file()]
    assert len(files)==25 and {p.suffix for p in files}=={'.k'}
    assert fingerprints(source)==before
    assert all((output/f'seed_{seed}/deg_{degree}/partsmat_goss.k').exists() for seed in range(1,6) for degree in [2,4,6,8,10])


def test_bad_grain_count_stops_entire_batch_before_output(tmp_path):
    source,output=prepare(tmp_path)
    np.savetxt(source/'seed_5/deg_10/goss.csv',np.zeros((4,3)),delimiter=',')
    result=run(source,output)
    assert result.returncode!=0 and '5 rows x 3 columns' in result.stderr
    assert not output.exists()


def test_existing_cards_require_explicit_overwrite(tmp_path):
    source,output=prepare(tmp_path);args=('--seeds','1','--degs','2')
    assert run(source,output,*args).returncode==0
    card=output/'seed_1/deg_2/partsmat_goss.k';before=card.read_bytes()
    csv=source/'seed_1/deg_2/goss.csv';ori=np.loadtxt(csv,delimiter=',');ori[0,0]=.125
    np.savetxt(csv,ori,delimiter=',')
    result=run(source,output,*args);assert result.returncode!=0 and 'FileExistsError' in result.stderr
    assert card.read_bytes()==before
    assert run(source,output,*args,'--overwrite').returncode==0
    assert card.read_bytes()!=before


def test_generated_cards_merge_into_all_100_rho_seed_degree_cases(tmp_path):
    source,output=prepare(tmp_path);assert run(source,output).returncode==0
    keys=tmp_path/'keywords';models=tmp_path/'models'
    put(keys/'consts/partset_diamond.k','*NODE\n1,0,0,0\n*ELEMENT_SOLID\n1,1,1,2,3,4,5,6,7,8\n')
    put(keys/'consts/control.k','*CONTROL_TERMINATION\n0.333\n')
    put(keys/'consts/section.k','*SECTION_SOLID\n1,1\n')
    for rho in [-.5,0,.5,1]:
        folder=keys/f'keyword_rho_{rho:g}'
        put(folder/f'boundary_diamond_rho_{rho:g}.k',f'*BOUNDARY_PRESCRIBED_MOTION_SET\n104,2,0,1,{rho},0,1e28,0\n')
        put(folder/f'curve_diamond_rho_{rho:g}.k','*DEFINE_CURVE\n1,0,1,1,0,0,0,0\n0,0\n0.333,0.135\n')
    result=subprocess.run([sys.executable,str(MERGE),'--keywords-dir',str(keys),'--partsmat-dir',str(output),'--output-dir',str(models),'--seeds','1','2','3','4','5','--degs','2','4','6','8','10'],capture_output=True,text=True)
    assert result.returncode==0,result.stderr
    cases=list(models.glob('rho_*/seed_*/deg_*/goss.k'));assert len(cases)==100
    assert len(list(models.rglob('*.k')))==120
    for case in cases:
        lines=case.read_text().splitlines()
        assert lines.count('*PART')==5 and lines.count('*MAT_USER_DEFINED_MATERIAL_MODELS_TITLE')==5
        assert lines.count('*KEYWORD')==1 and lines.count('*END')==1
    assert {p.suffix for p in models.rglob('*') if p.is_file()}=={'.k'}

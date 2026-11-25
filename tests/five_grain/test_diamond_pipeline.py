"""Actual MATLAB/MTEX checks for within-model mirror mixtures and downstream .k."""
from pathlib import Path
import hashlib
import subprocess
import sys

import numpy as np
import pytest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from src.config.diamond_cases import SEEDS,DEGREES,TEXTURES
from src.make_model_process.diamond_orientation import (plan_cases,generate_with_mtex,
    read_manifest,find_matlab,matlab_string)
from src.crystal_plasticity.taylor_factor import bunge_sample_to_crystal
from src.crystal_plasticity.orientation_colors import REFERENCE_EULER_DEG,cubic_rotations

PIPELINE=ROOT/'tools/preprocess/run_diamond_preprocess.py'


def keywords(root):
    def put(name,text):
        p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
    put('consts/partset_diamond.k','*NODE\n1,0,0,0\n*ELEMENT_SOLID\n1,1,1,2,3,4,5,6,7,8\n')
    put('consts/control.k','*CONTROL_TERMINATION\n0.333\n')
    put('consts/section.k','*SECTION_SOLID\n1,1\n')
    for r in [-.5,0,.5,1]:
        put(f'keyword_rho_{r:g}/boundary_diamond_rho_{r:g}.k',f'*BOUNDARY_PRESCRIBED_MOTION_SET\n104,2,0,1,{r},0,1e28,0\n')
        put(f'keyword_rho_{r:g}/curve_diamond_rho_{r:g}.k','*DEFINE_CURVE\n1,0,1,1,0,0,0,0\n0,0\n0.333,0.135\n')


@pytest.fixture(scope='module')
def generated(tmp_path_factory):
    try:find_matlab()
    except FileNotFoundError:pytest.skip('MATLAB not installed')
    root=tmp_path_factory.mktemp('mtex_diamond')
    cases=plan_cases(SEEDS,DEGREES,TEXTURES)
    manifest=generate_with_mtex(cases,root)
    return root,cases,manifest


def test_default_count_and_matlab_quoting():
    assert SEEDS==list(range(1,51))
    assert len(plan_cases(SEEDS,DEGREES,TEXTURES))==750
    assert matlab_string("a'b") == "'a''b'"
    with pytest.raises(ValueError):plan_cases([1],[float('nan')],['goss'])


def test_every_csv_matches_mtex_and_requested_variant_reference(generated):
    root,cases,manifest=generated
    assert len(manifest['records'])==750
    assert len(list(root.rglob('*.csv')))==750
    assert len(list(root.rglob('*.mat')))==1
    records={(int(r['seed']),float(r['degree']),r['texture'],int(r['sample'])):r for r in manifest['records']}
    Q=np.asarray(manifest['Q'])
    for c in cases:
        r=records[c.seed,c.degree,c.texture,c.sample]
        variants=np.asarray(r['variant_ids'],int)
        assert set(variants)=={1,2,3,4}
        assert sorted(np.bincount(variants,minlength=5)[1:])==[1,1,1,2]
        e=np.loadtxt(c.csv_path(root),delimiter=',');assert e.shape==(5,3)
        R=bunge_sample_to_crystal(e).swapaxes(1,2)
        np.testing.assert_allclose(R,np.moveaxis(r['R_crystal_to_sample'],2,0),atol=2e-12)
        ref=bunge_sample_to_crystal(np.deg2rad(REFERENCE_EULER_DEG[c.texture])).T
        refs=np.array([Q[:,:,v-1]@ref for v in variants])
        np.testing.assert_allclose(refs,np.moveaxis(r['reference_R_variant'],2,0),atol=2e-12)
        theta=np.rad2deg(np.arccos(np.clip((np.trace(R@refs.swapaxes(1,2),axis1=1,axis2=2)-1)/2,-1,1)))
        np.testing.assert_allclose(theta,c.degree,atol=2e-9)
        np.testing.assert_allclose(np.linalg.det(R),1,atol=2e-12)


def test_neighbor_matrices_and_mtex_crystal_only_misorientation(generated):
    _,_,manifest=generated;S=np.asarray(manifest['symmetry_matrices'])
    assert S.shape==(3,3,24)
    for r in manifest['records']:
        R=np.moveaxis(r['R_crystal_to_sample'],2,0);a=R[0]
        for j,b in enumerate(R[1:]):
            raw=b@a.T
            np.testing.assert_allclose(raw,r['neighbor_raw_sample_rotation'][:,:,j],atol=2e-12)
            variants=b[None]@cubic_rotations()@a.T
            traces=np.trace(variants,axis1=1,axis2=2)
            theta=np.rad2deg(np.arccos(np.clip((traces.max()-1)/2,-1,1)))
            assert theta==pytest.approx(r['neighbor_angle_deg'][j],abs=2e-8)
            index=int(r['neighbor_symmetry_operator_index'][j])-1
            np.testing.assert_allclose(b@S[:,:,index]@a.T,r['neighbor_min_sample_rotation'][:,:,j],atol=2e-12)
        assert np.asarray(r['grain_pair_ids']).shape==(8,2)
        for j,(i1,i2) in enumerate(np.asarray(r['grain_pair_ids'],int)):
            a,b=R[i1-1],R[i2-1]
            np.testing.assert_allclose(b@a.T,r['pair_raw_sample_rotation'][:,:,j],atol=2e-12)
            tr=np.trace(b[None]@cubic_rotations()@a.T,axis1=1,axis2=2).max()
            theta=np.rad2deg(np.arccos(np.clip((tr-1)/2,-1,1)))
            assert theta==pytest.approx(r['pair_angle_deg'][j],abs=2e-8)
        if r['texture']=='goss' and r['degree']==5:assert max(r['neighbor_angle_deg'])<=10+1e-7
        if r['texture']=='brass' and r['degree']==5:assert max(r['neighbor_angle_deg'])>45


def test_seed_pairing_and_reproducible_subset_preserves_full_manifest(generated):
    root,_,manifest=generated
    for seed in SEEDS:
        records=[r for r in manifest['records'] if r['seed']==seed]
        base=records[0]
        np.testing.assert_allclose(np.linalg.norm(base['axes_before_mirror'],axis=1),1,atol=1e-14)
        for r in records:
            np.testing.assert_array_equal(r['variant_ids'],base['variant_ids'])
            np.testing.assert_array_equal(r['axes_before_mirror'],base['axes_before_mirror'])
    c=plan_cases([7],[15],['s'])[0];before=c.csv_path(root).read_bytes()
    generate_with_mtex([c],root,overwrite=True)
    assert c.csv_path(root).read_bytes()==before
    assert len(read_manifest(root)['records'])==750
    with pytest.raises(FileExistsError):generate_with_mtex([c],root)


def test_actual_mtex_independent_mode_and_samples(tmp_path):
    try:find_matlab()
    except FileNotFoundError:pytest.skip('MATLAB not installed')
    cases=plan_cases([1,2],[5],['goss'],samples_per_seed=2)
    manifest=generate_with_mtex(cases,tmp_path,variant_sampling='independent')
    assert len(manifest['records'])==4
    assert (tmp_path/'seed_1/deg_5/goss_case02.csv').is_file()
    assert all(np.isin(r['variant_ids'],[1,2,3,4]).all() for r in manifest['records'])


def test_mtex_csv_to_existing_materials_to_3000_final_decks(generated,tmp_path):
    root,_,_=generated;keys=tmp_path/'keys';keywords(keys)
    original=(ROOT/'tools/preprocess/make_partsmat.py').read_bytes()
    result=subprocess.run([sys.executable,str(PIPELINE),'--orientation-dir',str(root),
        '--partsmat-dir',str(tmp_path/'mats'),'--keywords-dir',str(keys),'--output-dir',str(tmp_path/'models'),
        '--steps','materials','merge'],capture_output=True,text=True)
    assert result.returncode==0,result.stderr
    assert len(list((tmp_path/'mats').rglob('*.k')))==750
    cases=list((tmp_path/'models').glob('rho_*/seed_*/deg_*/*.k'));assert len(cases)==3000
    assert len(list((tmp_path/'models').rglob('*.k')))==3200
    for c in cases:
        lines=c.read_text().splitlines()
        assert lines.count('*PART')==5 and lines.count('*MAT_USER_DEFINED_MATERIAL_MODELS_TITLE')==5
        assert lines.count('*KEYWORD')==1 and lines.count('*END')==1
    assert (ROOT/'tools/preprocess/make_partsmat.py').read_bytes()==original


def test_missing_keywords_fail_before_matlab_or_output(tmp_path):
    result=subprocess.run([sys.executable,str(PIPELINE),'--orientation-dir',str(tmp_path/'ori'),
        '--partsmat-dir',str(tmp_path/'mats'),'--keywords-dir',str(tmp_path/'keys'),
        '--output-dir',str(tmp_path/'models'),'--seeds','1','--textures','goss','--degs','5'],capture_output=True,text=True)
    assert result.returncode!=0 and 'partset_diamond.k' in result.stderr
    assert not (tmp_path/'ori').exists() and not (tmp_path/'mats').exists() and not (tmp_path/'models').exists()

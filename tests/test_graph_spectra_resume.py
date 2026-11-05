from types import SimpleNamespace

import numpy as np
import pandas as pd
import pytest

from tools.postprocess import analyze_graph_spectra as cli


def setup_run(monkeypatch, tmp_path):
    cases = [SimpleNamespace(case_id=name, seed=1, rho=0, texture='x', sd=2,
                             state=2, spatial_model_dir=tmp_path) for name in ('old', 'new')]
    monkeypatch.setattr(cli, 'scan_outputs', lambda *a, **k: [])
    monkeypatch.setattr(cli, 'complete_cases', lambda *a: cases)
    graph = SimpleNamespace(node_ids=[1], eigenvalues=np.array([0.]), transform=lambda values: values, node_table=pd.DataFrame({'id': [1]}),
                            edge_table=pd.DataFrame({'id': [1]}))
    monkeypatch.setattr(cli, 'load_surface_graph', lambda *a, **k: graph)
    calls = []

    def load(case, graph):
        calls.append(case.case_id)
        return pd.DataFrame({'part_id': [1], 'height_std': [0.], 'height_elements': [1],
                             **{name: [0.] for name in ('height_mean', 'shear_mean', 'grain_rotation', 'gos')}})

    monkeypatch.setattr(cli, 'load_grain_signals', load)
    monkeypatch.setattr(cli, 'reconstruct_bands', lambda *a: {band: np.array([0.]) for band in ('low', 'mid', 'high')})
    monkeypatch.setattr('sys.argv', ['analyze', '--output-dir', str(tmp_path), '--skip-mode-coefficients'])
    return calls


def test_resume_adds_missing_and_repairs_incomplete_without_duplicates(monkeypatch, tmp_path):
    calls = setup_run(monkeypatch, tmp_path)
    cli.main()
    path = tmp_path / 'band_energies.csv'
    energies = pd.read_csv(path)
    energies = energies.loc[~((energies.case_id == 'new') & (energies.band == 'high'))]
    energies.to_csv(path, index=False)
    calls.clear()
    monkeypatch.setattr('sys.argv', ['analyze', '--output-dir', str(tmp_path), '--skip-mode-coefficients', '--resume'])
    cli.main()
    assert calls == ['new']
    assert pd.read_csv(path).groupby('case_id').size().to_dict() == {'new': 12, 'old': 12}
    before = path.read_bytes()
    calls.clear()
    cli.main()
    assert calls == []
    assert path.read_bytes() == before


def test_resume_failure_preserves_existing_csv(monkeypatch, tmp_path):
    setup_run(monkeypatch, tmp_path)
    cli.main()
    path = tmp_path / 'band_energies.csv'
    energies = pd.read_csv(path)
    energies.loc[energies.case_id == 'old'].to_csv(path, index=False)
    before = path.read_bytes()
    monkeypatch.setattr('sys.argv', ['analyze', '--output-dir', str(tmp_path), '--skip-mode-coefficients', '--resume'])

    def fail(*a):
        raise RuntimeError('input failure')

    monkeypatch.setattr(cli, 'load_grain_signals', fail)
    with pytest.raises(RuntimeError, match='input failure'):
        cli.main()
    assert path.read_bytes() == before

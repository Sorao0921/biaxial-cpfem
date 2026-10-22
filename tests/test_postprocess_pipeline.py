from pathlib import Path
from types import SimpleNamespace

import numpy as np
import pytest

from src.extract_process import pipeline
from src.extract_process.coordinates import process_coordinates


def test_coordinate_processing_retains_node_ids_and_reuses_output(tmp_path, monkeypatch):
    raw = tmp_path / 'coords/rawdata'
    case = raw / 'cube_sd2_seed1'
    case.mkdir(parents=True)
    source = case / 'coordinates_cube_sd2_seed1_state01.csv'
    values = np.arange(151 * 151 * 3).reshape(-1, 3)
    np.savetxt(source, values, delimiter=',')
    paths = SimpleNamespace(raw_coords_dir=raw, edge_dropped_dir=tmp_path / 'coords/edge_dropped')
    monkeypatch.setattr('src.extract_process.coordinates.build_post_directories', lambda **kw: paths)
    process_coordinates(0, 1)
    output = paths.edge_dropped_dir / case.name / source.name
    result = np.loadtxt(output, delimiter=',')
    assert result.shape == (113 * 113, 4)
    assert result[0, 0] == 19 * 151 + 20
    np.testing.assert_array_equal(result[:, 1:], values[result[:, 0].astype(int) - 1])
    timestamp = output.stat().st_mtime_ns
    process_coordinates(0, 1)
    assert output.stat().st_mtime_ns == timestamp
    assert {p.name for p in (tmp_path / 'coords').iterdir()} == {'rawdata', 'edge_dropped'}


@pytest.mark.parametrize('step, expected', [('edge', ['edge']), ('ids', ['ids']), ('all', ['edge', 'ids'])])
def test_cli_routes_steps_without_processing_other_cases(monkeypatch, step, expected):
    calls = []
    monkeypatch.setattr(pipeline, 'process_coordinates', lambda rho, seed: calls.append(('edge', rho, seed)))
    monkeypatch.setattr(pipeline, 'enrich_ids', lambda rho, seed: calls.append(('ids', rho, seed)))
    pipeline.main(['--rho', '0.5', '--seed', '2', '--step', step])
    assert calls == [(name, 0.5, 2) for name in expected]


def test_cli_requires_explicit_case():
    with pytest.raises(SystemExit) as error:
        pipeline.main([])
    assert error.value.code == 2

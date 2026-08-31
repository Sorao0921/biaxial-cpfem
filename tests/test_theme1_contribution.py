from pathlib import Path

import numpy as np
import pandas as pd
from src.dashboard.catalog import scan_outputs
from src.theme1.contribution import CaseArtifacts, estimate_contributions


def _case(tmp_path: Path, feature_weights: tuple[float, float, float]) -> CaseArtifacts:
    model = tmp_path / "spatial"
    model.mkdir()
    # Four top-surface elements with independent nodes and four grain IDs.
    elements = []
    height = []
    orientation = []
    shear = []
    rng = np.random.default_rng(7)
    for index in range(12):
        element_id = index + 1
        part_id = index + 1
        gos, rotation, gamma = rng.normal(size=3)
        roughness = (
            2.0
            + feature_weights[0] * gos
            + feature_weights[1] * rotation
            + feature_weights[2] * gamma
        )
        roughness = max(0.05, roughness)
        node_ids = list(range(index * 4 + 1, index * 4 + 5))
        x = index % 4
        y = index // 4
        for offset, node_id in enumerate(node_ids):
            height.append(
                [
                    node_id,
                    x + (offset % 2) * 0.2,
                    y + (offset // 2) * 0.2,
                    roughness * (-1 if index % 2 else 1),
                ]
            )
        elements.append([element_id, part_id, x, y, 1.0, *node_ids])
        orientation.append([part_id, gos, rotation])
        shear.append([element_id, gamma])
    pd.DataFrame(
        elements,
        columns=[
            "element_id",
            "part_id",
            "center_x",
            "center_y",
            "center_z",
            "node_id_1",
            "node_id_2",
            "node_id_3",
            "node_id_4",
        ],
    ).to_csv(model / "elements.csv", index=False)
    pd.DataFrame(height).to_csv(tmp_path / "height.csv", index=False, header=False)
    pd.DataFrame(
        orientation, columns=["part_id", "gos_deg", "grain_rotation_deg"]
    ).to_csv(tmp_path / "orientation.csv", index=False)
    pd.DataFrame(
        shear, columns=["element_id", "accumulated_shear_strain_total"]
    ).to_csv(tmp_path / "shear.csv", index=False)
    return CaseArtifacts(
        1.0,
        1,
        "cube",
        2,
        1,
        tmp_path / "height.csv",
        tmp_path / "orientation.csv",
        tmp_path / "shear.csv",
        model,
    )


def test_estimate_contributions_ranks_dominant_feature(tmp_path: Path) -> None:
    summary, cases, diagnostics = estimate_contributions(
        [_case(tmp_path, (3.0, 0.2, 0.1))]
    )
    assert summary.iloc[0]["feature"] == "gos"
    assert np.isclose(summary["relative_weight"].sum(), 1.0)
    assert diagnostics["cases"] == 1
    assert len(cases) == 1


def test_theme1_catalog_can_prefer_raw_height(tmp_path: Path) -> None:
    base = tmp_path / "rho_1" / "rho_1_seed1" / "coords"
    relative = Path("cube_sd2_seed1") / "coords_cube_sd2_seed1_state01.csv"
    for source in ("rawdata", "edge_dropped"):
        path = base / source / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("0,0,0\n", encoding="utf-8")
    records = scan_outputs(tmp_path, prefer_raw_height=True)
    assert len(records) == 1
    assert records[0].source == "rawdata"

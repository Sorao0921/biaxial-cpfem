from pathlib import Path
from src.dashboard.catalog import scan_outputs


def test_catalog_can_prefer_raw_height(tmp_path: Path) -> None:
    base = tmp_path / "rho_1" / "rho_1_seed1" / "coords"
    relative = Path("cube_sd2_seed1") / "coords_cube_sd2_seed1_state01.csv"
    for source in ("rawdata", "edge_dropped"):
        path = base / source / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("0,0,0\n", encoding="utf-8")
    records = scan_outputs(tmp_path, prefer_raw_height=True)
    assert len(records) == 1
    assert records[0].source == "rawdata"


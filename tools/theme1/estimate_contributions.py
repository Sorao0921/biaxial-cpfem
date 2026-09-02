from __future__ import annotations

import argparse
import json
from pathlib import Path

from tqdm.auto import tqdm

from src.config.pipeline_paths import OUTPUTS_DIR, SPATIAL_MODELS_DIR, THEME1_DIR
from src.dashboard.catalog import scan_outputs
from src.theme1.contribution import complete_cases, estimate_contributions


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Estimate GOS, grain-rotation, and shear-strain weights for surface roughness."
    )
    parser.add_argument("--outputs", type=Path, default=OUTPUTS_DIR)
    parser.add_argument("--spatial-models", type=Path, default=SPATIAL_MODELS_DIR)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=THEME1_DIR / "contributions",
    )
    parser.add_argument("--rho", type=float)
    parser.add_argument("--seed", type=int)
    parser.add_argument("--texture")
    parser.add_argument("--sd", type=int)
    parser.add_argument("--state", type=int)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    cases = complete_cases(
        scan_outputs(args.outputs, prefer_raw_height=True), args.spatial_models
    )
    for field in ("rho", "seed", "texture", "sd", "state"):
        value = getattr(args, field)
        if value is not None:
            cases = [case for case in cases if getattr(case, field) == value]
    if not cases:
        raise SystemExit("No cases found for the given arguments.")
    progress = tqdm(
        cases,
        total=len(cases),
        desc="Theme 1 contribution estimation",
        unit="case",
        dynamic_ncols=True,
    )
    summary, case_results, diagnostics = estimate_contributions(progress)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    summary.to_csv(args.output_dir / "contribution_weights.csv", index=False)
    case_results.to_csv(args.output_dir / "case_coefficients.csv", index=False)
    (args.output_dir / "diagnostics.json").write_text(
        json.dumps(diagnostics, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(summary.to_string(index=False))
    print(json.dumps(diagnostics, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
